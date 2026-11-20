import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import components

Item {
    id: page

    readonly property var borderStyleIds: ["none", "single", "double", "rounded", "ascii", "bold", "stars", "dots", "hash", "block"]
    readonly property var borderOptions: [
        { label: Lang.pages.asciiArt.borderNone },
        { label: Lang.pages.asciiArt.borderSingle },
        { label: Lang.pages.asciiArt.borderDouble },
        { label: Lang.pages.asciiArt.borderRounded },
        { label: Lang.pages.asciiArt.borderAscii },
        { label: Lang.pages.asciiArt.borderBold },
        { label: Lang.pages.asciiArt.borderStars },
        { label: Lang.pages.asciiArt.borderDots },
        { label: Lang.pages.asciiArt.borderHash },
        { label: Lang.pages.asciiArt.borderBlock }
    ]

    function processAction() {
        asciiArtVM.process()
    }

    PreviewBrowser {
        id: fontBrowser
        title: Lang.pages.asciiArt.chooseFont
        searchPlaceholderText: Lang.pages.asciiArt.searchFonts
        items: asciiArtVM.fonts
        currentItem: asciiArtVM.font
        favorites: asciiArtVM.favorites
        recents: asciiArtVM.recents
        sampleText: asciiArtVM.input
        itemSampleLength: 4
        itemNameSingular: Lang.pages.asciiArt.fontSingular
        itemNamePlural: Lang.pages.asciiArt.fontPlural
        noRecentsLabel: Lang.pages.asciiArt.noRecentFonts
        nothingSelectedLabel: Lang.pages.asciiArt.noFontSelected
        previewPlaceholderText: Lang.pages.asciiArt.selectFontPrompt
        showPreview: false
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
            acceptedButtons: Qt.NoButton

            WheelScrollArea {
                target: pageFlickable
            }

            ScrollBar.vertical: AppScrollBar {}

            Column {
                id: contentColumn
                width: parent.width
                x: Math.max(0, (parent.width - width) / 2)
                spacing: LayoutMetrics.spacing.md

                Title {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Lang.pages.asciiArt.title
                    textColor: Theme.textColor
                    pixelSize: Typography.h2
                }

                Label {
                    bold: false
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: Lang.pages.asciiArt.subtitle
                    textColor: Theme.dividerColor
                    pixelSize: Typography.h6
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    width: parent.width
                    height: LayoutMetrics.divider.s
                    color: Theme.dividerColor
                }

                Row {
                    id: controlsRow
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: LayoutMetrics.spacing.lg

                    Column {
                        spacing: LayoutMetrics.spacing.xxs
                        Label {
                            width: fontButton.width
                            horizontalAlignment: Text.AlignHCenter
                            bold: false
                            text: Lang.pages.asciiArt.font
                            textColor: Theme.textColor
                            pixelSize: Typography.h6
                        }
                        Button {
                            id: fontButton
                            buttonText: asciiArtVM.font
                            iconPath: SVGLibrary.dropDown
                            width: Math.max(LayoutMetrics.size.buttonWidth * 1.8, implicitWidth)
                            heightMultiplier: 1.5
                            onPressed: fontBrowser.open()
                        }
                    }

                    Column {
                        spacing: LayoutMetrics.spacing.xxs
                        Label {
                            width: borderCombo.width
                            horizontalAlignment: Text.AlignHCenter
                            bold: false
                            text: Lang.pages.asciiArt.border
                            textColor: Theme.textColor
                            pixelSize: Typography.h6
                        }
                        ComboBox {
                            id: borderCombo
                            width: LayoutMetrics.size.comboBoxWidth * 0.8
                            textRole: "label"
                            model: page.borderOptions
                            Component.onCompleted: {
                                var idx = page.borderStyleIds.indexOf(asciiArtVM.borderStyle)
                                if (idx >= 0) currentIndex = idx
                            }
                            onActivated: function(index) {
                                if (index >= 0 && index < page.borderStyleIds.length) {
                                    var id = page.borderStyleIds[index]
                                    if (id !== asciiArtVM.borderStyle)
                                        asciiArtVM.setBorderStyle(id)
                                }
                            }
                            onCurrentIndexChanged: {
                                if (currentIndex >= 0 && currentIndex < page.borderStyleIds.length) {
                                    var id = page.borderStyleIds[currentIndex]
                                    if (id !== asciiArtVM.borderStyle)
                                        asciiArtVM.setBorderStyle(id)
                                }
                            }
                        }
                    }

                    Column {
                        spacing: LayoutMetrics.spacing.xxs
                        Label {
                            width: hPadSpin.width
                            horizontalAlignment: Text.AlignHCenter
                            bold: false
                            text: Lang.pages.asciiArt.hPadding
                            textColor: Theme.textColor
                            pixelSize: Typography.h6
                        }
                        SpinBox {
                            id: hPadSpin
                            from: 0
                            to: 20
                            value: asciiArtVM.borderHPadding
                            onValueChanged: {
                                if (value !== asciiArtVM.borderHPadding)
                                    asciiArtVM.setBorderHPadding(value)
                            }
                        }
                    }

                    Column {
                        spacing: LayoutMetrics.spacing.xxs
                        Label {
                            width: vPadSpin.width
                            horizontalAlignment: Text.AlignHCenter
                            bold: false
                            text: Lang.pages.asciiArt.vPadding
                            textColor: Theme.textColor
                            pixelSize: Typography.h6
                        }
                        SpinBox {
                            id: vPadSpin
                            from: 0
                            to: 10
                            value: asciiArtVM.borderVPadding
                            onValueChanged: {
                                if (value !== asciiArtVM.borderVPadding)
                                    asciiArtVM.setBorderVPadding(value)
                            }
                        }
                    }

                    Column {
                        spacing: LayoutMetrics.spacing.xxs
                        Label {
                            width: outputSizeSpin.width
                            horizontalAlignment: Text.AlignHCenter
                            bold: false
                            text: Lang.pages.asciiArt.outputSize
                            textColor: Theme.textColor
                            pixelSize: Typography.h6
                        }
                        SpinBox {
                            id: outputSizeSpin
                            from: 8
                            to: 48
                            value: Typography.body
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: LayoutMetrics.spacing.sm

                    Button {
                        objectName: "exportSvgButton"
                        buttonText: Lang.pages.asciiArt.exportSvg
                        primary: true
                        isometric: true
                        heightMultiplier: 1.2
                        enabled: asciiArtVM.output !== ""
                        onPressed: svgFileDialog.open()
                    }
                    Button {
                        buttonText: Lang.pages.asciiArt.clear
                        iconPath: SVGLibrary.eraser
                        onPressed: asciiArtVM.clear()
                    }
                }

                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    bold: false
                    text: Lang.pages.asciiArt.input
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
                    placeholderText: Lang.pages.asciiArt.inputPlaceholder
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
                        visible: asciiArtVM.error === ""
                                 && asciiArtVM.status !== Lang.pages.asciiArt.msgEnterText
                                 && asciiArtVM.status !== Lang.pages.asciiArt.msgUnavailable
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
                    text: Lang.pages.asciiArt.output
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
                    fontPixelSize: outputSizeSpin.value
                    text: asciiArtVM.output
                    placeholderText: Lang.pages.asciiArt.outputPlaceholder
                    showCopyButton: true
                }

                Item {
                    width: 1
                    height: LayoutMetrics.spacing.xl
                }
            }
        }
    }

    FileDialog {
        id: svgFileDialog
        title: Lang.pages.asciiArt.exportDialogTitle
        fileMode: FileDialog.SaveFile
        defaultSuffix: "svg"
        nameFilters: [Lang.pages.asciiArt.svgFilter]
        onAccepted: asciiArtVM.exportSvg(
            selectedFile.toString(), Theme.textColor.toString()
        )
    }
}
