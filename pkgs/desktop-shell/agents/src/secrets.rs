//! org.freedesktop.NetworkManager.SecretAgent (nm-applet's applet-agent.c):
//! NetworkManager calls GetSecrets whenever a connection needs a password it
//! doesn't have: first connect to a new network, wrong / changed password
//! (REQUEST_NEW), 802.1X, VPN, PPPoE, mobile broadband. Agent-owned secrets
//! live in the keyring (keyring.rs); system-owned ones NM stores itself.

use crate::dbus::value_to_json;
use crate::keyring::Keyring;
use crate::nm::{conn_id, conn_uuid, ssid_text, bytes, NM, NM_PATH};
use crate::prompter::{Answer, Prompter};
use futures_util::StreamExt;
use serde_json::{json, Map, Value as Json};
use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use zbus::zvariant::{ObjectPath, OwnedValue, Value};
use zbus::{interface, Connection};

const AGENT_PATH: &str = "/org/freedesktop/NetworkManager/SecretAgent";
const AGENT_ID: &str = "org.shell.network";

const F_ALLOW_INTERACTION: u32 = 0x1;
const F_REQUEST_NEW: u32 = 0x2;
const F_WPS_PBC_ACTIVE: u32 = 0x8;
const AGENT_OWNED: u64 = 1;

#[derive(Debug, zbus::DBusError)]
#[zbus(prefix = "org.freedesktop.NetworkManager.SecretAgent")]
pub enum AgentError {
    #[zbus(error)]
    ZBus(zbus::Error),
    NoSecrets(String),
    UserCanceled(String),
    AgentCanceled(String),
    Failed(String),
    InvalidConnection(String),
}

type Dict = HashMap<String, HashMap<String, OwnedValue>>;

fn dict_to_json(d: &Dict) -> Json {
    let mut out = Map::new();
    for (setting, props) in d {
        let mut m = Map::new();
        for (k, v) in props {
            m.insert(k.clone(), value_to_json(v));
        }
        out.insert(setting.clone(), Json::Object(m));
    }
    Json::Object(out)
}

fn owned(v: Value<'_>) -> OwnedValue {
    v.try_to_owned().expect("no fds")
}

fn strings(setting: &str, m: &HashMap<String, String>) -> Dict {
    let inner = m.iter().map(|(k, v)| (k.clone(), owned(Value::from(v.as_str())))).collect();
    HashMap::from([(setting.to_string(), inner)])
}

// ---- prompt construction ---------------------------------------------------------

fn setting<'a>(c: &'a Json, name: &str) -> Option<&'a Json> {
    c.get(name)
}

fn secret_of(c: &Json, setting_name: &str, key: &str) -> Option<String> {
    c.get(setting_name)?.get(key)?.as_str().filter(|s| !s.is_empty()).map(String::from)
}

fn field(key: &str, label: &str, password: bool, validate: &str, value: Option<String>) -> Json {
    json!({"key": key, "label": label, "password": password, "validate": validate, "value": value})
}

