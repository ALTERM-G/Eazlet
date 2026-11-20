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
        var model = downloaderCombo.model
        for (var i = 0; i < model.length; i++) {
            if (model[i].id === target) {
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
                    text: {
                        switch (unifiedDownloadVM.downloader) {
                        case "direct": return Lang.pages.downloadUnified.directTitle
                        case "khinsider-dl": return Lang.pages.downloadUnified.tools.khid
                        case "spotdl": return Lang.pages.downloadUnified.tools.spotdl
                        case "bandcamp-dl": return Lang.pages.downloadUnified.tools.bandcamp
                        case "yt-dlp": return Lang.pages.downloadUnified.tools.ytdlp
                        case "gallery-dl": return Lang.pages.downloadUnified.tools.gallery
                        default: return unifiedDownloadVM.title
                        }
                    }
                    textColor: Theme.textColor
                    pixelSize: Typography.h2
                }

                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    bold: false
                    text: {
                        switch (unifiedDownloadVM.downloader) {
                        case "direct": return Lang.pages.downloadUnified.directHint
                        case "khinsider-dl": return Lang.pages.downloadUnified.hints.khid
                        case "spotdl": return Lang.pages.downloadUnified.hints.spotdl
                        case "bandcamp-dl": return Lang.pages.downloadUnified.hints.bandcamp
                        case "yt-dlp": return Lang.pages.downloadUnified.hints.ytdlp
                        case "gallery-dl": return Lang.pages.downloadUnified.hints.gallery
                        default: return unifiedDownloadVM.hint
                        }
                    }
                    textColor: Theme.dividerColor
                    pixelSize: Typography.h6
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    width: parent.width
                    height: LayoutMetrics.divider.s
                    color: Theme.dividerColor
                }

                Row {
                    width: parent.width
                    spacing: LayoutMetrics.spacing.sm
                    LineEdit {
                        id: unifiedUrl
                        width: Math.max(0, parent.width - pasteBtn.width - parent.spacing)
                        placeholderText: Lang.pages.downloadUnified.urlPlaceholder
                        text: unifiedDownloadVM.url
                        onTextChanged: unifiedDownloadVM.url = text
                    }
                    Button {
                        id: pasteBtn
                        buttonText: Lang.common.paste
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
                        anchors.horizontalCenter: parent.horizontalCenter
                        bold: false
                        text: Lang.pages.downloadUnified.downloaderLabel
                        textColor: Theme.textColor
                        pixelSize: Typography.h6
                    }

                    ComboBox {
                        id: downloaderCombo
                        width: parent.width
                        model: [
                            { id: "auto", label: Lang.pages.downloadUnified.autoByUrl },
                            { id: "direct", label: Lang.pages.downloadUnified.directFile },
                            { id: "khinsider-dl", label: Lang.pages.downloadUnified.tools.khid },
                            { id: "spotdl", label: Lang.pages.downloadUnified.tools.spotdl },
                            { id: "bandcamp-dl", label: Lang.pages.downloadUnified.tools.bandcamp },
                            { id: "yt-dlp", label: Lang.pages.downloadUnified.tools.ytdlp },
                            { id: "gallery-dl", label: Lang.pages.downloadUnified.tools.gallery }
                        ]
                        textRole: "label"
                        valueRole: "id"
                        onActivated: unifiedDownloadVM.setDownloader(currentValue)
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: LayoutMetrics.spacing.sm
                    Button { buttonText: Lang.common.openFolder; onPressed: unifiedDownloadVM.openDestination() }
                }

                Column {
                    width: parent.width
                    visible: unifiedDownloadVM.supportsFormats
                    spacing: LayoutMetrics.spacing.md

                    RowLayout {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: LayoutMetrics.spacing.md
                        Button {
                            Layout.alignment: Qt.AlignVCenter
                            buttonText: Lang.pages.downloadUnified.loadFormats
                            onPressed: unifiedDownloadVM.fetchFormats()
                        }
                        Switch {
                            Layout.alignment: Qt.AlignVCenter
                            text: Lang.pages.downloadUnified.audioOnlyMp3
                            checked: unifiedDownloadVM.audioOnly
                            onCheckedChanged: unifiedDownloadVM.audioOnly = checked
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: LayoutMetrics.spacing.xxs
                        visible: !unifiedDownloadVM.audioOnly

                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            bold: false
                            text: Lang.common.format
                            textColor: Theme.textColor
                            pixelSize: Typography.h6
                        }

                        ComboBox {
                            width: parent.width
                            model: unifiedDownloadVM.formats.length > 0 ? unifiedDownloadVM.formats : []
                            textRole: "label"
                            displayText: unifiedDownloadVM.formats.length > 0 ? currentText : Lang.common.bestAvailable
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
                    height: LayoutMetrics.divider.s
                    color: Theme.dividerColor
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: LayoutMetrics.spacing.md

                    Button {
                        buttonText: Lang.common.download
                        primary: true
                        isometric: true
                        heightMultiplier: 1.3
                        visible: !unifiedDownloadVM.downloading
                        onPressed: unifiedDownloadVM.startDownload()
                    }

                    Button {
                        buttonText: Lang.common.cancel
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
                        text: Lang.pages.downloadUnified.size + " " + unifiedDownloadVM.size
                        textColor: Theme.textColor
                        pixelSize: Typography.h6
                        visible: unifiedDownloadVM.size !== ""
                    }
                    Label {
                        bold: false
                        text: Lang.pages.downloadUnified.speed + " " + unifiedDownloadVM.speed
                        textColor: Theme.textColor
                        pixelSize: Typography.h6
                        visible: unifiedDownloadVM.speed !== ""
                    }
                    Label {
                        bold: false
                        text: Lang.pages.downloadUnified.eta + " " + unifiedDownloadVM.eta
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
                        visible: unifiedDownloadVM.status === Lang.common.done || unifiedDownloadVM.status === "Done"
                    }
                    Label {
                        bold: false
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(0, parent.width - ((unifiedDownloadVM.status === Lang.common.done || unifiedDownloadVM.status === "Done") ? LayoutMetrics.size.iconS + parent.spacing : 0))
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
