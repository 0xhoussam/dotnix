import { Gtk } from "ags/gtk4"
import { createState, createBinding } from "ags"
import AstalBluetooth from "gi://AstalBluetooth"
import { execAsync } from "ags/process"

interface PairingRequest {
  type: "pin" | "passkey" | "confirmation" | "authorization" | "authorize-service"
  devicePath: string
  deviceName: string
  passkey?: number
  entered?: number
  uuid?: string
  resolve: (value: any) => void
  reject: (reason: any) => void
}

class PairingUI {
  private currentRequest: PairingRequest | null = null
  private window: Gtk.Window | null = null
  private pinEntry: Gtk.Entry | null = null
  private showPinCheck: Gtk.CheckButton | null = null

  private deviceChangedHandler: number | null = null

  askPin(devicePath: string): Promise<string | null> {
    return this.showRequest({
      type: "pin",
      devicePath,
      deviceName: this.getDeviceDisplayName(devicePath),
      resolve: () => {},
      reject: () => {},
    })
  }

  askPasskey(devicePath: string): Promise<number | null> {
    return this.showRequest({
      type: "passkey",
      devicePath,
      deviceName: this.getDeviceDisplayName(devicePath),
      resolve: () => {},
      reject: () => {},
    })
  }

  showPinCode(devicePath: string, pincode: string): void {
    this.showDisplay({
      type: "pin",
      devicePath,
      deviceName: this.getDeviceDisplayName(devicePath),
      passkey: parseInt(pincode, 10),
      entered: pincode.length,
      resolve: () => {},
      reject: () => {},
    })
  }

  showPasskey(devicePath: string, passkey: number, entered: number): void {
    this.showDisplay({
      type: "passkey",
      devicePath,
      deviceName: this.getDeviceDisplayName(devicePath),
      passkey,
      entered,
      resolve: () => {},
      reject: () => {},
    })
  }

  requestConfirmation(devicePath: string, passkey: number): Promise<boolean> {
    return this.showRequest({
      type: "confirmation",
      devicePath,
      deviceName: this.getDeviceDisplayName(devicePath),
      passkey,
      resolve: () => {},
      reject: () => {},
    })
  }

  requestAuthorization(devicePath: string): Promise<boolean> {
    return this.showRequest({
      type: "authorization",
      devicePath,
      deviceName: this.getDeviceDisplayName(devicePath),
      resolve: () => {},
      reject: () => {},
    })
  }

  authorizeService(devicePath: string, uuid: string): Promise<"always" | "accept" | "deny"> {
    return this.showRequest({
      type: "authorize-service",
      devicePath,
      deviceName: this.getDeviceDisplayName(devicePath),
      uuid,
      resolve: () => {},
      reject: () => {},
    })
  }

  close(): void {
    if (this.currentRequest) {
      this.currentRequest.reject(new Error("Cancelled"))
      this.currentRequest = null
    }
    this.hideWindow()
  }

  trustDevice(devicePath: string): void {
    const bt = AstalBluetooth.get_default()
    const dev = this.getDeviceByPath(devicePath)
    if (dev) {
      dev.trusted = true
    }
  }

  private getDeviceByPath(path: string): AstalBluetooth.Device | null {
    const bt = AstalBluetooth.get_default()
    const address = this.devicePathToAddress(path)
    return bt.devices.find(d => d.address === address) || null
  }

  private devicePathToAddress(path: string): string {
    const devPrefix = "dev_"
    const idx = path.indexOf(devPrefix)
    if (idx === -1) return path
    const addrPart = path.slice(idx + devPrefix.length)
    return addrPart.split("_").join(":").toUpperCase()
  }

  private getDeviceDisplayName(path: string): string {
    const dev = this.getDeviceByPath(path)
    const addr = this.devicePathToAddress(path)
    return dev?.name ? `${dev.name} (${addr})` : addr
  }

