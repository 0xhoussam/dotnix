//! Agent-owned NetworkManager secrets in the user's keyring, stored exactly
//! like nm-applet / gnome-shell / libsecret do so existing entries keep
//! working: attributes xdg:schema=org.freedesktop.NetworkManager.Connection,
//! connection-uuid, setting-name, setting-key (Secret Service over D-Bus,
//! "plain" transport on the session bus).

use futures_util::StreamExt;
use std::collections::HashMap;
use zbus::zvariant::{ObjectPath, OwnedObjectPath, OwnedValue, Value};
use zbus::Connection;

const SVC: &str = "org.freedesktop.secrets";
const SVC_PATH: &str = "/org/freedesktop/secrets";
const SCHEMA: &str = "org.freedesktop.NetworkManager.Connection";

pub struct Keyring {
    conn: Connection,
}

type Attrs<'a> = HashMap<&'a str, &'a str>;

impl Keyring {
    pub fn new(conn: Connection) -> Self {
        Keyring { conn }
    }

    async fn session(&self) -> zbus::Result<OwnedObjectPath> {
        let msg = self
            .conn
            .call_method(Some(SVC), SVC_PATH, Some("org.freedesktop.Secret.Service"), "OpenSession", &("plain", Value::from("")))
            .await?;
        let body = msg.body();
        let (_out, path): (OwnedValue, OwnedObjectPath) = body.deserialize()?;
        Ok(path)
    }

    /// Run a Secret Service prompt and wait for it to finish.
    async fn prompt(&self, prompt: &str) -> zbus::Result<()> {
        if prompt == "/" {
            return Ok(());
        }
        let rule = zbus::MatchRule::builder()
            .msg_type(zbus::message::Type::Signal)
            .interface("org.freedesktop.Secret.Prompt")?
            .member("Completed")?
            .path(prompt)?
            .build();
        let mut stream = zbus::MessageStream::for_match_rule(rule, &self.conn, None).await?;
        self.conn.call_method(Some(SVC), prompt, Some("org.freedesktop.Secret.Prompt"), "Prompt", &("",)).await?;
        let _ = tokio::time::timeout(std::time::Duration::from_secs(120), stream.next()).await;
        Ok(())
    }

    async fn unlock(&self, items: &[OwnedObjectPath]) -> zbus::Result<Vec<OwnedObjectPath>> {
        if items.is_empty() {
            return Ok(vec![]);
        }
        let msg = self
            .conn
            .call_method(Some(SVC), SVC_PATH, Some("org.freedesktop.Secret.Service"), "Unlock", &(items.to_vec(),))
            .await?;
        let body = msg.body();
        let (unlocked, prompt): (Vec<OwnedObjectPath>, OwnedObjectPath) = body.deserialize()?;
        self.prompt(prompt.as_str()).await?;
        Ok(unlocked)
    }

    /// All items matching the attributes (unlocking if needed).
    async fn search(&self, attrs: &Attrs<'_>) -> zbus::Result<Vec<OwnedObjectPath>> {
        let msg = self
            .conn
            .call_method(Some(SVC), SVC_PATH, Some("org.freedesktop.Secret.Service"), "SearchItems", &(attrs,))
            .await?;
        let body = msg.body();
        let (mut unlocked, locked): (Vec<OwnedObjectPath>, Vec<OwnedObjectPath>) = body.deserialize()?;
        if !locked.is_empty() {
            unlocked.extend(self.unlock(&locked).await.unwrap_or_default());
        }
        Ok(unlocked)
    }

    /// All stored secrets for one setting of one connection: { key: value }.
    pub async fn lookup(&self, uuid: &str, setting: &str) -> HashMap<String, String> {
        self.lookup_inner(uuid, setting).await.unwrap_or_else(|e| {
            eprintln!("network: keyring lookup failed: {e}");
            HashMap::new()
        })
    }

    async fn lookup_inner(&self, uuid: &str, setting: &str) -> zbus::Result<HashMap<String, String>> {
        let mut out = HashMap::new();
        let mut attrs = Attrs::new();
        attrs.insert("xdg:schema", SCHEMA);
        attrs.insert("connection-uuid", uuid);
        attrs.insert("setting-name", setting);
        let items = self.search(&attrs).await?;
        if items.is_empty() {
            return Ok(out);
        }
        let session = self.session().await?;
        for item in items {
            let a = self
                .conn
                .call_method(Some(SVC), item.as_str(), Some("org.freedesktop.DBus.Properties"), "Get", &("org.freedesktop.Secret.Item", "Attributes"))
                .await?;
            let body = a.body();
            let v: OwnedValue = body.deserialize()?;
            let attrs: HashMap<String, String> = HashMap::try_from(v).unwrap_or_default();
            let Some(key) = attrs.get("setting-key") else { continue };
            let s = self
                .conn
                .call_method(Some(SVC), item.as_str(), Some("org.freedesktop.Secret.Item"), "GetSecret", &(&session,))
                .await?;
            let body = s.body();
            let (_sess, _params, value, _ct): (OwnedObjectPath, Vec<u8>, Vec<u8>, String) = body.deserialize()?;
            out.insert(key.clone(), String::from_utf8_lossy(&value).into_owned());
        }
        Ok(out)
    }

    pub async fn store(&self, uuid: &str, id: &str, setting: &str, key: &str, value: &str) {
        if let Err(e) = self.store_inner(uuid, id, setting, key, value).await {
            eprintln!("network: keyring store failed: {e}");
        }
    }

    async fn store_inner(&self, uuid: &str, id: &str, setting: &str, key: &str, value: &str) -> zbus::Result<()> {
        let session = self.session().await?;
        let mut attrs = Attrs::new();
        attrs.insert("xdg:schema", SCHEMA);
        attrs.insert("connection-uuid", uuid);
        attrs.insert("setting-name", setting);
        attrs.insert("setting-key", key);
        let label = format!("Network secret for {id}/{setting}/{key}");
        let mut props = HashMap::<&str, Value>::new();
        props.insert("org.freedesktop.Secret.Item.Label", Value::from(label.as_str()));
        props.insert("org.freedesktop.Secret.Item.Attributes", Value::from(attrs));
        let secret = (session, Vec::<u8>::new(), value.as_bytes().to_vec(), "text/plain");
        let msg = self
            .conn
            .call_method(
                Some(SVC),
                "/org/freedesktop/secrets/aliases/default",
                Some("org.freedesktop.Secret.Collection"),
                "CreateItem",
                &(props, secret, true),
            )
            .await?;
        let body = msg.body();
        let (_item, prompt): (OwnedObjectPath, OwnedObjectPath) = body.deserialize()?;
        self.prompt(prompt.as_str()).await
    }

    /// Remove every secret for a connection (or just one setting of it).
    pub async fn clear(&self, uuid: &str, setting: Option<&str>) {
        let mut attrs = Attrs::new();
        attrs.insert("xdg:schema", SCHEMA);
        attrs.insert("connection-uuid", uuid);
        if let Some(s) = setting {
            attrs.insert("setting-name", s);
        }
        match self.search(&attrs).await {
            Ok(items) => {
                for i in items {
                    let _ = self
                        .conn
                        .call_method(Some(SVC), i.as_str(), Some("org.freedesktop.Secret.Item"), "Delete", &())
                        .await;
                }
            }
            Err(e) => eprintln!("network: keyring clear failed: {e}"),
        }
    }
}

#[allow(dead_code)]
fn _p(_: ObjectPath<'_>) {}
