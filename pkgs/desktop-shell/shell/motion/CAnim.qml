import QtQuick
import ".."

// Colour animation on a motion token (default: slow effects).
ColorAnimation {
    property string kind: "slowEffects"
    duration: Math.round(Theme.durations[kind] * Theme.animScale)
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.curves[kind]
}
