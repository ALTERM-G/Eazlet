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
            acceptedButtons: Qt.NoButton

            anchors.fill: parent
            anchors.margins: LayoutMetrics.spacing.lg
            contentHeight: orgColumn.implicitHeight
            clip: true
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds

            WheelScrollArea {
                target: flick
            }

            Column {
                id: orgColumn
                width: parent.width
                x: Math.max(0, (parent.width - width) / 2)
                spacing: LayoutMetrics.spacing.md

                Title {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Lang.pages.organizer.title
                    textColor: Theme.textColor
                    pixelSize: Typography.h2
                }

                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    bold: false
                    text: Lang.pages.organizer.subtitle
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
                    Button { id: browseBtn; buttonText: Lang.common.browse; onPressed: orgFolderDialog.open() }
                    Button { id: openBtn; buttonText: Lang.common.open; onPressed: organizerVM.openFolder() }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: LayoutMetrics.spacing.sm
                    Button { buttonText: Lang.pages.organizer.scanDuplicates; primary: true; isometric: true; heightMultiplier: 1.3; enabled: !organizerVM.scanning; onPressed: organizerVM.scan() }
                }

                RowLayout {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: LayoutMetrics.spacing.sm
                    LineEdit {
                        id: renamePattern
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: 200
                        placeholderText: Lang.pages.organizer.prefixPlaceholder
                        text: Lang.pages.organizer.defaultPrefix
                    }
                    Button {
                        Layout.alignment: Qt.AlignVCenter
                        buttonText: Lang.pages.organizer.renameAll
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
                    text: Lang.pages.organizer.renameNote
                    textColor: Theme.dividerColor
                    pixelSize: Typography.h6
                    wrapMode: Text.WordWrap
                }

                ProgressBar {
                    width: Math.min(parent.width * 0.8, LayoutMetrics.unit * 60)
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
                        visible: organizerVM.status === Lang.common.done || organizerVM.status === "Done"
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
                    text: Lang.pages.organizer.duplicateGroupsCount.replace("{count}", organizerVM.duplicates.length)
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
                                text: Lang.pages.organizer.groupLabel.replace("{count}", (modelData.files ? modelData.files.length : 0))
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
                    text: Lang.pages.organizer.renameFilesTitle
                    textColor: Theme.textColor
                    pixelSize: Typography.h3
                }

                Label {
                    width: parent.width
                    bold: false
                    textFormat: Text.PlainText
                    text: renameDialog.fileCount > 0
                        ? (renameDialog.fileCount === 1
                           ? Lang.pages.organizer.renameConfirmSingle.replace(
                                 "{folder}", organizerVM.folder)
                           : Lang.pages.organizer.renameConfirmMultiple.replace(
                                 "{count}", renameDialog.fileCount).replace(
                                 "{folder}", organizerVM.folder))
                        : Lang.pages.organizer.renameNoFiles.replace(
                              "{folder}", organizerVM.folder)
                    textColor: Theme.textColor
                    pixelSize: Typography.h6
                    wrapMode: Text.WordWrap
                }

                Label {
                    width: parent.width
                    bold: false
                    visible: renameDialog.fileCount > 0
                    text: Lang.pages.organizer.subfoldersNote
                    textColor: Theme.dividerColor
                    pixelSize: Typography.h6
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    width: parent.width
                    spacing: LayoutMetrics.spacing.sm

                    Item { Layout.fillWidth: true }

                    Button {
                        buttonText: Lang.common.cancel
                        onPressed: renameDialog.close()
                    }

                    Button {
                        buttonText: renameDialog.fileCount === 1
                                    ? Lang.pages.organizer.renameButtonSingle
                                    : Lang.pages.organizer.renameButtonMultiple.replace(
                                          "{count}", renameDialog.fileCount)
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
