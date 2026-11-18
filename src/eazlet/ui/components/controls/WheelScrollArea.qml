import QtQuick

// Shared wheel scrolling for a Flickable (or any scrollable content item).
//
// Pages disable mouse-drag panning with `acceptedButtons: Qt.NoButton` so
// wheel input has to be handled explicitly. This component keeps that single
// wheel handler in one place and preserves the app's larger scroll step.
//
// `fallback` receives the leftover delta when `target` is already at a bound;
// TextEdit uses it to pass scrolling from its text area to the surrounding page.
Item {
    id: scroller

    property var target: null
    property var fallback: null
    property real step: LayoutMetrics.unit * 24
    property int cursor: Qt.ArrowCursor

    anchors.fill: parent

    // Kept separate from the event handler so the scrolling math can be
    // exercised directly in tests without synthesizing native wheel events.
    function scrollBy(delta) {
        var remaining = delta
        var f = scroller.target
        if (f) {
            const maxY = Math.max(0, f.contentHeight - f.height)
            const next = Math.max(0, Math.min(maxY, f.contentY - remaining))
            remaining += next - f.contentY
            f.contentY = next
        }

        var other = scroller.fallback
        if (other && Math.abs(remaining) > 0.5) {
            const maxOther = Math.max(0, other.contentHeight - other.height)
            other.contentY = Math.max(0, Math.min(maxOther, other.contentY - remaining))
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        cursorShape: scroller.cursor
        z: 1

        onWheel: function(wheel) {
            var delta = wheel.pixelDelta.y !== 0
                ? wheel.pixelDelta.y * 2
                : wheel.angleDelta.y / 120 * scroller.step
            scroller.scrollBy(delta)
            wheel.accepted = true
        }
    }
}
