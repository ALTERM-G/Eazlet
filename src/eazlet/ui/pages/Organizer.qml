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

                Text {
                    text: "Organizer / Sorter"
                    color: Theme.textColor
                    font.bold: true
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

                Text { text: organizerVM.status; color: Theme.textColor }
                Text { text: organizerVM.error; color: "red"; visible: organizerVM.error !== "" }

                Text { text: "Duplicate groups: " + organizerVM.duplicates.length; color: Theme.textColor; visible: organizerVM.duplicates.length > 0 }

                Column {
                    width: parent.width
                    visible: organizerVM.duplicates.length > 0
                    spacing: LayoutMetrics.spacing.md
                    Repeater {
                        model: organizerVM.duplicates
                        delegate: Column {
                            width: parent.width
                            spacing: LayoutMetrics.spacing.xs
                            Text { text: "Group (" + (modelData.files ? modelData.files.length : 0) + " files)"; color: Theme.textColor; font.bold: true }
                            Repeater {
                                model: modelData.files
                                delegate: Text { text: "  " + (modelData.path ? modelData.path : ""); color: Theme.textColor; elide: Text.ElideMiddle; width: parent.width }
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
