import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import components

Item {
    id: page
    Layout.fillWidth: true
    Layout.fillHeight: true

    function processAction() {
        if (!archiveVM.compressing && !archiveVM.extracting && archiveVM.files.length > 0)
            archiveVM.compress()
    }

    function fileBadge(item) {
        if (!item || !item.name)
            return "?"
        if (item.isDir)
            return "DIR"
        var dot = item.name.lastIndexOf(".")
        if (dot <= 0 || dot === item.name.length - 1)
            return "FILE"
        var ext = item.name.substring(dot + 1).toUpperCase()
        return ext.length > 4 ? ext.substring(0, 4) : ext
    }

    function parentPath(path) {
        if (!path)
            return ""
        var idx = path.lastIndexOf("/")
        return idx > 0 ? path.substring(0, idx) : path
    }

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
            contentHeight: archColumn.implicitHeight
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
                id: archColumn
                width: parent.width
                x: Math.max(0, (parent.width - width) / 2)
                spacing: LayoutMetrics.spacing.md

                Title {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Lang.pages.archive.title
                    textColor: Theme.textColor
                    pixelSize: Typography.h2
                }

                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    bold: false
                    text: Lang.pages.archive.subtitle
                    textColor: Theme.dividerColor
                    pixelSize: Typography.h6
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    width: parent.width
                    height: LayoutMetrics.spacing.xxs
                    color: Theme.dividerColor
                }

                DropZone {
                    width: parent.width
                    title: Lang.pages.archive.dropTitle
                    description: Lang.pages.archive.dropDescription
                    hint: Lang.pages.archive.dropHint
                    onClicked: fileDialog.open()
                    onFilesDropped: function(urls) {
                        archiveVM.addFiles(urls)
                    }
                }

                FileDialog {
                    id: fileDialog
                    title: Lang.pages.archive.selectDialogTitle
                    fileMode: FileDialog.OpenFiles
                    onAccepted: {
                        var files = selectedFiles && selectedFiles.length > 0
                                ? selectedFiles
                                : (selectedFile ? [selectedFile] : [])
                        archiveVM.addFiles(files)
                    }
                }

                Rectangle {
                    id: filesCard
                    width: parent.width
                    visible: archiveVM.files.length > 0
                    height: visible ? filesColumn.implicitHeight
                                      + LayoutMetrics.spacing.md * 2 : 0
                    radius: LayoutMetrics.radius.m
                    color: Theme.inputBackgroundColor
                    border.color: Theme.borderColor
                    border.width: LayoutMetrics.border.l
                    clip: true

                    Column {
                        id: filesColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: LayoutMetrics.spacing.md
                        spacing: LayoutMetrics.spacing.sm

                        RowLayout {
                            width: parent.width
                            spacing: LayoutMetrics.spacing.sm

                            Label {
                                text: Lang.pages.archive.files
                                textColor: Theme.textColor
                                pixelSize: Typography.h5
                            }

                            Label {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                bold: false
                                text: archiveVM.files.length + " "
                                      + (archiveVM.files.length === 1
                                         ? Lang.pages.archive.itemSingular
                                         : Lang.pages.archive.itemPlural)
                                textColor: Theme.dividerColor
                                pixelSize: Typography.h6
                                elide: Text.ElideRight
                            }

                            IconButton {
                                id: clearFilesButton
                                Layout.alignment: Qt.AlignVCenter
                                buttonWidth: LayoutMetrics.size.iconS
                                buttonHeight: LayoutMetrics.size.iconS
                                iconPath: SVGLibrary.eraser
                                onPressed: archiveVM.clearFiles()

                                ToolTip {
                                    text: Lang.pages.archive.clearAllFilesTooltip
                                    visible: clearFilesButton.hovered
                                    delay: 600
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: LayoutMetrics.spacing.xxs
                            color: Theme.dividerColor
                        }

                        ListView {
                            id: filesList
                            readonly property real rowHeight: LayoutMetrics.unit * 6.25

                            width: parent.width
                            height: Math.min(archiveVM.files.length * rowHeight,
                                             LayoutMetrics.unit * 25)
                            model: archiveVM.files
                            clip: true
                            interactive: contentHeight > height
                            boundsBehavior: Flickable.StopAtBounds
                            ScrollBar.vertical: AppScrollBar {}

                            delegate: Item {
                                id: fileRow

                                readonly property bool hovered: rowMouse.containsMouse

                                width: ListView.view.width
                                height: filesList.rowHeight

                                MouseArea {
                                    id: rowMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: LayoutMetrics.spacing.xxs
                                    radius: LayoutMetrics.radius.s
                                    color: fileRow.hovered
                                           ? Theme.backgroundColor : "transparent"

                                    Behavior on color {
                                        enabled: LayoutMetrics.animationsEnabled
                                        ColorAnimation { duration: 120 }
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: LayoutMetrics.spacing.sm
                                    anchors.rightMargin: LayoutMetrics.spacing.md
                                    spacing: LayoutMetrics.spacing.sm

                                    Rectangle {
                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.preferredWidth: LayoutMetrics.unit * 4.2
                                        Layout.preferredHeight: LayoutMetrics.unit * 3.4
                                        radius: LayoutMetrics.radius.s
                                        color: Theme.backgroundColor
                                        border.color: Theme.borderColor
                                        border.width: LayoutMetrics.border.m

                                        Label {
                                            anchors.centerIn: parent
                                            bold: false
                                            text: page.fileBadge(modelData)
                                            textColor: modelData.isDir
                                                       ? Theme.themeColor : Theme.dividerColor
                                            pixelSize: Typography.caption
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        spacing: 0

                                        Label {
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 0
                                            bold: false
                                            text: modelData.name
                                            textColor: Theme.textColor
                                            pixelSize: Typography.h5
                                            elide: Text.ElideMiddle
                                        }

                                        Label {
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 0
                                            bold: false
                                            text: page.parentPath(modelData.path)
                                            textColor: Theme.dividerColor
                                            pixelSize: Typography.caption
                                            elide: Text.ElideMiddle
                                        }
                                    }

                                    IconButton {
                                        id: removeFileButton
                                        Layout.alignment: Qt.AlignVCenter
                                        buttonWidth: LayoutMetrics.size.iconS
                                        buttonHeight: LayoutMetrics.size.iconS
                                        iconPath: SVGLibrary.cross
                                        onPressed: archiveVM.removeFile(index)

                                        ToolTip {
                                            text: Lang.pages.archive.removeTooltip
                                            visible: removeFileButton.hovered
                                            delay: 600
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: LayoutMetrics.spacing.lg

                    Column {
                        spacing: LayoutMetrics.spacing.xxs

                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            bold: false
                            text: Lang.pages.archive.format
                            textColor: Theme.textColor
                            pixelSize: Typography.h6
                        }
                        ComboBox {
                            width: 150
                            model: ["zip", "tar.gz", "tar.xz", "tar.bz2"]
                            scrollablePopup: true
                            maxVisibleItems: 10
                            currentIndex: {
                                var idx = model.indexOf(archiveVM.format)
                                return idx >= 0 ? idx : 0
                            }
                            onCurrentTextChanged: {
                                if (currentText && currentText !== archiveVM.format) {
                                    archiveVM.format = currentText
                                }
                            }
                        }
                    }

                    Column {
                        spacing: LayoutMetrics.spacing.xxs
                        visible: archiveVM.format === "zip"

                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            bold: false
                            text: Lang.pages.archive.compression
                            textColor: Theme.textColor
                            pixelSize: Typography.h6
                        }
                        SpinBox {
                            from: 1
                            to: 9
                            stepSize: 1
                            value: archiveVM.compressionLevel
                            onValueChanged: archiveVM.compressionLevel = value
                        }
                    }
                }

                PathPicker {
                    label: Lang.labels.outputFolder
                    path: archiveVM.outputDir
                    defaultPath: controller.get_archive_default_dir()
                    onPathAccepted: function(newPath) {
                        controller.save_archive_dir(newPath)
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: LayoutMetrics.spacing.sm
                    Button { buttonText: Lang.pages.archive.openFolder; onPressed: archiveVM.openOutputDir() }
                }

                Rectangle {
                    width: parent.width
                    height: LayoutMetrics.spacing.xxs
                    color: Theme.dividerColor
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: LayoutMetrics.spacing.sm
                    Button { buttonText: Lang.pages.archive.compress; primary: true; isometric: true; heightMultiplier: 1.3; enabled: !archiveVM.compressing && !archiveVM.extracting && archiveVM.files.length > 0; onPressed: archiveVM.compress() }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: LayoutMetrics.spacing.sm
                    Label {
                        bold: false
                        text: Lang.pages.archive.extractArchive
                        textColor: Theme.textColor
                        pixelSize: Typography.h6
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Button { buttonText: Lang.pages.archive.extractSelected; enabled: !archiveVM.extracting && archiveVM.files.length === 1; onPressed: archiveVM.extract(archiveVM.files[0].path) }
                }

                ProgressBar {
                    width: Math.min(parent.width * 0.8, LayoutMetrics.unit * 60)
                    anchors.horizontalCenter: parent.horizontalCenter
                    value: archiveVM.progress
                    visible: archiveVM.compressing || archiveVM.extracting || archiveVM.progress >= 1.0
                }

                Row {
                    spacing: LayoutMetrics.spacing.sm
                    visible: archiveVM.status !== ""
                    SVGObject {
                        anchors.verticalCenter: parent.verticalCenter
                        width: LayoutMetrics.size.iconS
                        height: LayoutMetrics.size.iconS
                        path: SVGLibrary.checkMark
                        color: Theme.textColor
                        visible: archiveVM.status === Lang.common.done || archiveVM.status === "Done"
                    }
                    Label {
                        bold: false
                        anchors.verticalCenter: parent.verticalCenter
                        text: archiveVM.status
                        textColor: Theme.textColor
                        pixelSize: Typography.h6
                    }
                }
                Row {
                    spacing: LayoutMetrics.spacing.sm
                    visible: archiveVM.error !== ""
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
                        text: archiveVM.error
                        textColor: "red"
                        pixelSize: Typography.h6
                    }
                }
                Item { width: 1; height: LayoutMetrics.spacing.xl }
            }
        }
    }
}
