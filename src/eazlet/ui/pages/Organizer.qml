import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import components

Item {
    Layout.fillWidth: true
    Layout.fillHeight: true

    Surface {
        anchors.centerIn: parent
        width: parent.width * 0.9
        height: parent.height * 0.9

        Flickable {
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            interactive: true

            anchors.fill: parent
            anchors.margins: LayoutMetrics.spacing.lg
            contentHeight: orgColumn.implicitHeight
            clip: true
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: orgColumn
                width: parent.width
                spacing: LayoutMetrics.spacing.lg

                Title {
                    text: "Organizer / Sorter"
                    textColor: Theme.textColor
                    pixelSize: Typography.h2
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
                    spacing: LayoutMetrics.spacing.sm
                    Button { buttonText: "Scan for duplicates"; primary: true; enabled: !organizerVM.scanning; onPressed: organizerVM.scan() }
                }

                Row {
                    spacing: LayoutMetrics.spacing.sm
                    LineEdit {
                        id: renamePattern
                        width: 200
                        placeholderText: "Prefix (e.g. photo)"
                        text: "file"
                    }
                    Button { buttonText: "Rename sequential"; onPressed: organizerVM.renameSequential(renamePattern.text) }
                }

                ProgressBar {
                    width: parent.width
                    value: organizerVM.progress
                    visible: organizerVM.scanning
                }

                Label {
    bold: false
                    text: organizerVM.status
                    textColor: Theme.textColor
                    pixelSize: Typography.h6
                }
                Label {
    bold: false
                    text: organizerVM.error
                    textColor: "red"
                    pixelSize: Typography.h6
                    visible: organizerVM.error !== ""
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
}
