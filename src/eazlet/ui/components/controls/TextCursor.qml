import QtQuick

Rectangle {
    id: cursor
    objectName: "textCursor"

    property rect cursorRect: Qt.rect(0, 0, 0, 0)
    property bool overwrite: false
    property font font
    property real heightScale: 1.0

    readonly property real thickness: Math.max(1, LayoutMetrics.border.m)
    readonly property real blockWidth: glyphMetrics.advanceWidth

    TextMetrics {
        id: glyphMetrics
        font: cursor.font
        text: "M"
    }

    width: overwrite ? blockWidth : thickness
    height: Math.max(1, Math.min(cursorRect.height * heightScale,
                                 parent ? parent.height : cursorRect.height * heightScale))
    x: cursorRect.x
    y: {
        var yy = cursorRect.y - (height - cursorRect.height) / 2
        var maxY = parent ? Math.max(0, parent.height - height) : yy
        return Math.max(0, Math.min(yy, maxY))
    }
    color: Theme.themeColor
    radius: overwrite ? 0 : width / 2

    Behavior on x {
        enabled: LayoutMetrics.animationsEnabled
        NumberAnimation {
            duration: 90
            easing.type: Easing.OutQuad
        }
    }

    Behavior on y {
        enabled: LayoutMetrics.animationsEnabled
        NumberAnimation {
            duration: 90
            easing.type: Easing.OutQuad
        }
    }

    Behavior on height {
        enabled: LayoutMetrics.animationsEnabled
        NumberAnimation {
            duration: 90
            easing.type: Easing.OutQuad
        }
    }

    Behavior on opacity {
        enabled: LayoutMetrics.animationsEnabled
        NumberAnimation { duration: 110 }
    }

    function restartBlink() {
        opacity = 1
        blink.restart()
    }

    onCursorRectChanged: if (!overwrite) restartBlink()
    onVisibleChanged: if (visible && !overwrite) restartBlink()
    onOverwriteChanged: {
        if (overwrite) {
            blink.stop()
            opacity = 1
        } else {
            restartBlink()
        }
    }

    Timer {
        id: blink
        interval: 530
        running: cursor.visible && !cursor.overwrite
        repeat: true
        onTriggered: cursor.opacity = cursor.opacity > 0.5 ? 0 : 1
    }
}
