import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import components

Item {
    Layout.fillWidth: true
    Layout.fillHeight: true

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
            contentHeight: archColumn.implicitHeight
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
                id: archColumn
                width: parent.width
                spacing: LayoutMetrics.spacing.lg

                Title {
                    text: "Archive / Compressor"
                    textColor: Theme.textColor
                    pixelSize: Typography.h2
                }

                DropZone {
                    width: parent.width
                    title: "Drop files or folders here"
                    description: "Add files to compress, or an archive to extract"
                    hint: "Drag and drop files or folders"
                    clickable: false
                    onFilesDropped: function(urls) {
                        for (var i = 0; i < urls.length; i++)
                            archiveVM.addFile(urls[i])
                    }
                }

                Row {
                    spacing: LayoutMetrics.spacing.sm
                    Button { buttonText: "Clear"; onPressed: archiveVM.clearFiles() }
                    Label {
                        bold: false
                        text: archiveVM.files.length + " item(s)"
                        textColor: Theme.textColor
                        pixelSize: Typography.h6
                    }
                }

                ListView {
                    width: parent.width
                    height: 150
                    model: archiveVM.files
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
                                width: parent.width * 0.8
                                elide: Text.ElideMiddle
                            }
                            Button { buttonText: "X"; width: 30; onPressed: archiveVM.removeFile(index) }
                        }
                    }
                }

                Row {
                    spacing: LayoutMetrics.spacing.md
                    Label {
                        bold: false
                        text: "Format:"
                        textColor: Theme.textColor
                        pixelSize: Typography.h6
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    ComboBox {
                        width: 150
                        model: ["zip", "tar.gz", "tar.xz", "tar.bz2"]
                        currentIndex: {
                            var idx = model.indexOf(archiveVM.format)
                            return idx >= 0 ? idx : 0
                        }
                        onCurrentTextChanged: {
                            if (currentText && currentText !== archiveVM.format) {
                                archiveVM.format = currentText
                            }
                        }
                    }
                    Label {
                        bold: false
                        text: "Compression:"
                        textColor: Theme.textColor
                        pixelSize: Typography.h6
                        anchors.verticalCenter: parent.verticalCenter
                        visible: archiveVM.format === "zip"
                    }
                    SpinBox {
                        from: 1
                        to: 9
                        value: archiveVM.compressionLevel
                        visible: archiveVM.format === "zip"
                        onValueChanged: archiveVM.compressionLevel = value
                    }
                }

                Row {
                    spacing: LayoutMetrics.spacing.sm
                    Label {
                        bold: false
                        text: "Output: " + archiveVM.outputDir
                        textColor: Theme.textColor
                        pixelSize: Typography.h6
                        elide: Text.ElideMiddle
                        width: parent.width * 0.7
                    }
                    Button { buttonText: "Open Folder"; onPressed: archiveVM.openOutputDir() }
                }

                Row {
                    spacing: LayoutMetrics.spacing.sm
                    Button { buttonText: "Compress"; primary: true; enabled: !archiveVM.compressing && !archiveVM.extracting && archiveVM.files.length > 0; onPressed: archiveVM.compress() }
                }

                Row {
                    spacing: LayoutMetrics.spacing.sm
                    Label {
                        bold: false
                        text: "Extract archive:"
                        textColor: Theme.textColor
                        pixelSize: Typography.h6
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Button { buttonText: "Extract Selected"; enabled: !archiveVM.extracting && archiveVM.files.length === 1; onPressed: archiveVM.extract(archiveVM.files[0].path) }
                }

                ProgressBar {
                    width: parent.width
                    value: archiveVM.progress
                    visible: archiveVM.compressing || archiveVM.extracting || archiveVM.progress >= 1.0
                }

                Label {
                    bold: false
                    text: archiveVM.status
                    textColor: Theme.textColor
                    pixelSize: Typography.h6
                }
                Label {
                    bold: false
                    text: archiveVM.error
                    textColor: "red"
                    pixelSize: Typography.h6
                    visible: archiveVM.error !== ""
                }
                Item { width: 1; height: LayoutMetrics.spacing.xl }
            }
        }
    }
}
