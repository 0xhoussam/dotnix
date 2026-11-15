//! NetworkManager model: a cache of the D-Bus objects we care about, kept
//! current from PropertiesChanged and the NM-specific add/remove signals,
//! plus a pure `snapshot` that turns it into the JSON the UI renders.
//! (Replaces libnm: pure-Rust D-Bus only.)

use crate::dbus::{get_all, value_to_json};
use futures_util::StreamExt;
use serde_json::{json, Map, Value as Json};
use std::collections::{HashMap, HashSet};
use std::sync::{Arc, Mutex};
use tokio::sync::Notify;
use zbus::zvariant::{OwnedObjectPath, Value};
use zbus::Connection;

pub const NM: &str = "org.freedesktop.NetworkManager";
pub const NM_PATH: &str = "/org/freedesktop/NetworkManager";
pub const SETTINGS_PATH: &str = "/org/freedesktop/NetworkManager/Settings";

const I_NM: &str = "org.freedesktop.NetworkManager";
const I_DEV: &str = "org.freedesktop.NetworkManager.Device";
const I_WIFI: &str = "org.freedesktop.NetworkManager.Device.Wireless";
const I_WIRED: &str = "org.freedesktop.NetworkManager.Device.Wired";
const I_AP: &str = "org.freedesktop.NetworkManager.AccessPoint";
const I_AC: &str = "org.freedesktop.NetworkManager.Connection.Active";
const I_IP4: &str = "org.freedesktop.NetworkManager.IP4Config";
const I_IP6: &str = "org.freedesktop.NetworkManager.IP6Config";

type Props = HashMap<String, Json>;

#[derive(Default)]
pub struct Store {
    /// path -> interface -> properties
    objs: HashMap<String, HashMap<String, Props>>,
    /// saved connections: path -> GetSettings (setting -> key -> value)
    pub conns: HashMap<String, Json>,
    pub running: bool,
}

pub type Shared = Arc<Mutex<Store>>;

impl Store {
    fn get(&self, path: &str, iface: &str) -> Option<&Props> {
        self.objs.get(path)?.get(iface)
    }
    fn prop(&self, path: &str, iface: &str, key: &str) -> Option<&Json> {
        self.get(path, iface)?.get(key)
    }
    fn str_(&self, path: &str, iface: &str, key: &str) -> String {
        self.prop(path, iface, key).and_then(Json::as_str).unwrap_or_default().to_string()
    }
    fn u(&self, path: &str, iface: &str, key: &str) -> u64 {
        self.prop(path, iface, key).and_then(Json::as_u64).unwrap_or(0)
    }
    fn b(&self, path: &str, iface: &str, key: &str) -> bool {
        self.prop(path, iface, key).and_then(Json::as_bool).unwrap_or(false)
    }
    fn paths(&self, path: &str, iface: &str, key: &str) -> Vec<String> {
        self.prop(path, iface, key)
            .and_then(Json::as_array)
            .map(|a| a.iter().filter_map(|v| v.as_str().map(String::from)).collect())
            .unwrap_or_default()
    }
    fn path(&self, path: &str, iface: &str, key: &str) -> Option<String> {
        let s = self.str_(path, iface, key);
        (!s.is_empty() && s != "/").then_some(s)
    }

    /// ActiveConnection State, None when the object is gone.
    pub fn ac_state(&self, ac: &str) -> Option<u64> {
        self.prop(ac, I_AC, "State").and_then(Json::as_u64)
    }
    /// Reason of the device's last state change.
    pub fn device_reason(&self, dev: &str) -> u64 {
        self.prop(dev, I_DEV, "StateReason").and_then(Json::as_array).and_then(|a| a.get(1)).and_then(Json::as_u64).unwrap_or(0)
    }

    pub fn merge(&mut self, path: &str, iface: &str, changed: Props) {
        self.objs.entry(path.to_string()).or_default().entry(iface.to_string()).or_default().extend(changed);
    }
    pub fn insert(&mut self, path: &str, iface: &str, props: Props) {
        self.objs.entry(path.to_string()).or_default().insert(iface.to_string(), props);
    }
    pub fn has(&self, path: &str) -> bool {
        self.objs.contains_key(path)
    }

    /// Paths referenced from the root that must be loaded.
    pub fn wanted(&self) -> HashSet<String> {
        let mut want = HashSet::new();
        for d in self.paths(NM_PATH, I_NM, "AllDevices") {
            want.extend(self.paths(&d, I_WIFI, "AccessPoints"));
            if let Some(ap) = self.path(&d, I_WIFI, "ActiveAccessPoint") {
                want.insert(ap);
            }
            want.insert(d);
        }
        for ac in self.paths(NM_PATH, I_NM, "ActiveConnections") {
            for k in ["Ip4Config", "Ip6Config"] {
                if let Some(c) = self.path(&ac, I_AC, k) {
                    want.insert(c);
                }
            }
            want.insert(ac);
        }
        want
    }
}

// ---- constants & small helpers --------------------------------------------------

const DEV_ETHERNET: u64 = 1;
const DEV_WIFI: u64 = 2;
const DEV_BT: u64 = 5;
const DEV_MODEM: u64 = 8;

const ST_UNMANAGED: u64 = 10;
const ST_UNAVAILABLE: u64 = 20;
const ST_DISCONNECTED: u64 = 30;
const ST_PREPARE: u64 = 40;
const ST_NEED_AUTH: u64 = 60;
const ST_IP_CONFIG: u64 = 70;
const ST_IP_CHECK: u64 = 80;
const ST_SECONDARIES: u64 = 90;
const ST_ACTIVATED: u64 = 100;
const ST_DEACTIVATING: u64 = 110;

const AC_ACTIVATING: u64 = 1;
const AC_ACTIVATED: u64 = 2;

const KM_PSK: u64 = 0x100;
const KM_8021X: u64 = 0x200;
const KM_SAE: u64 = 0x400;
const KM_OWE: u64 = 0x800;
const KM_OWE_TM: u64 = 0x1000;
const KM_EAP_192: u64 = 0x2000;
const AP_PRIVACY: u64 = 1;