/// The form for one `setting` of connection `c` (None: nothing to ask).
pub fn build_prompt(c: &Json, path: &str, setting_name: &str, hints: &[String], flags: u32) -> Option<Json> {
    let id = conn_id(c);
    let ctype = c.get("connection").and_then(|s| s.get("type")).and_then(Json::as_str).unwrap_or_default();
    let ssid = ssid_text(&bytes(c.get("802-11-wireless").and_then(|s| s.get("ssid"))));
    let is_wifi = ctype == "802-11-wireless";
    let note = (flags & F_REQUEST_NEW != 0).then_some("The previous secret was not accepted. Please try again.");
    let mut fields: Vec<Json> = vec![];
    let mut title = "Authentication Required".to_string();
    let mut message = format!("Secrets are required to connect to “{id}”.");
    let mut icon = "dialog-password-symbolic".to_string();
    let name = if ssid.is_empty() { id.clone() } else { ssid.clone() };

    match setting_name {
        "802-11-wireless-security" => {
            let s = setting(c, "802-11-wireless-security");
            let km = s.and_then(|s| s.get("key-mgmt")).and_then(Json::as_str).unwrap_or_default();
            title = "Wi-Fi Network Authentication Required".into();
            message = format!("Passwords or encryption keys are required to access the Wi-Fi network “{name}”.");
            icon = "network-wireless-encrypted-symbolic".into();
            if flags & F_WPS_PBC_ACTIVE != 0 {
                message.push_str(" You can also push the WPS button on your router.");
            }
            if km == "wpa-psk" {
                fields.push(field("psk", "Password", true, "psk", secret_of(c, "802-11-wireless-security", "psk")));
            } else if km == "sae" {
                fields.push(field("psk", "Password", true, "nonempty", secret_of(c, "802-11-wireless-security", "psk")));
            } else if s.and_then(|s| s.get("auth-alg")).and_then(Json::as_str) == Some("leap") {
                let user = s.and_then(|s| s.get("leap-username")).and_then(Json::as_str).unwrap_or_default();
                message = format!("LEAP password for “{user}” on “{name}”.");
                fields.push(field("leap-password", "Password", true, "nonempty", None));
            } else if km == "none" {
                let idx = s.and_then(|s| s.get("wep-tx-keyidx")).and_then(Json::as_u64).unwrap_or(0);
                let passphrase = s.and_then(|s| s.get("wep-key-type")).and_then(Json::as_u64) == Some(2);
                let key = format!("wep-key{idx}");
                fields.push(field(
                    &key,
                    if passphrase { "WEP passphrase" } else { "WEP key" },
                    true,
                    if passphrase { "wep-passphrase" } else { "wep" },
                    secret_of(c, "802-11-wireless-security", &key),
                ));
            }
        }
        "802-1x" => {
            let s = setting(c, "802-1x");
            let eap = s.and_then(|s| s.get("eap")).and_then(Json::as_array).and_then(|a| a.first()).and_then(Json::as_str).unwrap_or_default();
            title = if is_wifi { "Wi-Fi Network Authentication Required" } else { "Wired 802.1X Authentication" }.into();
            message = if is_wifi {
                format!("Authentication is required to access the Wi-Fi network “{name}”.")
            } else {
                format!("Authentication is required to access the network “{id}”.")
            };
            icon = if is_wifi { "network-wireless-encrypted-symbolic" } else { "network-wired-symbolic" }.into();
            if eap == "tls" {
                fields.push(field("private-key-password", "Private key password", true, "", None));
            } else {
                let identity = s.and_then(|s| s.get("identity")).and_then(Json::as_str).unwrap_or_default();
                if identity.is_empty() {
                    fields.push(field("identity", "Username", false, "nonempty", None));
                } else {
                    message.push_str(&format!(" (as {identity})"));
                }
                fields.push(field("password", "Password", true, "nonempty", None));
            }
        }
        "pppoe" => {
            let user = setting(c, "pppoe").and_then(|s| s.get("username")).and_then(Json::as_str).unwrap_or(&id);
            title = "DSL Authentication".into();
            message = format!("A password is required for “{user}”.");
            icon = "network-wired-symbolic".into();
            fields.push(field("password", "Password", true, "", None));
        }
        "gsm" | "cdma" => {
            icon = "network-cellular-symbolic".into();
            if hints.iter().any(|h| h == "pin") {
                title = "SIM PIN Required".into();
                message = format!("The mobile broadband connection “{id}” requires a SIM PIN.");
                fields.push(field("pin", "PIN code", true, "pin", None));
            } else {
                title = "Mobile Broadband Network Password".into();
                message = format!("A password is required to connect to “{id}”.");
                fields.push(field("password", "Password", true, "", None));
            }
        }
        "wireguard" => {
            title = "WireGuard Key Required".into();
            message = format!("The WireGuard connection “{id}” needs its private key.");
            icon = "network-vpn-symbolic".into();
            fields.push(field("private-key", "Private key", true, "nonempty", None));
        }
        other => {
            if other == "vpn" {
                icon = "network-vpn-symbolic".into();
            }
            for h in hints.iter().filter(|h| !h.starts_with("x-")) {
                fields.push(field(h, h, true, "", None));
            }
            if fields.is_empty() {
                fields.push(field("password", "Password", true, "", None));
            }
        }
    }
    if fields.is_empty() {
        return None;
    }
    Some(json!({"kind": "secrets", "path": path, "setting": setting_name, "title": title, "message": message,
                "icon": icon, "fields": fields, "note": note}))
}

