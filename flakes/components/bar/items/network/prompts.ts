import { createState } from "ags"

// One secrets prompt at a time, asked by the NetworkManager secret agent and
// rendered by SecretsDialog. A newer request supersedes the current one.

export const USER_CANCEL = Symbol("user-cancel") // user pressed Cancel / Escape
export const AGENT_CANCEL = Symbol("agent-cancel") // NM sent CancelGetSecrets / superseded

export interface SecretField {
  key: string // secret key returned to NM (or "identity", handled by the agent)
  label: string
  value?: string // prefill
  password?: boolean
  validate?: (v: string) => string | null // error text or null
}

export interface SecretPrompt {
  path: string // connection D-Bus path
  setting: string
  title: string
  message: string
  icon: string
  fields: SecretField[]
  note?: string // e.g. "The password you entered was not accepted."
}

export type SecretAnswer = Record<string, string> | typeof USER_CANCEL | typeof AGENT_CANCEL

interface Active {
  id: number
  prompt: SecretPrompt
  resolve: (a: SecretAnswer) => void
}

let nextId = 1
let active: Active | null = null

export const [currentSecret, setCurrentSecret] = createState<{ id: number; prompt: SecretPrompt } | null>(null)

function settle(a: SecretAnswer) {
  const cur = active
  active = null
  setCurrentSecret(null)
  cur?.resolve(a)
}

export function askSecrets(prompt: SecretPrompt): Promise<SecretAnswer> {
  settle(AGENT_CANCEL)
  return new Promise((resolve) => {
    active = { id: nextId++, prompt, resolve }
    setCurrentSecret({ id: active.id, prompt })
  })
}

export function answerSecrets(id: number, a: SecretAnswer) {
  if (active?.id === id) settle(a)
}

// NM cancelled the request (or went away). Without arguments: whatever is open.
export function cancelSecrets(path?: string, setting?: string) {
  if (!active) return
  if (path && active.prompt.path !== path) return
  if (setting && active.prompt.setting !== setting) return
  settle(AGENT_CANCEL)
}