pub fn bytes(v: Option<&Json>) -> Vec<u8> {
    v.and_then(Json::as_array).map(|a| a.iter().filter_map(|n| n.as_u64().map(|n| n as u8)).collect()).unwrap_or_default()
}

pub fn ssid_text(b: &[u8]) -> String {
    String::from_utf8_lossy(b).into_owned()
}

pub fn ap_security(flags: u64, wpa: u64, rsn: u64) -> &'static str {
    let all = wpa | rsn;
    if all & KM_EAP_192 != 0 {
        "enterprise-192"
    } else if all & KM_8021X != 0 {
        "enterprise"
    } else if all & KM_SAE != 0 {
        if all & KM_PSK != 0 { "wpa2-wpa3" } else { "wpa3" }
    } else if rsn & KM_PSK != 0 {
        "wpa2"
    } else if wpa & KM_PSK != 0 {
        "wpa"
    } else if all & (KM_OWE | KM_OWE_TM) != 0 {
        "owe"
    } else if flags & AP_PRIVACY != 0 {
        "wep"
    } else {
        "none"
    }
}

fn strength_icon(s: u64, prefix: &str) -> String {
    let level = if s > 80 { "excellent" } else if s > 55 { "good" } else if s > 30 { "ok" } else if s > 5 { "weak" } else { "none" };
    format!("{prefix}-{level}-symbolic")
}

fn conn_get<'a>(c: &'a Json, setting: &str, key: &str) -> Option<&'a Json> {
    c.get(setting)?.get(key)
}

pub fn conn_id(c: &Json) -> String {
    conn_get(c, "connection", "id").and_then(Json::as_str).unwrap_or_default().to_string()
}
pub fn conn_uuid(c: &Json) -> String {
    conn_get(c, "connection", "uuid").and_then(Json::as_str).unwrap_or_default().to_string()
}
pub fn conn_type(c: &Json) -> String {
    conn_get(c, "connection", "type").and_then(Json::as_str).unwrap_or_default().to_string()
}
fn is_vpn_like(c: &Json) -> bool {
    matches!(conn_type(c).as_str(), "vpn" | "wireguard")
}
fn wifi_mode(c: &Json) -> String {
    conn_get(c, "802-11-wireless", "mode").and_then(Json::as_str).unwrap_or_default().to_string()
}
fn is_hotspot(c: &Json) -> bool {
    matches!(wifi_mode(c).as_str(), "ap" | "adhoc")
}

fn hex(b: &[u8]) -> String {
    b.iter().map(|x| format!("{x:02x}")).collect()
}

const DENYLISTED: &[&str] = &["Free Public WiFi"];

fn listable(ssid: &[u8]) -> bool {
    !ssid.is_empty() && !ssid.iter().all(|c| *c == 0) && !DENYLISTED.contains(&ssid_text(ssid).as_str())
}

/// Does saved connection `c` fit access point `ap` on device `dev`? (A
/// simplified `nm_access_point_connection_valid`: type, SSID, mode, BSSID,
/// interface and MAC pins.)
fn ap_matches(st: &Store, dev: &str, ap: &str, c: &Json) -> bool {
    if conn_type(c) != "802-11-wireless" {
        return false;
    }
    let ssid = bytes(st.prop(ap, I_AP, "Ssid"));
    if bytes(conn_get(c, "802-11-wireless", "ssid")) != ssid {
        return false;
    }
    let ap_mode = st.u(ap, I_AP, "Mode");
    let want = match wifi_mode(c).as_str() {
        "" | "infrastructure" => 2,
        "adhoc" => 1,
        "ap" => 3,
        _ => 0,
    };
    if ap_mode != want {
        return false;
    }
    let bssid = bytes(conn_get(c, "802-11-wireless", "bssid"));
    if !bssid.is_empty() {
        let hw = st.str_(ap, I_AP, "HwAddress").to_lowercase();
        let want: String = bssid.iter().map(|b| format!("{b:02x}")).collect::<Vec<_>>().join(":");
        if hw != want {
            return false;
        }
    }
    device_accepts(st, dev, c)
}

fn device_accepts(st: &Store, dev: &str, c: &Json) -> bool {
    if let Some(i) = conn_get(c, "connection", "interface-name").and_then(Json::as_str) {
        if !i.is_empty() && i != st.str_(dev, I_DEV, "Interface") {
            return false;
        }
    }
    true
}

fn device_connections<'a>(st: &'a Store, dev: &str) -> Vec<(String, &'a Json)> {
    // AvailableConnections is exactly NM's own validity check.
    let avail = st.paths(dev, I_DEV, "AvailableConnections");
    avail.into_iter().filter_map(|p| st.conns.get(&p).map(|c| (p, c))).collect()
}

fn device_state_text(state: u64) -> Option<&'static str> {
    match state {
        ST_PREPARE | 50 => Some("Connecting…"),
        ST_NEED_AUTH => Some("Authenticating…"),
        ST_IP_CONFIG | ST_IP_CHECK | ST_SECONDARIES => Some("Getting IP address…"),
        ST_DEACTIVATING => Some("Disconnecting…"),
        _ => None,
    }
}

fn connectivity_text(c: u64) -> Option<&'static str> {
    match c {
        2 => Some("Sign-in required"),
        3 => Some("Limited connectivity"),
        1 => Some("No internet"),
        _ => None,
    }
}

fn device_kind(t: u64) -> &'static str {
    match t {
        DEV_WIFI => "wifi",
        DEV_ETHERNET => "ethernet",
        DEV_MODEM => "modem",
        DEV_BT => "bt",
        _ => "other",
    }
}

fn device_name(st: &Store, d: &str) -> String {
    let iface = st.str_(d, I_DEV, "Interface");
    match st.u(d, I_DEV, "DeviceType") {
        DEV_WIFI => format!("Wi-Fi ({iface})"),
        DEV_ETHERNET => format!("Ethernet ({iface})"),
        DEV_MODEM => format!("Mobile Broadband ({iface})"),
        DEV_BT => format!("Bluetooth ({iface})"),
        _ => iface,
    }
}