  private showRequest(request: Omit<PairingRequest, "resolve" | "reject">): Promise<any> {
    return new Promise((resolve, reject) => {
      this.cancelPending()
      this.currentRequest = { ...request, resolve, reject }
      this.showWindow()
    })
  }

  private showDisplay(request: Omit<PairingRequest, "resolve" | "reject">): void {
    this.cancelPending()
    this.currentRequest = { ...request, resolve: () => {}, reject: () => {} }
    this.showWindow()
  }

  private cancelPending(): void {
    if (this.currentRequest) {
      this.currentRequest.reject(new Error("Superseded"))
      this.currentRequest = null
    }
  }

  private showWindow(): void {
    if (this.window) {
      this.updateWindowContent()
      this.window.present()
      return
    }

    this.window = new Gtk.Window({
      title: "Bluetooth Pairing",
      modal: true,
      resizable: false,
      decorate: true,
      hideOnClose: true,
      defaultWidth: 360,
    })

    this.window.connect("close-request", () => {
      this.close()
      return true
    })

    this.updateWindowContent()
    this.window.present()

    this.setupDeviceWatcher()
  }

  private hideWindow(): void {
    if (this.window) {
      this.window.close()
      this.window.destroy()
      this.window = null
    }
    this.cleanupDeviceWatcher()
  }

  private setupDeviceWatcher(): void {
    this.cleanupDeviceWatcher()
    if (!this.currentRequest) return

    const dev = this.getDeviceByPath(this.currentRequest.devicePath)
    if (!dev) return

    this.deviceChangedHandler = dev.connect("notify::paired", () => {
      if (dev.paired) {
        this.close()
      }
    })
    dev.connect("notify::connected", () => {
      if (dev.connected) {
        this.close()
      }
    })
  }

  private cleanupDeviceWatcher(): void {
    if (this.deviceChangedHandler && this.currentRequest) {
      const dev = this.getDeviceByPath(this.currentRequest.devicePath)
      if (dev) {
        try {
          dev.disconnect(this.deviceChangedHandler)
        } catch {}
      }
      this.deviceChangedHandler = null
    }
  }

  private updateWindowContent(): void {
    if (!this.window || !this.currentRequest) return

    const req = this.currentRequest
    const content = new Gtk.Box({
      orientation: Gtk.Orientation.VERTICAL,
      spacing: 16,
      marginTop: 24,
      marginBottom: 24,
      marginStart: 24,
      marginEnd: 24,
    })

    const title = new Gtk.Label({
      label: this.getTitle(req),
      wrap: true,
      justify: Gtk.Justification.CENTER,
      xalign: 0.5,
      cssClasses: ["pairing-title"],
    })
    content.append(title)

    switch (req.type) {
      case "pin":
        this.addPinEntry(content, req)
        break
      case "passkey":
        this.addPasskeyEntry(content, req)
        break
      case "confirmation":
        this.addConfirmation(content, req)
        break
      case "authorization":
        this.addAuthorization(content, req)
        break
      case "authorize-service":
        this.addAuthorizeService(content, req)
        break
    }

    this.window.set_child(content)
  }

  private getTitle(req: PairingRequest): string {
    switch (req.type) {
      case "pin":
        return `Pairing request for ${req.deviceName}\nEnter the PIN code shown on the device`
      case "passkey":
        return `Pairing request for ${req.deviceName}\nEnter the 6-digit passkey`
      case "confirmation":
        return `Confirm pairing with ${req.deviceName}?\nPasskey: ${req.passkey?.toString().padStart(6, "0")}`
      case "authorization":
        return `Authorize connection from ${req.deviceName}?`
      case "authorize-service":
        return `Authorize service access for ${req.deviceName}?\nService: ${this.uuidToName(req.uuid || "")}`
      default:
        return `Pairing request for ${req.deviceName}`
    }
  }

