//! OBEX object push via obexd (session bus): an org.bluez.obex.Agent1 that
//! accepts incoming files into the download dir, plus sending files to a
//! device. Transfer state goes to the UI as `{"type":"transfers",...}`.

use crate::dbus::{get_all, value_to_json};
use crate::prompter::{Answer, Prompter};
use crate::util::{bt_setting_bool, download_dir, notify, unique_dest};
use futures_util::StreamExt;
use serde_json::{json, Value as Json};
use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};
use tokio::sync::{mpsc, oneshot};
use zbus::zvariant::{ObjectPath, OwnedObjectPath, OwnedValue, Value};
use zbus::{fdo::DBusProxy, interface, Connection};

const OBEX: &str = "org.bluez.obex";
const AGENT_PATH: &str = "/org/shell/bluetooth/obex_agent";

#[derive(Debug, zbus::DBusError)]
#[zbus(prefix = "org.bluez.obex.Error")]
pub enum ObexError {
    #[zbus(error)]
    ZBus(zbus::Error),
    Rejected(String),
}

#[derive(Clone, Default)]
struct Transfer {
    path: String,
    direction: &'static str,
    name: String,
    device: String,
    size: u64,
    transferred: u64,
    status: String,
}

#[derive(Clone)]
pub struct Obex {
    session: Connection,
    system: Connection,
    prompter: Prompter,
    out: mpsc::UnboundedSender<Json>,
    transfers: Arc<Mutex<Vec<Transfer>>>,
    waiters: Arc<Mutex<HashMap<String, oneshot::Sender<bool>>>>,
    allowed: Arc<Mutex<HashMap<String, Instant>>>,
}

impl Obex {
    pub fn new(session: Connection, system: Connection, prompter: Prompter, out: mpsc::UnboundedSender<Json>) -> Self {
        Obex {
            session,
            system,
            prompter,
            out,
            transfers: Default::default(),
            waiters: Default::default(),
            allowed: Default::default(),
        }
    }

    fn emit(&self) {
        let list: Vec<Json> = self
            .transfers
            .lock()
            .unwrap()
            .iter()
            .map(|t| {
                json!({"path": t.path, "direction": t.direction, "name": t.name, "device": t.device,
                       "size": t.size, "transferred": t.transferred, "status": t.status})
            })
            .collect();
        let _ = self.out.send(json!({"type": "transfers", "list": list}));
    }

    fn upsert(&self, t: Transfer) {
        let mut l = self.transfers.lock().unwrap();
        match l.iter_mut().find(|x| x.path == t.path) {
            Some(x) => *x = t,
            None => l.push(t),
        }
        drop(l);
        self.emit();
    }

    fn drop_transfer(&self, path: &str) {
        self.transfers.lock().unwrap().retain(|t| t.path != path);
        self.emit();
    }

    /// Resolves true when the transfer completes, false on error.
    fn wait_done(&self, path: &str) -> oneshot::Receiver<bool> {
        let (tx, rx) = oneshot::channel();
        self.waiters.lock().unwrap().insert(path.to_string(), tx);
        rx
    }

    /// Device (path, display name, trusted) for a Bluetooth address.
    async fn device_by_address(&self, address: &str) -> Option<(String, String, bool)> {
        let msg = self
            .system
            .call_method(Some("org.bluez"), "/", Some("org.freedesktop.DBus.ObjectManager"), "GetManagedObjects", &())
            .await
            .ok()?;
        let body = msg.body();
        let objs: HashMap<OwnedObjectPath, HashMap<String, HashMap<String, OwnedValue>>> = body.deserialize().ok()?;
        for (path, ifaces) in objs {
            let Some(d) = ifaces.get("org.bluez.Device1") else { continue };
            let addr = d.get("Address").and_then(|v| String::try_from(v.try_clone().ok()?).ok())?;
            if addr.eq_ignore_ascii_case(address) {
                let s = |k: &str| d.get(k).and_then(|v| String::try_from(v.try_clone().ok()?).ok());
                let name = s("Alias").or_else(|| s("Name")).unwrap_or(addr);
                let trusted = d.get("Trusted").and_then(|v| bool::try_from(v.try_clone().ok()?).ok()).unwrap_or(false);
                return Some((path.to_string(), name, trusted));
            }
        }
        None
    }

