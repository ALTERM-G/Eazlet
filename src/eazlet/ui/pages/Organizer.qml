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
        if (!organizerVM.scanning)
            organizerVM.scan()
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
            contentHeight: orgColumn.implicitHeight
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
                id: orgColumn
                width: Math.max(0, parent.width - LayoutMetrics.unit * 1.6)
                x: Math.max(0, (parent.width - width) / 2)
                spacing: LayoutMetrics.spacing.lg

                Title {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Organizer / Sorter"
                    textColor: Theme.textColor
                    pixelSize: Typography.h2
                }

                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    bold: false
                    text: "Scan a folder for duplicate files or rename its files in order."
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
                    spacing: LayoutMetrics.spacing.sm
                    width: parent.width
                    LineEdit {
                        id: orgFolder
                        width: parent.width - browseBtn.width - openBtn.width - LayoutMetrics.spacing.sm * 2
                        text: organizerVM.folder
                        onTextChanged: organizerVM.folder = text
                    }
                    Button { id: browseBtn; buttonText: "Browse"; onPressed: orgFolderDialog.open() }
                    Button { id: openBtn; buttonText: "Open"; onPressed: organizerVM.openFolder() }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: LayoutMetrics.spacing.sm
                    Button { buttonText: "Scan for duplicates"; primary: true; isometric: true; heightMultiplier: 1.3; enabled: !organizerVM.scanning; onPressed: organizerVM.scan() }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: LayoutMetrics.spacing.sm
                    LineEdit {
                        id: renamePattern
                        width: 200
                        placeholderText: "Prefix (e.g. photo)"
                        text: "file"
                    }
                    Button {
                        buttonText: "Rename all files…"
                        enabled: !organizerVM.scanning
                        onPressed: {
                            renameDialog.fileCount = organizerVM.renameTargetCount()
                            renameDialog.open()
                        }
                    }
                }

                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    bold: false
                    text: "Renames every file directly inside the selected folder. Files in subfolders are left untouched."
                    textColor: Theme.dividerColor
                    pixelSize: Typography.h6
                    wrapMode: Text.WordWrap
                }

                ProgressBar {
                    width: Math.min(parent.width, LayoutMetrics.unit * 50)
                    anchors.horizontalCenter: parent.horizontalCenter
                    value: organizerVM.progress
                    visible: organizerVM.scanning
                }

                Row {
                    spacing: LayoutMetrics.spacing.sm
                    visible: organizerVM.status !== ""
                    SVGObject {
                        anchors.verticalCenter: parent.verticalCenter
                        width: LayoutMetrics.size.iconS
                        height: LayoutMetrics.size.iconS
                        path: SVGLibrary.checkMark
                        color: Theme.textColor
                        visible: organizerVM.status === "Done"
                    }
                    Label {
                        bold: false
                        anchors.verticalCenter: parent.verticalCenter
                        text: organizerVM.status
                        textColor: Theme.textColor
                        pixelSize: Typography.h6
                    }
                }
                Row {
                    spacing: LayoutMetrics.spacing.sm
                    visible: organizerVM.error !== ""
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
                        text: organizerVM.error
                        textColor: "red"
                        pixelSize: Typography.h6
                    }
                }

                Label {
                    text: "Duplicate groups: " + organizerVM.duplicates.length
                    textColor: Theme.textColor
                    pixelSize: Typography.h4
                    visible: organizerVM.duplicates.length > 0
                }

                Column {
                    width: parent.width
                    visible: organizerVM.duplicates.length > 0
                    spacing: LayoutMetrics.spacing.md
                    Repeater {
                        model: organizerVM.duplicates
                        delegate: Column {
                            width: parent.width
                            spacing: LayoutMetrics.spacing.xs
                            Label {
                                text: "Group (" + (modelData.files ? modelData.files.length : 0) + " files)"
                                textColor: Theme.textColor
                                pixelSize: Typography.h4
                            }
                            Repeater {
                                model: modelData.files
                                delegate: Label {
                                    bold: false
                                    text: "  " + (modelData.path ? modelData.path : "")
                                    textColor: Theme.textColor
                                    pixelSize: Typography.h6
                                    elide: Text.ElideMiddle
                                    width: parent.width
                                }
                            }
                            Rectangle { width: parent.width; height: 1; color: Theme.dividerColor }
                        }
                    }
                }

                Item { width: 1; height: LayoutMetrics.spacing.xl }
            }

            FolderDialog {
                id: orgFolderDialog
                onAccepted: organizerVM.folder = selectedFolder.toString().replace("file://", "")
            }
        }
    }

    Popup {
        id: renameDialog

        property int fileCount: 0

        width: Math.min(LayoutMetrics.window.width * 0.86, LayoutMetrics.unit * 58)
        height: confirmColumn.implicitHeight + LayoutMetrics.spacing.xl * 2
        x: (LayoutMetrics.window.width - width) / 2
        y: (LayoutMetrics.window.height - height) / 2
        padding: 0
        background: Item {}
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        Surface {
            anchors.fill: parent

            Column {
                id: confirmColumn
                anchors.fill: parent
                anchors.margins: LayoutMetrics.spacing.lg
                spacing: LayoutMetrics.spacing.md

                Label {
                    width: parent.width
                    text: "Rename files?"
                    textColor: Theme.textColor
                    pixelSize: Typography.h3
                }

                Label {
                    width: parent.width
                    bold: false
                    textFormat: Text.PlainText
                    text: renameDialog.fileCount > 0
                        ? "This will rename " + (renameDialog.fileCount === 1
                           ? "1 file" : renameDialog.fileCount + " files")
                          + " directly inside \"" + organizerVM.folder + "\". "
                          + "This cannot be undone."
                        : "There are no files directly inside \""
                          + organizerVM.folder + "\" to rename."
                    textColor: Theme.textColor
                    pixelSize: Typography.h6
                    wrapMode: Text.WordWrap
                }

                Label {
                    width: parent.width
                    bold: false
                    visible: renameDialog.fileCount > 0
                    text: "Files inside subfolders are not touched."
                    textColor: Theme.dividerColor
                    pixelSize: Typography.h6
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    width: parent.width
                    spacing: LayoutMetrics.spacing.sm

                    Item { Layout.fillWidth: true }

                    Button {
                        buttonText: "Cancel"
                        onPressed: renameDialog.close()
                    }

                    Button {
                        buttonText: renameDialog.fileCount === 1
                                    ? "Rename 1 file"
                                    : "Rename " + renameDialog.fileCount + " files"
                        primary: true
                        enabled: renameDialog.fileCount > 0
                        onPressed: {
                            organizerVM.renameSequential(renamePattern.text)
                            renameDialog.close()
                        }
                    }
                }
            }
        }
    }
}
