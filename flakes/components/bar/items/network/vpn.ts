import Gio from "gi://Gio"
import NM from "gi://NM"

// VPN secrets come from the plugin's own auth-dialog (nm-openvpn-auth-dialog,
// ...), driven with the same stdin/stdout protocol nm-applet uses
// (applet-vpn-request.c, non-external-UI mode):
//   stdin:  DATA_KEY=k / DATA_VAL=v / SECRET_KEY=k / SECRET_VAL=v ... DONE, QUIT
//   stdout: key\nvalue\n pairs, terminated by an empty line
// A non-zero exit status means the user cancelled.

export class VpnCancelled extends Error {}

export function authDialogFor(service: string): string | null {
  try {
    const plugins = NM.VpnPluginInfo.list_load()
    return NM.VpnPluginInfo.list_find_by_service(plugins, service)?.get_auth_dialog() ?? null
  } catch {
    return null
  }
}

const line = (tag: string, value: string) => `${tag}=${value.replace(/\n/g, "\\n")}\n\n`

export function runAuthDialog(
  conn: NM.Connection,
  hints: string[],
  flags: number,
): Promise<Record<string, string>> | null {
  const sVpn = conn.get_setting_vpn()
  if (!sVpn) return null
  const service = sVpn.get_service_type()
  const dialog = authDialogFor(service)
  if (!dialog) return null

  const argv = [dialog, "-u", conn.get_uuid(), "-n", conn.get_id(), "-s", service]
  if (flags & NM.SecretAgentGetSecretsFlags.ALLOW_INTERACTION) argv.push("-i")
  if (flags & NM.SecretAgentGetSecretsFlags.REQUEST_NEW) argv.push("-r")
  for (const h of hints) argv.push("-t", h)

  let input = ""
  sVpn.foreach_data_item((k: string, v: string) => (input += line("DATA_KEY", k) + line("DATA_VAL", v)))
  sVpn.foreach_secret((k: string, v: string) => (input += line("SECRET_KEY", k) + line("SECRET_VAL", v)))
  input += "DONE\n\nQUIT\n\n"

  return new Promise((resolve, reject) => {
    let proc: Gio.Subprocess
    try {
      proc = Gio.Subprocess.new(argv, Gio.SubprocessFlags.STDIN_PIPE | Gio.SubprocessFlags.STDOUT_PIPE)
    } catch (e) {
      return reject(e)
    }
    proc.communicate_utf8_async(input, null, (_p, res) => {
      try {
        const [, stdout] = proc.communicate_utf8_finish(res)
        if (!proc.get_successful()) return reject(new VpnCancelled("cancelled"))
        const lines = (stdout ?? "").split("\n")
        const secrets: Record<string, string> = {}
        for (let i = 0; i + 1 < lines.length && lines[i]; i += 2) secrets[lines[i]] = lines[i + 1]
        resolve(secrets)
      } catch (e) {
        reject(e)
      }
    })
  })
}
