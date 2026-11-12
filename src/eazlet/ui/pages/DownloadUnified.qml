import QtQuick
import QtQuick.Controls
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

    // Keeps the form readable and centred on wide windows without letting it
    // get cramped when the window is small.
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
                width: Math.max(0, parent.width - LayoutMetrics.unit * 1.6)
                x: Math.max(0, (parent.width - width) / 2)
                spacing: LayoutMetrics.spacing.lg

                Title {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: unifiedDownloadVM.mode === "social" ? "Social Media Download" : "Direct Download"
                    textColor: Theme.textColor
                    pixelSize: Typography.h2
                }

                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    bold: false
                    text: unifiedDownloadVM.mode === "social"
                        ? "Paste a video link from a supported site, choose a format, then download."
                        : "Paste a direct file link, choose where to save it, then download."
                    textColor: Theme.dividerColor
                    pixelSize: Typography.h6
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    width: parent.width
                    height: LayoutMetrics.spacing.xxs
                    color: Theme.dividerColor
                }

                Row {
                    width: parent.width
                    spacing: LayoutMetrics.spacing.sm
                    LineEdit {
                        id: unifiedUrl
                        width: Math.max(0, parent.width - pasteBtn.width - parent.spacing)
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

                PathPicker {
                    label: Lang.labels.downloadFolder
                    path: unifiedDownloadVM.destination
                    defaultPath: controller.get_downloader_default_dir()
                    onPathAccepted: function(newPath) {
                        controller.save_downloader_dir(newPath)
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: LayoutMetrics.spacing.sm
                    Button { buttonText: "Open Folder"; onPressed: unifiedDownloadVM.openDestination() }
                    Button { buttonText: "Force File"; onPressed: unifiedDownloadVM.forceDirect() }
                    Button { buttonText: "Force Social"; onPressed: unifiedDownloadVM.forceSocial() }
                }

                Column {
                    width: parent.width
                    visible: unifiedDownloadVM.mode === "social"
                    spacing: LayoutMetrics.spacing.md

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: LayoutMetrics.spacing.md
                        Button { buttonText: "Load Formats"; onPressed: unifiedDownloadVM.fetchFormats() }
                        Switch {
                            text: "Audio only (MP3)"
                            checked: unifiedDownloadVM.audioOnly
                            onCheckedChanged: unifiedDownloadVM.audioOnly = checked
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: LayoutMetrics.spacing.md
                        visible: !unifiedDownloadVM.audioOnly
                        Label {
                            id: formatLabel
                            bold: false
                            text: "Format:"
                            textColor: Theme.textColor
                            pixelSize: Typography.h6
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        ComboBox {
                            width: Math.max(0, parent.width - formatLabel.width - parent.spacing)
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

                Rectangle {
                    width: parent.width
                    height: LayoutMetrics.spacing.xxs
                    color: Theme.dividerColor
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: LayoutMetrics.spacing.md

                    Button {
                        buttonText: "Download"
                        primary: true
                        isometric: true
                        heightMultiplier: 1.3
                        visible: !unifiedDownloadVM.downloading
                        onPressed: unifiedDownloadVM.startDownload()
                    }

                    Button {
                        buttonText: "Cancel"
                        visible: unifiedDownloadVM.downloading
                        onPressed: unifiedDownloadVM.cancel()
                    }
                }

                ProgressBar {
                    width: Math.min(parent.width, LayoutMetrics.unit * 50)
                    anchors.horizontalCenter: parent.horizontalCenter
                    value: unifiedDownloadVM.progress
                    visible: unifiedDownloadVM.downloading || unifiedDownloadVM.progress >= 1.0
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
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
        }
    }
}