fn device_icon(t: u64) -> &'static str {
    match t {
        DEV_WIFI => "network-wireless-symbolic",
        DEV_MODEM => "network-cellular-symbolic",
        DEV_BT => "bluetooth-active-symbolic",
        _ => "network-wired-symbolic",
    }
}

fn unusable_text(st: &Store, d: &str) -> Option<String> {
    match st.u(d, I_DEV, "State") {
        ST_UNMANAGED => Some("Device not managed".into()),
        ST_UNAVAILABLE => Some(if st.b(d, I_DEV, "FirmwareMissing") {
            "Device not ready (firmware missing)".into()
        } else if st.u(d, I_DEV, "DeviceType") == DEV_ETHERNET {
            "Cable unplugged".into()
        } else if st.u(d, I_DEV, "DeviceType") == DEV_WIFI {
            if !st.b(NM_PATH, I_NM, "WirelessHardwareEnabled") {
                "Wi-Fi is disabled by hardware switch".into()
            } else if !st.b(NM_PATH, I_NM, "WirelessEnabled") {
                "Wi-Fi is disabled".into()
            } else {
                "Device not ready".into()
            }
        } else {
            "Device not ready".into()
        }),
        _ => None,
    }
}

// ---- snapshot ------------------------------------------------------------------

fn visible_acs(st: &Store) -> Vec<String> {
    st.paths(NM_PATH, I_NM, "ActiveConnections")
        .into_iter()
        .filter(|a| st.str_(a, I_AC, "Type") != "loopback")
        .collect()
}

fn is_vpn_ac(st: &Store, ac: &str) -> bool {
    st.b(ac, I_AC, "Vpn") || matches!(st.str_(ac, I_AC, "Type").as_str(), "vpn" | "wireguard")
}

fn ac_conn<'a>(st: &'a Store, ac: &str) -> Option<&'a Json> {
    st.conns.get(&st.path(ac, I_AC, "Connection")?)
}

fn main_connection(st: &Store) -> Option<String> {
    let all = visible_acs(st);
    let primary = st.path(NM_PATH, I_NM, "PrimaryConnection");
    if let Some(p) = &primary {
        if !is_vpn_ac(st, p) {
            return Some(p.clone());
        }
    }
    st.path(NM_PATH, I_NM, "ActivatingConnection")
        .or_else(|| all.into_iter().find(|a| !is_vpn_ac(st, a) && !st.paths(a, I_AC, "Devices").is_empty()))
}

fn bar_icon(st: &Store) -> String {
    if !st.running {
        return "network-error-symbolic".into();
    }
    if !st.b(NM_PATH, I_NM, "NetworkingEnabled") {
        return "network-offline-symbolic".into();
    }
    let devs = st.paths(NM_PATH, I_NM, "AllDevices");
    let has_wifi = devs.iter().any(|d| st.u(d, I_DEV, "DeviceType") == DEV_WIFI);
    let Some(ac) = main_connection(st) else {
        return if !has_wifi {
            "network-wired-disconnected-symbolic"
        } else if st.b(NM_PATH, I_NM, "WirelessEnabled") {
            "network-wireless-offline-symbolic"
        } else {
            "network-wireless-disabled-symbolic"
        }
        .into();
    };
    let dev = st.paths(&ac, I_AC, "Devices").into_iter().next();
    let activating = st.u(&ac, I_AC, "State") == AC_ACTIVATING;
    let c = st.u(NM_PATH, I_NM, "Connectivity");
    let is_primary = st.path(NM_PATH, I_NM, "PrimaryConnection").as_deref() == Some(ac.as_str());
    let limited = is_primary && matches!(c, 1..=3);
    let dtype = dev.as_ref().map(|d| st.u(d, I_DEV, "DeviceType")).unwrap_or(0);
    match dtype {
        DEV_WIFI => {
            let d = dev.unwrap();
            if activating {
                "network-wireless-acquiring-symbolic".into()
            } else if ac_conn(st, &ac).map_or(false, is_hotspot) {
                "network-wireless-hotspot-symbolic".into()
            } else if limited {
                "network-wireless-no-route-symbolic".into()
            } else {
                let s = st.path(&d, I_WIFI, "ActiveAccessPoint").map(|ap| st.u(&ap, I_AP, "Strength")).unwrap_or(0);
                strength_icon(s, "network-wireless-signal")
            }
        }
        DEV_MODEM => if activating { "network-cellular-acquiring-symbolic" } else if limited { "network-cellular-no-route-symbolic" } else { "network-cellular-connected-symbolic" }.into(),
        DEV_BT => "bluetooth-active-symbolic".into(),
        _ => if activating { "network-wired-acquiring-symbolic" } else if limited { "network-wired-no-route-symbolic" } else { "network-wired-symbolic" }.into(),
    }
}

fn tooltip_line(st: &Store, ac: &str) -> String {
    let id = st.str_(ac, I_AC, "Id");
    let state = st.u(ac, I_AC, "State");
    if is_vpn_ac(st, ac) {
        return match state {
            AC_ACTIVATING => format!("Starting VPN connection “{id}”…"),
            AC_ACTIVATED => format!("VPN connection “{id}” active"),
            _ => String::new(),
        };
    }
    let dev = st.paths(ac, I_AC, "Devices").into_iter().next();
    if state == AC_ACTIVATING {
        if let Some(d) = &dev {
            return match st.u(d, I_DEV, "State") {
                ST_NEED_AUTH => format!("User authentication required for network connection “{id}”…"),
                ST_IP_CONFIG | ST_IP_CHECK => format!("Requesting a network address for “{id}”…"),
                _ => format!("Preparing network connection “{id}”…"),
            };
        }
    }
    if state != AC_ACTIVATED {
        return String::new();
    }
    let mut line = format!("Network connection “{id}” active");
    if let Some(d) = &dev {
        if st.u(d, I_DEV, "DeviceType") == DEV_WIFI {
            let ap = st.path(d, I_WIFI, "ActiveAccessPoint");
            line = if ac_conn(st, ac).map_or(false, is_hotspot) {
                let ssid = ac_conn(st, ac).map(|c| ssid_text(&bytes(conn_get(c, "802-11-wireless", "ssid")))).unwrap_or_default();
                format!("Hotspot “{ssid}” active")
            } else {
                let extra = ap
                    .map(|ap| format!(": {} ({}%)", ssid_text(&bytes(st.prop(&ap, I_AP, "Ssid"))), st.u(&ap, I_AP, "Strength")))
                    .unwrap_or_default();
                format!("Wi-Fi network connection “{id}” active{extra}")
            };
        }
    }
    if st.path(NM_PATH, I_NM, "PrimaryConnection").as_deref() == Some(ac) {
        if let Some(c) = connectivity_text(st.u(NM_PATH, I_NM, "Connectivity")) {
            line.push_str(&format!(" — {c}"));
        }
    }
    line
}

