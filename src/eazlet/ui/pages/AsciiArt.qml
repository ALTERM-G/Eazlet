import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import components

Item {
    id: page

    function processAction() {
        asciiArtVM.process()
    }

    PreviewBrowser {
        id: fontBrowser
        title: "Choose a font"
        searchPlaceholderText: "Search fonts…"
        items: asciiArtVM.fonts
        currentItem: asciiArtVM.font
        favorites: asciiArtVM.favorites
        recents: asciiArtVM.recents
        sampleText: asciiArtVM.input
        tileSampleLength: 4
        itemNameSingular: "font"
        itemNamePlural: "fonts"
        noRecentsLabel: "No recent fonts yet"
        nothingSelectedLabel: "No font selected"
        previewPlaceholderText: "Select a font from the list"
        previewProvider: function(item, text) {
            return asciiArtVM.preview(item, text)
        }
        onApplied: function(item) {
            asciiArtVM.setFont(item)
        }
        onFavoriteToggled: function(item) {
            asciiArtVM.toggleFavorite(item)
        }
    }

    Surface {
        anchors.centerIn: parent
        width: parent.width * 0.9
        height: parent.height * 0.9

        Flickable {
            id: pageFlickable
            anchors.fill: parent
            anchors.margins: LayoutMetrics.spacing.lg
            contentWidth: width
            contentHeight: contentColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: false

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: function(wheel) {
                    var step = wheel.pixelDelta.y !== 0
                               ? wheel.pixelDelta.y * 2
                               : wheel.angleDelta.y / 120 * LayoutMetrics.unit * 24
                    var maxY = Math.max(0, pageFlickable.contentHeight - pageFlickable.height)
                    pageFlickable.contentY = Math.max(0, Math.min(maxY, pageFlickable.contentY - step))
                    wheel.accepted = true
                }
            }

            ScrollBar.vertical: AppScrollBar {}

            Column {
                id: contentColumn
                width: Math.max(0, parent.width - LayoutMetrics.unit * 1.6)
                x: Math.max(0, (parent.width - width) / 2)
                spacing: LayoutMetrics.spacing.lg

                Title {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "ASCII Art"
                    textColor: Theme.textColor
                    pixelSize: Typography.h2
                }

                Label {
                    bold: false
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "Convert text into ASCII art using FIGlet fonts."
                    textColor: Theme.dividerColor
                    pixelSize: Typography.h6
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    width: parent.width
                    height: LayoutMetrics.spacing.xxs
                    color: Theme.dividerColor
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: LayoutMetrics.spacing.md

                    Label {
                        bold: false
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Font"
                        textColor: Theme.textColor
                        pixelSize: Typography.h6
                    }

                    Button {
                        id: fontButton
                        buttonText: asciiArtVM.font
                        iconPath: SVGLibrary.dropDown
                        onPressed: fontBrowser.open()
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: LayoutMetrics.spacing.sm

                    Button {
                        buttonText: "Copy"
                        iconPath: SVGLibrary.copy
                        enabled: asciiArtVM.output !== ""
                        onPressed: asciiArtVM.copyOutput()
                    }
                    Button {
                        buttonText: "Clear"
                        iconPath: SVGLibrary.eraser
                        onPressed: asciiArtVM.clear()
                    }
                }

                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    bold: false
                    text: "Input"
                    textColor: Theme.textColor
                    pixelSize: Typography.h4
                }

                Timer {
                    id: previewTimer
                    interval: 180
                    repeat: false
                    onTriggered: asciiArtVM.process()
                }

                TextEdit {
                    id: inputEdit
                    width: parent.width
                    height: LayoutMetrics.unit * 14
                    placeholderText: "Type text to convert…"
                    text: asciiArtVM.input
                    onTextChanged: {
                        if (text !== asciiArtVM.input)
                            asciiArtVM.setInput(text)
                        previewTimer.restart()
                    }
                }

                Row {
                    spacing: LayoutMetrics.spacing.sm
                    visible: asciiArtVM.status !== ""

                    SVGObject {
                        anchors.verticalCenter: parent.verticalCenter
                        width: LayoutMetrics.size.iconS
                        height: LayoutMetrics.size.iconS
                        path: SVGLibrary.checkMark
                        color: Theme.textColor
                        visible: asciiArtVM.status === "Copied"
                    }
                    Label {
                        bold: false
                        anchors.verticalCenter: parent.verticalCenter
                        text: asciiArtVM.status
                        textColor: Theme.textColor
                        pixelSize: Typography.h6
                    }
                }

                Row {
                    width: parent.width
                    spacing: LayoutMetrics.spacing.sm
                    visible: asciiArtVM.error !== ""

                    SVGObject {
                        anchors.verticalCenter: parent.verticalCenter
                        width: LayoutMetrics.size.iconS
                        height: LayoutMetrics.size.iconS
                        path: SVGLibrary.cross
                        color: "red"
                    }
                    Label {
                        bold: false
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(0, parent.width - LayoutMetrics.size.iconS - parent.spacing)
                        text: asciiArtVM.error
                        textColor: "red"
                        pixelSize: Typography.h6
                        wrapMode: Text.WordWrap
                    }
                }

                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    bold: false
                    text: "Output"
                    textColor: Theme.textColor
                    pixelSize: Typography.h4
                }

                TextEdit {
                    id: outputEdit
                    width: parent.width
                    height: Math.max(LayoutMetrics.unit * 28, page.height * 0.38)
                    readOnly: true
                    wrapMode: Text.NoWrap
                    horizontalScroll: true
                    fontFamily: "JetBrains Mono"
                    fontPixelSize: Typography.body
                    text: asciiArtVM.output
                    placeholderText: "ASCII art output will appear here"
                    showCopyButton: true
                }

                Item {
                    width: 1
                    height: LayoutMetrics.spacing.xl
                }
            }
        }
    }
}
