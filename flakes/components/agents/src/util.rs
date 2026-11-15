//! Small helpers: desktop notifications, paths, settings, percent-decoding.

use serde_json::Value as Json;
use std::path::{Path, PathBuf};
use zbus::zvariant::Value;
use zbus::Connection;

/// Notify over the session bus (lands in our own notification server).
pub async fn notify(conn: &Connection, summary: &str, body: &str, icon: &str) {
    let mut hints = std::collections::HashMap::<&str, Value>::new();
    hints.insert("urgency", Value::U8(1));
    hints.insert("desktop-entry", Value::from("bluetooth"));
    let r = conn
        .call_method(
            Some("org.freedesktop.Notifications"),
            "/org/freedesktop/Notifications",
            Some("org.freedesktop.Notifications"),
            "Notify",
            &("Bluetooth", 0u32, icon, summary, body, Vec::<&str>::new(), hints, -1i32),
        )
        .await;
    if let Err(e) = r {
        eprintln!("notify failed: {e}");
    }
}

pub fn home() -> PathBuf {
    std::env::var_os("HOME").map(PathBuf::from).unwrap_or_else(|| PathBuf::from("/"))
}

pub fn config_dir() -> PathBuf {
    std::env::var_os("XDG_CONFIG_HOME").map(PathBuf::from).unwrap_or_else(|| home().join(".config"))
}

/// XDG_DOWNLOAD_DIR from user-dirs.dirs, else ~/Downloads.
pub fn download_dir() -> PathBuf {
    if let Ok(t) = std::fs::read_to_string(config_dir().join("user-dirs.dirs")) {
        for l in t.lines() {
            if let Some(v) = l.trim().strip_prefix("XDG_DOWNLOAD_DIR=") {
                let v = v.trim().trim_matches('"').replace("$HOME", &home().to_string_lossy());
                if !v.is_empty() {
                    return PathBuf::from(v);
                }
            }
        }
    }
    home().join("Downloads")
}

/// `dir/name`, or `dir/base (1).ext` etc. when it exists.
pub fn unique_dest(dir: &Path, name: &str) -> PathBuf {
    let first = dir.join(name);
    if !first.exists() {
        return first;
    }
    let (base, ext) = match name.rfind('.') {
        Some(d) if d > 0 => (&name[..d], &name[d..]),
        _ => (name, ""),
    };
    (1..)
        .map(|i| dir.join(format!("{base} ({i}){ext}")))
        .find(|p| !p.exists())
        .unwrap()
}

/// Bluetooth settings file written by the QML side.
pub fn bt_setting_bool(key: &str) -> bool {
    let p = config_dir().join("my-shell").join("bluetooth.json");
    std::fs::read_to_string(p)
        .ok()
        .and_then(|t| serde_json::from_str::<Json>(&t).ok())
        .and_then(|j| j.get(key).and_then(Json::as_bool))
        .unwrap_or(false)
}

pub fn percent_decode(s: &str) -> String {
    let b = s.as_bytes();
    let mut out = Vec::with_capacity(b.len());
    let mut i = 0;
    while i < b.len() {
        if b[i] == b'%' && i + 2 < b.len() {
            let hex = std::str::from_utf8(&b[i + 1..i + 3]).ok().and_then(|h| u8::from_str_radix(h, 16).ok());
            if let Some(v) = hex {
                out.push(v);
                i += 3;
                continue;
            }
        }
        out.push(b[i]);
        i += 1;
    }
    String::from_utf8_lossy(&out).into_owned()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn decodes_percent() {
        assert_eq!(percent_decode("file:///a%20b/c%2Bd.txt"), "file:///a b/c+d.txt");
        assert_eq!(percent_decode("100%"), "100%");
        assert_eq!(percent_decode("%zz"), "%zz");
    }

    #[test]
    fn unique_names() {
        let d = std::env::temp_dir().join(format!("sa-test-{}", std::process::id()));
        std::fs::create_dir_all(&d).unwrap();
        assert_eq!(unique_dest(&d, "a.txt"), d.join("a.txt"));
        std::fs::write(d.join("a.txt"), "").unwrap();
        assert_eq!(unique_dest(&d, "a.txt"), d.join("a (1).txt"));
        std::fs::write(d.join("a (1).txt"), "").unwrap();
        assert_eq!(unique_dest(&d, "a.txt"), d.join("a (2).txt"));
        std::fs::write(d.join("noext"), "").unwrap();
        assert_eq!(unique_dest(&d, "noext"), d.join("noext (1)"));
        std::fs::remove_dir_all(&d).unwrap();
    }
}
