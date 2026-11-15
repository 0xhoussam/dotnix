//! Requests from the network panel: activate / add / disconnect / forget,
//! radios, scan. Activation waits until the connection is up or has failed,
//! like the old `connectAndWait`.

use crate::nm::{Nm, NM, NM_PATH};
use serde_json::{json, Value as Json};
use std::collections::HashMap;
use std::time::Duration;
use zbus::zvariant::{ObjectPath, OwnedObjectPath, Value};

const I_NM: &str = "org.freedesktop.NetworkManager";
const I_DEV: &str = "org.freedesktop.NetworkManager.Device";

fn s<'a>(req: &'a Json, k: &str) -> Result<&'a str, String> {
    req.get(k).and_then(Json::as_str).ok_or(format!("missing {k}"))
}

fn path(p: &str) -> Result<ObjectPath<'_>, String> {
    ObjectPath::try_from(p).map_err(|e| e.to_string())
}

fn err(e: zbus::Error) -> String {
    // "org.freedesktop.NetworkManager.Settings.PermissionDenied: ..." -> text
    match e {
        zbus::Error::MethodError(name, msg, _) => format!("{}: {}", name.as_str(), msg.unwrap_or_default()),
        other => other.to_string(),
    }
}

/// NM_DEVICE_STATE_REASON values worth explaining (nm-applet's list).
pub fn device_reason_text(r: u64) -> &'static str {
    match r {
        4 => "Configuration failed",
        5 => "Couldn't get an IP address",
        6 => "IP address lease expired",
        7 => "Password required",
        8 => "Authentication failed — wrong password?",
        9 => "Wi-Fi configuration rejected",
        10 => "Wi-Fi supplicant failed",
        11 => "Authentication timed out — wrong password?",
        15 => "DHCP failed to start",
        16 => "DHCP error",
        17 => "Couldn't get an IP address (DHCP)",
        35 => "Firmware missing",
        36 => "Device removed",
        37 => "System is sleeping",
        38 => "Connection was removed",
        39 => "Disconnected by user",
        40 => "Cable unplugged",
        50 => "A required connection failed",
        53 => "Network not found",
        54 => "Secondary connection (VPN) failed",
        64 => "IP address already in use",
        _ => "Connection failed",
    }
}

#[derive(Debug, PartialEq)]
pub enum Wait {
    Pending,
    Done,
    Failed,
}

/// Activation progress from the active connection's state (NM_ACTIVE_CONNECTION_STATE:
/// 1 activating, 2 activated, 3 deactivating, 4 deactivated). `seen`: the
/// object has been in the store at least once.
pub fn wait_status(seen: bool, state: Option<u64>) -> Wait {
    match state {
        Some(2) => Wait::Done,
        Some(3) | Some(4) => Wait::Failed,
        Some(_) => Wait::Pending,
        None if seen => Wait::Failed, // it appeared and is gone again
        None => Wait::Pending,        // not loaded yet
    }
}

impl Nm {
    async fn call<B>(&self, p: &str, iface: &str, method: &str, body: &B) -> Result<zbus::Message, String>
    where
        B: serde::Serialize + zbus::zvariant::DynamicType,
    {
        self.conn.call_method(Some(NM), p, Some(iface), method, body).await.map_err(err)
    }

    /// Wait until active connection `ac` is activated; Err(reason) otherwise.
    /// The store learns about a fresh active connection a moment after
    /// ActivateConnection returns, so "not there yet" is pending until it
    /// has been seen once.
    async fn wait_active(&self, ac: &str, dev: Option<&str>) -> Result<(), String> {
        let deadline = tokio::time::Instant::now() + Duration::from_secs(90);
        let mut seen = false;
        loop {
            let notified = self.changed.notified();
            let (state, reason) = self.snapshot_raw(ac, dev);
            seen |= state.is_some();
            match wait_status(seen, state) {
                Wait::Done => return Ok(()),
                Wait::Failed => return Err(device_reason_text(reason).to_string()),
                Wait::Pending => {}
            }
            if tokio::time::timeout_at(deadline, notified).await.is_err() {
                return Err("Connection timed out".into());
            }
        }
    }

    /// (active connection state, device state reason).
    fn snapshot_raw(&self, ac: &str, dev: Option<&str>) -> (Option<u64>, u64) {
        let st = self.store.lock().unwrap();
        let state = st.ac_state(ac);
        let reason = dev.map(|d| st.device_reason(d)).unwrap_or(0);
        (state, reason)
    }

