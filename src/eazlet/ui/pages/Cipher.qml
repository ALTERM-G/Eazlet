import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import components

Item {
    Layout.fillWidth: true
    Layout.fillHeight: true

    Surface {
        anchors.centerIn: parent
        width: parent.width * 0.9
        height: parent.height * 0.9

        Flickable {
            anchors.fill: parent
            anchors.margins: LayoutMetrics.spacing.lg
            contentHeight: cipherColumn.implicitHeight
            clip: true
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            interactive: true

            Column {
                id: cipherColumn
                width: parent.width
                spacing: LayoutMetrics.spacing.lg

                Text {
                    text: "Ciphers / Encoders"
                    color: Theme.textColor
                    font.bold: true
                }

                Row {
                    spacing: LayoutMetrics.spacing.md
                    Text { text: "Cipher:"; color: Theme.textColor; anchors.verticalCenter: parent.verticalCenter }
                    ComboBox {
                        width: 220
                        model: cipherVM.ciphers
                        currentIndex: {
                            var idx = model.indexOf(cipherVM.cipher)
                            return idx >= 0 ? idx : 0
                        }
                        onCurrentTextChanged: {
                            if (currentText && currentText !== cipherVM.cipher) {
                                cipherVM.cipher = currentText
                            }
                        }
                    }
                    Button { buttonText: cipherVM.mode === "encode" ? "Mode: Encode" : "Mode: Decode"; onPressed: cipherVM.mode = cipherVM.mode === "encode" ? "decode" : "encode" }
                }

                Row {
                    spacing: LayoutMetrics.spacing.sm
                    Button { buttonText: "Process"; primary: true; onPressed: cipherVM.process() }
                    Button { buttonText: "Detect"; onPressed: cipherVM.detect() }
                    Button { buttonText: "Swap"; onPressed: cipherVM.swap() }
                    Button { buttonText: "Clear"; onPressed: cipherVM.clear() }
                }




                Text { text: "Input:"; color: Theme.textColor }
                TextEdit {
                    id: cipherInput
                    width: parent.width
                    height: 150
                    text: cipherVM.input
                    onTextChanged: cipherVM.input = text
                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Return && (event.modifiers & Qt.ShiftModifier)) {
                            cipherVM.process()
                            event.accepted = true
                        }
                    }
                }

                Row {
                    spacing: LayoutMetrics.spacing.sm
                    Text { text: "Output:"; color: Theme.textColor; anchors.verticalCenter: parent.verticalCenter }
                    Button { buttonText: "Copy"; onPressed: cipherVM.copyOutput() }
                }
                Rectangle {
                    width: parent.width
                    height: 150
                    color: Theme.inputBackgroundColor
                    border.color: Theme.borderColor
                    border.width: 1
                    radius: LayoutMetrics.radius.m
                    clip: true
                    TextEdit {
                        id: cipherOutput
                        anchors.fill: parent
                        anchors.margins: LayoutMetrics.spacing.sm
                        text: cipherVM.output
                        enabled: false
                    }
                }

                Text { text: cipherVM.status; color: Theme.textColor }
                Text { text: cipherVM.error; color: "red"; visible: cipherVM.error !== "" }
                Item { width: 1; height: LayoutMetrics.spacing.xl }
            }
        }
    }
}