fn tooltip(st: &Store) -> String {
    if !st.running {
        return "NetworkManager is not running".into();
    }
    if !st.b(NM_PATH, I_NM, "NetworkingEnabled") {
        return "Networking disabled".into();
    }
    let lines: Vec<String> = visible_acs(st).iter().map(|a| tooltip_line(st, a)).filter(|l| !l.is_empty()).collect();
    if lines.is_empty() { "No network connection".into() } else { lines.join("\n") }
}

fn ip_group(st: &Store, ac: &str, key: &str, iface: &str, title: &str) -> Option<Json> {
    let cfg = st.path(ac, I_AC, key)?;
    let v4 = iface == I_IP4;
    let mut rows: Vec<Json> = vec![];
    let addrs = st.prop(&cfg, iface, "AddressData").and_then(Json::as_array).cloned().unwrap_or_default();
    for (i, a) in addrs.iter().enumerate() {
        let ip = a.get("address").and_then(Json::as_str).unwrap_or_default();
        let prefix = a.get("prefix").and_then(Json::as_u64).unwrap_or(0);
        let label = if addrs.len() > 1 { format!("Address {}", i + 1) } else { "IP Address".into() };
        rows.push(json!([label, if v4 { ip.to_string() } else { format!("{ip}/{prefix}") }]));
        if v4 && i == 0 {
            let mask: u32 = if prefix == 0 { 0 } else { (!0u32) << (32 - prefix.min(32)) };
            let parts: Vec<u32> = ip.split('.').filter_map(|o| o.parse().ok()).collect();
            if parts.len() == 4 {
                let n = parts.iter().fold(0u32, |acc, o| (acc << 8) | (o & 255));
                let fmt = |n: u32| format!("{}.{}.{}.{}", n >> 24, (n >> 16) & 255, (n >> 8) & 255, n & 255);
                rows.push(json!(["Broadcast", fmt(n | !mask)]));
                rows.push(json!(["Subnet Mask", fmt(mask)]));
            }
        }
    }
    let gw = st.str_(&cfg, iface, "Gateway");
    if !gw.is_empty() {
        rows.push(json!(["Default Route", gw]));
    }
    let names = ["Primary DNS", "Secondary DNS", "Tertiary DNS"];
    let dns = st.prop(&cfg, iface, "NameserverData").and_then(Json::as_array).cloned().unwrap_or_default();
    for (i, d) in dns.iter().enumerate() {
        let label = names.get(i).map(|s| s.to_string()).unwrap_or_else(|| format!("DNS {}", i + 1));
        rows.push(json!([label, d.get("address").and_then(Json::as_str).unwrap_or_default()]));
    }
    let domains = st.paths(&cfg, iface, "Domains");
    if !domains.is_empty() {
        rows.push(json!(["Domains", domains.join(", ")]));
    }
    (!rows.is_empty()).then(|| json!({"title": title, "rows": rows}))
}

fn speed_text(mbit: u64) -> String {
    if mbit == 0 {
        "Unknown".into()
    } else if mbit >= 1000 {
        let g = mbit as f64 / 1000.0;
        if mbit % 1000 == 0 { format!("{g:.0} Gb/s") } else { format!("{g:.1} Gb/s") }
    } else {
        format!("{mbit} Mb/s")
    }
}

