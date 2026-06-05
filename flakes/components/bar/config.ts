// Bar configuration. Registry in Bar.tsx renders modules per location.
// Module names must match keys in Bar.tsx `Bar_Items`.

export type Location = "start" | "center" | "end"

export const config = {
  position: "top" as "top" | "bottom",
  size: 40, // bar height in px (heightRequest)
  spacing: 8, // gap between modules in a section

  modules: {
    start: ["workspaces"],
    center: ["clock"],
    // notifications moved into the date panel (Clock → panel); bell removed.
    end: ["systray", "keyboard", "volume", "network", "bluetooth", "battery", "clipboard", "settings"],
  } satisfies Record<Location, string[]>,

  // World Clocks shown in the date panel. tz = IANA timezone id.
  worldClocks: [
    { label: "Seattle", tz: "America/Los_Angeles" },
    { label: "New York", tz: "America/New_York" },
    { label: "London", tz: "Europe/London" },
    { label: "Tokyo", tz: "Asia/Tokyo" },
  ] as { label: string; tz: string }[],

  // Map a window class (Hyprland `class`, matched lowercase) to a themed
  // icon name. Lets you override apps whose class != their icon name.
  // Lookup order in Workspaces: taskbarIcons[class] -> class -> defaultAppIcon.
  taskbarIcons: {
    firefox: "firefox",
    "firefox-esr": "firefox",
    zen: "zen-browser",
    chromium: "chromium",
    "google-chrome": "google-chrome",
    brave: "brave-browser",
    discord: "discord",
    vesktop: "discord",
    telegram: "org.telegram.desktop",
    "org.telegram.desktop": "org.telegram.desktop",
    spotify: "spotify",
    code: "visual-studio-code",
    "code-url-handler": "visual-studio-code",
    "code-oss": "code",
    cursor: "cursor",
    kitty: "kitty",
    alacritty: "Alacritty",
    foot: "foot",
    "org.wezfurlong.wezterm": "org.wezfurlong.wezterm",
    "com.mitchellh.ghostty": "com.mitchellh.ghostty",
    nautilus: "org.gnome.Nautilus",
    "org.gnome.nautilus": "org.gnome.Nautilus",
    thunar: "thunar",
    "org.kde.dolphin": "org.kde.dolphin",
    mpv: "mpv",
    vlc: "vlc",
    obsidian: "obsidian",
    slack: "slack",
    "com.obsproject.studio": "com.obsproject.Studio",
    steam: "steam",
  } as Record<string, string>,

  // Fallback icon when class is empty or unmapped and no themed icon matches.
  defaultAppIcon: "application-x-executable",
}