// ---- VPN auth dialog -----------------------------------------------------------------
// VPN secrets come from the plugin's own auth-dialog (nm-openvpn-auth-dialog,
// ...), driven with the same stdin/stdout protocol nm-applet uses
// (applet-vpn-request.c, non-external-UI mode):
//   stdin:  DATA_KEY=k / DATA_VAL=v / SECRET_KEY=k / SECRET_VAL=v ... DONE, QUIT
//   stdout: key\nvalue\n pairs, terminated by an empty line
// A non-zero exit status means the user cancelled.

pub enum VpnError {
    Cancelled,
    Failed(String),
}

fn plugin_dirs() -> Vec<PathBuf> {
    let mut v: Vec<PathBuf> = std::env::var("NM_VPN_PLUGIN_DIR").ok().map(PathBuf::from).into_iter().collect();
    for d in [
        "/etc/NetworkManager/VPN",
        "/run/current-system/sw/lib/NetworkManager/VPN",
        "/usr/lib/NetworkManager/VPN",
        "/usr/lib64/NetworkManager/VPN",
    ] {
        v.push(PathBuf::from(d));
    }
    v.push(crate::util::home().join(".nix-profile/lib/NetworkManager/VPN"));
    v
}

/// Auth-dialog binary for a VPN service type, from the plugins' `.name` files.
pub fn auth_dialog_for(service: &str) -> Option<PathBuf> {
    for dir in plugin_dirs() {
        let Ok(rd) = std::fs::read_dir(&dir) else { continue };
        for e in rd.flatten() {
            let p = e.path();
            if p.extension().and_then(|s| s.to_str()) != Some("name") {
                continue;
            }
            let Ok(text) = std::fs::read_to_string(&p) else { continue };
            if let Some(d) = parse_name_file(&text, service) {
                return resolve_dialog(&d, &p);
            }
        }
    }
    None
}

pub fn parse_name_file(text: &str, service: &str) -> Option<String> {
    let (mut section, mut svc, mut dialog) = (String::new(), None, None);
    for l in text.lines() {
        let l = l.trim();
        if let Some(s) = l.strip_prefix('[').and_then(|s| s.strip_suffix(']')) {
            section = s.to_string();
        } else if let Some((k, v)) = l.split_once('=') {
            match (section.as_str(), k.trim()) {
                ("VPN Connection", "service") => svc = Some(v.trim().to_string()),
                ("GNOME", "auth-dialog") => dialog = Some(v.trim().to_string()),
                _ => {}
            }
        }
    }
    (svc.as_deref() == Some(service)).then_some(dialog?)
}

fn resolve_dialog(d: &str, name_file: &std::path::Path) -> Option<PathBuf> {
    let p = PathBuf::from(d);
    if p.is_absolute() {
        return p.exists().then_some(p);
    }
    let mut cands: Vec<PathBuf> = vec![];
    if let Some(dir) = name_file.parent().and_then(|p| std::fs::canonicalize(p).ok()) {
        // <prefix>/lib/NetworkManager/VPN -> <prefix>/{libexec,lib/NetworkManager}
        if let Some(prefix) = dir.ancestors().nth(3) {
            cands.push(prefix.join("libexec").join(d));
            cands.push(prefix.join("lib/NetworkManager").join(d));
        }
    }
    if let Some(path) = std::env::var_os("PATH") {
        cands.extend(std::env::split_paths(&path).map(|p| p.join(d)));
    }
    cands.push(PathBuf::from("/usr/lib/NetworkManager").join(d));
    cands.push(PathBuf::from("/run/current-system/sw/libexec").join(d));
    cands.into_iter().find(|c| c.exists())
}