  private uuidToName(uuid: string): string {
    const uuids: Record<string, string> = {
      "00001101-0000-1000-8000-00805f9b34fb": "Serial Port",
      "0000110a-0000-1000-8000-00805f9b34fb": "Audio Source",
      "0000110b-0000-1000-8000-00805f9b34fb": "Audio Sink",
      "0000110c-0000-1000-8000-00805f9b34fb": "AV Remote Control",
      "0000110d-0000-1000-8000-00805f9b34fb": "AV Remote Control Target",
      "0000110e-0000-1000-8000-00805f9b34fb": "Advanced Audio Distribution",
      "00001112-0000-1000-8000-00805f9b34fb": "Headset",
      "00001115-0000-1000-8000-00805f9b34fb": "PANU",
      "00001116-0000-1000-8000-00805f9b34fb": "NAP",
      "0000111f-0000-1000-8000-00805f9b34fb": "Handsfree",
      "00001124-0000-1000-8000-00805f9b34fb": "Human Interface Device",
      "0000112d-0000-1000-8000-00805f9b34fb": "HID",
      "0000112e-0000-1000-8000-00805f9b34fb": "Hardcopy Cable Replacement",
      "00001130-0000-1000-8000-00805f9b34fb": "HCR Print",
      "00001131-0000-1000-8000-00805f9b34fb": "HCR Scan",
      "00001200-0000-1000-8000-00805f9b34fb": "PnP Information",
      "00001800-0000-1000-8000-00805f9b34fb": "Generic Access",
      "00001801-0000-1000-8000-00805f9b34fb": "Generic Attribute",
      "0000180d-0000-1000-8000-00805f9b34fb": "Heart Rate",
      "0000180f-0000-1000-8000-00805f9b34fb": "Battery Service",
      "00001812-0000-1000-8000-00805f9b34fb": "Human Interface Device",
      "00001819-0000-1000-8000-00805f9b34fb": "Location and Navigation",
    }
    return uuids[uuid.toLowerCase()] || uuid
  }

