import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
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
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            interactive: true

            anchors.fill: parent
            anchors.margins: LayoutMetrics.spacing.lg
            contentHeight: contentColumn.implicitHeight
            clip: true
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: contentColumn
                width: parent.width
                spacing: LayoutMetrics.spacing.lg

                Title {
                    text: unifiedDownloadVM.mode === "social" ? "Social Media Download" : "Direct Download"
                    textColor: Theme.textColor
                    pixelSize: Typography.h2
                }

                Row {
                    spacing: LayoutMetrics.spacing.sm
                    width: parent.width
                    LineEdit {
                        id: unifiedUrl
                        width: parent.width - pasteBtn.width - LayoutMetrics.spacing.sm
                        placeholderText: "Paste a link here (YouTube, TikTok, Instagram, etc. or direct file URL)"
                        text: unifiedDownloadVM.url
                        onTextChanged: unifiedDownloadVM.url = text
                    }
                    Button {
                        id: pasteBtn
                        buttonText: "Paste"
                        onPressed: unifiedDownloadVM.pasteFromClipboard()
                    }
                }

                Row {
                    spacing: LayoutMetrics.spacing.sm
                    Button { buttonText: "Destination"; onPressed: unifFolderDialog.open() }
                    Label {
    bold: false
                        text: unifiedDownloadVM.destination
                        textColor: Theme.textColor
                        pixelSize: Typography.h6
                        elide: Text.ElideMiddle
                        width: parent.width * 0.3
                    }
                    Button { buttonText: "Open Folder"; onPressed: unifiedDownloadVM.openDestination() }
                    Button { buttonText: "Force File"; onPressed: unifiedDownloadVM.forceDirect() }
                    Button { buttonText: "Force Social"; onPressed: unifiedDownloadVM.forceSocial() }
                }

                Column {
                    visible: unifiedDownloadVM.mode === "social"
                    spacing: LayoutMetrics.spacing.md
                    width: parent.width

                    Row {
                        spacing: LayoutMetrics.spacing.md
                        Button { buttonText: "Load Formats"; onPressed: unifiedDownloadVM.fetchFormats() }
                        CheckBox {
                            text: "Audio only (MP3)"
                            checked: unifiedDownloadVM.audioOnly
                            onToggled: unifiedDownloadVM.audioOnly = checked
                        }
                    }

                    Row {
                        spacing: LayoutMetrics.spacing.md
                        visible: !unifiedDownloadVM.audioOnly
                        Label {
    bold: false
                            text: "Format:"
                            textColor: Theme.textColor
                            pixelSize: Typography.h6
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        ComboBox {
                            width: parent.width * 0.85
                            model: unifiedDownloadVM.formats.length > 0 ? unifiedDownloadVM.formats : []
                            textRole: "label"
                            displayText: unifiedDownloadVM.formats.length > 0 ? currentText : "Best available"
                            onCurrentIndexChanged: {
                                if (currentIndex >= 0 && unifiedDownloadVM.formats.length > 0 && unifiedDownloadVM.formats[currentIndex])
                                    unifiedDownloadVM.selectedFormat = unifiedDownloadVM.formats[currentIndex].id
                            }
                        }
                    }
                }

                Row {
                    spacing: LayoutMetrics.spacing.sm
                    Button { buttonText: "Download"; primary: true; enabled: !unifiedDownloadVM.downloading; onPressed: unifiedDownloadVM.startDownload() }
                    Button { buttonText: "Cancel"; enabled: unifiedDownloadVM.downloading; onPressed: unifiedDownloadVM.cancel() }
                }

                ProgressBar {
                    width: parent.width
                    value: unifiedDownloadVM.progress
                    visible: unifiedDownloadVM.downloading || unifiedDownloadVM.progress >= 1.0
                }

                Row {
                    spacing: LayoutMetrics.spacing.lg
                    visible: unifiedDownloadVM.downloading || unifiedDownloadVM.size !== "" || unifiedDownloadVM.speed !== ""
                    Label {
    bold: false
                        text: "Size: " + unifiedDownloadVM.size
                        textColor: Theme.textColor
                        pixelSize: Typography.h6
                        visible: unifiedDownloadVM.size !== ""
                    }
                    Label {
    bold: false
                        text: "Speed: " + unifiedDownloadVM.speed
                        textColor: Theme.textColor
                        pixelSize: Typography.h6
                        visible: unifiedDownloadVM.speed !== ""
                    }
                    Label {
    bold: false
                        text: "ETA: " + unifiedDownloadVM.eta
                        textColor: Theme.textColor
                        pixelSize: Typography.h6
                        visible: unifiedDownloadVM.eta !== ""
                    }
                }

                Label {
    bold: false
                    text: unifiedDownloadVM.status
                    textColor: Theme.textColor
                    pixelSize: Typography.h6
                    elide: Text.ElideRight
                    width: parent.width
                }
                Label {
    bold: false
                    text: unifiedDownloadVM.error
                    textColor: "red"
                    pixelSize: Typography.h6
                    visible: unifiedDownloadVM.error !== ""
                }
                Item { width: 1; height: LayoutMetrics.spacing.xl }
            }

            FolderDialog {
                id: unifFolderDialog
                onAccepted: unifiedDownloadVM.destination = selectedFolder.toString().replace("file://", "")
            }
        }
    }
}