async fn run_auth_dialog(
    c: &Json,
    stored: &HashMap<String, String>,
    hints: &[String],
    flags: u32,
) -> Option<Result<HashMap<String, String>, VpnError>> {
    let vpn = c.get("vpn")?;
    let service = vpn.get("service-type")?.as_str()?;
    let dialog = auth_dialog_for(service)?;
    let mut args = vec![
        "-u".to_string(), conn_uuid(c), "-n".to_string(), conn_id(c), "-s".to_string(), service.to_string(),
    ];
    if flags & F_ALLOW_INTERACTION != 0 {
        args.push("-i".into());
    }
    if flags & F_REQUEST_NEW != 0 {
        args.push("-r".into());
    }
    for h in hints {
        args.push("-t".into());
        args.push(h.clone());
    }
    let line = |tag: &str, v: &str| format!("{tag}={}\n\n", v.replace('\n', "\\n"));
    let mut input = String::new();
    if let Some(d) = vpn.get("data").and_then(Json::as_object) {
        for (k, v) in d {
            input += &line("DATA_KEY", k);
            input += &line("DATA_VAL", v.as_str().unwrap_or_default());
        }
    }
    let mut secrets: HashMap<String, String> = vpn
        .get("secrets")
        .and_then(Json::as_object)
        .map(|m| m.iter().filter_map(|(k, v)| v.as_str().map(|s| (k.clone(), s.to_string()))).collect())
        .unwrap_or_default();
    secrets.extend(stored.clone());
    for (k, v) in &secrets {
        input += &line("SECRET_KEY", k);
        input += &line("SECRET_VAL", v);
    }
    input += "DONE\n\nQUIT\n\n";

    use tokio::io::AsyncWriteExt;
    let child = tokio::process::Command::new(dialog)
        .args(&args)
        .stdin(std::process::Stdio::piped())
        .stdout(std::process::Stdio::piped())
        .spawn();
    let mut child = match child {
        Ok(c) => c,
        Err(e) => return Some(Err(VpnError::Failed(e.to_string()))),
    };
    if let Some(mut stdin) = child.stdin.take() {
        let _ = stdin.write_all(input.as_bytes()).await;
    }
    let out = match child.wait_with_output().await {
        Ok(o) => o,
        Err(e) => return Some(Err(VpnError::Failed(e.to_string()))),
    };
    if !out.status.success() {
        return Some(Err(VpnError::Cancelled));
    }
    Some(Ok(parse_dialog_output(&String::from_utf8_lossy(&out.stdout))))
}

pub fn parse_dialog_output(text: &str) -> HashMap<String, String> {
    let lines: Vec<&str> = text.split('\n').collect();
    let mut m = HashMap::new();
    let mut i = 0;
    while i + 1 < lines.len() && !lines[i].is_empty() {
        m.insert(lines[i].to_string(), lines[i + 1].to_string());
        i += 2;
    }
    m
}

// ---- the agent ---------------------------------------------------------------------------

const SECRET_KEYS: &[(&str, &[&str])] = &[
    ("802-11-wireless-security", &["psk", "wep-key0", "wep-key1", "wep-key2", "wep-key3", "leap-password"]),
    ("802-1x", &["password", "private-key-password", "phase2-private-key-password", "pin"]),
    ("pppoe", &["password"]),
    ("gsm", &["password", "pin"]),
    ("cdma", &["password"]),
    ("wireguard", &["private-key"]),
];

/// Secret flags from "<key>-flags" (WEP keys share "wep-key-flags"; VPN keeps
/// per-secret flags as "<key>-flags" data items).
fn secret_flags(c: &Json, setting_name: &str, key: &str) -> u64 {
    if setting_name == "vpn" {
        return c["vpn"]["data"][format!("{key}-flags")].as_str().and_then(|s| s.parse().ok()).unwrap_or(0);
    }
    let k = if key.len() == 8 && key.starts_with("wep-key") && key.as_bytes()[7].is_ascii_digit() {
        "wep-key-flags".to_string()
    } else {
        format!("{key}-flags")
    };
    c.get(setting_name).and_then(|s| s.get(&k)).and_then(Json::as_u64).unwrap_or(0)
}

