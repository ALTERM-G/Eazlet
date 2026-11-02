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
            contentHeight: archColumn.implicitHeight
            clip: true
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: archColumn
                width: parent.width
                spacing: LayoutMetrics.spacing.lg

                Text {
                    text: "Archive / Compressor"
                    color: Theme.textColor
                    font.bold: true
                }

                DropArea {
                    id: dropArea
                    width: parent.width
                    height: 120
                    onDropped: (drop) => {
                        if (drop.hasUrls) {
                            for (var i = 0; i < drop.urls.length; i++) {
                                archiveVM.addFile(drop.urls[i].toString())
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: LayoutMetrics.radius.m
                        color: dropArea.containsDrag ? Theme.hoverBackgroundColor : Theme.inputBackgroundColor
                        border.color: dropArea.containsDrag ? Theme.themeColor : Theme.borderColor
                        border.width: LayoutMetrics.border.m

                        Column {
                            anchors.centerIn: parent
                            spacing: LayoutMetrics.spacing.sm
                            Text {
                                text: "Drop files or folders here"
                                color: Theme.textColor
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }
                }

                Row {
                    spacing: LayoutMetrics.spacing.sm
                    Button { buttonText: "Clear"; onPressed: archiveVM.clearFiles() }
                    Text { text: archiveVM.files.length + " item(s)"; color: Theme.textColor }
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
                            Text { text: modelData.name; color: Theme.textColor; width: parent.width * 0.8; elide: Text.ElideMiddle }
                            Button { buttonText: "X"; width: 30; onPressed: archiveVM.removeFile(index) }
                        }
                    }
                }

                Row {
                    spacing: LayoutMetrics.spacing.md
                    Text { text: "Format:"; color: Theme.textColor; anchors.verticalCenter: parent.verticalCenter }
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
                    Text { text: "Compression:"; color: Theme.textColor; anchors.verticalCenter: parent.verticalCenter; visible: archiveVM.format === "zip" }
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
                    Text { text: "Output: " + archiveVM.outputDir; color: Theme.textColor; elide: Text.ElideMiddle; width: parent.width * 0.7 }
                    Button { buttonText: "Open Folder"; onPressed: archiveVM.openOutputDir() }
                }

                Row {
                    spacing: LayoutMetrics.spacing.sm
                    Button { buttonText: "Compress"; primary: true; enabled: !archiveVM.compressing && !archiveVM.extracting && archiveVM.files.length > 0; onPressed: archiveVM.compress() }
                }

                Row {
                    spacing: LayoutMetrics.spacing.sm
                    Text { text: "Extract archive:"; color: Theme.textColor; anchors.verticalCenter: parent.verticalCenter }
                    Button { buttonText: "Extract Selected"; enabled: !archiveVM.extracting && archiveVM.files.length === 1; onPressed: archiveVM.extract(archiveVM.files[0].path) }
                }

                ProgressBar {
                    width: parent.width
                    value: archiveVM.progress
                    visible: archiveVM.compressing || archiveVM.extracting || archiveVM.progress >= 1.0
                }

                Text { text: archiveVM.status; color: Theme.textColor }
                Text { text: archiveVM.error; color: "red"; visible: archiveVM.error !== "" }
                Item { width: 1; height: LayoutMetrics.spacing.xl }
            }
        }
    }
}
