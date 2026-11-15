//! File chooser via xdg-desktop-portal (the old GTK dialog did the same).

use crate::util::percent_decode;
use futures_util::StreamExt;
use std::collections::HashMap;
use zbus::zvariant::{OwnedValue, Value};
use zbus::Connection;

/// Ask the user for one or more files. Empty on cancel or any failure.
pub async fn pick_files(conn: &Connection, title: &str) -> Vec<String> {
    run(conn, title).await.unwrap_or_default()
}

async fn run(conn: &Connection, title: &str) -> zbus::Result<Vec<String>> {
    let sender = conn.unique_name().map(|n| n.as_str().trim_start_matches(':').replace('.', "_")).unwrap_or_default();
    let token = format!("shell_agents_{}", std::process::id());
    let handle = format!("/org/freedesktop/portal/desktop/request/{sender}/{token}");

    // Subscribe before the call so the Response cannot be missed.
    let rule = zbus::MatchRule::builder()
        .msg_type(zbus::message::Type::Signal)
        .interface("org.freedesktop.portal.Request")?
        .member("Response")?
        .path(handle.as_str())?
        .build();
    let mut stream = zbus::MessageStream::for_match_rule(rule, conn, None).await?;

    let mut opts = HashMap::<&str, Value>::new();
    opts.insert("handle_token", Value::from(token.as_str()));
    opts.insert("multiple", Value::Bool(true));
    conn.call_method(
        Some("org.freedesktop.portal.Desktop"),
        "/org/freedesktop/portal/desktop",
        Some("org.freedesktop.portal.FileChooser"),
        "OpenFile",
        &("", title, opts),
    )
    .await?;

    let Some(Ok(msg)) = stream.next().await else { return Ok(vec![]) };
    let body = msg.body();
    let (code, results): (u32, HashMap<String, OwnedValue>) = body.deserialize()?;
    if code != 0 {
        return Ok(vec![]);
    }
    let uris: Vec<String> = results
        .get("uris")
        .and_then(|v| <Vec<String>>::try_from(v.try_clone().ok()?).ok())
        .unwrap_or_default();
    Ok(uris
        .iter()
        .filter_map(|u| u.strip_prefix("file://"))
        .map(percent_decode)
        .collect())
}
