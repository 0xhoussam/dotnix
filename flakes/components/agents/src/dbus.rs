//! Generic D-Bus call proxy for the QML side, plus JSON <-> zvariant
//! conversion. The UI describes arguments as `{"t": <signature>, "v": ...}`
//! and gets replies as plain JSON.

use serde_json::{json, Map, Value as Json};
use std::collections::HashMap;
use zbus::zvariant::{self, Array, Dict, ObjectPath, Signature, Structure, Value};
use zbus::Connection;

/// Plain JSON for any D-Bus value (dicts become objects when keys are
/// strings, variants are unwrapped, file descriptors become null).
pub fn value_to_json(v: &Value<'_>) -> Json {
    match v {
        Value::U8(n) => json!(n),
        Value::Bool(b) => json!(b),
        Value::I16(n) => json!(n),
        Value::U16(n) => json!(n),
        Value::I32(n) => json!(n),
        Value::U32(n) => json!(n),
        Value::I64(n) => json!(n),
        Value::U64(n) => json!(n),
        Value::F64(n) => json!(n),
        Value::Str(s) => json!(s.as_str()),
        Value::Signature(s) => json!(s.to_string()),
        Value::ObjectPath(p) => json!(p.as_str()),
        Value::Value(inner) => value_to_json(inner),
        Value::Array(a) => Json::Array(a.iter().map(value_to_json).collect()),
        Value::Dict(d) => {
            let mut m = Map::new();
            for (k, val) in d.iter() {
                let key = match k {
                    Value::Str(s) => s.to_string(),
                    Value::ObjectPath(p) => p.to_string(),
                    other => value_to_json(other).to_string(),
                };
                m.insert(key, value_to_json(val));
            }
            Json::Object(m)
        }
        Value::Structure(s) => Json::Array(s.fields().iter().map(value_to_json).collect()),
        _ => Json::Null,
    }
}

/// `{"t":"s","v":"x"}` -> Value. Supported: y b n q i u x t d s o g, `as`,
/// `ao`, and `a{sv}` (whose values are themselves `{t,v}` objects).
pub fn json_to_value(j: &Json) -> Result<Value<'static>, String> {
    let t = j.get("t").and_then(Json::as_str).ok_or("argument without \"t\"")?;
    let v = j.get("v").ok_or("argument without \"v\"")?;
    let bad = || format!("bad value for type {t}");
    Ok(match t {
        "y" => Value::U8(v.as_u64().ok_or_else(bad)? as u8),
        "b" => Value::Bool(v.as_bool().ok_or_else(bad)?),
        "n" => Value::I16(v.as_i64().ok_or_else(bad)? as i16),
        "q" => Value::U16(v.as_u64().ok_or_else(bad)? as u16),
        "i" => Value::I32(v.as_i64().ok_or_else(bad)? as i32),
        "u" => Value::U32(v.as_u64().ok_or_else(bad)? as u32),
        "x" => Value::I64(v.as_i64().ok_or_else(bad)?),
        "t" => Value::U64(v.as_u64().ok_or_else(bad)?),
        "d" => Value::F64(v.as_f64().ok_or_else(bad)?),
        "s" => Value::Str(v.as_str().ok_or_else(bad)?.to_string().into()),
        "o" => Value::ObjectPath(
            ObjectPath::try_from(v.as_str().ok_or_else(bad)?.to_string()).map_err(|e| e.to_string())?,
        ),
        "g" => Value::Signature(Signature::try_from(v.as_str().ok_or_else(bad)?).map_err(|e| e.to_string())?.to_owned()),
        "v" => Value::Value(Box::new(json_to_value(v)?)),
        "as" => {
            let mut a = Array::new(&Signature::Str);
            for item in v.as_array().ok_or_else(bad)? {
                a.append(Value::Str(item.as_str().ok_or_else(bad)?.to_string().into()))
                    .map_err(|e| e.to_string())?;
            }
            Value::Array(a)
        }
        "ao" => {
            let mut a = Array::new(&Signature::ObjectPath);
            for item in v.as_array().ok_or_else(bad)? {
                let p = ObjectPath::try_from(item.as_str().ok_or_else(bad)?.to_string()).map_err(|e| e.to_string())?;
                a.append(Value::ObjectPath(p)).map_err(|e| e.to_string())?;
            }
            Value::Array(a)
        }
        "a{sv}" => {
            let mut d = Dict::new(&Signature::Str, &Signature::Variant);
            for (k, val) in v.as_object().ok_or_else(bad)? {
                let inner = json_to_value(val)?;
                d.append(Value::Str(k.clone().into()), Value::Value(Box::new(inner)))
                    .map_err(|e| e.to_string())?;
            }
            Value::Dict(d)
        }
        other => return Err(format!("unsupported type {other}")),
    })
}

