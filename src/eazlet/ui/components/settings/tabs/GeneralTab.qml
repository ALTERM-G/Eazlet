import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import components

Column {
    id: generalTab

    required property QtObject settingsMenu
    required property QtObject settingsPopup
    required property QtObject settingsTabBar

    visible: settingsTabBar.currentIndex === 0
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: LayoutMetrics.spacing.lg

    function resetControls() {
        languageCombo.initialized = false
        languageCombo.currentIndex = controller.get_language()
        languageCombo.initialized = true

        downloadField.text = controller.get_download_dir()
    }

    function commitDownloadDir() {
        if (downloadField.text === controller.get_download_dir())
            return
        controller.save_download_dir(downloadField.text)
        downloadField.text = controller.get_download_dir()
    }

    Column {
        id: languageSection
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: LayoutMetrics.spacing.xxs

        Label {
            text: Lang.labels.language
            style_2: true
        }

        ComboBox {
            id: languageCombo
            anchors.horizontalCenter: parent.horizontalCenter
            model: controller.get_languages()

            property bool initialized: false

            onCurrentIndexChanged: {
                if (initialized) {
                    controller.save_language(currentIndex)
                }
            }
        }
    }

    Column {
        id: downloadSection
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: LayoutMetrics.spacing.xxs

        Label {
            text: Lang.labels.downloadFolder
            style_2: true
        }

        Row {
            id: downloadRow
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: LayoutMetrics.spacing.sm

            LineEdit {
                id: downloadField
                width: Math.round(LayoutMetrics.size.lineEditWidth * 0.7)
                placeholderText: controller.get_default_download_dir()

                onEditingFinished: generalTab.commitDownloadDir()
            }

            Button {
                buttonText: Lang.labels.browse
                iconPath: SVGLibrary.browse
                height: downloadField.height
                anchors.verticalCenter: parent.verticalCenter
                onPressed: downloadFolderDialog.open()
            }

            IconButton {
                id: resetDownloadButton
                anchors.verticalCenter: parent.verticalCenter
                iconPath: SVGLibrary.reset
                buttonWidth: LayoutMetrics.size.iconM
                buttonHeight: LayoutMetrics.size.iconM
                enabled: downloadField.text !== controller.get_default_download_dir()
                opacity: enabled ? 1 : 0

                onPressed: {
                    var defaultDir = controller.get_default_download_dir()
                    downloadField.text = defaultDir
                    controller.save_download_dir(defaultDir)
                }

                ToolTip {
                    text: Lang.labels.reset
                    visible: resetDownloadButton.hovered && resetDownloadButton.enabled
                    delay: 600
                }
            }
        }

        Label {
            width: downloadRow.width
            text: Lang.labels.downloadFolderHint
            textColor: Theme.borderColor
            bold: false
            style_2: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
    }

    FolderDialog {
        id: downloadFolderDialog
        onAccepted: {
            controller.save_download_dir(selectedFolder.toString())
            downloadField.text = controller.get_download_dir()
        }
    }
}
