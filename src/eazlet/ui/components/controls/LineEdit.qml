import QtQuick
import QtQuick.Controls
import components

TextField {
    id: control
    width: LayoutMetrics.size.lineEditWidth
    height: LayoutMetrics.size.lineEditHeight

    cursorDelegate: Item {}

    readonly property real scaledPadding: Math.max(1, Math.round(LayoutMetrics.spacing.xs))
    topPadding: Math.max(1, Math.min(scaledPadding, Math.floor(height * 0.2)))
    bottomPadding: topPadding
    leftPadding: scaledPadding + Math.max(1, Math.round(LayoutMetrics.spacing.xxs))
    rightPadding: scaledPadding

    ContextMenu.menu: TextContextMenu {
        editor: control
    }

    Keys.onShortcutOverride: function(event) {
        if (typeof Shortcuts !== "undefined" && !Shortcuts.capturing
                && Shortcuts.matchesAction("processAction", event))
            event.accepted = false
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Insert) {
            control.overwriteMode = !control.overwriteMode
            event.accepted = true
            return
        }
        if (typeof Shortcuts !== "undefined" && !Shortcuts.capturing
                && Shortcuts.matchesAction("processAction", event)) {
            event.accepted = true
            var win = control.Window.window
            if (win && typeof win.triggerProcessAction === "function")
                win.triggerProcessAction()
        }
    }

    font.pixelSize: Typography.h4
    font.family: Typography.fontRegular
    color: Theme.textColor
    selectionColor: Theme.themeColor
    selectedTextColor: Theme.hoverTextColor
    selectByMouse: true
    verticalAlignment: Text.AlignVCenter

    placeholderTextColor: Theme.dividerColor

    background: Rectangle {
        implicitWidth: control.width
        implicitHeight: control.height
        color: Theme.inputBackgroundColor
        border.color: control.activeFocus ? Theme.themeColor : Theme.borderColor
        border.width: LayoutMetrics.border.m
        radius: LayoutMetrics.radius.m

        Behavior on border.color {
            enabled: LayoutMetrics.animationsEnabled
            ColorAnimation {
                duration: 150
            }
        }
    }

    TextCursor {
        cursorRect: control.cursorRectangle
        overwrite: control.overwriteMode
        font: control.font
        visible: control.activeFocus && control.cursorVisible && control.selectionStart === control.selectionEnd
        z: 5
    }

    FocusRing {}
}
