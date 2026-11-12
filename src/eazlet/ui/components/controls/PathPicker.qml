import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import components

Column {
    id: root

    property string label: ""
    property string path: ""
    property string defaultPath: ""

    signal pathAccepted(string newPath)

    width: parent ? parent.width : implicitWidth
    spacing: LayoutMetrics.spacing.xxs

    onPathChanged: field.text = path

    Label {
        text: root.label
        style_2: true
        visible: root.label !== ""
    }

    Row {
        id: pathRow
        width: parent.width
        spacing: LayoutMetrics.spacing.sm

        LineEdit {
            id: field
            width: Math.max(0, pathRow.width - browseButton.width
                            - resetButton.width - pathRow.spacing * 2)
            text: root.path
            placeholderText: root.defaultPath
            onEditingFinished: {
                root.pathAccepted(text)
                field.text = root.path
            }
        }

        Button {
            id: browseButton
            buttonText: Lang.labels.browse
            iconPath: SVGLibrary.browse
            height: field.height
            anchors.verticalCenter: parent.verticalCenter
            onPressed: folderDialog.open()
        }

        IconButton {
            id: resetButton
            anchors.verticalCenter: parent.verticalCenter
            iconPath: SVGLibrary.reset
            buttonWidth: LayoutMetrics.size.iconM
            buttonHeight: LayoutMetrics.size.iconM
            enabled: root.path !== root.defaultPath
            opacity: enabled ? 1 : 0

            onPressed: root.pathAccepted(root.defaultPath)

            ToolTip {
                text: Lang.labels.reset
                visible: resetButton.hovered && resetButton.enabled
                delay: 600
            }
        }
    }

    FolderDialog {
        id: folderDialog
        onAccepted: root.pathAccepted(selectedFolder.toString())
    }
}