/// "Connection Information" groups for one active connection.
fn connection_info(st: &Store, ac: &str) -> Vec<Json> {
    let mut groups = vec![];
    let conn = ac_conn(st, ac);
    let dev = st.paths(ac, I_AC, "Devices").into_iter().next();
    if is_vpn_ac(st, ac) {
        let mut rows: Vec<Json> = vec![];
        if let Some(c) = conn {
            if let Some(v) = c.get("vpn") {
                let svc = v.get("service-type").and_then(Json::as_str).unwrap_or_default();
                rows.push(json!(["VPN Type", svc.rsplit('.').next().unwrap_or(svc)]));
                let data = v.get("data");
                let item = |k: &str| data.and_then(|d| d.get(k)).and_then(Json::as_str);
                if let Some(gw) = item("gateway").or_else(|| item("remote")) {
                    rows.push(json!(["VPN Gateway", gw]));
                }
                if let Some(u) = v.get("user-name").and_then(Json::as_str).or_else(|| item("username")) {
                    rows.push(json!(["VPN Username", u]));
                }
            } else {
                rows.push(json!(["VPN Type", "WireGuard"]));
            }
        }
        let base = st.path(ac, I_AC, "SpecificObject").map(|s| st.str_(&s, I_AC, "Id")).filter(|s| !s.is_empty());
        rows.push(json!(["Base Connection", base.unwrap_or_else(|| "Unknown".into())]));
        groups.push(json!({"title": "General", "rows": rows}));
    } else if let Some(d) = &dev {
        let t = st.u(d, I_DEV, "DeviceType");
        let iface = st.str_(d, I_DEV, "Interface");
        let label = match t {
            DEV_WIFI => format!("802.11 Wi-Fi ({iface})"),
            DEV_ETHERNET => format!("Ethernet ({iface})"),
            _ => device_name(st, d),
        };
        let mut rows: Vec<Json> = vec![json!(["Interface", label])];
        let hw = st.str_(d, if t == DEV_WIFI { I_WIFI } else { I_WIRED }, "HwAddress");
        if !hw.is_empty() {
            rows.push(json!(["Hardware Address", hw]));
        }
        let drv = st.str_(d, I_DEV, "Driver");
        if !drv.is_empty() {
            rows.push(json!(["Driver", drv]));
        }
        if t == DEV_WIFI {
            rows.push(json!(["Speed", speed_text(st.u(d, I_WIFI, "Bitrate") / 1000)]));
            let ap = st.path(d, I_WIFI, "ActiveAccessPoint");
            let sec = match &ap {
                Some(ap) => sec_label(ap_security(st.u(ap, I_AP, "Flags"), st.u(ap, I_AP, "WpaFlags"), st.u(ap, I_AP, "RsnFlags"))).to_string(),
                None => conn
                    .and_then(|c| conn_get(c, "802-11-wireless-security", "key-mgmt"))
                    .and_then(Json::as_str)
                    .map(|s| s.to_uppercase())
                    .unwrap_or_else(|| "None".into()),
            };
            rows.push(json!(["Security", sec]));
            if let (Some(ap), false) = (&ap, conn.map_or(false, is_hotspot)) {
                rows.push(json!(["Signal", format!("{}%", st.u(ap, I_AP, "Strength"))]));
                rows.push(json!(["Frequency", format!("{} MHz", st.u(ap, I_AP, "Frequency"))]));
                rows.push(json!(["BSSID", st.str_(ap, I_AP, "HwAddress")]));
            }
        } else if t == DEV_ETHERNET {
            rows.push(json!(["Speed", speed_text(st.u(d, I_WIRED, "Speed"))]));
            rows.push(json!(["Security", if conn.and_then(|c| c.get("802-1x")).is_some() { "802.1X" } else { "None" }]));
        }
        if st.path(NM_PATH, I_NM, "PrimaryConnection").as_deref() == Some(ac) {
            rows.push(json!(["Internet", connectivity_text(st.u(NM_PATH, I_NM, "Connectivity")).unwrap_or("Connected")]));
        }
        groups.push(json!({"title": "General", "rows": rows}));
    }
    if let Some(g) = ip_group(st, ac, "Ip4Config", I_IP4, "IPv4") {
        groups.push(g);
    }
    if let Some(g) = ip_group(st, ac, "Ip6Config", I_IP6, "IPv6") {
        groups.push(g);
    }
    groups
}

pub fn sec_label(s: &str) -> &'static str {
    match s {
        "none" => "Open",
        "owe" => "Enhanced Open",
        "wep" => "WEP",
        "wpa" => "WPA",
        "wpa2" => "WPA2",
        "wpa3" => "WPA3",
        "wpa2-wpa3" => "WPA2/WPA3",
        "enterprise" => "Enterprise",
        "enterprise-192" => "WPA3 Enterprise",
        _ => "",
    }
}

fn wifi_device(st: &Store, d: &str) -> Json {
    // group APs sharing SSID + mode + security (nm-applet's duplicate hashing)
    struct Net {
        key: String,
        ssid: String,
        security: &'static str,
        mode: u64,
        aps: Vec<String>,
    }
    let conns = device_connections(st, d);
    let mut nets: Vec<Net> = vec![];
    for ap in st.paths(d, I_WIFI, "AccessPoints") {
        let ssid = bytes(st.prop(&ap, I_AP, "Ssid"));
        if !listable(&ssid) {
            continue;
        }
        let sec = ap_security(st.u(&ap, I_AP, "Flags"), st.u(&ap, I_AP, "WpaFlags"), st.u(&ap, I_AP, "RsnFlags"));
        let mode = st.u(&ap, I_AP, "Mode");
        let key = format!("{}|{}|{}", hex(&ssid), mode, sec);
        match nets.iter_mut().find(|n| n.key == key) {
            Some(n) => n.aps.push(ap),
            None => nets.push(Net { key, ssid: ssid_text(&ssid), security: sec, mode, aps: vec![ap] }),
        }
    }
    let strength_of = |ap: &String| st.u(ap, I_AP, "Strength");
    let net_json = |n: &Net| {
        let best = n.aps.iter().max_by_key(|a| strength_of(a)).unwrap();
        let mut seen = HashSet::new();
        let saved: Vec<Json> = n
            .aps
            .iter()
            .flat_map(|ap| conns.iter().filter(move |(_, c)| ap_matches(st, d, ap, c)))
            .filter(|(_, c)| seen.insert(conn_uuid(c)))
            .map(|(p, c)| json!({"path": p, "id": conn_id(c), "uuid": conn_uuid(c)}))
            .collect();
        let freq = st.u(best, I_AP, "Frequency");
        json!({
            "key": n.key, "ssid": n.ssid, "security": n.security, "securityLabel": sec_label(n.security),
            "mode": n.mode, "strength": strength_of(best), "ap": best, "bssid": st.str_(best, I_AP, "HwAddress"),
            "frequency": freq, "maxBitrate": st.u(best, I_AP, "MaxBitrate") / 1000, "apCount": n.aps.len(),
            "saved": !saved.is_empty(), "connections": saved,
        })
    };
    let active_key = st
        .path(d, I_WIFI, "ActiveAccessPoint")
        .filter(|ap| listable(&bytes(st.prop(ap, I_AP, "Ssid"))))
        .map(|ap| {
            let ssid = bytes(st.prop(&ap, I_AP, "Ssid"));
            format!(
                "{}|{}|{}",
                hex(&ssid),
                st.u(&ap, I_AP, "Mode"),
                ap_security(st.u(&ap, I_AP, "Flags"), st.u(&ap, I_AP, "WpaFlags"), st.u(&ap, I_AP, "RsnFlags"))
            )
        });
    let mut js: Vec<(u64, Json, bool, bool)> = nets
        .iter()
        .map(|n| {
            let j = net_json(n);
            let strength = j["strength"].as_u64().unwrap_or(0);
            let saved = j["saved"].as_bool().unwrap_or(false);
            let active = Some(&n.key) == active_key.as_ref();
            (strength, j, saved, active)
        })
        .collect();
    js.sort_by(|a, b| b.0.cmp(&a.0).then_with(|| a.1["ssid"].as_str().cmp(&b.1["ssid"].as_str())));
    let active = js.iter().find(|x| x.3).map(|x| x.1.clone());
    let saved: Vec<Json> = js.iter().filter(|x| !x.3 && x.2).map(|x| x.1.clone()).collect();
    let other: Vec<Json> = js.iter().filter(|x| !x.3 && !x.2).take(40).map(|x| x.1.clone()).collect();

    let ac = st.path(d, I_DEV, "ActiveConnection");
    let hotspot = ac.as_ref().filter(|ac| ac_conn(st, ac).map_or(false, is_hotspot)).map(|ac| {
        let ssid = ac_conn(st, ac).map(|c| ssid_text(&bytes(conn_get(c, "802-11-wireless", "ssid")))).unwrap_or_default();
        json!({"ac": ac, "ssid": ssid, "info": connection_info(st, ac)})
    });
    json!({
        "path": d, "iface": st.str_(d, I_DEV, "Interface"), "name": device_name(st, d),
        "state": st.u(d, I_DEV, "State"), "stateText": device_state_text(st.u(d, I_DEV, "State")),
        "unusable": unusable_text(st, d), "hotspot": hotspot,
        "reasonText": crate::netops::device_reason_text(st.device_reason(d)), "reason": st.device_reason(d),
        "activeAc": ac, "activeInfo": ac.as_ref().map(|a| connection_info(st, a)),
        "active": active, "saved": saved, "other": other,
    })
}

