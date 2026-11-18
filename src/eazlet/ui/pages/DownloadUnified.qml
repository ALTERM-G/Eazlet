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

    function syncDownloader() {
        var target = unifiedDownloadVM.autoDetect ? "auto" : unifiedDownloadVM.downloader
        for (var i = 0; i < unifiedDownloadVM.downloaders.length; i++) {
            if (unifiedDownloadVM.downloaders[i].id === target) {
                downloaderCombo.currentIndex = i
                return
            }
        }
        downloaderCombo.currentIndex = 0
    }

    Component.onCompleted: syncDownloader()

    Connections {
        target: unifiedDownloadVM
        function onDownloaderChanged() { page.syncDownloader() }
        function onAutoDetectChanged() { page.syncDownloader() }
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
            acceptedButtons: Qt.NoButton

            anchors.fill: parent
            anchors.margins: LayoutMetrics.spacing.lg
            contentHeight: contentColumn.implicitHeight
            clip: true
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds

            WheelScrollArea {
                target: flick
            }

            Column {
                id: contentColumn
                width: parent.width
                x: Math.max(0, (parent.width - width) / 2)
                spacing: LayoutMetrics.spacing.md

                Title {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: unifiedDownloadVM.title
                    textColor: Theme.textColor
                    pixelSize: Typography.h2
                }

                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    bold: false
                    text: unifiedDownloadVM.hint
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
                        placeholderText: "Paste a link here (video, gallery, Spotify, Bandcamp, Khinsider, or direct file URL)"
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

                Column {
                    width: parent.width
                    spacing: LayoutMetrics.spacing.xxs

                    Label {
                        bold: false
                        text: "Downloader"
                        textColor: Theme.textColor
                        pixelSize: Typography.h6
                    }

                    ComboBox {
                        id: downloaderCombo
                        width: parent.width
                        model: unifiedDownloadVM.downloaders
                        textRole: "label"
                        valueRole: "id"
                        onActivated: unifiedDownloadVM.setDownloader(currentValue)
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: LayoutMetrics.spacing.sm
                    Button { buttonText: "Open Folder"; onPressed: unifiedDownloadVM.openDestination() }
                }

                Column {
                    width: parent.width
                    visible: unifiedDownloadVM.supportsFormats
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

                    Column {
                        width: parent.width
                        spacing: LayoutMetrics.spacing.xxs
                        visible: !unifiedDownloadVM.audioOnly

                        Label {
                            bold: false
                            text: "Format"
                            textColor: Theme.textColor
                            pixelSize: Typography.h6
                        }

                        ComboBox {
                            width: parent.width
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
                    width: Math.min(parent.width * 0.8, LayoutMetrics.unit * 60)
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
