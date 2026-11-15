//! shell-agents: D-Bus agents for the Quickshell bar. Talks to the QML side
//! with JSON lines: events on stdout, answers on stdin. When stdin closes
//! (the shell exited), every pending prompt is cancelled and we exit, so
//! BlueZ and NetworkManager never wait on a dead UI.

mod bluetooth;
mod prompter;

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
        _ => return None,
    };
    Some((id, answer))
}

#[tokio::main]
async fn main() {
    let (out_tx, mut out_rx) = mpsc::unbounded_channel::<Value>();
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

    {
        let p = prompter.clone();
        tokio::spawn(async move {
            if let Err(e) = bluetooth::run(p).await {
                eprintln!("bluetooth agent stopped: {e}");
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
            Ok(_) => {}
            Err(e) => eprintln!("bad input line: {e}"),
        }
    }
    prompter.cancel_current(None);
    // Let the Canceled replies reach BlueZ before the runtime goes away.
    tokio::time::sleep(std::time::Duration::from_millis(300)).await;
}
