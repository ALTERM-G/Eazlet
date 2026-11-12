import QtQuick
import QtQuick.Controls

// Shared vertical scroll bar. Flush with the flickable's right edge so its
// rounded corners are never clipped, and revealed only while the pointer is
// over it (or while it is being dragged).
ScrollBar {
    id: control

    policy: ScrollBar.AsNeeded
    visible: size < 1.0
    padding: 0
    // Wider than the thumb itself so the bar is easy to find with the pointer.
    implicitWidth: LayoutMetrics.unit * 2.2
    minimumSize: 0.14
    hoverEnabled: true

    x: parent ? parent.width - width : 0

    opacity: (hovered || pressed || active) ? 1.0 : 0.0

    Behavior on opacity {
        enabled: LayoutMetrics.animationsEnabled
        NumberAnimation { duration: 120 }
    }

    contentItem: Item {
        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: LayoutMetrics.unit
            radius: LayoutMetrics.radius.s
            color: control.pressed
                   ? Qt.rgba(Theme.themeColor.r, Theme.themeColor.g, Theme.themeColor.b, 0.85)
                   : control.hovered
                     ? Qt.rgba(Theme.themeColor.r, Theme.themeColor.g, Theme.themeColor.b, 0.55)
                     : Theme.dividerColor

            Behavior on color {
                enabled: LayoutMetrics.animationsEnabled
                ColorAnimation { duration: 120 }
            }
        }
    }
}
