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
            contentHeight: convColumn.implicitHeight
            clip: true
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: convColumn
                width: parent.width
                spacing: LayoutMetrics.spacing.lg

            Text {
                text: "Converter"
                color: Theme.textColor
                font.bold: true
            }

            DropArea {
                id: dropArea
                width: parent.width
                height: 120
                onDropped: (drop) => {
                    if (drop.hasUrls) {
                        for (var i = 0; i < drop.urls.length; i++) {
                            converterVM.addFile(drop.urls[i].toString())
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: LayoutMetrics.radius.m
                    color: dropArea.containsDrag ? Theme.hoverBackgroundColor : Theme.inputBackgroundColor
                    border.color: dropArea.containsDrag ? Theme.themeColor : Theme.borderColor
                    border.width: LayoutMetrics.border.m

                    Column {
                        anchors.centerIn: parent
                        spacing: LayoutMetrics.spacing.sm
                        Text {
                            text: "Drop files here"
                            color: Theme.textColor
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }

            Row {
                spacing: LayoutMetrics.spacing.sm
                Button { buttonText: "Clear"; onPressed: converterVM.clearFiles() }
                Text { text: converterVM.files.length + " file(s)"; color: Theme.textColor }
            }

            ListView {
                width: parent.width
                height: 150
                model: converterVM.files
                clip: true
                delegate: Rectangle {
                    width: parent.width
                    height: 30
                    color: index % 2 === 0 ? Theme.backgroundColor : Theme.inputBackgroundColor
                    Row {
                        anchors.fill: parent
                        anchors.margins: LayoutMetrics.spacing.sm
                        spacing: LayoutMetrics.spacing.sm
                        Text { text: modelData.name; color: Theme.textColor; width: parent.width * 0.7; elide: Text.ElideMiddle }
                        Text { text: modelData.ext.toUpperCase(); color: Theme.textColor; width: 40 }
                        Button { buttonText: "X"; width: 30; onPressed: converterVM.removeFile(index) }
                    }
                }
            }

            Row {
                spacing: LayoutMetrics.spacing.md
                visible: converterVM.files.length > 0 && converterVM.validTargetFormats.length > 0
                Text { text: "Convert to:"; color: Theme.textColor; anchors.verticalCenter: parent.verticalCenter }
                ComboBox {
                    width: 200
                    model: converterVM.validTargetFormats
                    currentIndex: {
                        var idx = model.indexOf(converterVM.targetFormat)
                        return idx >= 0 ? idx : 0
                    }
                    onCurrentTextChanged: {
                        if (currentText && currentText !== converterVM.targetFormat) {
                            converterVM.targetFormat = currentText
                        }
                    }
                }
            }

            Row {
                spacing: LayoutMetrics.spacing.sm
                Text { text: "Output: " + converterVM.outputDir; color: Theme.textColor; elide: Text.ElideMiddle; width: parent.width * 0.7 }
                Button { buttonText: "Open Folder"; onPressed: converterVM.openOutputDir() }
            }

            Row {
                spacing: LayoutMetrics.spacing.sm
                Button { buttonText: "Convert"; primary: true; enabled: !converterVM.converting && converterVM.files.length > 0 && converterVM.targetFormat !== ""; onPressed: converterVM.convert() }
                Button { buttonText: "Cancel"; enabled: converterVM.converting; onPressed: converterVM.cancel() }
            }

            ProgressBar {
                width: parent.width
                value: converterVM.progress
                visible: converterVM.converting || converterVM.progress >= 1.0
            }

            Text { text: converterVM.status; color: Theme.textColor }
            Text { text: converterVM.error; color: "red"; visible: converterVM.error !== "" }
            Item { width: 1; height: LayoutMetrics.spacing.xl }
            }
        }
    }
}
