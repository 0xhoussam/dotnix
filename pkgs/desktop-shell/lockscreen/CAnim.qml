import QtQuick

ColorAnimation {
    property string kind: "slowEffects"
    duration: Theme.durations[kind]
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Theme.curves[kind]
}