struct Pending {
    path: String,
    setting: String,
    cancelled: bool,
}

pub struct SecretAgent {
    conn: Connection,
    prompter: Prompter,
    keyring: Arc<Keyring>,
    serial: tokio::sync::Mutex<()>,
    pending: Mutex<Vec<(u64, Pending)>>,
    next: Mutex<u64>,
}

impl SecretAgent {
    fn is_cancelled(&self, id: u64) -> bool {
        self.pending.lock().unwrap().iter().any(|(i, p)| *i == id && p.cancelled)
    }

    async fn vpn_secrets(&self, c: &Json, path: &str, hints: &[String], flags: u32) -> Result<Dict, AgentError> {
        let uuid = conn_uuid(c);
        let stored = if flags & F_REQUEST_NEW != 0 { HashMap::new() } else { self.keyring.lookup(&uuid, "vpn").await };
        let wrap = |m: &HashMap<String, String>| -> Dict {
            let v: HashMap<String, OwnedValue> = HashMap::from([("secrets".to_string(), owned(Value::from(m.clone())))]);
            HashMap::from([("vpn".to_string(), v)])
        };
        match run_auth_dialog(c, &stored, hints, flags).await {
            Some(Ok(secrets)) => return Ok(wrap(&secrets)),
            Some(Err(VpnError::Cancelled)) => return Err(AgentError::UserCanceled("User cancelled".into())),
            Some(Err(VpnError::Failed(e))) => return Err(AgentError::Failed(format!("VPN auth dialog failed: {e}"))),
            None => {}
        }
        if !stored.is_empty() {
            return Ok(wrap(&stored));
        }
        if flags & F_ALLOW_INTERACTION == 0 {
            return Err(AgentError::NoSecrets("No stored VPN secrets".into()));
        }
        // No auth-dialog installed for this plugin: ask for the hinted secrets ourselves.
        let mut prompt = build_prompt(c, path, "vpn", hints, flags).unwrap();
        prompt["title"] = json!("VPN Password");
        prompt["message"] = json!(format!("Secrets are required to connect to the VPN “{}”.", conn_id(c)));
        match self.prompter.ask(prompt).await {
            Answer::Fields(f) => Ok(wrap(&f)),
            Answer::Cancel => Err(AgentError::AgentCanceled("Cancelled".into())),
            _ => Err(AgentError::UserCanceled("User cancelled".into())),
        }
    }

    async fn secrets_for(&self, id: u64, c: Json, path: &str, setting_name: &str, hints: &[String], flags: u32) -> Result<Dict, AgentError> {
        let _turn = self.serial.lock().await; // prompts are shown one after another
        if self.is_cancelled(id) {
            return Err(AgentError::AgentCanceled("Cancelled".into()));
        }
        if setting_name == "vpn" {
            return self.vpn_secrets(&c, path, hints, flags).await;
        }
        // Agent-owned secrets we already have in the keyring.
        if flags & F_REQUEST_NEW == 0 {
            let stored = self.keyring.lookup(&conn_uuid(&c), setting_name).await;
            if !stored.is_empty() {
                return Ok(strings(setting_name, &stored));
            }
        }
        if flags & F_ALLOW_INTERACTION == 0 {
            return Err(AgentError::NoSecrets("No secrets and interaction not allowed".into()));
        }
        let Some(prompt) = build_prompt(&c, path, setting_name, hints, flags) else {
            return Ok(HashMap::new()); // nothing to ask (e.g. OWE)
        };
        match self.prompter.ask(prompt).await {
            Answer::Fields(mut f) => {
                // 802.1X username isn't a secret: write it into the saved connection.
                if let Some(identity) = f.remove("identity").filter(|s| !s.is_empty()) {
                    if let Err(e) = self.save_identity(path, &identity).await {
                        eprintln!("network: saving identity failed: {e}");
                    }
                }
                Ok(strings(setting_name, &f))
            }
            Answer::Cancel => Err(AgentError::AgentCanceled("Cancelled".into())),
            _ => Err(AgentError::UserCanceled("User cancelled".into())),
        }
    }

