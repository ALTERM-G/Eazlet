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

            Row {
                spacing: LayoutMetrics.spacing.sm
                Text { text: "Platforms: YouTube, TikTok, Instagram, Facebook, X, Reddit, Vimeo, Twitch"; color: Theme.textColor; elide: Text.ElideRight; width: parent.width }
            }

            LineEdit {
                id: smUrlInput
                width: parent.width
                placeholderText: "Social media URL (YouTube, TikTok, Instagram, Facebook, X, etc.)"
                text: socialMediaVM.url
                onTextChanged: socialMediaVM.url = text
            }

            Row {
                spacing: LayoutMetrics.spacing.md
                Button { buttonText: "Fetch Formats"; onPressed: socialMediaVM.fetchFormats() }
                Button { buttonText: "Destination"; onPressed: smFolderDialog.open() }
                Text { text: socialMediaVM.destination; color: Theme.textColor; elide: Text.ElideMiddle; width: parent.width * 0.4 }
                Button { buttonText: "Open Folder"; onPressed: socialMediaVM.openDestination() }
            }

            Row {
                spacing: LayoutMetrics.spacing.md
                CheckBox {
                    text: "Audio only (MP3)"
                    checked: socialMediaVM.audioOnly
                    onToggled: socialMediaVM.audioOnly = checked
                }
            }

            ComboBox {
                width: parent.width
                model: socialMediaVM.formats.length > 0 ? socialMediaVM.formats : []
                textRole: "label"
                displayText: socialMediaVM.formats.length > 0 ? currentText : "Select format (optional)"
                onCurrentIndexChanged: {
                    if (currentIndex >= 0 && socialMediaVM.formats.length > 0 && socialMediaVM.formats[currentIndex])
                        socialMediaVM.selectedFormat = socialMediaVM.formats[currentIndex].id
                }
            }

            Row {
                spacing: LayoutMetrics.spacing.md
                Button { buttonText: "Download"; primary: true; enabled: !socialMediaVM.downloading; onPressed: socialMediaVM.startDownload() }
                Button { buttonText: "Cancel"; enabled: socialMediaVM.downloading; onPressed: socialMediaVM.cancel() }
            }

            ProgressBar {
                width: parent.width
                value: socialMediaVM.progress
                visible: socialMediaVM.downloading || socialMediaVM.progress >= 1.0
            }

            Text { text: socialMediaVM.status; color: Theme.textColor; elide: Text.ElideRight; width: parent.width }
            Text { text: socialMediaVM.error; color: "red"; visible: socialMediaVM.error !== "" }
        }
    }

    FolderDialog {
        id: smFolderDialog
        onAccepted: socialMediaVM.destination = selectedFolder.toString().replace("file://", "")
    }
}
