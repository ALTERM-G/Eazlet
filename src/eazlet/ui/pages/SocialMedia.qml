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

            Title {
                text: "Social Media Download"
                textColor: Theme.textColor
                pixelSize: Typography.h2
            }

            Row {
                spacing: LayoutMetrics.spacing.sm
                Label {
                    bold: false
                    text: "Platforms: YouTube, TikTok, Instagram, Facebook, X, Reddit, Vimeo, Twitch"
                    textColor: Theme.textColor
                    pixelSize: Typography.h6
                    elide: Text.ElideRight
                    width: parent.width
                }
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
                Label {
                    bold: false
                    text: socialMediaVM.destination
                    textColor: Theme.textColor
                    pixelSize: Typography.h6
                    elide: Text.ElideMiddle
                    width: parent.width * 0.4
                }
                Button { buttonText: "Open Folder"; onPressed: socialMediaVM.openDestination() }
            }

            Row {
                spacing: LayoutMetrics.spacing.md
                Switch {
                    text: "Audio only (MP3)"
                    checked: socialMediaVM.audioOnly
                    onCheckedChanged: socialMediaVM.audioOnly = checked
                }
            }

            ComboBox {
                width: parent.width
                model: socialMediaVM.formats.length > 0 ? socialMediaVM.formats : []
                textRole: "label"
                displayText: socialMediaVM.formats.length > 0 ? currentText : "Select format (optional)"
                scrollablePopup: true
                maxVisibleItems: 10
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

            Row {
                width: parent.width
                spacing: LayoutMetrics.spacing.sm
                visible: socialMediaVM.status !== ""
                SVGObject {
                    anchors.verticalCenter: parent.verticalCenter
                    width: LayoutMetrics.size.iconS
                    height: LayoutMetrics.size.iconS
                    path: SVGLibrary.checkMark
                    color: Theme.textColor
                    visible: socialMediaVM.status === "Done"
                }
                Label {
                    bold: false
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, parent.width - (socialMediaVM.status === "Done" ? LayoutMetrics.size.iconS + parent.spacing : 0))
                    text: socialMediaVM.status
                    textColor: Theme.textColor
                    pixelSize: Typography.h6
                    elide: Text.ElideRight
                }
            }
            Row {
                width: parent.width
                spacing: LayoutMetrics.spacing.sm
                visible: socialMediaVM.error !== ""
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
                    text: socialMediaVM.error
                    textColor: "red"
                    pixelSize: Typography.h6
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    FolderDialog {
        id: smFolderDialog
        onAccepted: socialMediaVM.destination = selectedFolder.toString().replace("file://", "")
    }
}
