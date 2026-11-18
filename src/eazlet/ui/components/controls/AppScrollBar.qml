import QtQuick
import QtQuick.Controls
import components

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
    // Set to false when the flickable reserves its own right-hand gutter
    // (for example a two-column page where the surface gutter would land on
    // top of the neighbouring panel).
    property bool autoGutter: true

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
        if (autoGutter && !gutterHost) {
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

    contentItem: ScrollBarThumb {
        bar: control
        orientation: Qt.Vertical
    }
}