    /// Follow Transfer1 PropertiesChanged signals.
    async fn watch_signals(self) -> zbus::Result<()> {
        let rule = zbus::MatchRule::builder()
            .msg_type(zbus::message::Type::Signal)
            .sender(OBEX)?
            .interface("org.freedesktop.DBus.Properties")?
            .member("PropertiesChanged")?
            .build();
        let mut stream = zbus::MessageStream::for_match_rule(rule, &self.session, None).await?;
        while let Some(Ok(msg)) = stream.next().await {
            let body = msg.body();
            let Ok((iface, changed, _)): Result<(String, HashMap<String, Value>, Vec<String>), _> = body.deserialize()
            else {
                continue;
            };
            if iface != "org.bluez.obex.Transfer1" {
                continue;
            }
            let Some(path) = msg.header().path().map(|p| p.to_string()) else { continue };
            {
                let mut l = self.transfers.lock().unwrap();
                if let Some(t) = l.iter_mut().find(|t| t.path == path) {
                    if let Some(Value::U64(n)) = changed.get("Transferred") {
                        t.transferred = *n;
                    }
                    if let Some(Value::U64(n)) = changed.get("Size") {
                        t.size = *n;
                    }
                    if let Some(Value::Str(s)) = changed.get("Status") {
                        t.status = s.to_string();
                    }
                }
            }
            self.emit();
            if let Some(Value::Str(s)) = changed.get("Status") {
                let done = match s.as_str() {
                    "complete" => Some(true),
                    "error" => Some(false),
                    _ => None,
                };
                if let (Some(ok), Some(tx)) = (done, self.waiters.lock().unwrap().remove(&path)) {
                    let _ = tx.send(ok);
                }
            }
        }
        Ok(())
    }

    async fn register(&self) {
        let r = self
            .session
            .call_method(
                Some(OBEX),
                "/org/bluez/obex",
                Some("org.bluez.obex.AgentManager1"),
                "RegisterAgent",
                &(ObjectPath::try_from(AGENT_PATH).unwrap(),),
            )
            .await;
        if let Err(e) = r {
            eprintln!("bluetooth: OBEX RegisterAgent failed: {e}");
        }
    }

    /// Export the agent; (re-)register whenever obexd appears. obexd is
    /// D-Bus activated, so the first call also starts it.
    pub async fn run(self) -> zbus::Result<()> {
        self.session.object_server().at(AGENT_PATH, ObexAgent { obex: self.clone() }).await?;
        tokio::spawn({
            let me = self.clone();
            async move {
                if let Err(e) = me.watch_signals().await {
                    eprintln!("obex signal watch stopped: {e}");
                }
            }
        });
        self.register().await;
        let dbus = DBusProxy::new(&self.session).await?;
        let mut owner = dbus.receive_name_owner_changed_with_args(&[(0, OBEX)]).await?;
        while let Some(sig) = owner.next().await {
            let Ok(args) = sig.args() else { continue };
            if args.new_owner().is_some() {
                self.register().await;
            } else {
                self.transfers.lock().unwrap().clear();
                self.emit();
            }
        }
        Ok(())
    }

    pub async fn cancel(&self, path: &str) {
        let _ = self
            .session
            .call_method(Some(OBEX), path, Some("org.bluez.obex.Transfer1"), "Cancel", &())
            .await;
    }

    async fn finish_incoming(&self, tmp: PathBuf, name: &str, from: &str, ok: bool) {
        if !ok {
            notify(&self.session, "Transfer failed", &format!("{name} from {from}"), "dialog-error-symbolic").await;
            return;
        }
        let dir = download_dir();
        let _ = std::fs::create_dir_all(&dir);
        let base = std::path::Path::new(name).file_name().map(|s| s.to_string_lossy().into_owned()).unwrap_or_else(|| "file".into());
        let dest = unique_dest(&dir, &base);
        match std::fs::rename(&tmp, &dest).or_else(|_| std::fs::copy(&tmp, &dest).map(|_| ()).and_then(|_| std::fs::remove_file(&tmp))) {
            Ok(()) => {
                let shown = dest.file_name().unwrap().to_string_lossy().into_owned();
                notify(
                    &self.session,
                    "File received",
                    &format!("{shown} from {from}\nSaved to {}", dir.display()),
                    "document-save-symbolic",
                )
                .await
            }
            Err(e) => {
                eprintln!("bluetooth: moving received file failed: {e}");
                notify(
                    &self.session,
                    "File received",
                    &format!("{name} from {from}\nLeft at {}", tmp.display()),
                    "document-save-symbolic",
                )
                .await
            }
        }
    }

