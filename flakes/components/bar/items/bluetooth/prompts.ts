import { createState } from "ags"

// One prompt at a time, shared by the pairing agent and the OBEX agent and
// rendered by PairingDialog. A newer request supersedes the current one
// (which resolves as "cancel").

export const CANCEL = Symbol("cancel")
export type Cancel = typeof CANCEL

export type Prompt =
  | { kind: "pin"; path: string }
  | { kind: "passkey"; path: string }
  | { kind: "confirm"; path: string; passkey: number }
  | { kind: "authorize"; path: string }
  | { kind: "service"; path: string; uuid: string }
  | { kind: "show-pin"; path: string; pin: string }
  | { kind: "show-passkey"; path: string; passkey: number; entered: number }
  | { kind: "file"; path: string; name: string; size: number }

export type Answer = string | number | boolean | "always" | null | Cancel

interface Active {
  id: number
  prompt: Prompt
  resolve: (a: Answer) => void
}

let nextId = 1
let active: Active | null = null

export const [current, setCurrent] = createState<{ id: number; prompt: Prompt } | null>(null)

function settle(answer: Answer) {
  const a = active
  active = null
  setCurrent(null)
  a?.resolve(answer)
}

// Show a prompt and wait for the user's answer.
export function ask(prompt: Prompt): Promise<Answer> {
  settle(CANCEL)
  return new Promise((resolve) => {
    active = { id: nextId++, prompt, resolve }
    setCurrent({ id: active.id, prompt })
  })
}

// Show an informational prompt (passkey to type on the device). Repeated
// DisplayPasskey calls for the same device just update the digits.
export function show(prompt: Prompt) {
  if (active && active.prompt.kind === prompt.kind && active.prompt.path === prompt.path) {
    active.prompt = prompt
    setCurrent({ id: active.id, prompt })
    return
  }
  void ask(prompt)
}

// Answer the prompt with the given id (ignored if it's already gone).
export function answer(id: number, value: Answer) {
  if (active?.id === id) settle(value)
}

// BlueZ sent Cancel, or the device finished pairing.
export function cancelCurrent(path?: string) {
  if (!active) return
  if (path && active.prompt.path !== path) return
  settle(CANCEL)
}