pub fn snapshot(st: &Store) -> Json {
    let devs = st.paths(NM_PATH, I_NM, "AllDevices");
    let managed = |d: &String| st.prop(d, I_DEV, "Managed").and_then(Json::as_bool).unwrap_or(true);
    let wifi: Vec<Json> = devs
        .iter()
        .filter(|d| st.u(d, I_DEV, "DeviceType") == DEV_WIFI && managed(d))
        .map(|d| wifi_device(st, d))
        .collect();

    let primary = st.path(NM_PATH, I_NM, "PrimaryConnection");
    let others: Vec<Json> = devs
        .iter()
        .filter(|d| matches!(st.u(d, I_DEV, "DeviceType"), DEV_ETHERNET | DEV_MODEM | DEV_BT) && managed(d))
        .map(|d| {
            let ac = st.path(d, I_DEV, "ActiveConnection");
            let state = st.u(d, I_DEV, "State");
            let status = if let Some(t) = device_state_text(state) {
                t.to_string()
            } else if state == ST_UNAVAILABLE {
                if st.u(d, I_DEV, "DeviceType") == DEV_ETHERNET {
                    "Cable unplugged".into()
                } else if st.b(d, I_DEV, "FirmwareMissing") {
                    "Firmware missing".into()
                } else {
                    "Unavailable".into()
                }
            } else if state == ST_UNMANAGED {
                "Not managed".into()
            } else if state == ST_ACTIVATED {
                let id = ac.as_ref().map(|a| st.str_(a, I_AC, "Id")).filter(|s| !s.is_empty()).unwrap_or_else(|| "Connected".into());
                let extra = (ac.as_deref() == primary.as_deref()).then(|| connectivity_text(st.u(NM_PATH, I_NM, "Connectivity"))).flatten();
                match extra {
                    Some(e) => format!("{id} · {e}"),
                    None => id,
                }
            } else {
                "Disconnected".into()
            };
            let available: Vec<Json> = device_connections(st, d)
                .into_iter()
                .map(|(p, c)| json!({"path": p, "id": conn_id(c), "uuid": conn_uuid(c), "active": ac.as_ref().map_or(false, |a| st.str_(a, I_AC, "Uuid") == conn_uuid(c))}))
                .collect();
            json!({
                "path": d, "kind": device_kind(st.u(d, I_DEV, "DeviceType")), "name": device_name(st, d),
                "icon": device_icon(st.u(d, I_DEV, "DeviceType")), "state": state, "status": status,
                "reasonText": crate::netops::device_reason_text(st.device_reason(d)), "reason": st.device_reason(d),
                "activated": state == ST_ACTIVATED, "usable": state >= ST_DISCONNECTED, "working": device_state_text(state).is_some(),
                "activeAc": ac, "info": ac.as_ref().map(|a| connection_info(st, a)), "available": available,
            })
        })
        .collect();

    let acs = st.paths(NM_PATH, I_NM, "ActiveConnections");
    let mut vpns: Vec<Json> = st
        .conns
        .iter()
        .filter(|(_, c)| is_vpn_like(c))
        .map(|(p, c)| {
            let uuid = conn_uuid(c);
            let ac = acs.iter().find(|a| st.str_(a, I_AC, "Uuid") == uuid);
            json!({
                "path": p, "id": conn_id(c), "uuid": uuid, "type": conn_type(c),
                "state": ac.map(|a| st.u(a, I_AC, "State")).unwrap_or(4),
                "ac": ac, "info": ac.map(|a| connection_info(st, a)),
            })
        })
        .collect();
    vpns.sort_by(|a, b| a["id"].as_str().cmp(&b["id"].as_str()));
    let vpn_active = visible_acs(st).iter().any(|a| is_vpn_ac(st, a) && st.u(a, I_AC, "State") == AC_ACTIVATED);

    json!({
        "type": "net-state",
        "nmRunning": st.running,
        "networking": st.b(NM_PATH, I_NM, "NetworkingEnabled"),
        "wifiEnabled": st.b(NM_PATH, I_NM, "WirelessEnabled"),
        "wifiHw": st.b(NM_PATH, I_NM, "WirelessHardwareEnabled"),
        "wwanEnabled": st.b(NM_PATH, I_NM, "WwanEnabled"),
        "wwanHw": st.b(NM_PATH, I_NM, "WwanHardwareEnabled"),
        "hasModem": devs.iter().any(|d| st.u(d, I_DEV, "DeviceType") == DEV_MODEM),
        "connectivity": st.u(NM_PATH, I_NM, "Connectivity"),
        "icon": bar_icon(st), "tooltip": tooltip(st), "vpnActive": vpn_active,
        "wifi": wifi, "devices": others, "vpns": vpns,
    })
}

