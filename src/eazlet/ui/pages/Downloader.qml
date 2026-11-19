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
                text: Lang.pages.downloader.title
                textColor: Theme.textColor
                pixelSize: Typography.h2
            }

            LineEdit {
                id: urlInput
                width: parent.width
                placeholderText: Lang.pages.downloader.urlPlaceholder
                text: downloadVM.url
                onTextChanged: downloadVM.url = text
            }

            Row {
                spacing: LayoutMetrics.spacing.md
                Button { buttonText: Lang.common.paste; iconPath: SVGLibrary.paste; onPressed: downloadVM.pasteFromClipboard() }
                Button { buttonText: Lang.pages.downloader.destination; onPressed: folderDialog.open() }
                Label {
                    bold: false
                    text: downloadVM.destination
                    textColor: Theme.textColor
                    pixelSize: Typography.h6
                    elide: Text.ElideMiddle
                    width: parent.width * 0.5
                }
                Button { buttonText: Lang.common.openFolder; onPressed: downloadVM.openDestination() }
            }

            Row {
                spacing: LayoutMetrics.spacing.md
                Button { buttonText: Lang.common.download; primary: true; isometric: true; heightMultiplier: 1.3; enabled: !downloadVM.downloading; onPressed: downloadVM.startDownload() }
                Button { buttonText: Lang.pages.downloader.addToQueue; enabled: !downloadVM.downloading; onPressed: downloadVM.addToQueue() }
                Button { buttonText: Lang.pages.downloader.pause; enabled: downloadVM.downloading; onPressed: downloadVM.pause() }
                Button { buttonText: Lang.pages.downloader.resume; onPressed: downloadVM.resume() }
                Button { buttonText: Lang.common.cancel; enabled: downloadVM.downloading; onPressed: downloadVM.cancel() }
                Button { buttonText: Lang.pages.downloader.retry; onPressed: downloadVM.retry() }
            }

            ProgressBar {
                width: parent.width
                value: downloadVM.progress
            }

            Row {
                spacing: LayoutMetrics.spacing.lg
                Label {
                    bold: false
                    text: Lang.pages.downloader.size + " " + downloadVM.size
                    textColor: Theme.textColor
                    pixelSize: Typography.h6
                }
                Label {
                    bold: false
                    text: Lang.pages.downloader.speed + " " + downloadVM.speed
                    textColor: Theme.textColor
                    pixelSize: Typography.h6
                }
                Label {
                    bold: false
                    text: Lang.pages.downloader.eta + " " + downloadVM.eta
                    textColor: Theme.textColor
                    pixelSize: Typography.h6
                }
            }

            Row {
                width: parent.width
                spacing: LayoutMetrics.spacing.sm
                visible: downloadVM.status !== ""
                SVGObject {
                    anchors.verticalCenter: parent.verticalCenter
                    width: LayoutMetrics.size.iconS
                    height: LayoutMetrics.size.iconS
                    path: SVGLibrary.checkMark
                    color: Theme.textColor
                    visible: downloadVM.status === Lang.common.done || downloadVM.status === "Done"
                }
                Label {
                    bold: false
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, parent.width - ((downloadVM.status === Lang.common.done || downloadVM.status === "Done") ? LayoutMetrics.size.iconS + parent.spacing : 0))
                    text: downloadVM.status
                    textColor: Theme.textColor
                    pixelSize: Typography.h6
                    elide: Text.ElideRight
                }
            }
            Row {
                width: parent.width
                spacing: LayoutMetrics.spacing.sm
                visible: downloadVM.error !== ""
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
                    text: downloadVM.error
                    textColor: "red"
                    pixelSize: Typography.h6
                    wrapMode: Text.WordWrap
                }
            }

            Label {
                text: Lang.pages.downloader.queue + " (" + downloadVM.queue.length + ")"
                textColor: Theme.textColor
                pixelSize: Typography.h4
            }
            Row {
                spacing: LayoutMetrics.spacing.sm
                Button { buttonText: Lang.pages.downloader.clearQueue; onPressed: downloadVM.clearQueue() }
            }

            Label {
                text: Lang.pages.downloader.history
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