    async fn save_identity(&self, path: &str, identity: &str) -> zbus::Result<()> {
        let iface = "org.freedesktop.NetworkManager.Settings.Connection";
        let msg = self.conn.call_method(Some(NM), path, Some(iface), "GetSettings", &()).await?;
        let body = msg.body();
        let mut settings: Dict = body.deserialize()?;
        let Some(s) = settings.get_mut("802-1x") else { return Ok(()) };
        s.insert("identity".into(), owned(Value::from(identity)));
        self.conn.call_method(Some(NM), path, Some(iface), "Update", &(settings,)).await?;
        Ok(())
    }
}

#[interface(name = "org.freedesktop.NetworkManager.SecretAgent")]
impl SecretAgent {
    async fn get_secrets(
        &self,
        connection: Dict,
        connection_path: ObjectPath<'_>,
        setting_name: String,
        hints: Vec<String>,
        flags: u32,
    ) -> Result<Dict, AgentError> {
        let c = dict_to_json(&connection);
        let path = connection_path.to_string();
        let id = {
            let mut n = self.next.lock().unwrap();
            *n += 1;
            *n
        };
        self.pending.lock().unwrap().push((id, Pending { path: path.clone(), setting: setting_name.clone(), cancelled: false }));
        let r = self.secrets_for(id, c, &path, &setting_name, &hints, flags).await;
        self.pending.lock().unwrap().retain(|(i, _)| *i != id);
        r
    }

    fn cancel_get_secrets(&self, connection_path: ObjectPath<'_>, setting_name: String) {
        for (_, p) in self.pending.lock().unwrap().iter_mut() {
            if p.path == connection_path.as_str() && p.setting == setting_name {
                p.cancelled = true;
            }
        }
        // clear a prompt about exactly this request
        self.prompter.cancel_current(Some(connection_path.as_str()));
    }

    async fn save_secrets(&self, connection: Dict, _connection_path: ObjectPath<'_>) -> Result<(), AgentError> {
        let c = dict_to_json(&connection);
        let (uuid, id) = (conn_uuid(&c), conn_id(&c));
        self.keyring.clear(&uuid, None).await;
        for (name, keys) in SECRET_KEYS {
            for key in *keys {
                if let Some(v) = secret_of(&c, name, key) {
                    if secret_flags(&c, name, key) == AGENT_OWNED {
                        self.keyring.store(&uuid, &id, name, key, &v).await;
                    }
                }
            }
        }
        if let Some(secrets) = c["vpn"]["secrets"].as_object() {
            for (k, v) in secrets {
                if let Some(v) = v.as_str().filter(|s| !s.is_empty()) {
                    if secret_flags(&c, "vpn", k) == AGENT_OWNED {
                        self.keyring.store(&uuid, &id, "vpn", k, v).await;
                    }
                }
            }
        }
        Ok(())
    }

    async fn delete_secrets(&self, connection: Dict, _connection_path: ObjectPath<'_>) -> Result<(), AgentError> {
        self.keyring.clear(&conn_uuid(&dict_to_json(&connection)), None).await;
        Ok(())
    }
}

async fn register(conn: &Connection) {
    // VPN_HINTS capability = 1
    let r = conn
        .call_method(
            Some(NM),
            format!("{NM_PATH}/AgentManager"),
            Some("org.freedesktop.NetworkManager.AgentManager"),
            "RegisterWithCapabilities",
            &(AGENT_ID, 1u32),
        )
        .await;
    if let Err(e) = r {
        eprintln!("network: agent registration failed: {e}");
    }
}

