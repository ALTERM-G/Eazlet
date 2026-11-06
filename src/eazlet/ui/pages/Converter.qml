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
        if (!converterVM.converting && converterVM.files.length > 0 && converterVM.targetFormat !== "")
            converterVM.convert()
    }

    Surface {
        anchors.centerIn: parent
        width: parent.width * 0.9
        height: parent.height * 0.9

        Flickable {
            id: flick
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                implicitWidth: LayoutMetrics.unit * 1.2
            }
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
                width: parent.width
                spacing: LayoutMetrics.spacing.lg

                Title {
                    text: "Converter"
                    textColor: Theme.textColor
                    pixelSize: Typography.h2
                }

                DropZone {
                    width: parent.width
                    title: "Drop files here"
                    description: "Drag and drop files, or click to browse"
                    hint: "Files are added to the conversion queue"
                    onClicked: converterVM.addFiles()
                    onFilesDropped: function(urls) {
                        for (var i = 0; i < urls.length; i++)
                            converterVM.addFile(urls[i])
                    }
                }

                Row {
                    spacing: LayoutMetrics.spacing.sm
                    Button { buttonText: "Clear"; iconPath: SVGLibrary.eraser; onPressed: converterVM.clearFiles() }
                    Label {
                        bold: false
                        text: converterVM.files.length + " file(s)"
                        textColor: Theme.textColor
                        pixelSize: Typography.h6
                    }
                }

                ListView {
                    width: parent.width
                    height: 150
                    model: converterVM.files
                    clip: true
                    delegate: Rectangle {
                        width: parent.width
                        height: 30
                        color: index % 2 === 0 ? Theme.backgroundColor : Theme.inputBackgroundColor
                        Row {
                            anchors.fill: parent
                            anchors.margins: LayoutMetrics.spacing.sm
                            spacing: LayoutMetrics.spacing.sm
                            Label {
                                bold: false
                                text: modelData.name
                                textColor: Theme.textColor
                                pixelSize: Typography.h6
                                width: parent.width * 0.7
                                elide: Text.ElideMiddle
                            }
                            Label {
                                bold: false
                                text: modelData.ext.toUpperCase()
                                textColor: Theme.textColor
                                pixelSize: Typography.h6
                                width: 40
                            }
                            IconButton {
                                anchors.verticalCenter: parent.verticalCenter
                                buttonWidth: LayoutMetrics.size.iconS
                                buttonHeight: LayoutMetrics.size.iconS
                                iconPath: SVGLibrary.cross
                                onPressed: converterVM.removeFile(index)
                            }
                        }
                    }
                }

                Row {
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
                    spacing: LayoutMetrics.spacing.sm
                    Label {
                        bold: false
                        text: "Output: " + converterVM.outputDir
                        textColor: Theme.textColor
                        pixelSize: Typography.h6
                        elide: Text.ElideMiddle
                        width: parent.width * 0.7
                    }
                    Button { buttonText: "Open Folder"; onPressed: converterVM.openOutputDir() }
                }

                Row {
                    spacing: LayoutMetrics.spacing.sm
                    Button { buttonText: "Convert"; primary: true; isometric: true; heightMultiplier: 1.3; enabled: !converterVM.converting && converterVM.files.length > 0 && converterVM.targetFormat !== ""; onPressed: converterVM.convert() }
                    Button { buttonText: "Cancel"; enabled: converterVM.converting; onPressed: converterVM.cancel() }
                }

                ProgressBar {
                    width: parent.width
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
