import GLib from "gi://GLib"
import Secret from "gi://Secret"

// Agent-owned secrets (secret flag AGENT_OWNED) live in the user's keyring,
// stored exactly like nm-applet / gnome-shell do so existing entries keep
// working: schema org.freedesktop.NetworkManager.Connection, keyed by
// connection-uuid / setting-name / setting-key.

const SCHEMA = new Secret.Schema(
  "org.freedesktop.NetworkManager.Connection",
  Secret.SchemaFlags.DONT_MATCH_NAME,
  {
    "connection-uuid": Secret.SchemaAttributeType.STRING,
    "setting-name": Secret.SchemaAttributeType.STRING,
    "setting-key": Secret.SchemaAttributeType.STRING,
  },
)

// All stored secrets for one setting of one connection: { key: value }.
export function lookupSecrets(uuid: string, setting: string): Promise<Record<string, string>> {
  return new Promise((resolve) => {
    Secret.password_search(
      SCHEMA,
      { "connection-uuid": uuid, "setting-name": setting },
      Secret.SearchFlags.ALL | Secret.SearchFlags.UNLOCK | Secret.SearchFlags.LOAD_SECRETS,
      null,
      (_src, res) => {
        const out: Record<string, string> = {}
        try {
          const items = Secret.password_search_finish(res) ?? []
          for (const item of items) {
            const key = item.get_attributes()["setting-key"]
            const value = item.retrieve_secret_sync(null)?.get_text()
            if (key && value != null) out[key] = value
          }
        } catch (e) {
          console.error("network: keyring lookup failed:", e)
        }
        resolve(out)
      },
    )
  })
}

export function storeSecret(uuid: string, id: string, setting: string, key: string, value: string): Promise<void> {
  return new Promise((resolve) => {
    Secret.password_store(
      SCHEMA,
      { "connection-uuid": uuid, "setting-name": setting, "setting-key": key },
      null, // default collection
      `Network secret for ${id}/${setting}/${key}`,
      value,
      null,
      (_src, res) => {
        try {
          Secret.password_store_finish(res)
        } catch (e) {
          console.error("network: keyring store failed:", e)
        }
        resolve()
      },
    )
  })
}

// Remove every secret for a connection (or just one setting of it).
export function clearSecrets(uuid: string, setting?: string): Promise<void> {
  const attrs: Record<string, string> = { "connection-uuid": uuid }
  if (setting) attrs["setting-name"] = setting
  return new Promise((resolve) => {
    Secret.password_clear(SCHEMA, attrs, null, (_src, res) => {
      try {
        Secret.password_clear_finish(res)
      } catch (e) {
        if (!(e instanceof GLib.Error)) console.error("network: keyring clear failed:", e)
      }
      resolve()
    })
  })
}
