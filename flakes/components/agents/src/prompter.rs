//! One prompt at a time, shared by every agent in this process. A newer
//! request supersedes the current one (which resolves as `Cancel`). Same
//! semantics as the old `prompts.ts`: `ask` waits for the user, `show`
//! displays information and updates in place for repeated calls.

use serde_json::{json, Value};
use std::sync::{Arc, Mutex};
use tokio::sync::{mpsc, oneshot};

#[derive(Debug, Clone, PartialEq)]
pub enum Answer {
    /// Dialog dismissed, superseded, or the UI went away.
    Cancel,
    /// Explicit "no".
    Reject,
    Text(String),
    Number(u32),
    Yes,
    /// "Yes, and trust the device".
    Always,
}

struct Active {
    id: u64,
    kind: String,
    path: String,
    prompt: Value,
    tx: Option<oneshot::Sender<Answer>>,
}

struct Inner {
    next_id: u64,
    active: Option<Active>,
}

/// Messages for the UI, serialised as JSON lines on stdout.
pub type Out = mpsc::UnboundedSender<Value>;

#[derive(Clone)]
pub struct Prompter {
    inner: Arc<Mutex<Inner>>,
    out: Out,
}

impl Prompter {
    pub fn new(out: Out) -> Self {
        Prompter { inner: Arc::new(Mutex::new(Inner { next_id: 1, active: None })), out }
    }

    fn settle_locked(&self, inner: &mut Inner, answer: Answer) {
        if let Some(a) = inner.active.take() {
            let _ = self.out.send(json!({ "type": "prompt-clear", "id": a.id }));
            if let Some(tx) = a.tx {
                let _ = tx.send(answer);
            }
        }
    }

    fn begin(&self, prompt: Value, wants_answer: bool) -> (u64, Option<oneshot::Receiver<Answer>>) {
        let mut inner = self.inner.lock().unwrap();
        self.settle_locked(&mut inner, Answer::Cancel);
        let id = inner.next_id;
        inner.next_id += 1;
        let (tx, rx) = if wants_answer {
            let (tx, rx) = oneshot::channel();
            (Some(tx), Some(rx))
        } else {
            (None, None)
        };
        let kind = prompt["kind"].as_str().unwrap_or_default().to_string();
        let path = prompt["path"].as_str().unwrap_or_default().to_string();
        let _ = self.out.send(json!({ "type": "prompt", "id": id, "prompt": prompt }));
        inner.active = Some(Active { id, kind, path, prompt, tx });
        (id, rx)
    }

    /// Show a prompt and wait for the user's answer. Resolves `Cancel` if
    /// superseded, cancelled by the agent, or the UI is gone.
    pub async fn ask(&self, prompt: Value) -> Answer {
        let (_, rx) = self.begin(prompt, true);
        rx.unwrap().await.unwrap_or(Answer::Cancel)
    }

    /// Informational prompt (passkey to type on the device). Repeated calls
    /// for the same kind and device update the digits in place.
    pub fn show(&self, prompt: Value) {
        {
            let mut inner = self.inner.lock().unwrap();
            if let Some(a) = inner.active.as_mut() {
                if a.tx.is_none()
                    && a.kind == prompt["kind"].as_str().unwrap_or_default()
                    && a.path == prompt["path"].as_str().unwrap_or_default()
                {
                    a.prompt = prompt.clone();
                    let _ = self.out.send(json!({ "type": "prompt", "id": a.id, "prompt": prompt }));
                    return;
                }
            }
        }
        self.begin(prompt, false);
    }

    /// The user answered prompt `id` (ignored if it is already gone).
    pub fn answer(&self, id: u64, answer: Answer) {
        let mut inner = self.inner.lock().unwrap();
        if inner.active.as_ref().map(|a| a.id) == Some(id) {
            self.settle_locked(&mut inner, answer);
        }
    }

    /// The agent was cancelled, or the device finished pairing. With a path,
    /// only a prompt about that path is cleared.
    pub fn cancel_current(&self, path: Option<&str>) {
        let mut inner = self.inner.lock().unwrap();
        if let (Some(a), Some(p)) = (inner.active.as_ref(), path) {
            if a.path != p {
                return;
            }
        }
        self.settle_locked(&mut inner, Answer::Cancel);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn setup() -> (Prompter, mpsc::UnboundedReceiver<Value>) {
        let (tx, rx) = mpsc::unbounded_channel();
        (Prompter::new(tx), rx)
    }

    #[tokio::test]
    async fn answer_resolves_ask() {
        let (p, mut rx) = setup();
        let p2 = p.clone();
        let h = tokio::spawn(async move { p2.ask(json!({"kind":"confirm","path":"/d"})).await });
        let m = rx.recv().await.unwrap();
        assert_eq!(m["type"], "prompt");
        p.answer(m["id"].as_u64().unwrap(), Answer::Yes);
        assert_eq!(h.await.unwrap(), Answer::Yes);
        assert_eq!(rx.recv().await.unwrap()["type"], "prompt-clear");
    }

    #[tokio::test]
    async fn newer_prompt_supersedes_older() {
        let (p, mut rx) = setup();
        let p1 = p.clone();
        let first = tokio::spawn(async move { p1.ask(json!({"kind":"pin","path":"/a"})).await });
        rx.recv().await.unwrap();
        let p2 = p.clone();
        let second = tokio::spawn(async move { p2.ask(json!({"kind":"pin","path":"/b"})).await });
        assert_eq!(first.await.unwrap(), Answer::Cancel);
        let clear = rx.recv().await.unwrap();
        assert_eq!(clear["type"], "prompt-clear");
        let m = rx.recv().await.unwrap();
        assert_eq!(m["type"], "prompt");
        p.answer(m["id"].as_u64().unwrap(), Answer::Text("1234".into()));
        assert_eq!(second.await.unwrap(), Answer::Text("1234".into()));
    }

    #[tokio::test]
    async fn stale_answer_ignored() {
        let (p, mut rx) = setup();
        let p2 = p.clone();
        let h = tokio::spawn(async move { p2.ask(json!({"kind":"pin","path":"/a"})).await });
        let m = rx.recv().await.unwrap();
        p.answer(999, Answer::Yes);
        p.cancel_current(Some("/other"));
        p.cancel_current(Some("/a"));
        assert_eq!(h.await.unwrap(), Answer::Cancel);
        let _ = m;
    }

    #[tokio::test]
    async fn show_updates_in_place() {
        let (p, mut rx) = setup();
        p.show(json!({"kind":"show-passkey","path":"/d","passkey":123456,"entered":0}));
        let a = rx.recv().await.unwrap();
        p.show(json!({"kind":"show-passkey","path":"/d","passkey":123456,"entered":3}));
        let b = rx.recv().await.unwrap();
        assert_eq!(a["id"], b["id"]);
        assert_eq!(b["prompt"]["entered"], 3);
    }
}