// ---- loading & watching ----------------------------------------------------------

fn props_to_map(v: HashMap<String, Json>) -> Props {
    v
}

async fn load_object(conn: &Connection, path: &str) -> Option<HashMap<String, Props>> {
    let mut out = HashMap::new();
    // Which interfaces exist is implied by the path; try the plausible ones.
    let candidates: &[&str] = if path == NM_PATH {
        &[I_NM]
    } else if path.contains("/Devices/") {
        &[I_DEV, I_WIFI, I_WIRED]
    } else if path.contains("/AccessPoint/") {
        &[I_AP]
    } else if path.contains("/ActiveConnection/") {
        &[I_AC]
    } else if path.contains("/IP4Config/") {
        &[I_IP4]
    } else if path.contains("/IP6Config/") {
        &[I_IP6]
    } else {
        return None;
    };
    for i in candidates {
        if let Some(p) = get_all(conn, NM, path, i).await {
            out.insert(i.to_string(), props_to_map(p));
        }
    }
    (!out.is_empty()).then_some(out)
}

async fn load_connection(conn: &Connection, path: &str) -> Option<Json> {
    let msg = conn
        .call_method(Some(NM), path, Some("org.freedesktop.NetworkManager.Settings.Connection"), "GetSettings", &())
        .await
        .ok()?;
    let body = msg.body();
    let st: zbus::zvariant::Structure = body.deserialize().ok()?;
    Some(value_to_json(&st.fields()[0]))
}

pub struct Nm {
    pub conn: Connection,
    pub store: Shared,
    pub changed: Arc<Notify>,
}

impl Nm {
    pub fn new(conn: Connection) -> Self {
        Nm { conn, store: Arc::new(Mutex::new(Store::default())), changed: Arc::new(Notify::new()) }
    }

    /// Fetch everything reachable from the root that we do not have yet,
    /// and forget what is no longer reachable.
    async fn reconcile(&self) {
        loop {
            let (missing, wanted) = {
                let s = self.store.lock().unwrap();
                let wanted = s.wanted();
                (wanted.iter().filter(|p| !s.has(p)).cloned().collect::<Vec<_>>(), wanted)
            };
            if missing.is_empty() {
                let mut s = self.store.lock().unwrap();
                s.objs.retain(|p, _| p == NM_PATH || wanted.contains(p));
                return;
            }
            for p in missing {
                if let Some(o) = load_object(&self.conn, &p).await {
                    let mut s = self.store.lock().unwrap();
                    for (i, props) in o {
                        s.insert(&p, &i, props);
                    }
                } else {
                    // unreachable now (device vanished); mark loaded so we do not spin
                    self.store.lock().unwrap().objs.entry(p).or_default();
                }
            }
        }
    }

    async fn load_connections(&self) {
        let Ok(msg) = self
            .conn
            .call_method(Some(NM), SETTINGS_PATH, Some("org.freedesktop.NetworkManager.Settings"), "ListConnections", &())
            .await
        else {
            return;
        };
        let body = msg.body();
        let Ok(paths): Result<Vec<OwnedObjectPath>, _> = body.deserialize() else { return };
        let mut map = HashMap::new();
        for p in paths {
            if let Some(c) = load_connection(&self.conn, p.as_str()).await {
                map.insert(p.to_string(), c);
            }
        }
        self.store.lock().unwrap().conns = map;
    }

    pub async fn load_all(&self) {
        let root = load_object(&self.conn, NM_PATH).await;
        {
            let mut s = self.store.lock().unwrap();
            s.running = root.is_some();
            if let Some(o) = root {
                for (i, props) in o {
                    s.insert(NM_PATH, &i, props);
                }
            } else {
                s.objs.clear();
                s.conns.clear();
            }
        }
        if self.store.lock().unwrap().running {
            self.load_connections().await;
            self.reconcile().await;
        }
        self.changed.notify_one();
    }

    pub fn snapshot(&self) -> Json {
        snapshot(&self.store.lock().unwrap())
    }

    /// Follow NM: reload on (re)appearance, merge PropertiesChanged, refresh
    /// saved connections on the Settings signals.
    pub async fn watch(self: Arc<Self>) -> zbus::Result<()> {
        // property changes anywhere under NM
        let props_rule = zbus::MatchRule::builder()
            .msg_type(zbus::message::Type::Signal)
            .sender(NM)?
            .interface("org.freedesktop.DBus.Properties")?
            .member("PropertiesChanged")?
            .build();
        let sig_rule = zbus::MatchRule::builder().msg_type(zbus::message::Type::Signal).sender(NM)?.build();
        let mut props = zbus::MessageStream::for_match_rule(props_rule, &self.conn, None).await?;
        let mut sigs = zbus::MessageStream::for_match_rule(sig_rule, &self.conn, None).await?;
        let owner = zbus::fdo::DBusProxy::new(&self.conn).await?;
        let mut names = owner.receive_name_owner_changed_with_args(&[(0, NM)]).await?;

        self.load_all().await;
        loop {
            tokio::select! {
                Some(Ok(msg)) = props.next() => {
                    let body = msg.body();
                    let Ok((iface, changed, _)): Result<(String, HashMap<String, Value>, Vec<String>), _> = body.deserialize() else { continue };
                    let Some(path) = msg.header().path().map(|p| p.to_string()) else { continue };
                    if iface == "org.freedesktop.NetworkManager.Settings.Connection" {
                        continue; // handled through the Updated signal
                    }
                    let changed: Props = changed.iter().map(|(k, v)| (k.clone(), value_to_json(v))).collect();
                    let known = self.store.lock().unwrap().has(&path);
                    if known {
                        self.store.lock().unwrap().merge(&path, &iface, changed);
                        self.reconcile().await;
                        self.changed.notify_one();
                    }
                }
                Some(Ok(msg)) = sigs.next() => {
                    let h = msg.header();
                    let member = h.member().map(|m| m.to_string()).unwrap_or_default();
                    let iface = h.interface().map(|m| m.to_string()).unwrap_or_default();
                    if iface == "org.freedesktop.DBus.Properties" { continue; }
                    match (iface.as_str(), member.as_str()) {
                        ("org.freedesktop.NetworkManager.Settings", "NewConnection")
                        | ("org.freedesktop.NetworkManager.Settings", "ConnectionRemoved")
                        | ("org.freedesktop.NetworkManager.Settings.Connection", "Updated")
                        | ("org.freedesktop.NetworkManager.Settings.Connection", "Removed") => {
                            self.load_connections().await;
                            self.changed.notify_one();
                        }
                        ("org.freedesktop.NetworkManager", "DeviceAdded" | "DeviceRemoved")
                        | ("org.freedesktop.NetworkManager.Device.Wireless", "AccessPointAdded" | "AccessPointRemoved") => {
                            // the list properties follow in PropertiesChanged; reload to be safe
                            self.load_all().await;
                        }
                        _ => {}
                    }
                }
                Some(sig) = names.next() => {
                    if sig.args().map(|a| a.new_owner().is_some()).unwrap_or(false) {
                        self.load_all().await;
                    } else {
                        let mut s = self.store.lock().unwrap();
                        s.running = false;
                        s.objs.clear();
                        s.conns.clear();
                        drop(s);
                        self.changed.notify_one();
                    }
                }
                else => break,
            }
        }
        Ok(())
    }
}