/// Export the agent and (re-)register whenever NetworkManager (re)appears.
pub async fn run(system: Connection, session: Connection, prompter: Prompter) -> zbus::Result<()> {
    let agent = SecretAgent {
        conn: system.clone(),
        prompter: prompter.clone(),
        keyring: Arc::new(Keyring::new(session)),
        serial: tokio::sync::Mutex::new(()),
        pending: Mutex::new(vec![]),
        next: Mutex::new(0),
    };
    system.object_server().at(AGENT_PATH, agent).await?;
    let dbus = zbus::fdo::DBusProxy::new(&system).await?;
    let mut owner = dbus.receive_name_owner_changed_with_args(&[(0, NM)]).await?;
    if dbus.name_has_owner(NM.try_into().unwrap()).await.unwrap_or(false) {
        register(&system).await;
    }
    while let Some(sig) = owner.next().await {
        let Ok(args) = sig.args() else { continue };
        if args.new_owner().is_some() {
            register(&system).await;
        } else {
            prompter.cancel_current(None);
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn psk_prompt() {
        let c = json!({"connection": {"id": "Home", "uuid": "u", "type": "802-11-wireless"},
                       "802-11-wireless": {"ssid": b"Home".to_vec()},
                       "802-11-wireless-security": {"key-mgmt": "wpa-psk"}});
        let p = build_prompt(&c, "/c/1", "802-11-wireless-security", &[], F_ALLOW_INTERACTION | F_REQUEST_NEW).unwrap();
        assert_eq!(p["kind"], "secrets");
        assert_eq!(p["fields"][0]["key"], "psk");
        assert_eq!(p["fields"][0]["validate"], "psk");
        assert!(p["message"].as_str().unwrap().contains("“Home”"));
        assert!(p["note"].is_string());
    }

    #[test]
    fn eap_asks_for_identity_only_when_missing() {
        let mut c = json!({"connection": {"id": "Corp", "uuid": "u", "type": "802-11-wireless"},
                           "802-1x": {"eap": ["peap"]}});
        let p = build_prompt(&c, "/c", "802-1x", &[], 1).unwrap();
        assert_eq!(p["fields"].as_array().unwrap().len(), 2);
        c["802-1x"]["identity"] = json!("bob");
        let p = build_prompt(&c, "/c", "802-1x", &[], 1).unwrap();
        assert_eq!(p["fields"].as_array().unwrap().len(), 1);
        assert!(p["message"].as_str().unwrap().contains("as bob"));
    }

    #[test]
    fn owe_has_nothing_to_ask() {
        let c = json!({"connection": {"id": "x", "uuid": "u", "type": "802-11-wireless"},
                       "802-11-wireless-security": {"key-mgmt": "owe"}});
        assert!(build_prompt(&c, "/c", "802-11-wireless-security", &[], 1).is_none());
    }

    #[test]
    fn flags_and_dialog_protocol() {
        let c = json!({"802-11-wireless-security": {"psk-flags": 1, "wep-key-flags": 1},
                       "vpn": {"data": {"password-flags": "1"}}});
        assert_eq!(secret_flags(&c, "802-11-wireless-security", "psk"), 1);
        assert_eq!(secret_flags(&c, "802-11-wireless-security", "wep-key2"), 1);
        assert_eq!(secret_flags(&c, "vpn", "password"), 1);
        assert_eq!(secret_flags(&c, "vpn", "other"), 0);
        let m = parse_dialog_output("password\nhunter2\nuser\nbob\n\n");
        assert_eq!(m["password"], "hunter2");
        assert_eq!(m["user"], "bob");
    }

    #[test]
    fn name_file() {
        let t = "[VPN Connection]\nname=openvpn\nservice=org.freedesktop.NetworkManager.openvpn\n[GNOME]\nauth-dialog=nm-openvpn-auth-dialog\n";
        assert_eq!(parse_name_file(t, "org.freedesktop.NetworkManager.openvpn").as_deref(), Some("nm-openvpn-auth-dialog"));
        assert!(parse_name_file(t, "other").is_none());
    }
}
