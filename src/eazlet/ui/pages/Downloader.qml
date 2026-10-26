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

            LineEdit {
                id: urlInput
                width: parent.width
                placeholderText: "URL"
                text: downloadVM.url
                onTextChanged: downloadVM.url = text
            }

            Row {
                spacing: LayoutMetrics.spacing.md
                Button { buttonText: "Paste"; onPressed: downloadVM.pasteFromClipboard() }
                Button { buttonText: "Destination"; onPressed: folderDialog.open() }
                Text { text: downloadVM.destination; color: Theme.textColor; elide: Text.ElideMiddle; width: parent.width * 0.5 }
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
                Text { text: "Size: " + downloadVM.size; color: Theme.textColor }
                Text { text: "Speed: " + downloadVM.speed; color: Theme.textColor }
                Text { text: "ETA: " + downloadVM.eta; color: Theme.textColor }
            }

            Text { text: downloadVM.status; color: Theme.textColor; elide: Text.ElideRight; width: parent.width }
            Text { text: downloadVM.error; color: "red"; visible: downloadVM.error !== "" }

            Text { text: "Queue (" + downloadVM.queue.length + ")"; color: Theme.textColor; font.bold: true }
            Row {
                spacing: LayoutMetrics.spacing.sm
                Button { buttonText: "Clear Queue"; onPressed: downloadVM.clearQueue() }
            }

            Text { text: "History"; color: Theme.textColor; font.bold: true }
        }
    }

    FolderDialog {
        id: folderDialog
        onAccepted: downloadVM.destination = selectedFolder.toString().replace("file://", "")
    }
}
