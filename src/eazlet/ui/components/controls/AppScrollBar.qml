import QtQuick
import QtQuick.Controls

// Shared scroll bar, styled like the ASCII font chooser's item grid bar.
//
// The bar is moved into the nearest ancestor gutter with room to spare, so it
// sits beside the flickable instead of on top of its widgets. When no such
// ancestor exists it stays attached to the flickable's right edge as a normal
// overlay bar.
ScrollBar {
    id: control

    property Item flick: null
    property Item gutterHost: null
    property real gutterGap: LayoutMetrics.spacing.xs

    policy: ScrollBar.AsNeeded
    visible: size < 1.0
    padding: 0
    implicitWidth: LayoutMetrics.unit * 1.2
    minimumSize: 0.14
    hoverEnabled: true

    function gutterX() {
        return gutterHost
             ? flick.mapToItem(gutterHost, flick.width, 0).x + gutterGap
             : flick.width - width
    }

    Component.onCompleted: {
        flick = parent
        var node = flick ? flick.parent : null
        while (node) {
            if (node.objectName === "workplaceSurface") {
                var needed = flick.mapToItem(node, flick.width, 0).x
                             + gutterGap + implicitWidth
                if (node.width >= needed)
                    gutterHost = node
                break
            }
            node = node.parent
        }
        if (gutterHost)
            parent = gutterHost
        // Qt Quick Controls assigns geometry while attaching the bar, which
        // destroys declarative bindings on x/y. Re-establish them here.
        x = Qt.binding(gutterX)
        y = Qt.binding(function () {
            return gutterHost ? flick.mapToItem(gutterHost, 0, 0).y : 0
        })
        height = Qt.binding(function () { return flick.height })
    }

    contentItem: Rectangle {
        implicitWidth: LayoutMetrics.unit * 1.2
        radius: Math.min(width / 2, LayoutMetrics.radius.m)
        color: control.pressed ? Theme.themeColor
             : control.hovered ? Theme.borderColor
             : Theme.dividerColor
        opacity: (control.active || control.hovered) ? 1.0 : 0.55

        Behavior on color {
            enabled: LayoutMetrics.animationsEnabled
            ColorAnimation { duration: 120 }
        }

        Behavior on opacity {
            enabled: LayoutMetrics.animationsEnabled
            NumberAnimation { duration: 120 }
        }
    }
}
