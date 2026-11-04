import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import components

Item {
    id: page

    Layout.fillWidth: true
    Layout.fillHeight: true

    Surface {
        anchors.centerIn: parent
        width: parent.width * 0.9
        height: parent.height * 0.9

        Column {
            id: pageColumn
            anchors.fill: parent
            anchors.margins: LayoutMetrics.spacing.lg
            spacing: LayoutMetrics.spacing.md

            TabBar {
                id: toolTabs
                anchors.horizontalCenter: parent.horizontalCenter
                tabData: ["Encoding", "Ciphers", "Encryption", "Hashing"]
            }

            Rectangle {
                id: divider
                width: parent.width
                height: LayoutMetrics.spacing.xxs
                color: Theme.dividerColor
            }

            Flickable {
                id: toolScroll
                width: parent.width
                height: parent.height - toolTabs.height - divider.height
                        - pageColumn.spacing * 2
                contentHeight: toolContent.implicitHeight
                clip: true
                flickableDirection: Flickable.VerticalFlick
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                interactive: true

                Column {
                    id: toolContent
                    width: toolScroll.width
                    spacing: LayoutMetrics.spacing.lg

                    // Encoding -------------------------------------------------
                    Column {
                        id: encodingControls
                        width: parent.width
                        spacing: LayoutMetrics.spacing.md
                        visible: toolTabs.currentIndex === 0

                        Label {
    bold: false
                            text: "Convert text to and from reversible encodings."
                            textColor: Theme.dividerColor
                            pixelSize: Typography.h6
                        }

                        Row {
                            spacing: LayoutMetrics.spacing.md

                            Label {
    bold: false
                                text: "Encoding:"
                                textColor: Theme.textColor
                                pixelSize: Typography.h6
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            ComboBox {
                                id: encodingCombo
                                width: 260
                                model: cipherVM.encodings
                                scrollablePopup: true
                                maxVisibleItems: 12
                                currentIndex: {
                                    var idx = model.indexOf(cipherVM.encodingAlgorithm)
                                    return idx >= 0 ? idx : 0
                                }
                                onCurrentTextChanged: {
                                    if (currentText && currentText !== cipherVM.encodingAlgorithm)
                                        cipherVM.encodingAlgorithm = currentText
                                }
                            }

                            Button {
                                buttonText: cipherVM.mode === "encode" ? "Mode: Encode" : "Mode: Decode"
                                onPressed: cipherVM.mode = cipherVM.mode === "encode" ? "decode" : "encode"
                            }
                        }

                        Row {
                            spacing: LayoutMetrics.spacing.sm
                            Button { buttonText: "Process"; primary: true; onPressed: cipherVM.processEncoding() }
                            Button { buttonText: "Detect"; onPressed: cipherVM.detect() }
                            Button { buttonText: "Swap"; onPressed: cipherVM.swap() }
                            Button { buttonText: "Clear"; onPressed: cipherVM.clear() }
                        }
                    }

                    // Ciphers --------------------------------------------------
                    Column {
                        id: cipherControls
                        width: parent.width
                        spacing: LayoutMetrics.spacing.md
                        visible: toolTabs.currentIndex === 1

                        Label {
    bold: false
                            text: "Apply classical substitution and transposition ciphers."
                            textColor: Theme.dividerColor
                            pixelSize: Typography.h6
                        }

                        Row {
                            spacing: LayoutMetrics.spacing.md

                            Label {
    bold: false
                                text: "Cipher:"
                                textColor: Theme.textColor
                                pixelSize: Typography.h6
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            ComboBox {
                                id: cipherCombo
                                width: 260
                                model: cipherVM.classicalCiphers
                                scrollablePopup: true
                                maxVisibleItems: 12
                                currentIndex: {
                                    var idx = model.indexOf(cipherVM.cipherAlgorithm)
                                    return idx >= 0 ? idx : 0
                                }
                                onCurrentTextChanged: {
                                    if (currentText && currentText !== cipherVM.cipherAlgorithm)
                                        cipherVM.cipherAlgorithm = currentText
                                }
                            }

                            Button {
                                buttonText: cipherVM.mode === "encode" ? "Mode: Encode" : "Mode: Decode"
                                onPressed: cipherVM.mode = cipherVM.mode === "encode" ? "decode" : "encode"
                            }
                        }

                        Row {
                            spacing: LayoutMetrics.spacing.md

                            Label {
    bold: false
                                text: "Key:"
                                textColor: Theme.textColor
                                pixelSize: Typography.h6
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            LineEdit {
                                id: keyInput
                                width: 260
                                text: cipherVM.key
                                placeholderText: "e.g. KEY or 5,8"
                                onTextChanged: cipherVM.key = text
                            }
                        }

                        Label {
    bold: false
                            width: parent.width
                            text: "Used by Affine (a,b), Vigenere, Beaufort, Autokey, and XOR."
                            textColor: Theme.dividerColor
                            pixelSize: Typography.h6
                            wrapMode: Text.WordWrap
                        }

                        Row {
                            spacing: LayoutMetrics.spacing.sm
                            Button { buttonText: "Process"; primary: true; onPressed: cipherVM.processCipher() }
                            Button { buttonText: "Swap"; onPressed: cipherVM.swap() }
                            Button { buttonText: "Clear"; onPressed: cipherVM.clear() }
                        }
                    }

                    // Encryption -----------------------------------------------
                    Column {
                        id: encryptionControls
                        width: parent.width
                        spacing: LayoutMetrics.spacing.md
                        visible: toolTabs.currentIndex === 2

                        Label {
    bold: false
                            text: "Authenticated encryption. The passphrase is used to derive the key."
                            textColor: Theme.dividerColor
                            pixelSize: Typography.h6
                            width: parent.width
                            wrapMode: Text.WordWrap
                        }

                        Row {
                            spacing: LayoutMetrics.spacing.md

                            Label {
    bold: false
                                text: "Algorithm:"
                                textColor: Theme.textColor
                                pixelSize: Typography.h6
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            ComboBox {
                                id: encryptionCombo
                                width: 260
                                model: cipherVM.encryptionAlgorithms
                                currentIndex: {
                                    var idx = model.indexOf(cipherVM.encryptionAlgorithm)
                                    return idx >= 0 ? idx : 0
                                }
                                onCurrentTextChanged: {
                                    if (currentText && currentText !== cipherVM.encryptionAlgorithm)
                                        cipherVM.encryptionAlgorithm = currentText
                                }
                            }
                        }

                        Row {
                            spacing: LayoutMetrics.spacing.md

                            Label {
    bold: false
                                text: "Passphrase:"
                                textColor: Theme.textColor
                                pixelSize: Typography.h6
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            LineEdit {
                                id: passphraseInput
                                width: 260
                                text: cipherVM.passphrase
                                placeholderText: "Enter a passphrase"
                                echoMode: revealPassphrase.checked ? TextInput.Normal : TextInput.Password
                                onTextChanged: cipherVM.passphrase = text
                            }

                            Button {
                                id: revealPassphrase
                                property bool checked: false
                                buttonText: checked ? "Hide" : "Show"
                                onPressed: checked = !checked
                            }
                        }

                        Label {
    bold: false
                            width: parent.width
                            text: "Anyone with the passphrase can decrypt the payload. There is no recovery if it is lost."
                            textColor: Theme.dividerColor
                            pixelSize: Typography.h6
                            wrapMode: Text.WordWrap
                        }

                        Row {
                            spacing: LayoutMetrics.spacing.sm
                            Button { buttonText: "Encrypt"; primary: true; onPressed: cipherVM.encrypt() }
                            Button { buttonText: "Decrypt"; onPressed: cipherVM.decrypt() }
                            Button { buttonText: "Clear"; onPressed: cipherVM.clear() }
                        }
                    }

                    // Hashing --------------------------------------------------
                    Column {
                        id: hashingControls
                        width: parent.width
                        spacing: LayoutMetrics.spacing.md
                        visible: toolTabs.currentIndex === 3

                        Label {
    bold: false
                            text: "Create a one-way digest. Hashing cannot be reversed."
                            textColor: Theme.dividerColor
                            pixelSize: Typography.h6
                        }

                        Row {
                            spacing: LayoutMetrics.spacing.md

                            Label {
    bold: false
                                text: "Hash:"
                                textColor: Theme.textColor
                                pixelSize: Typography.h6
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            ComboBox {
                                id: hashCombo
                                width: 260
                                model: cipherVM.hashAlgorithms
                                currentIndex: {
                                    var idx = model.indexOf(cipherVM.hashAlgorithm)
                                    return idx >= 0 ? idx : 0
                                }
                                onCurrentTextChanged: {
                                    if (currentText && currentText !== cipherVM.hashAlgorithm)
                                        cipherVM.hashAlgorithm = currentText
                                }
                            }
                        }

                        Row {
                            spacing: LayoutMetrics.spacing.sm
                            Button { buttonText: "Hash"; primary: true; onPressed: cipherVM.hashInput() }
                            Button { buttonText: "Clear"; onPressed: cipherVM.clear() }
                        }
                    }

                    // Shared input / output ------------------------------------
                    Label {
                        text: "Input"
                        textColor: Theme.textColor
                        pixelSize: Typography.h4
                    }

                    TextEdit {
                        id: toolInput
                        width: parent.width
                        height: 150
                        text: cipherVM.input
                        placeholderText: "Enter text or a payload here"
                        onTextChanged: cipherVM.input = text
                        Keys.onShortcutOverride: function(event) {
                            if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.ShiftModifier))
                                event.accepted = true
                        }
                        Keys.onPressed: function(event) {
                            if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.ShiftModifier)) {
                                if (toolTabs.currentIndex === 0)
                                    cipherVM.processEncoding()
                                else if (toolTabs.currentIndex === 1)
                                    cipherVM.processCipher()
                                else if (toolTabs.currentIndex === 2)
                                    cipherVM.encrypt()
                                else
                                    cipherVM.hashInput()
                                event.accepted = true
                            }
                        }
                    }

                    Row {
                        spacing: LayoutMetrics.spacing.sm

                        Label {
                            text: "Output"
                            textColor: Theme.textColor
                            pixelSize: Typography.h4
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Button { buttonText: "Copy"; onPressed: cipherVM.copyOutput() }
                    }

                    TextEdit {
                        id: toolOutput
                        width: parent.width
                        height: 150
                        text: cipherVM.output
                        enabled: false
                    }

                    Label {
    bold: false
                        text: cipherVM.status
                        textColor: Theme.textColor
                        pixelSize: Typography.h6
                    }

                    Label {
    bold: false
                        width: parent.width
                        text: cipherVM.error
                        textColor: "red"
                        pixelSize: Typography.h6
                        visible: cipherVM.error !== ""
                        wrapMode: Text.WordWrap
                    }

                    Item {
                        width: 1
                        height: LayoutMetrics.spacing.xl
                    }
                }
            }
        }
    }
}