/// Connections by bus name. The session bus is opened lazily.
#[derive(Clone)]
pub struct Buses {
    pub system: Connection,
    pub session: Connection,
}

impl Buses {
    pub async fn connect() -> zbus::Result<Self> {
        Ok(Buses { system: Connection::system().await?, session: Connection::session().await? })
    }
    pub fn get(&self, name: &str) -> &Connection {
        if name == "session" { &self.session } else { &self.system }
    }
}

/// Run one `{"type":"call", ...}` request; returns the reply body as a JSON array.
pub async fn call(buses: &Buses, req: &Json) -> Result<Json, String> {
    let s = |k: &str| req.get(k).and_then(Json::as_str).ok_or(format!("missing {k}"));
    let conn = buses.get(req.get("bus").and_then(Json::as_str).unwrap_or("system"));
    let mut fields = Vec::new();
    for a in req.get("args").and_then(Json::as_array).unwrap_or(&vec![]) {
        fields.push(json_to_value(a)?);
    }
    let timeout = req.get("timeout_ms").and_then(Json::as_u64).unwrap_or(30_000);
    let (dest, path, iface, method) = (s("dest")?, s("path")?, s("iface")?, s("method")?);
    let fut: std::pin::Pin<Box<dyn std::future::Future<Output = zbus::Result<zbus::Message>> + Send + '_>> =
        if fields.is_empty() {
            Box::pin(conn.call_method(Some(dest), path, Some(iface), method, &()))
        } else {
            let body = fields
                .into_iter()
                .fold(zvariant::StructureBuilder::new(), |b, v| b.append_field(v))
                .build()
                .map_err(|e| e.to_string())?;
            Box::pin(async move { conn.call_method(Some(dest), path, Some(iface), method, &body).await })
        };
    let msg = tokio::time::timeout(std::time::Duration::from_millis(timeout), fut)
        .await
        .map_err(|_| "Timeout was reached".to_string())?
        .map_err(|e| e.to_string())?;
    let b = msg.body();
    if b.signature().to_string().is_empty() {
        return Ok(json!([]));
    }
    let st: Structure = b.deserialize().map_err(|e| e.to_string())?;
    Ok(Json::Array(st.fields().iter().map(value_to_json).collect()))
}

/// GetAll helper for Rust-side callers.
pub async fn get_all(conn: &Connection, dest: &str, path: &str, iface: &str) -> Option<HashMap<String, Json>> {
    let msg = conn
        .call_method(Some(dest), path, Some("org.freedesktop.DBus.Properties"), "GetAll", &(iface,))
        .await
        .ok()?;
    let b = msg.body();
    let st: Structure = b.deserialize().ok()?;
    match value_to_json(&st.fields()[0]) {
        Json::Object(m) => Some(m.into_iter().collect()),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn args_round_trip() {
        let v = json_to_value(&json!({"t":"a{sv}","v":{"Target":{"t":"s","v":"opp"}}})).unwrap();
        let j = value_to_json(&v);
        assert_eq!(j, json!({"Target":"opp"}));
        assert_eq!(value_to_json(&json_to_value(&json!({"t":"o","v":"/a/b"})).unwrap()), json!("/a/b"));
        assert_eq!(value_to_json(&json_to_value(&json!({"t":"as","v":["x","y"]})).unwrap()), json!(["x", "y"]));
        assert!(json_to_value(&json!({"t":"s","v":1})).is_err());
        assert!(json_to_value(&json!({"t":"zz","v":1})).is_err());
    }
}
