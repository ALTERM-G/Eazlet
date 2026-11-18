import QtQuick
import QtQuick.Controls

// Shared pill thumb for every ScrollBar in the app.
//
// Only the visual is shared: each bar keeps ownership of its own geometry,
// policy and placement. The bar is passed explicitly so the same component
// works for vertical and horizontal bars, attached and standalone ones.
Rectangle {
    id: thumb

    property ScrollBar bar: null
    property int orientation: Qt.Vertical
    property real thumbLength: LayoutMetrics.spacing.sm

    readonly property real thickness: LayoutMetrics.unit * 1.2

    implicitWidth: orientation === Qt.Vertical ? thickness : thumbLength
    implicitHeight: orientation === Qt.Vertical ? thumbLength : thickness

    radius: Math.min(Math.min(width, height) / 2, LayoutMetrics.radius.m)
    color: !bar ? Theme.dividerColor
         : bar.pressed ? Theme.themeColor
         : bar.hovered ? Theme.borderColor
         : Theme.dividerColor
    opacity: bar && (bar.active || bar.hovered) ? 1.0 : 0.55

    Behavior on color {
        enabled: LayoutMetrics.animationsEnabled
        ColorAnimation { duration: 120 }
    }

    Behavior on opacity {
        enabled: LayoutMetrics.animationsEnabled
        NumberAnimation { duration: 120 }
    }
}
