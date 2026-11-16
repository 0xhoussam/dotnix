import QtQuick

// Number animation on a motion token from Theme (`kind` is a key of Theme.curves).
NumberAnimation {
    property string kind: "spatial"
    duration: Theme.durations[kind]
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.curves[kind]
}
