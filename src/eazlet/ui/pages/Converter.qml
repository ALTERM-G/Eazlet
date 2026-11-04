import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import components

Item {
    Layout.fillWidth: true
    Layout.fillHeight: true

    Surface {
        anchors.centerIn: parent
        width: parent.width * 0.9
        height: parent.height * 0.9

        Flickable {
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            interactive: true

            anchors.fill: parent
            anchors.margins: LayoutMetrics.spacing.lg
            contentHeight: convColumn.implicitHeight
            clip: true
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds

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
                    Button { buttonText: "Clear"; onPressed: converterVM.clearFiles() }
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
                            Button { buttonText: "X"; width: 30; onPressed: converterVM.removeFile(index) }
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
                    Button { buttonText: "Convert"; primary: true; enabled: !converterVM.converting && converterVM.files.length > 0 && converterVM.targetFormat !== ""; onPressed: converterVM.convert() }
                    Button { buttonText: "Cancel"; enabled: converterVM.converting; onPressed: converterVM.cancel() }
                }

                ProgressBar {
                    width: parent.width
                    value: converterVM.progress
                    visible: converterVM.converting || converterVM.progress >= 1.0
                }

                Label {
    bold: false
                    text: converterVM.status
                    textColor: Theme.textColor
                    pixelSize: Typography.h6
                }
                Label {
    bold: false
                    text: converterVM.error
                    textColor: "red"
                    pixelSize: Typography.h6
                    visible: converterVM.error !== ""
                }
                Item { width: 1; height: LayoutMetrics.spacing.xl }
            }
        }
    }
}
