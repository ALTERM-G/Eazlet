import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import components

Item {
    id: page
    Layout.fillWidth: true
    Layout.fillHeight: true

    function processAction() {
        if (!converterVM.converting && converterVM.files.length === 1 && converterVM.targetFormat !== "")
            converterVM.convert()
    }

    function categoryName(category) {
        switch (category) {
        case "video": return "Video"
        case "audio": return "Audio"
        case "image": return "Image"
        case "document": return "Document"
        default: return "Unsupported"
        }
    }

    function sourceSummary() {
        if (converterVM.files.length === 0)
            return ""
        if (converterVM.sourceCategory === "unsupported")
            return "Unsupported file type" + (converterVM.sourceFormat !== "" ? " · ." + converterVM.sourceFormat.toUpperCase() : "")
        return categoryName(converterVM.sourceCategory) + " · ." + converterVM.sourceFormat.toUpperCase()
    }

    function noTargetMessage() {
        if (converterVM.sourceCategory === "unsupported")
            return "This file type is not supported."
        if (converterVM.sourceCategory === "document")
            return "No document conversion is available for this file."
        return "No conversion targets are available for this file."
    }

    Surface {
        anchors.centerIn: parent
        width: parent.width * 0.9
        height: parent.height * 0.9

        Flickable {
            id: flick
            ScrollBar.vertical: AppScrollBar {}
            interactive: false

            anchors.fill: parent
            anchors.margins: LayoutMetrics.spacing.lg
            contentHeight: convColumn.implicitHeight
            clip: true
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: function(wheel) {
                    var delta = wheel.pixelDelta.y !== 0
                        ? wheel.pixelDelta.y * 2
                        : wheel.angleDelta.y / 120 * LayoutMetrics.unit * 24
                    var maxY = Math.max(0, flick.contentHeight - flick.height)
                    flick.contentY = Math.max(0, Math.min(maxY, flick.contentY - delta))
                    wheel.accepted = true
                }
            }

            Column {
                id: convColumn
                width: Math.max(0, parent.width - LayoutMetrics.unit * 1.6)
                x: Math.max(0, (parent.width - width) / 2)
                spacing: LayoutMetrics.spacing.lg

                Title {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Converter"
                    textColor: Theme.textColor
                    pixelSize: Typography.h2
                }

                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    bold: false
                    text: "Drop a file, choose a target format, and convert it locally."
                    textColor: Theme.dividerColor
                    pixelSize: Typography.h6
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    width: parent.width
                    height: LayoutMetrics.spacing.xxs
                    color: Theme.dividerColor
                }

                DropZone {
                    width: parent.width
                    enabled: !converterVM.converting
                    title: "Drop a file here"
                    description: "Drag and drop a file, or click to browse"
                    hint: "One file at a time — adding another replaces the current file"
                    onClicked: fileDialog.open()
                    onFilesDropped: function(urls) {
                        if (urls.length > 0)
                            converterVM.addFile(urls[0])
                    }
                }

                FileDialog {
                    id: fileDialog
                    title: "Select a file to convert"
                    fileMode: FileDialog.OpenFile
                    onAccepted: converterVM.addFile(selectedFile.toString())
                }

                Rectangle {
                    width: parent.width
                    visible: converterVM.files.length > 0
                    height: visible ? fileRow.implicitHeight + LayoutMetrics.spacing.md * 2 : 0
                    radius: LayoutMetrics.radius.m
                    color: Theme.inputBackgroundColor
                    border.color: Theme.borderColor
                    border.width: LayoutMetrics.border.l

                    RowLayout {
                        id: fileRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: LayoutMetrics.spacing.md
                        anchors.rightMargin: LayoutMetrics.spacing.md
                        spacing: LayoutMetrics.spacing.md

                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: formatBadge.implicitWidth + LayoutMetrics.spacing.md
                            Layout.preferredHeight: formatBadge.implicitHeight + LayoutMetrics.spacing.sm
                            radius: LayoutMetrics.radius.s
                            color: Theme.backgroundColor
                            border.color: Theme.borderColor
                            border.width: LayoutMetrics.border.l

                            Label {
                                id: formatBadge
                                anchors.centerIn: parent
                                bold: false
                                text: converterVM.sourceFormat !== "" ? converterVM.sourceFormat.toUpperCase() : "?"
                                textColor: converterVM.sourceCategory === "unsupported" ? "red" : Theme.themeColor
                                pixelSize: Typography.caption
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: LayoutMetrics.spacing.xxs

                            Label {
                                Layout.fillWidth: true
                                bold: false
                                text: converterVM.files.length > 0 ? converterVM.files[0].name : ""
                                textColor: Theme.textColor
                                pixelSize: Typography.h5
                                elide: Text.ElideMiddle
                            }

                            Label {
                                Layout.fillWidth: true
                                bold: false
                                text: page.sourceSummary()
                                textColor: converterVM.sourceCategory === "unsupported" ? "red" : Theme.dividerColor
                                pixelSize: Typography.caption
                                elide: Text.ElideRight
                            }
                        }

                        IconButton {
                            Layout.alignment: Qt.AlignVCenter
                            buttonWidth: LayoutMetrics.size.iconS
                            buttonHeight: LayoutMetrics.size.iconS
                            enabled: !converterVM.converting
                            iconPath: SVGLibrary.cross
                            onPressed: converterVM.clearFiles()
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: LayoutMetrics.spacing.md
                    visible: converterVM.files.length > 0 && converterVM.validTargetFormats.length > 0
                    Label {
                        bold: false
                        text: "Convert to:"
                        textColor: Theme.textColor
                        pixelSize: Typography.h6
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    ComboBox {
                        width: 200
                        model: converterVM.validTargetFormats
                        scrollablePopup: true
                        maxVisibleItems: 10
                        currentIndex: {
                            var idx = model.indexOf(converterVM.targetFormat)
                            return idx >= 0 ? idx : 0
                        }
                        onCurrentTextChanged: {
                            if (currentText && currentText !== converterVM.targetFormat) {
                                converterVM.targetFormat = currentText
                            }
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: LayoutMetrics.spacing.sm
                    visible: converterVM.files.length > 0 && converterVM.validTargetFormats.length === 0
                    SVGObject {
                        anchors.verticalCenter: parent.verticalCenter
                        width: LayoutMetrics.size.iconS
                        height: LayoutMetrics.size.iconS
                        path: SVGLibrary.info
                        color: converterVM.sourceCategory === "unsupported" ? "red" : Theme.textColor
                    }
                    Label {
                        bold: false
                        anchors.verticalCenter: parent.verticalCenter
                        text: page.noTargetMessage()
                        textColor: converterVM.sourceCategory === "unsupported" ? "red" : Theme.textColor
                        pixelSize: Typography.h6
                    }
                }

                PathPicker {
                    label: Lang.labels.outputFolder
                    path: converterVM.outputDir
                    defaultPath: controller.get_converter_default_dir()
                    onPathAccepted: function(newPath) {
                        controller.save_converter_dir(newPath)
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: LayoutMetrics.spacing.sm
                    Button { buttonText: "Open Folder"; onPressed: converterVM.openOutputDir() }
                }

                Rectangle {
                    width: parent.width
                    height: LayoutMetrics.spacing.xxs
                    color: Theme.dividerColor
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: LayoutMetrics.spacing.md

                    Button {
                        buttonText: "Convert"
                        primary: true
                        isometric: true
                        heightMultiplier: 1.3
                        visible: !converterVM.converting
                        enabled: converterVM.files.length === 1 && converterVM.targetFormat !== ""
                        onPressed: converterVM.convert()
                    }

                    Button {
                        buttonText: "Cancel"
                        visible: converterVM.converting
                        onPressed: converterVM.cancel()
                    }
                }

                ProgressBar {
                    width: Math.min(parent.width, LayoutMetrics.unit * 50)
                    anchors.horizontalCenter: parent.horizontalCenter
                    value: converterVM.progress
                    visible: converterVM.converting || converterVM.progress >= 1.0
                }

                Row {
                    spacing: LayoutMetrics.spacing.sm
                    visible: converterVM.status !== ""
                    SVGObject {
                        anchors.verticalCenter: parent.verticalCenter
                        width: LayoutMetrics.size.iconS
                        height: LayoutMetrics.size.iconS
                        path: SVGLibrary.checkMark
                        color: Theme.textColor
                        visible: converterVM.status === "Done"
                    }
                    Label {
                        bold: false
                        anchors.verticalCenter: parent.verticalCenter
                        text: converterVM.status
                        textColor: Theme.textColor
                        pixelSize: Typography.h6
                    }
                }
                Row {
                    spacing: LayoutMetrics.spacing.sm
                    visible: converterVM.error !== ""
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
                        text: converterVM.error
                        textColor: "red"
                        pixelSize: Typography.h6
                    }
                }
                Item { width: 1; height: LayoutMetrics.spacing.xl }
            }
        }
    }
}
