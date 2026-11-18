import QtQuick
import QtQuick as QQ
import QtQuick.Controls
import QtQuick.Layouts
import components

Item {
    id: page

    Layout.fillWidth: true
    Layout.fillHeight: true

    readonly property real bannerSourceWidth: 399
    readonly property real bannerSourceHeight: 96
    readonly property real bannerAspect: bannerSourceWidth / bannerSourceHeight
    readonly property real bannerWidth: Math.min(
        page.width - LayoutMetrics.spacing.lg * 2,
        page.height * 0.16 * page.bannerAspect * LayoutMetrics.scaleFactor
    )

    property var commandHistory: []
    property int historyCursor: 0

    readonly property string consoleOutput: replVM.output
    readonly property string activePrompt: consoleOutput.endsWith("... ")
                                           ? "... "
                                           : ">>> "
    readonly property string transcript: {
        var text = consoleOutput
        if (text.endsWith(">>> ") || text.endsWith("... "))
            return text.slice(0, -4)
        return text
    }

    function closingPair(character) {
        switch (character) {
        case "(": return ")"
        case "[": return "]"
        case "{": return "}"
        case "\"": return "\""
        case "'": return "'"
        default: return ""
        }
    }

    function isClosing(character) {
        return character === ")" || character === "]" || character === "}"
    }

    function insertPaired(character) {
        var closing = page.closingPair(character)
        if (closing === "")
            return false

        var text = commandInput.text
        var start = commandInput.selectionStart
        var end = commandInput.selectionEnd
        if (end > start) {
            var selected = text.substring(start, end)
            commandInput.text = text.substring(0, start) + character + selected
                                + closing + text.substring(end)
            commandInput.cursorPosition = start + 1 + selected.length
        } else if (text.charAt(start) === closing) {
            commandInput.cursorPosition = start + 1
        } else {
            commandInput.text = text.substring(0, start) + character + closing
                                + text.substring(start)
            commandInput.cursorPosition = start + 1
        }
        return true
    }

    function skipClosing(character) {
        if (!page.isClosing(character)
            || commandInput.text.charAt(commandInput.cursorPosition) !== character)
            return false
        commandInput.cursorPosition += 1
        return true
    }

    function removeEmptyPair() {
        var position = commandInput.cursorPosition
        if (position === 0 || commandInput.selectionStart !== commandInput.selectionEnd)
            return false
        var before = commandInput.text.charAt(position - 1)
        var after = commandInput.text.charAt(position)
        if (page.closingPair(before) !== after)
            return false
        commandInput.text = commandInput.text.substring(0, position - 1)
                            + commandInput.text.substring(position + 1)
        commandInput.cursorPosition = position - 1
        return true
    }

    function clearTerminal() {
        replVM.clear()
        scrollToEnd()
    }

    function submitCommand() {
        var command = commandInput.text
        if (command.trim().length > 0)
            page.commandHistory.push(command)
        page.historyCursor = page.commandHistory.length
        if (command.trim() === "clear")
            page.clearTerminal()
        else
            replVM.submit(command)
        commandInput.text = ""
        commandInput.forceActiveFocus()
        scrollToEnd()
    }

    function scrollToEnd() {
        Qt.callLater(function () {
            outputView.contentY = Math.max(
                0, outputView.contentHeight - outputView.height
            )
        })
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: LayoutMetrics.spacing.lg
        spacing: LayoutMetrics.spacing.md

        EazletBanner {
            id: banner
            objectName: "homeBanner"
            fillColor: Theme.themeColor
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: page.bannerWidth
            Layout.preferredHeight: page.bannerWidth / page.bannerAspect
        }

        Label {
            objectName: "homeTagline"
            text: "Simple tools. Easy workflow."
            bold: true
            pixelSize: Typography.body
            Layout.alignment: Qt.AlignHCenter
            horizontalAlignment: Text.AlignHCenter
        }

        Rectangle {
            objectName: "homeSeparator"
            Layout.fillWidth: true
            Layout.preferredHeight: LayoutMetrics.border.s
            color: Theme.dividerColor
        }

        Flickable {
            id: outputView
            objectName: "replOutputView"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            contentWidth: width
            contentHeight: consoleColumn.implicitHeight

            Column {
                id: consoleColumn
                width: parent.width
                spacing: 0

                QQ.TextEdit {
                    id: transcriptText
                    objectName: "replOutput"
                    width: parent.width
                    height: implicitHeight
                    text: page.transcript
                    readOnly: true
                    selectByMouse: true
                    color: Theme.textColor
                    selectionColor: Theme.themeColor
                    selectedTextColor: Theme.hoverTextColor
                    font.family: Typography.terminalFontFamily
                    font.pixelSize: Typography.h5
                    wrapMode: Text.WrapAnywhere
                }

                Row {
                    width: parent.width
                    spacing: 0

                    Text {
                        id: promptText
                        objectName: "replPrompt"
                        text: page.activePrompt
                        color: Theme.themeColor
                        font.family: Typography.terminalFontFamily
                        font.pixelSize: Typography.h5
                        font.weight: Font.Bold
                    }

                    TextField {
                        id: commandInput
                        objectName: "replInput"
                        width: parent.width - promptText.width
                        background: Item {}
                        padding: 0
                        leftPadding: 0
                        rightPadding: 0
                        color: Theme.textColor
                        selectionColor: Theme.themeColor
                        selectedTextColor: Theme.hoverTextColor
                        placeholderTextColor: Theme.borderColor
                        font.family: Typography.terminalFontFamily
                        font.pixelSize: Typography.h5
                        placeholderText: "type here"
                        activeFocusOnTab: true

                        Component.onCompleted: commandInput.forceActiveFocus()

                        onAccepted: page.submitCommand()

                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_L
                                && (event.modifiers & Qt.ControlModifier)) {
                                page.clearTerminal()
                                event.accepted = true
                                return
                            }
                            if (event.modifiers
                                & (Qt.ControlModifier | Qt.MetaModifier
                                   | Qt.AltModifier))
                                return
                            if (event.text.length === 1
                                && page.closingPair(event.text) !== "") {
                                page.insertPaired(event.text)
                                event.accepted = true
                            } else if (event.text.length === 1
                                       && page.skipClosing(event.text)) {
                                event.accepted = true
                            } else if (event.key === Qt.Key_Backspace
                                       && page.removeEmptyPair()) {
                                event.accepted = true
                            }
                        }

                        Keys.onUpPressed: {
                            if (page.commandHistory.length === 0)
                                return
                            page.historyCursor = Math.max(0, page.historyCursor - 1)
                            commandInput.text = page.commandHistory[page.historyCursor]
                            event.accepted = true
                        }

                        Keys.onDownPressed: {
                            if (page.commandHistory.length === 0)
                                return
                            page.historyCursor = Math.min(
                                page.commandHistory.length, page.historyCursor + 1
                            )
                            commandInput.text = page.historyCursor
                                                === page.commandHistory.length
                                                ? "" : page.commandHistory[page.historyCursor]
                            event.accepted = true
                        }
                    }
                }
            }

            ScrollBar.vertical: AppScrollBar {
                autoGutter: false
            }

            onContentHeightChanged: page.scrollToEnd()
        }
    }

    Component.onDestruction: replVM.stop()
}