#[allow(dead_code)]
fn _unused(_: Map<String, Json>) {}

#[cfg(test)]
mod tests {
    use super::*;

    fn ap(st: &mut Store, path: &str, ssid: &str, strength: u64, rsn: u64) {
        st.insert(
            path,
            I_AP,
            [
                ("Ssid", json!(ssid.as_bytes())),
                ("Strength", json!(strength)),
                ("Flags", json!(1)),
                ("WpaFlags", json!(0)),
                ("RsnFlags", json!(rsn)),
                ("Mode", json!(2)),
                ("Frequency", json!(5180)),
                ("HwAddress", json!("AA:BB:CC:DD:EE:01")),
                ("MaxBitrate", json!(300000)),
            ]
            .into_iter()
            .map(|(k, v)| (k.to_string(), v))
            .collect(),
        );
    }

    fn fixture() -> Store {
        let mut st = Store { running: true, ..Default::default() };
        let root: Props = [
            ("AllDevices", json!(["/d/1"])),
            ("ActiveConnections", json!([])),
            ("NetworkingEnabled", json!(true)),
            ("WirelessEnabled", json!(true)),
            ("WirelessHardwareEnabled", json!(true)),
            ("Connectivity", json!(4)),
        ]
        .into_iter()
        .map(|(k, v)| (k.to_string(), v))
        .collect();
        st.insert(NM_PATH, I_NM, root);
        let dev: Props = [
            ("DeviceType", json!(2)),
            ("Interface", json!("wlan0")),
            ("State", json!(30)),
            ("Managed", json!(true)),
            ("AvailableConnections", json!(["/c/1"])),
        ]
        .into_iter()
        .map(|(k, v)| (k.to_string(), v))
        .collect();
        st.insert("/d/1", I_DEV, dev);
        let w: Props = [("AccessPoints", json!(["/a/1", "/a/2", "/a/3", "/a/4"])), ("ActiveAccessPoint", json!("/"))]
            .into_iter()
            .map(|(k, v)| (k.to_string(), v))
            .collect();
        st.insert("/d/1", I_WIFI, w);
        ap(&mut st, "/a/1", "Home", 40, KM_PSK);
        ap(&mut st, "/a/2", "Home", 70, KM_PSK); // same net, stronger AP
        ap(&mut st, "/a/3", "Cafe", 90, 0);
        ap(&mut st, "/a/4", "", 99, 0); // hidden: not listed
        st.conns.insert(
            "/c/1".into(),
            json!({"connection": {"id": "Home", "uuid": "u1", "type": "802-11-wireless"},
                   "802-11-wireless": {"ssid": b"Home".to_vec(), "mode": "infrastructure"}}),
        );
        st
    }

    #[test]
    fn groups_access_points_and_sections() {
        let snap = snapshot(&fixture());
        let w = &snap["wifi"][0];
        assert!(w["active"].is_null());
        let saved = w["saved"].as_array().unwrap();
        assert_eq!(saved.len(), 1);
        assert_eq!(saved[0]["ssid"], "Home");
        assert_eq!(saved[0]["strength"], 70); // best AP wins
        assert_eq!(saved[0]["apCount"], 2);
        assert_eq!(saved[0]["connections"][0]["uuid"], "u1");
        let other = w["other"].as_array().unwrap();
        assert_eq!(other.len(), 1);
        assert_eq!(other[0]["ssid"], "Cafe");
        assert_eq!(other[0]["security"], "wep"); // privacy flag, no wpa flags
        assert_eq!(snap["icon"], "network-wireless-offline-symbolic");
        assert_eq!(snap["tooltip"], "No network connection");
    }

    #[test]
    fn security_classification() {
        assert_eq!(ap_security(0, 0, 0), "none");
        assert_eq!(ap_security(1, 0, 0), "wep");
        assert_eq!(ap_security(1, 0, KM_PSK), "wpa2");
        assert_eq!(ap_security(1, KM_PSK, 0), "wpa");
        assert_eq!(ap_security(1, 0, KM_PSK | KM_SAE), "wpa2-wpa3");
        assert_eq!(ap_security(1, 0, KM_SAE), "wpa3");
        assert_eq!(ap_security(1, 0, KM_8021X), "enterprise");
        assert_eq!(ap_security(0, 0, KM_OWE), "owe");
    }

    #[test]
    fn nm_not_running() {
        let st = Store::default();
        let snap = snapshot(&st);
        assert_eq!(snap["icon"], "network-error-symbolic");
        assert_eq!(snap["tooltip"], "NetworkManager is not running");
    }
}
