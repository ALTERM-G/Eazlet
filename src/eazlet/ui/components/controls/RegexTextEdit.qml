import QtQuick
import QtQuick.Controls
import components

// Editable text box with a live, read-only rich-text layer behind it. Matches
// are painted from backend match spans without turning the editor itself into
// rich text, so typing, selection and plain-text extraction stay simple.
Item {
    id: control
    width: LayoutMetrics.size.textEditWidth
    height: LayoutMetrics.size.textEditHeight

    property string placeholderText: ""
    property alias text: area.text
    property alias readOnly: area.readOnly
    property var matches: []
    property color highlightColor: Qt.rgba(Theme.themeColor.r,
                                           Theme.themeColor.g,
                                           Theme.themeColor.b, 0.32)

    signal textEdited()

    function paste() {
        area.forceActiveFocus()
        area.paste()
    }

    function copy() {
        area.forceActiveFocus()
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

    function cssColor(value) {
        return "rgba(" + Math.round(value.r * 255) + ","
                + Math.round(value.g * 255) + ","
                + Math.round(value.b * 255) + "," + value.a + ")"
    }

    function escapeHtml(value) {
        return value.replace(/&/g, "&amp;")
                    .replace(/</g, "&lt;")
                    .replace(/>/g, "&gt;")
    }

    function htmlFor(value) {
        return escapeHtml(value).replace(/\n/g, "<br>")
    }

    function highlightedHtml() {
        var source = area.text
        if (!control.matches || control.matches.length === 0)
            return htmlFor(source)

        var spans = (control.matches || []).slice().sort(function(left, right) {
            return left.start - right.start
        })
        var html = ""
        var cursor = 0

        for (var i = 0; i < spans.length; i++) {
            var start = Math.max(cursor,
                                 Math.min(source.length,
                                          Math.max(0, spans[i].start || 0)))
            var end = Math.max(start,
                               Math.min(source.length,
                                        Math.max(0, spans[i].end || 0)))
            if (end <= start)
                continue

            html += htmlFor(source.slice(cursor, start))
            html += "<span style=\"background-color:"
                    + cssColor(control.highlightColor) + ";\">"
                    + htmlFor(source.slice(start, end)) + "</span>"
            cursor = end
        }

        html += htmlFor(source.slice(cursor))
        return html
    }

    Rectangle {
        anchors.fill: parent
        radius: LayoutMetrics.radius.m
        color: Theme.inputBackgroundColor
        border.color: area.activeFocus ? Theme.themeColor : Theme.borderColor
        border.width: LayoutMetrics.border.m

        Behavior on border.color {
            enabled: LayoutMetrics.animationsEnabled
            ColorAnimation { duration: 150 }
        }
    }

    Flickable {
        id: view
        // Reserve the right edge for the scroll bar thumb.
        readonly property real gutter: LayoutMetrics.unit * 1.6

        anchors.fill: parent
        anchors.margins: LayoutMetrics.border.m
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: area.width
        contentHeight: area.height

        Text {
            id: highlightLayer
            visible: area.text.length > 0
            x: area.leftPadding
            y: area.topPadding
            width: Math.max(0, area.width - area.leftPadding - area.rightPadding)
            height: Math.max(0, area.height - area.topPadding - area.bottomPadding)
            text: control.highlightedHtml()
            textFormat: Text.RichText
            font: area.font
            color: Theme.textColor
            wrapMode: area.wrapMode
            z: 0
        }

        Text {
            id: placeholder
            x: highlightLayer.x
            y: highlightLayer.y
            width: highlightLayer.width
            height: highlightLayer.height
            visible: area.text.length === 0
            text: control.placeholderText
            font: area.font
            color: Theme.dividerColor
            wrapMode: area.wrapMode
            z: 1
        }

        TextArea {
            id: area
            activeFocusOnTab: true
            width: Math.max(0, view.width - view.gutter)
            height: Math.max(view.height, implicitHeight)
            leftPadding: LayoutMetrics.spacing.sm
            rightPadding: LayoutMetrics.spacing.sm
            topPadding: LayoutMetrics.spacing.xs
            bottomPadding: LayoutMetrics.spacing.xs
            font.pixelSize: Typography.h4
            font.family: Typography.fontRegular
            // The layer behind draws the visible glyphs.
            color: "transparent"
            selectionColor: Qt.rgba(Theme.themeColor.r, Theme.themeColor.g,
                                    Theme.themeColor.b, 0.45)
            selectedTextColor: Theme.textColor
            wrapMode: Text.WrapAnywhere
            textFormat: Text.PlainText
            selectByMouse: true
            cursorDelegate: Item {}
            background: null
            z: 2

            onTextChanged: control.textEdited()

            ContextMenu.menu: TextContextMenu { editor: area }

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

            TextCursor {
                cursorRect: area.cursorRectangle
                font: area.font
                visible: area.activeFocus && area.cursorVisible
                         && area.selectionStart === area.selectionEnd
                z: 5
            }
        }

        ScrollBar.vertical: ScrollBar {
            id: vbar
            parent: view
            x: view.width - width
            y: 0
            height: view.height
            policy: ScrollBar.AsNeeded
            visible: vbar.size < 1.0
            padding: 0

            contentItem: ScrollBarThumb {
                bar: vbar
                orientation: Qt.Vertical
            }
        }
    }

    WheelScrollArea {
        target: view
        cursor: Qt.IBeamCursor
    }

    FocusRing {
        focusItem: area
    }
}
