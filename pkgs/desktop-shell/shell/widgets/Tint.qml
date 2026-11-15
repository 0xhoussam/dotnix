import QtQuick
import QtQuick.Effects
import ".."

// Recolors a symbolic icon: Adwaita's are dark grey, unreadable on the dark
// bar. Use as `layer.effect: Tint {}` with `layer.enabled: true`.
MultiEffect {
    brightness: 1.0 // dark source -> white first, so the tint is not multiplied by luminance
    colorization: 1.0
    colorizationColor: Theme.fg
}