    pub async fn net_op(&self, req: &Json) -> Result<Json, String> {
        match s(req, "op")? {
            "scan" => {
                for d in req["devices"].as_array().cloned().unwrap_or_default() {
                    let Some(d) = d.as_str() else { continue };
                    // rate limited / busy: ignore
                    let _ = self
                        .conn
                        .call_method(Some(NM), d, Some("org.freedesktop.NetworkManager.Device.Wireless"), "RequestScan", &(HashMap::<&str, Value>::new(),))
                        .await;
                }
                Ok(json!([]))
            }
            op @ ("set-wifi" | "set-wwan") => {
                let on = req["on"].as_bool().ok_or("missing on")?;
                let prop = if op == "set-wifi" { "WirelessEnabled" } else { "WwanEnabled" };
                self.call(NM_PATH, "org.freedesktop.DBus.Properties", "Set", &(I_NM, prop, Value::Bool(on))).await?;
                Ok(json!([]))
            }
            "set-networking" => {
                let on = req["on"].as_bool().ok_or("missing on")?;
                match self.call(NM_PATH, I_NM, "Enable", &(on,)).await {
                    Err(e) if e.contains("AlreadyEnabledOrDisabled") => {}
                    Err(e) => return Err(e),
                    Ok(_) => {}
                }
                Ok(json!([]))
            }
            "connect" => {
                // activate a saved connection (device / ap optional: "/" = pick)
                let (conn, dev, ap) = (req["conn"].as_str().unwrap_or("/"), req["device"].as_str().unwrap_or("/"), req["ap"].as_str().unwrap_or("/"));
                let m = self.call(NM_PATH, I_NM, "ActivateConnection", &(path(conn)?, path(dev)?, path(ap)?)).await?;
                let ac: OwnedObjectPath = m.body().deserialize().map_err(|e| e.to_string())?;
                self.wait_active(ac.as_str(), (dev != "/").then_some(dev)).await?;
                Ok(json!([]))
            }
            "connect-new" => {
                // new connection: NM completes `settings` and asks our secret agent for secrets
                let (dev, ap) = (s(req, "device")?, req["ap"].as_str().unwrap_or("/"));
                let settings = build_settings(&req["settings"])?;
                let m = self.call(NM_PATH, I_NM, "AddAndActivateConnection", &(settings, path(dev)?, path(ap)?)).await?;
                let (conn, ac): (OwnedObjectPath, OwnedObjectPath) = m.body().deserialize().map_err(|e| e.to_string())?;
                if let Err(e) = self.wait_active(ac.as_str(), Some(dev)).await {
                    // do not leave a half-made connection behind
                    let _ = self.call(conn.as_str(), "org.freedesktop.NetworkManager.Settings.Connection", "Delete", &()).await;
                    return Err(e);
                }
                Ok(json!([]))
            }
            "disconnect-device" => {
                self.call(s(req, "device")?, I_DEV, "Disconnect", &()).await?;
                Ok(json!([]))
            }
            "deactivate" => {
                self.call(NM_PATH, I_NM, "DeactivateConnection", &(path(s(req, "ac")?)?,)).await?;
                Ok(json!([]))
            }
            "forget" => {
                for c in req["conns"].as_array().cloned().unwrap_or_default() {
                    let Some(c) = c.as_str() else { continue };
                    self.call(c, "org.freedesktop.NetworkManager.Settings.Connection", "Delete", &()).await?;
                }
                Ok(json!([]))
            }
            op => Err(format!("unknown op {op}")),
        }
    }
}

/// `{"connection": {"type": "802-11-wireless", ...}, ...}` with plain JSON
/// scalars/arrays -> a{sa{sv}}. Arrays of numbers become `ay`.
pub fn build_settings(j: &Json) -> Result<HashMap<String, HashMap<String, zbus::zvariant::OwnedValue>>, String> {
    let mut out = HashMap::new();
    let Some(obj) = j.as_object() else { return Ok(out) };
    for (setting, props) in obj {
        let mut m = HashMap::new();
        for (k, v) in props.as_object().ok_or("settings must be objects")? {
            let val: Value = match v {
                Json::Bool(b) => Value::Bool(*b),
                Json::String(s) => Value::from(s.as_str()),
                Json::Number(n) => Value::U32(n.as_u64().ok_or("bad number")? as u32),
                Json::Array(a) if a.iter().all(|x| x.is_u64()) => {
                    Value::from(a.iter().map(|x| x.as_u64().unwrap() as u8).collect::<Vec<u8>>())
                }
                Json::Array(a) => Value::from(a.iter().filter_map(|x| x.as_str().map(String::from)).collect::<Vec<String>>()),
                _ => return Err(format!("unsupported value for {setting}.{k}")),
            };
            m.insert(k.clone(), val.try_to_owned().map_err(|e| e.to_string())?);
        }
        out.insert(setting.clone(), m);
    }
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn activation_waits_for_the_object_to_appear() {
        assert_eq!(wait_status(false, None), Wait::Pending); // right after ActivateConnection
        assert_eq!(wait_status(true, Some(1)), Wait::Pending);
        assert_eq!(wait_status(true, Some(2)), Wait::Done);
        assert_eq!(wait_status(true, Some(4)), Wait::Failed);
        assert_eq!(wait_status(true, None), Wait::Failed); // gone after being seen
    }

    #[test]
    fn settings_conversion() {
        let s = build_settings(&json!({
            "connection": {"type": "802-11-wireless", "id": "x", "autoconnect": true},
            "802-11-wireless": {"ssid": [72, 105], "hidden": true},
            "802-11-wireless-security": {"key-mgmt": "wpa-psk", "psk": "secret123"}
        }))
        .unwrap();
        assert_eq!(s.len(), 3);
        let ssid = &s["802-11-wireless"]["ssid"];
        assert_eq!(ssid.value_signature().to_string(), "ay");
        assert_eq!(s["connection"]["autoconnect"].value_signature().to_string(), "b");
        assert!(build_settings(&json!({"a": {"k": null}})).is_err());
    }
}
