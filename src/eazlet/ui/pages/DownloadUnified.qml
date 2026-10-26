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

        Column {
            anchors.fill: parent
            anchors.margins: LayoutMetrics.spacing.lg
            spacing: LayoutMetrics.spacing.lg

            Text {
                text: unifiedDownloadVM.mode === "social" ? "Social Media Download" : "Direct Download"
                color: Theme.textColor
                font.bold: true
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
                Text { text: unifiedDownloadVM.destination; color: Theme.textColor; elide: Text.ElideMiddle; width: parent.width * 0.3 }
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
                    Text { text: "Format:"; color: Theme.textColor; anchors.verticalCenter: parent.verticalCenter }
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
                Text { text: "Size: " + unifiedDownloadVM.size; color: Theme.textColor; visible: unifiedDownloadVM.size !== "" }
                Text { text: "Speed: " + unifiedDownloadVM.speed; color: Theme.textColor; visible: unifiedDownloadVM.speed !== "" }
                Text { text: "ETA: " + unifiedDownloadVM.eta; color: Theme.textColor; visible: unifiedDownloadVM.eta !== "" }
            }

            Text { text: unifiedDownloadVM.status; color: Theme.textColor; elide: Text.ElideRight; width: parent.width }
            Text { text: unifiedDownloadVM.error; color: "red"; visible: unifiedDownloadVM.error !== "" }
        }
    }

    FolderDialog {
        id: unifFolderDialog
        onAccepted: unifiedDownloadVM.destination = selectedFolder.toString().replace("file://", "")
    }
}
