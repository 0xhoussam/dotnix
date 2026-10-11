import AstalWp from "gi://AstalWp"

// PipeWire side of a Bluetooth audio device: the card (profiles: A2DP codecs,
// HFP/HSP, off) and its sink/source nodes, matched by BT address.

const wp = AstalWp.get_default()
export const audio = wp?.audio ?? null

export function wpDeviceFor(address: string): AstalWp.Device | null {
  if (!audio) return null
  const a = address.toUpperCase()
  return (
    (audio.devices ?? []).find((d) => (d.get_pw_property("api.bluez5.address") ?? "").toUpperCase() === a) ?? null
  )
}

export interface ProfileOption {
  index: number
  label: string
}

// Usable profiles, best first (WirePlumber priority), "off" last.
export function profilesOf(dev: AstalWp.Device): ProfileOption[] {
  return (dev.profiles ?? [])
    .filter((p) => p.available !== AstalWp.Available.NO)
    .sort((a, b) => Number(a.name === "off") - Number(b.name === "off") || b.priority - a.priority)
    .map((p) => ({ index: p.index, label: prettyProfile(p) }))
}

function prettyProfile(p: AstalWp.Profile): string {
  if (p.name === "off") return "Off"
  const d = p.description || p.name
  // "High Fidelity Playback (A2DP Sink, codec AAC)" -> "Music · AAC"
  const codec = d.match(/codec ([\w-]+)/i)?.[1]
  if (/a2dp/i.test(d) || /a2dp/i.test(p.name)) return codec ? `Music (A2DP) · ${codec}` : "Music (A2DP)"
  if (/hsp|hfp|head/i.test(d) || /headset|handsfree/i.test(p.name))
    return codec ? `Calls (HFP) · ${codec}` : "Calls (HFP, with mic)"
  if (/bap|le audio/i.test(d) || /bap/i.test(p.name)) return codec ? `LE Audio · ${codec}` : "LE Audio"
  return d
}

const endpointsOf = (list: AstalWp.Endpoint[] | null, dev: AstalWp.Device) =>
  (list ?? []).filter((e) => e.deviceId === dev.id)

export function speakerFor(dev: AstalWp.Device): AstalWp.Endpoint | null {
  return audio ? (endpointsOf(audio.speakers, dev)[0] ?? null) : null
}

export function micFor(dev: AstalWp.Device): AstalWp.Endpoint | null {
  return audio ? (endpointsOf(audio.microphones, dev)[0] ?? null) : null
}