  private addPinEntry(content: Gtk.Box, req: PairingRequest): void {
    const entryBox = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL, spacing: 8 })

    this.pinEntry = new Gtk.Entry({
      placeholderText: "PIN (up to 16 chars)",
      maxLength: 16,
      visibility: false,
      hexpand: true,
    })

    this.showPinCheck = new Gtk.CheckButton({
      label: "Show PIN",
      active: false,
    })
    this.showPinCheck.connect("toggled", () => {
      if (this.pinEntry && this.showPinCheck) {
        this.pinEntry.set_visibility(this.showPinCheck.active)
      }
    })

    const btnBox = new Gtk.Box({ spacing: 8, halign: Gtk.Align.END })
    const cancelBtn = new Gtk.Button({ label: "Cancel" })
    cancelBtn.connect("clicked", () => {
      this.currentRequest?.reject(new Error("Cancelled"))
      this.close()
    })
    const okBtn = new Gtk.Button({ label: "OK", cssClasses: ["suggested-action"] })
    okBtn.connect("clicked", () => {
      const pin = this.pinEntry?.get_text() || ""
      if (pin) {
        this.currentRequest?.resolve(pin)
        this.close()
      }
    })

    btnBox.append(cancelBtn)
    btnBox.append(okBtn)

    entryBox.append(this.pinEntry)
    entryBox.append(this.showPinCheck)
    entryBox.append(btnBox)
    content.append(entryBox)

    this.pinEntry.grab_focus()
    this.pinEntry.connect("activate", () => {
      const pin = this.pinEntry?.get_text() || ""
      if (pin) {
        this.currentRequest?.resolve(pin)
        this.close()
      }
    })
  }

  private addPasskeyEntry(content: Gtk.Box, req: PairingRequest): void {
    const entryBox = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL, spacing: 8 })

    this.pinEntry = new Gtk.Entry({
      placeholderText: "6-digit passkey",
      maxLength: 6,
      inputPurpose: Gtk.InputPurpose.DIGITS,
      visibility: false,
      hexpand: true,
    })

    this.showPinCheck = new Gtk.CheckButton({
      label: "Show passkey",
      active: false,
    })
    this.showPinCheck.connect("toggled", () => {
      if (this.pinEntry && this.showPinCheck) {
        this.pinEntry.set_visibility(this.showPinCheck.active)
      }
    })

    const btnBox = new Gtk.Box({ spacing: 8, halign: Gtk.Align.END })
    const cancelBtn = new Gtk.Button({ label: "Cancel" })
    cancelBtn.connect("clicked", () => {
      this.currentRequest?.reject(new Error("Cancelled"))
      this.close()
    })
    const okBtn = new Gtk.Button({ label: "OK", cssClasses: ["suggested-action"] })
    okBtn.connect("clicked", () => {
      const text = this.pinEntry?.get_text() || ""
      const num = parseInt(text, 10)
      if (!isNaN(num) && text.length === 6) {
        this.currentRequest?.resolve(num)
        this.close()
      }
    })

    btnBox.append(cancelBtn)
    btnBox.append(okBtn)

    entryBox.append(this.pinEntry)
    entryBox.append(this.showPinCheck)
    entryBox.append(btnBox)
    content.append(entryBox)

    this.pinEntry.grab_focus()
    this.pinEntry.connect("activate", () => {
      const text = this.pinEntry?.get_text() || ""
      const num = parseInt(text, 10)
      if (!isNaN(num) && text.length === 6) {
        this.currentRequest?.resolve(num)
        this.close()
      }
    })
  }

  private addConfirmation(content: Gtk.Box, req: PairingRequest): void {
    const btnBox = new Gtk.Box({ spacing: 8, halign: Gtk.Align.END })
    const denyBtn = new Gtk.Button({ label: "Deny", cssClasses: ["destructive-action"] })
    denyBtn.connect("clicked", () => {
      this.currentRequest?.resolve(false)
      this.close()
    })
    const confirmBtn = new Gtk.Button({ label: "Confirm", cssClasses: ["suggested-action"] })
    confirmBtn.connect("clicked", () => {
      this.currentRequest?.resolve(true)
      this.close()
    })
    btnBox.append(denyBtn)
    btnBox.append(confirmBtn)
    content.append(btnBox)
  }

  private addAuthorization(content: Gtk.Box, req: PairingRequest): void {
    const btnBox = new Gtk.Box({ spacing: 8, halign: Gtk.Align.END })
    const denyBtn = new Gtk.Button({ label: "Deny", cssClasses: ["destructive-action"] })
    denyBtn.connect("clicked", () => {
      this.currentRequest?.resolve(false)
      this.close()
    })
    const allowBtn = new Gtk.Button({ label: "Allow", cssClasses: ["suggested-action"] })
    allowBtn.connect("clicked", () => {
      this.currentRequest?.resolve(true)
      this.close()
    })
    btnBox.append(denyBtn)
    btnBox.append(allowBtn)
    content.append(btnBox)
  }

  private addAuthorizeService(content: Gtk.Box, req: PairingRequest): void {
    const btnBox = new Gtk.Box({ spacing: 8, halign: Gtk.Align.END, orientation: Gtk.Orientation.VERTICAL })

    const denyBtn = new Gtk.Button({ label: "Deny", cssClasses: ["destructive-action"] })
    denyBtn.connect("clicked", () => {
      this.currentRequest?.resolve("deny")
      this.close()
    })

    const acceptBtn = new Gtk.Button({ label: "Accept once" })
    acceptBtn.connect("clicked", () => {
      this.currentRequest?.resolve("accept")
      this.close()
    })

    const alwaysBtn = new Gtk.Button({ label: "Always accept", cssClasses: ["suggested-action"] })
    alwaysBtn.connect("clicked", () => {
      this.currentRequest?.resolve("always")
      this.close()
    })

    btnBox.append(denyBtn)
    btnBox.append(acceptBtn)
    btnBox.append(alwaysBtn)
    content.append(btnBox)
  }
}

export const pairingUI = new PairingUI()