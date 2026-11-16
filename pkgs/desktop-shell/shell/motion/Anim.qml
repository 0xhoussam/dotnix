import QtQuick
import ".."

// Number animation using a named motion token from Theme (see Theme.curves).
// `kind` is a key of Theme.curves; duration is the token's, times Config.animScale.
NumberAnimation {
    property string kind: "spatial"
    duration: Math.round(Theme.durations[kind] * Theme.animScale)
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.curves[kind]
}
