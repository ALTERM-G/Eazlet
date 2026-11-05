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
                text: "Downloader"
                textColor: Theme.textColor
                pixelSize: Typography.h2
            }

            LineEdit {
                id: urlInput
                width: parent.width
                placeholderText: "URL"
                text: downloadVM.url
                onTextChanged: downloadVM.url = text
            }

            Row {
                spacing: LayoutMetrics.spacing.md
                Button { buttonText: "Paste"; iconPath: SVGLibrary.paste; onPressed: downloadVM.pasteFromClipboard() }
                Button { buttonText: "Destination"; onPressed: folderDialog.open() }
                Label {
                    bold: false
                    text: downloadVM.destination
                    textColor: Theme.textColor
                    pixelSize: Typography.h6
                    elide: Text.ElideMiddle
                    width: parent.width * 0.5
                }
                Button { buttonText: "Open Folder"; onPressed: downloadVM.openDestination() }
            }

            Row {
                spacing: LayoutMetrics.spacing.md
                Button { buttonText: "Download"; primary: true; enabled: !downloadVM.downloading; onPressed: downloadVM.startDownload() }
                Button { buttonText: "Add to Queue"; enabled: !downloadVM.downloading; onPressed: downloadVM.addToQueue() }
                Button { buttonText: "Pause"; enabled: downloadVM.downloading; onPressed: downloadVM.pause() }
                Button { buttonText: "Resume"; onPressed: downloadVM.resume() }
                Button { buttonText: "Cancel"; enabled: downloadVM.downloading; onPressed: downloadVM.cancel() }
                Button { buttonText: "Retry"; onPressed: downloadVM.retry() }
            }

            ProgressBar {
                width: parent.width
                value: downloadVM.progress
            }

            Row {
                spacing: LayoutMetrics.spacing.lg
                Label {
                    bold: false
                    text: "Size: " + downloadVM.size
                    textColor: Theme.textColor
                    pixelSize: Typography.h6
                }
                Label {
                    bold: false
                    text: "Speed: " + downloadVM.speed
                    textColor: Theme.textColor
                    pixelSize: Typography.h6
                }
                Label {
                    bold: false
                    text: "ETA: " + downloadVM.eta
                    textColor: Theme.textColor
                    pixelSize: Typography.h6
                }
            }

            Label {
                bold: false
                text: downloadVM.status
                textColor: Theme.textColor
                pixelSize: Typography.h6
                elide: Text.ElideRight
                width: parent.width
            }
            Label {
                bold: false
                text: downloadVM.error
                textColor: "red"
                pixelSize: Typography.h6
                visible: downloadVM.error !== ""
            }

            Label {
                text: "Queue (" + downloadVM.queue.length + ")"
                textColor: Theme.textColor
                pixelSize: Typography.h4
            }
            Row {
                spacing: LayoutMetrics.spacing.sm
                Button { buttonText: "Clear Queue"; onPressed: downloadVM.clearQueue() }
            }

            Label {
                text: "History"
                textColor: Theme.textColor
                pixelSize: Typography.h4
            }
        }
    }

    FolderDialog {
        id: folderDialog
        onAccepted: downloadVM.destination = selectedFolder.toString().replace("file://", "")
    }
}
