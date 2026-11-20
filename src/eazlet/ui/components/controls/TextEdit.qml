import QtQuick
import QtQuick.Controls
import components

Item {
    id: control
    width: LayoutMetrics.size.textEditWidth
    height: LayoutMetrics.size.textEditHeight

    property string placeholderText: ""
    property alias text: area.text
    property alias readOnly: area.readOnly
    property alias wrapMode: area.wrapMode
    property alias fontFamily: area.font.family
    property alias fontPixelSize: area.font.pixelSize
    property bool horizontalScroll: false
    property bool showCopyButton: false

    // Briefly swapped to a check mark after the copy overlay is pressed.
    property bool copyConfirmed: false

    function paste() {
        area.forceActiveFocus()
        area.paste()
    }

    function copy() {
        area.forceActiveFocus()
        // The corner button is meant to copy the whole output when nothing is
        // selected, which is the common case for a read-only result box.
        if (area.selectedText.length === 0 && area.text.length > 0) {
            area.selectAll()
            area.copy()
            area.deselect()
        } else {
            area.copy()
        }
    }

    function selectAll() {
        area.forceActiveFocus()
        area.selectAll()
    }

    ScrollView {
        id: view
        anchors.fill: parent

        clip: true

        ScrollBar.horizontal: ScrollBar {
            id: hbar
            readonly property real gap: LayoutMetrics.border.m * 2
            parent: view
            x: view.leftPadding + gap
            y: view.height - height - gap
            width: view.availableWidth - gap * 2
            policy: control.horizontalScroll ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            visible: control.horizontalScroll && hbar.size < 1.0
            padding: 0

            contentItem: ScrollBarThumb {
                bar: hbar
                orientation: Qt.Horizontal
            }
        }

        Binding {
            target: view.contentItem
            property: "boundsBehavior"
            value: Flickable.StopAtBounds
            when: view.contentItem !== null
            restoreMode: Binding.RestoreNone
        }

        ScrollBar.vertical: ScrollBar {
            id: vbar
            readonly property real inset: LayoutMetrics.radius.m
            readonly property real gap: LayoutMetrics.border.m * 2

            parent: view
            x: view.mirrored ? gap : view.width - width - gap
            y: view.topPadding + inset
            height: view.availableHeight - inset * 2
            policy: ScrollBar.AsNeeded
            visible: vbar.size < 1.0
            padding: 0

            contentItem: ScrollBarThumb {
                bar: vbar
                orientation: Qt.Vertical
            }
        }

        background: Rectangle {
            color: Theme.inputBackgroundColor
            border.color: area.activeFocus ? Theme.themeColor : Theme.borderColor
            border.width: LayoutMetrics.border.m
            radius: LayoutMetrics.radius.m

            Behavior on border.color {
                enabled: LayoutMetrics.animationsEnabled
                ColorAnimation {
                    duration: 150
                }
            }
        }

        TextArea {
            id: area
            activeFocusOnTab: true
            width: control.horizontalScroll
                   ? Math.max(view.availableWidth, implicitWidth)
                   : view.availableWidth

            font.pixelSize: Typography.h4
            font.family: Typography.fontRegular
            color: Theme.textColor
            selectionColor: Theme.themeColor
            selectedTextColor: Theme.hoverTextColor
            selectByMouse: true
            wrapMode: Text.Wrap

            cursorDelegate: Item {}

            ContextMenu.menu: TextContextMenu {
                editor: area
            }

            Keys.onShortcutOverride: function(event) {
                if (typeof Shortcuts !== "undefined" && !Shortcuts.capturing
                        && Shortcuts.matchesAction("processAction", event))
                    event.accepted = false
            }

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Tab) {
                    if (area.nextItemInFocusChain(true))
                        area.nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocusReason)
                    event.accepted = true
                    return
                }
                if (event.key === Qt.Key_Backtab) {
                    if (area.nextItemInFocusChain(false))
                        area.nextItemInFocusChain(false).forceActiveFocus(Qt.BacktabFocusReason)
                    event.accepted = true
                    return
                }
                if (event.key === Qt.Key_Insert) {
                    area.overwriteMode = !area.overwriteMode
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

            background: null

            Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: area.leftPadding
                anchors.rightMargin: area.rightPadding
                anchors.topMargin: area.topPadding
                text: control.placeholderText
                color: Theme.dividerColor
                font: area.font
                wrapMode: area.wrapMode
                visible: text.length > 0 && area.text.length === 0
                enabled: false
                z: 1
            }

            TextCursor {
                cursorRect: area.cursorRectangle
                overwrite: area.overwriteMode
                font: area.font
                visible: area.activeFocus && area.cursorVisible && area.selectionStart === area.selectionEnd
                z: 5
            }
        }
    }

    // The nearest scrollable page around this editor.
    function pageFlickable() {
        var item = control.parent
        while (item && (item.contentY === undefined || item.contentHeight === undefined))
            item = item.parent
        return item
    }

    // Scrolling over the editor scrolls its text first; leftover delta is
    // handed to the surrounding page, so the page keeps scrolling at the
    // text's top or bottom.
    WheelScrollArea {
        target: view.contentItem
        fallback: control.pageFlickable()
        cursor: Qt.IBeamCursor
    }

    IconButton {
        id: copyOverlay
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: LayoutMetrics.spacing.sm
        // Keep clear of the vertical scrollbar.
        anchors.rightMargin: vbar.visible
                            ? vbar.width + vbar.gap + LayoutMetrics.spacing.xs
                            : LayoutMetrics.spacing.sm
        z: 10
        visible: control.showCopyButton
        opacity: control.text.length > 0 ? 1.0 : 0.45
        enabled: control.text.length > 0
        activeFocusOnTab: false
        buttonWidth: LayoutMetrics.size.iconM
        buttonHeight: LayoutMetrics.size.iconM
        iconPath: control.copyConfirmed ? SVGLibrary.checkMark : SVGLibrary.copy
        onPressed: {
            control.copy()
            control.copyConfirmed = true
            copyFeedbackTimer.restart()
        }
    }

    Timer {
        id: copyFeedbackTimer
        interval: 1000
        onTriggered: control.copyConfirmed = false
    }

    FocusRing {
        focusItem: area
    }
}
