import "./bar/preinit" // must stay first: clears dark-theme flag pre Adw.init
import app from "ags/gtk4/app"
import Adw from "gi://Adw?version=1"
import style from "./bar/style.scss"
import Bar from "./bar/app"
import DatePanel from "./bar/widget/DatePanel"
import NotificationPopups from "./bar/widget/NotificationPopups"
import ScreenCorners from "./bar/widget/ScreenCorners"
import PairingDialog from "./bar/items/bluetooth/PairingDialog"
import { startAgent, stopAgent } from "./bar/items/bluetooth/agent"
import { startObexAgent, stopObexAgent } from "./bar/items/bluetooth/obex"
import { startRfkillWatch } from "./bar/items/bluetooth/rfkill"
import { startBluetoothServices, stopBluetoothServices } from "./bar/items/bluetooth/services"
import SecretsDialog from "./bar/items/network/SecretsDialog"
import JoinDialog from "./bar/items/network/JoinDialog"
import { startNetworkAgent, stopNetworkAgent } from "./bar/items/network/agent"
import { startNetworkServices, stopNetworkServices } from "./bar/items/network/services"

app.start({
  css: style,
  main() {
    Adw.StyleManager.get_default().colorScheme = Adw.ColorScheme.FORCE_DARK

    const monitors = app.get_monitors()
    monitors.map(Bar)
    monitors.map(ScreenCorners)

    // Single-instance overlays on the primary monitor.
    const primary = monitors[0]
    if (primary) {
      DatePanel(primary)
      NotificationPopups(primary)
      PairingDialog(primary)
      SecretsDialog(primary)
      JoinDialog(primary)
    }

    // Bluetooth: pairing + OBEX agents, kill-switch watch, notifications,
    // auto-connect and controller wakelock.
    startAgent()
    startObexAgent()
    startRfkillWatch()
    startBluetoothServices()

    // Network: NetworkManager secret agent (passwords / 802.1X / VPN) and
    // connection notifications.
    startNetworkAgent()
    startNetworkServices()

    app.connect("shutdown", () => {
      stopAgent()
      stopObexAgent()
      stopBluetoothServices()
      stopNetworkAgent()
      stopNetworkServices()
    })
  },
})
