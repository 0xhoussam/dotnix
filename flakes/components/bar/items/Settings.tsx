// Settings / quick-settings button. Stub: wire to a QuickSettings panel later.
export function Settings() {
  return (
    <button class="settings" onClicked={() => print("Settings: TODO")}>
      <image iconName="emblem-system-symbolic" pixelSize={16} />
    </button>
  )
}