    /// Push files to a device, one at a time (obexd queues per session).
    pub async fn send(&self, address: &str, files: Vec<String>) {
        let to = self.device_by_address(address).await.map(|d| d.1).unwrap_or_else(|| address.to_string());
        let mut opts = HashMap::<&str, Value>::new();
        opts.insert("Target", Value::from("opp"));
        let session = match tokio::time::timeout(
            Duration::from_secs(60),
            self.session.call_method(
                Some(OBEX),
                "/org/bluez/obex",
                Some("org.bluez.obex.Client1"),
                "CreateSession",
                &(address, opts),
            ),
        )
        .await
        {
            Ok(Ok(m)) => m.body().deserialize::<OwnedObjectPath>().ok(),
            Ok(Err(e)) => {
                notify(&self.session, "Sending failed", &format!("{to}: {e}"), "dialog-error-symbolic").await;
                return;
            }
            Err(_) => {
                notify(&self.session, "Sending failed", &format!("{to}: timed out"), "dialog-error-symbolic").await;
                return;
            }
        };
        let Some(session) = session else { return };

        let mut sent = 0;
        for file in &files {
            let name = std::path::Path::new(file).file_name().map(|s| s.to_string_lossy().into_owned()).unwrap_or_default();
            let r = self
                .session
                .call_method(Some(OBEX), &session, Some("org.bluez.obex.ObjectPush1"), "SendFile", &(file.as_str(),))
                .await;
            let msg = match r {
                Ok(m) => m,
                Err(e) => {
                    notify(&self.session, "Sending failed", &format!("{name} to {to}: {e}"), "dialog-error-symbolic").await;
                    continue;
                }
            };
            let body = msg.body();
            let Ok((tpath, props)): Result<(OwnedObjectPath, HashMap<String, OwnedValue>), _> = body.deserialize() else {
                continue;
            };
            let tpath = tpath.to_string();
            let rx = self.wait_done(&tpath);
            self.upsert(Transfer {
                path: tpath.clone(),
                direction: "out",
                name: name.clone(),
                device: to.clone(),
                size: props.get("Size").and_then(|v| u64::try_from(v.try_clone().ok()?).ok()).unwrap_or(0),
                transferred: 0,
                status: props.get("Status").and_then(|v| String::try_from(v.try_clone().ok()?).ok()).unwrap_or_else(|| "queued".into()),
            });
            let ok = rx.await.unwrap_or(false);
            self.drop_transfer(&tpath);
            if ok {
                sent += 1;
            } else {
                notify(&self.session, "Sending failed", &format!("{name} to {to}"), "dialog-error-symbolic").await;
            }
        }
        if sent > 0 {
            notify(
                &self.session,
                "Files sent",
                &format!("{sent} file{} sent to {to}", if sent > 1 { "s" } else { "" }),
                "document-send-symbolic",
            )
            .await;
        }
        let _ = self
            .session
            .call_method(
                Some(OBEX),
                "/org/bluez/obex",
                Some("org.bluez.obex.Client1"),
                "RemoveSession",
                &(session.as_ref(),),
            )
            .await;
    }
}

struct ObexAgent {
    obex: Obex,
}

#[interface(name = "org.bluez.obex.Agent1")]
impl ObexAgent {
    fn release(&self) {}
    fn cancel(&self) {}

    async fn authorize_push(&self, transfer: ObjectPath<'_>) -> Result<String, ObexError> {
        let o = &self.obex;
        let reject = |m: &str| ObexError::Rejected(m.to_string());
        let t = get_all(&o.session, OBEX, transfer.as_str(), "org.bluez.obex.Transfer1")
            .await
            .ok_or_else(|| reject("transfer vanished"))?;
        let sess_path = t.get("Session").and_then(Json::as_str).ok_or_else(|| reject("no session"))?.to_string();
        let s = get_all(&o.session, OBEX, &sess_path, "org.bluez.obex.Session1")
            .await
            .ok_or_else(|| reject("session vanished"))?;
        let address = s.get("Destination").and_then(Json::as_str).unwrap_or_default().to_string();
        let dev = o.device_by_address(&address).await;
        let from = dev.as_ref().map(|d| d.1.clone()).unwrap_or_else(|| address.clone());
        let name = t.get("Name").and_then(Json::as_str).filter(|n| !n.is_empty()).unwrap_or("file").to_string();
        let size = t.get("Size").and_then(Json::as_u64).unwrap_or(0);

        let recently = o.allowed.lock().unwrap().get(&address).map_or(false, |until| *until > Instant::now());
        let trusted = dev.as_ref().map_or(false, |d| d.2);
        if !(recently || (trusted && bt_setting_bool("acceptFromTrusted"))) {
            let path = dev.as_ref().map(|d| d.0.clone()).unwrap_or_else(|| transfer.to_string());
            let a = o.prompter.ask(json!({"kind":"file","path":path,"name":name,"size":size})).await;
            if !matches!(a, Answer::Yes | Answer::Always) {
                return Err(reject("Rejected by user"));
            }
        }
        // further files in the same batch go through silently for a minute
        o.allowed.lock().unwrap().insert(address, Instant::now() + Duration::from_secs(60));

        let root = s.get("Root").and_then(Json::as_str).map(PathBuf::from).unwrap_or_else(std::env::temp_dir);
        let base = std::path::Path::new(&name).file_name().map(|s| s.to_string_lossy().into_owned()).unwrap_or_else(|| "file".into());
        let tmp = root.join(base);
        let path = transfer.to_string();
        let rx = o.wait_done(&path);
        o.upsert(Transfer {
            path: path.clone(),
            direction: "in",
            name: name.clone(),
            device: from.clone(),
            size,
            transferred: 0,
            status: "queued".into(),
        });
        let me = o.clone();
        let tmp2 = tmp.clone();
        tokio::spawn(async move {
            let ok = rx.await.unwrap_or(false);
            me.drop_transfer(&path);
            me.finish_incoming(tmp2, &name, &from, ok).await;
        });
        Ok(tmp.to_string_lossy().into_owned())
    }
}

#[allow(dead_code)]
fn _json(v: &Value) -> Json {
    value_to_json(v)
}
