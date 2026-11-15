//! org.bluez.Agent1: answers BlueZ's pairing / authorization questions via
//! the shared prompter. Every method call gets exactly one reply.

use crate::prompter::{Answer, Prompter};
use futures_util::StreamExt;
use serde_json::json;
use zbus::zvariant::{ObjectPath, Value};
use zbus::{fdo::DBusProxy, interface, Connection};

const AGENT_PATH: &str = "/org/shell/bluetooth/agent";

#[derive(Debug, zbus::DBusError)]
#[zbus(prefix = "org.bluez.Error")]
pub enum BluezError {
    #[zbus(error)]
    ZBus(zbus::Error),
    Canceled(String),
    Rejected(String),
}

fn refuse(a: Answer) -> BluezError {
    match a {
        Answer::Cancel => BluezError::Canceled("Canceled by user".into()),
        _ => BluezError::Rejected("Rejected by user".into()),
    }
}

struct Agent {
    prompter: Prompter,
    conn: Connection,
}

#[interface(name = "org.bluez.Agent1")]
impl Agent {
    fn release(&self) {
        self.prompter.cancel_current(None);
    }

    fn cancel(&self) {
        self.prompter.cancel_current(None);
    }

    async fn request_pin_code(&self, device: ObjectPath<'_>) -> Result<String, BluezError> {
        match self.prompter.ask(json!({"kind":"pin","path":device.as_str()})).await {
            Answer::Text(s) if !s.is_empty() => Ok(s),
            a => Err(refuse(a)),
        }
    }

    async fn request_passkey(&self, device: ObjectPath<'_>) -> Result<u32, BluezError> {
        match self.prompter.ask(json!({"kind":"passkey","path":device.as_str()})).await {
            Answer::Number(n) => Ok(n),
            a => Err(refuse(a)),
        }
    }

    fn display_pin_code(&self, device: ObjectPath<'_>, pincode: String) {
        self.prompter.show(json!({"kind":"show-pin","path":device.as_str(),"pin":pincode}));
    }

    fn display_passkey(&self, device: ObjectPath<'_>, passkey: u32, entered: u16) {
        self.prompter.show(
            json!({"kind":"show-passkey","path":device.as_str(),"passkey":passkey,"entered":entered}),
        );
    }

    async fn request_confirmation(&self, device: ObjectPath<'_>, passkey: u32) -> Result<(), BluezError> {
        match self.prompter.ask(json!({"kind":"confirm","path":device.as_str(),"passkey":passkey})).await {
            Answer::Yes | Answer::Always => Ok(()),
            a => Err(refuse(a)),
        }
    }

    async fn request_authorization(&self, device: ObjectPath<'_>) -> Result<(), BluezError> {
        match self.prompter.ask(json!({"kind":"authorize","path":device.as_str()})).await {
            Answer::Yes | Answer::Always => Ok(()),
            a => Err(refuse(a)),
        }
    }

    async fn authorize_service(&self, device: ObjectPath<'_>, uuid: String) -> Result<(), BluezError> {
        let a = self
            .prompter
            .ask(json!({"kind":"service","path":device.as_str(),"uuid":uuid}))
            .await;
        if a == Answer::Always {
            let _ = self
                .conn
                .call_method(
                    Some("org.bluez"),
                    device.clone(),
                    Some("org.freedesktop.DBus.Properties"),
                    "Set",
                    &("org.bluez.Device1", "Trusted", Value::from(true)),
                )
                .await;
        }
        match a {
            Answer::Yes | Answer::Always => Ok(()),
            a => Err(refuse(a)),
        }
    }
}

async fn register(conn: &Connection) {
    let reg = conn
        .call_method(
            Some("org.bluez"),
            "/org/bluez",
            Some("org.bluez.AgentManager1"),
            "RegisterAgent",
            &(ObjectPath::try_from(AGENT_PATH).unwrap(), "KeyboardDisplay"),
        )
        .await;
    // AlreadyExists after a bluetoothd hiccup is fine.
    if let Err(e) = reg {
        if !e.to_string().contains("AlreadyExists") {
            eprintln!("bluetooth: RegisterAgent failed: {e}");
            return;
        }
    }
    if let Err(e) = conn
        .call_method(
            Some("org.bluez"),
            "/org/bluez",
            Some("org.bluez.AgentManager1"),
            "RequestDefaultAgent",
            &(ObjectPath::try_from(AGENT_PATH).unwrap(),),
        )
        .await
    {
        eprintln!("bluetooth: RequestDefaultAgent failed: {e}");
    }
}

/// Export the agent and (re-)register it whenever bluetoothd (re)appears.
pub async fn run(prompter: Prompter) -> zbus::Result<()> {
    let conn = zbus::connection::Builder::system()?.build().await?;
    conn.object_server()
        .at(AGENT_PATH, Agent { prompter: prompter.clone(), conn: conn.clone() })
        .await?;

    // A device that finished pairing / connected makes its prompt stale.
    let stale = {
        let conn = conn.clone();
        let prompter = prompter.clone();
        tokio::spawn(async move {
            let rule = zbus::MatchRule::builder()
                .msg_type(zbus::message::Type::Signal)
                .sender("org.bluez")?
                .interface("org.freedesktop.DBus.Properties")?
                .member("PropertiesChanged")?
                .build();
            let mut stream = zbus::MessageStream::for_match_rule(rule, &conn, None).await?;
            while let Some(Ok(msg)) = stream.next().await {
                let body = msg.body();
                let Ok((iface, changed, _)): Result<(String, std::collections::HashMap<String, Value>, Vec<String>), _> =
                    body.deserialize()
                else {
                    continue;
                };
                if iface != "org.bluez.Device1" {
                    continue;
                }
                let done = ["Connected", "Paired"]
                    .iter()
                    .any(|k| matches!(changed.get(*k), Some(Value::Bool(true))));
                if done {
                    if let Some(path) = msg.header().path() {
                        prompter.cancel_current(Some(path.as_str()));
                    }
                }
            }
            zbus::Result::Ok(())
        })
    };

    let dbus = DBusProxy::new(&conn).await?;
    let mut owner = dbus.receive_name_owner_changed_with_args(&[(0, "org.bluez")]).await?;
    if dbus.name_has_owner("org.bluez".try_into().unwrap()).await.unwrap_or(false) {
        register(&conn).await;
    }
    while let Some(sig) = owner.next().await {
        let Ok(args) = sig.args() else { continue };
        if args.new_owner().is_some() {
            register(&conn).await;
        } else {
            prompter.cancel_current(None);
        }
    }
    stale.abort();
    Ok(())
}
