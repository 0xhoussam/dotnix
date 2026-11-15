//! shell-agents: D-Bus agents for the Quickshell bar. Talks to the QML side
//! with JSON lines: events on stdout, answers on stdin. When stdin closes
//! (the shell exited), every pending prompt is cancelled and we exit, so
//! BlueZ and NetworkManager never wait on a dead UI.

mod bluetooth;
mod dbus;
mod keyring;
mod netops;
mod nm;
mod obex;
mod portal;
mod prompter;
mod secrets;
mod util;

use prompter::{Answer, Prompter};
use serde_json::Value;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::sync::mpsc;

fn parse_answer(v: &Value) -> Option<(u64, Answer)> {
    let id = v.get("id")?.as_u64()?;
    let answer = match v.get("kind")?.as_str()? {
        "cancel" => Answer::Cancel,
        "reject" => Answer::Reject,
        "yes" => Answer::Yes,
        "always" => Answer::Always,
        "text" => Answer::Text(v.get("text")?.as_str()?.to_string()),
        "number" => Answer::Number(u32::try_from(v.get("number")?.as_u64()?).ok()?),
        "fields" => Answer::Fields(
            v.get("fields")?
                .as_object()?
                .iter()
                .filter_map(|(k, v)| v.as_str().map(|s| (k.clone(), s.to_string())))
                .collect(),
        ),
        _ => return None,
    };
    Some((id, answer))
}

#[tokio::main]
async fn main() {
    let (out_tx, mut out_rx) = mpsc::unbounded_channel::<Value>();
    let out_tx2 = out_tx.clone();
    let prompter = Prompter::new(out_tx);

    tokio::spawn(async move {
        let mut stdout = tokio::io::stdout();
        while let Some(v) = out_rx.recv().await {
            let mut line = v.to_string();
            line.push('\n');
            if stdout.write_all(line.as_bytes()).await.is_err() || stdout.flush().await.is_err() {
                break;
            }
        }
    });

    // SHELL_AGENTS_SKIP=bluetooth,obex,... leaves parts out (safe live tests
    // next to the old bar, which owns the same agent slots).
    let skip: Vec<String> = std::env::var("SHELL_AGENTS_SKIP")
        .map(|v| v.split(',').map(|s| s.trim().to_string()).collect())
        .unwrap_or_default();
    let on = |name: &str| !skip.iter().any(|s| s == name);

    if on("bluetooth") {
        let p = prompter.clone();
        tokio::spawn(async move {
            if let Err(e) = bluetooth::run(p).await {
                eprintln!("bluetooth agent stopped: {e}");
            }
        });
    }

    // Generic D-Bus proxy, OBEX and the file picker need both buses.
    let buses = match dbus::Buses::connect().await {
        Ok(b) => Some(b),
        Err(e) => {
            eprintln!("could not connect to the buses: {e}");
            None
        }
    };
    let obex = buses.as_ref().map(|b| {
        let o = obex::Obex::new(b.session.clone(), b.system.clone(), prompter.clone(), out_tx2.clone());
        if on("obex") {
            let run = o.clone();
            tokio::spawn(async move {
                if let Err(e) = run.run().await {
                    eprintln!("obex agent stopped: {e}");
                }
            });
        }
        o
    });

    if let (true, Some(b)) = (on("secrets"), buses.as_ref()) {
        let (sys, ses, p) = (b.system.clone(), b.session.clone(), prompter.clone());
        tokio::spawn(async move {
            if let Err(e) = secrets::run(sys, ses, p).await {
                eprintln!("network secret agent stopped: {e}");
            }
        });
    }

    // NetworkManager model: snapshots to the UI on every (debounced) change.
    let mut nm_handle: Option<std::sync::Arc<nm::Nm>> = None;
    if let (true, Some(b)) = (on("network"), buses.as_ref()) {
        let nm = std::sync::Arc::new(nm::Nm::new(b.system.clone()));
        nm_handle = Some(nm.clone());
        let w = nm.clone();
        tokio::spawn(async move {
            if let Err(e) = w.watch().await {
                eprintln!("network watch stopped: {e}");
            }
        });
        let out = out_tx2.clone();
        tokio::spawn(async move {
            loop {
                nm.changed.notified().await;
                tokio::time::sleep(std::time::Duration::from_millis(300)).await;
                let _ = out.send(nm.snapshot());
            }
        });
    }

    let mut lines = BufReader::new(tokio::io::stdin()).lines();
    while let Ok(Some(line)) = lines.next_line().await {
        match serde_json::from_str::<Value>(&line) {
            Ok(v) if v["type"] == "answer" => {
                if let Some((id, a)) = parse_answer(&v) {
                    prompter.answer(id, a);
                }
            }
            Ok(v) => handle_request(v, &buses, &obex, &nm_handle, &out_tx2),
            Err(e) => eprintln!("bad input line: {e}"),
        }
    }
    prompter.cancel_current(None);
    // Let the Canceled replies reach BlueZ before the runtime goes away.
    tokio::time::sleep(std::time::Duration::from_millis(300)).await;
}

/// Requests from the UI: `call` (generic D-Bus), `send`, `pick-send`,
/// `cancel-transfer`. Each `call` gets exactly one `reply` with the same rid.
fn handle_request(
    v: Value,
    buses: &Option<dbus::Buses>,
    obex: &Option<obex::Obex>,
    nm: &Option<std::sync::Arc<nm::Nm>>,
    out: &mpsc::UnboundedSender<Value>,
) {
    if v["type"] == "net" {
        if let Some(nm) = nm.clone() {
            let out = out.clone();
            tokio::spawn(async move {
                let rid = v["rid"].clone();
                let reply = match nm.net_op(&v).await {
                    Ok(value) => serde_json::json!({"type":"reply","rid":rid,"ok":true,"value":value}),
                    Err(e) => serde_json::json!({"type":"reply","rid":rid,"ok":false,"error":e}),
                };
                let _ = out.send(reply);
            });
        }
        return;
    }
    let (Some(buses), Some(obex)) = (buses.clone(), obex.clone()) else { return };
    let out = out.clone();
    match v["type"].as_str() {
        Some("call") => {
            tokio::spawn(async move {
                let rid = v["rid"].clone();
                let reply = match dbus::call(&buses, &v).await {
                    Ok(value) => serde_json::json!({"type":"reply","rid":rid,"ok":true,"value":value}),
                    Err(e) => serde_json::json!({"type":"reply","rid":rid,"ok":false,"error":e}),
                };
                let _ = out.send(reply);
            });
        }
        Some("send") => {
            let address = v["address"].as_str().unwrap_or_default().to_string();
            let files: Vec<String> =
                v["files"].as_array().map(|a| a.iter().filter_map(|f| f.as_str().map(String::from)).collect()).unwrap_or_default();
            tokio::spawn(async move { obex.send(&address, files).await });
        }
        Some("pick-send") => {
            let address = v["address"].as_str().unwrap_or_default().to_string();
            let title = v["title"].as_str().unwrap_or("Send files").to_string();
            tokio::spawn(async move {
                let files = portal::pick_files(&buses.session, &title).await;
                if !files.is_empty() {
                    obex.send(&address, files).await;
                }
            });
        }
        Some("cancel-transfer") => {
            let path = v["path"].as_str().unwrap_or_default().to_string();
            tokio::spawn(async move { obex.cancel(&path).await });
        }
        _ => {}
    }
}
