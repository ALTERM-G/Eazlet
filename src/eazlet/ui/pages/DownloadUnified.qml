import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import components

Item {
    id: page
    Layout.fillWidth: true
    Layout.fillHeight: true

    function processAction() {
        if (!unifiedDownloadVM.downloading)
            unifiedDownloadVM.startDownload()
    }

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
            contentHeight: contentColumn.implicitHeight
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
                        iconPath: SVGLibrary.paste
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
                        Switch {
                            text: "Audio only (MP3)"
                            checked: unifiedDownloadVM.audioOnly
                            onCheckedChanged: unifiedDownloadVM.audioOnly = checked
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
                            scrollablePopup: true
                            maxVisibleItems: 10
                            onCurrentIndexChanged: {
                                if (currentIndex >= 0 && unifiedDownloadVM.formats.length > 0 && unifiedDownloadVM.formats[currentIndex])
                                    unifiedDownloadVM.selectedFormat = unifiedDownloadVM.formats[currentIndex].id
                            }
                        }
                    }
                }

                Row {
                    spacing: LayoutMetrics.spacing.sm
                    Button { buttonText: "Download"; primary: true; isometric: true; heightMultiplier: 1.3; enabled: !unifiedDownloadVM.downloading; onPressed: unifiedDownloadVM.startDownload() }
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

                Row {
                    width: parent.width
                    spacing: LayoutMetrics.spacing.sm
                    visible: unifiedDownloadVM.status !== ""
                    SVGObject {
                        anchors.verticalCenter: parent.verticalCenter
                        width: LayoutMetrics.size.iconS
                        height: LayoutMetrics.size.iconS
                        path: SVGLibrary.checkMark
                        color: Theme.textColor
                        visible: unifiedDownloadVM.status === "Done"
                    }
                    Label {
                        bold: false
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(0, parent.width - (unifiedDownloadVM.status === "Done" ? LayoutMetrics.size.iconS + parent.spacing : 0))
                        text: unifiedDownloadVM.status
                        textColor: Theme.textColor
                        pixelSize: Typography.h6
                        elide: Text.ElideRight
                    }
                }
                Row {
                    width: parent.width
                    spacing: LayoutMetrics.spacing.sm
                    visible: unifiedDownloadVM.error !== ""
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
                        text: unifiedDownloadVM.error
                        textColor: "red"
                        pixelSize: Typography.h6
                        wrapMode: Text.WordWrap
                    }
                }
                Item { width: 1; height: LayoutMetrics.spacing.xl }
            }

            FolderDialog {
                id: unifFolderDialog
                onAccepted: controller.save_download_dir(selectedFolder.toString())
            }
        }
    }
}
