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
        if (!archiveVM.compressing && !archiveVM.extracting && archiveVM.files.length > 0)
            archiveVM.compress()
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
                width: Math.max(0, parent.width - LayoutMetrics.unit * 1.6)
                x: Math.max(0, (parent.width - width) / 2)
                spacing: LayoutMetrics.spacing.lg

                Title {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Archive / Compressor"
                    textColor: Theme.textColor
                    pixelSize: Typography.h2
                }

                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    bold: false
                    text: "Compress files into an archive or extract an archive you added."
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
                    title: "Drop files or folders here"
                    description: "Add files to compress, or an archive to extract"
                    hint: "Drag and drop files or folders, or click to browse files"
                    onClicked: fileDialog.open()
                    onFilesDropped: function(urls) {
                        for (var i = 0; i < urls.length; i++)
                            archiveVM.addFile(urls[i])
                    }
                }

                FileDialog {
                    id: fileDialog
                    title: "Select files to add"
                    fileMode: FileDialog.OpenFiles
                    onAccepted: {
                        for (var i = 0; i < selectedFiles.length; i++)
                            archiveVM.addFile(selectedFiles[i].toString())
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: LayoutMetrics.spacing.sm
                    Button { buttonText: "Clear"; iconPath: SVGLibrary.eraser; onPressed: archiveVM.clearFiles() }
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
                            IconButton {
                                anchors.verticalCenter: parent.verticalCenter
                                buttonWidth: LayoutMetrics.size.iconS
                                buttonHeight: LayoutMetrics.size.iconS
                                iconPath: SVGLibrary.cross
                                onPressed: archiveVM.removeFile(index)
                            }
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
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
                        scrollablePopup: true
                        maxVisibleItems: 10
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

                PathPicker {
                    label: Lang.labels.outputFolder
                    path: archiveVM.outputDir
                    defaultPath: controller.get_archive_default_dir()
                    onPathAccepted: function(newPath) {
                        controller.save_archive_dir(newPath)
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: LayoutMetrics.spacing.sm
                    Button { buttonText: "Open Folder"; onPressed: archiveVM.openOutputDir() }
                }

                Rectangle {
                    width: parent.width
                    height: LayoutMetrics.spacing.xxs
                    color: Theme.dividerColor
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: LayoutMetrics.spacing.sm
                    Button { buttonText: "Compress"; primary: true; isometric: true; heightMultiplier: 1.3; enabled: !archiveVM.compressing && !archiveVM.extracting && archiveVM.files.length > 0; onPressed: archiveVM.compress() }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
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
                    width: Math.min(parent.width, LayoutMetrics.unit * 50)
                    anchors.horizontalCenter: parent.horizontalCenter
                    value: archiveVM.progress
                    visible: archiveVM.compressing || archiveVM.extracting || archiveVM.progress >= 1.0
                }

                Row {
                    spacing: LayoutMetrics.spacing.sm
                    visible: archiveVM.status !== ""
                    SVGObject {
                        anchors.verticalCenter: parent.verticalCenter
                        width: LayoutMetrics.size.iconS
                        height: LayoutMetrics.size.iconS
                        path: SVGLibrary.checkMark
                        color: Theme.textColor
                        visible: archiveVM.status === "Done"
                    }
                    Label {
                        bold: false
                        anchors.verticalCenter: parent.verticalCenter
                        text: archiveVM.status
                        textColor: Theme.textColor
                        pixelSize: Typography.h6
                    }
                }
                Row {
                    spacing: LayoutMetrics.spacing.sm
                    visible: archiveVM.error !== ""
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
                        text: archiveVM.error
                        textColor: "red"
                        pixelSize: Typography.h6
                    }
                }
                Item { width: 1; height: LayoutMetrics.spacing.xl }
            }
        }
    }
}
