pragma Singleton
import QtQuick
import Quickshell

// Bar configuration, ported from bar/config.ts (same field names).
// Module names must match the registry in bar/Bar.qml.
Singleton {
    readonly property string position: "top" // "top" | "bottom"
    readonly property int size: 40 // bar height in px
    readonly property int spacing: 8 // gap between modules in a section
    readonly property int screenCornerRadius: 14 // 0 disables

    // Hide the bar until the pointer reaches the screen edge. While enabled
    // the bar floats over windows instead of reserving space.
    readonly property bool autohideEnabled: true
    readonly property int revealZone: 4 // px strip that reveals the bar on hover
    readonly property int hideDelay: 500 // ms with nothing holding the bar
    readonly property int transition: 200 // slide animation in ms

    readonly property var modulesStart: ["logo", "workspaces", "media", "systray"]
    readonly property var modulesCenter: ["clock"]
    readonly property var modulesEnd: ["stats", "keyboard", "volume", "network", "bluetooth", "battery", "clipboard", "settings"]

    // Map a window class (Hyprland `class`, matched lowercase) to a themed
    // icon name, for apps whose class differs from their icon name. Lookup in
    // the workspace dots: taskbarIcons[class] -> desktop entry icon -> class
    // -> defaultAppIcon.
    readonly property var taskbarIcons: ({
        "firefox-esr": "firefox", zen: "zen-browser", "google-chrome": "google-chrome", brave: "brave-browser",
        "brave-browser": "brave-browser", vesktop: "discord", "org.telegram.desktop": "org.telegram.desktop",
        "code-url-handler": "visual-studio-code", code: "visual-studio-code", "code-oss": "code",
        alacritty: "Alacritty", "com.mitchellh.ghostty": "com.mitchellh.ghostty",
        "org.gnome.nautilus": "org.gnome.Nautilus", "org.kde.dolphin": "org.kde.dolphin",
        "com.obsproject.studio": "com.obsproject.Studio"
    })
    readonly property string defaultAppIcon: "application-x-executable"

    readonly property var worldClocks: [
        { label: "Seattle", tz: "America/Los_Angeles" },
        { label: "New York", tz: "America/New_York" },
        { label: "London", tz: "Europe/London" },
        { label: "Tokyo", tz: "Asia/Tokyo" }
    ]
}
