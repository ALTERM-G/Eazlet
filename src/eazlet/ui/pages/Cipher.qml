import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import components

Item {
    id: page

    Layout.fillWidth: true
    Layout.fillHeight: true

    function processAction() {
        if (toolTabs.currentIndex === 0)
            cipherVM.processEncoding()
        else if (toolTabs.currentIndex === 1)
            cipherVM.processCipher()
        else if (toolTabs.currentIndex === 2)
            cipherVM.encrypt()
        else
            cipherVM.processHash()
    }

    Surface {
        anchors.centerIn: parent
        width: parent.width * 0.9
        height: parent.height * 0.9

        Column {
            id: pageColumn
            width: Math.max(0, parent.width - LayoutMetrics.spacing.lg * 2)
            height: parent.height - LayoutMetrics.spacing.lg * 2
            x: (parent.width - width) / 2
            y: LayoutMetrics.spacing.lg
            spacing: LayoutMetrics.spacing.md

            Title {
                id: pageTitle
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Code Tools"
                textColor: Theme.textColor
                pixelSize: Typography.h2
            }

            Label {
                id: pageSubtitle
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                bold: false
                text: "Encode, cipher, encrypt, and hash text in one place."
                textColor: Theme.dividerColor
                pixelSize: Typography.h6
                wrapMode: Text.WordWrap
            }

            TabBar {
                id: toolTabs
                anchors.horizontalCenter: parent.horizontalCenter
                tabData: ["Encoding", "Ciphers", "Encryption", "Hashing"]
                active: page.visible
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
                height: parent.height - pageTitle.height - pageSubtitle.height
                        - toolTabs.height - divider.height - pageColumn.spacing * 4
                contentHeight: toolContent.implicitHeight
                clip: true
                flickableDirection: Flickable.VerticalFlick
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: AppScrollBar {}
                interactive: false

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: function(wheel) {
                        var delta = wheel.pixelDelta.y !== 0
                            ? wheel.pixelDelta.y * 2
                            : wheel.angleDelta.y / 120 * LayoutMetrics.unit * 24
                        var maxY = Math.max(0, toolScroll.contentHeight - toolScroll.height)
                        toolScroll.contentY = Math.max(0, Math.min(maxY, toolScroll.contentY - delta))
                        wheel.accepted = true
                    }
                }

                TabSlide {
                    id: tabSlide
                    tabBar: toolTabs
                    target: toolContent
                }

                Column {
                    id: toolContent
                    width: Math.max(0, parent.width - LayoutMetrics.unit * 1.6)
                    spacing: LayoutMetrics.spacing.lg

                    // Encoding -----------------------------------------
                    Column {
                        id: encodingControls
                        width: parent.width
                        spacing: LayoutMetrics.spacing.md
                        visible: toolTabs.currentIndex === 0

                        Label {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
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
                                maxVisibleItems: 10
                                currentIndex: {
                                    var idx = model.indexOf(cipherVM.encodingAlgorithm)
                                    return idx >= 0 ? idx : 0
                                }
                                onCurrentTextChanged: {
                                    if (currentText && currentText !== cipherVM.encodingAlgorithm)
                                        cipherVM.encodingAlgorithm = currentText
                                }
                            }

                            Switch {
                                text: "Decode"
                                checked: cipherVM.mode === "decode"
                                onCheckedChanged: cipherVM.mode = checked ? "decode" : "encode"
                            }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: LayoutMetrics.spacing.xs
                            Button { buttonText: "Process"; primary: true; isometric: true; heightMultiplier: 1.3; onPressed: cipherVM.processEncoding() }
                            Button { buttonText: "Detect"; onPressed: cipherVM.detect() }
                            Button { buttonText: "Swap"; onPressed: cipherVM.swapEncoding() }
                            Button { buttonText: "Clear"; iconPath: SVGLibrary.eraser; onPressed: cipherVM.clearEncoding() }
                        }

                        CipherIO {
                            viewModel: cipherVM
                            inputProperty: "encodingInput"
                            outputProperty: "encodingOutput"
                            placeholderText: "Enter text or an encoded payload here"
                            onClearRequested: cipherVM.clearEncoding()
                        }
                    }

                    // Ciphers ------------------------------------------
                    Column {
                        id: cipherControls
                        width: parent.width
                        spacing: LayoutMetrics.spacing.md
                        visible: toolTabs.currentIndex === 1

                        Label {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
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
                                maxVisibleItems: 10
                                currentIndex: {
                                    var idx = model.indexOf(cipherVM.cipherAlgorithm)
                                    return idx >= 0 ? idx : 0
                                }
                                onCurrentTextChanged: {
                                    if (currentText && currentText !== cipherVM.cipherAlgorithm)
                                        cipherVM.cipherAlgorithm = currentText
                                }
                            }

                            Switch {
                                text: "Decode"
                                checked: cipherVM.mode === "decode"
                                onCheckedChanged: cipherVM.mode = checked ? "decode" : "encode"
                            }
                        }

                        Row {
                            spacing: LayoutMetrics.spacing.md
                            visible: cipherVM.usesKey

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
                                placeholderText: cipherVM.keyHint || "e.g. KEY"
                                onTextChanged: cipherVM.key = text
                            }
                        }

                        Row {
                            spacing: LayoutMetrics.spacing.md
                            visible: cipherVM.usesShift

                            Label {
                                bold: false
                                text: "Shift:"
                                textColor: Theme.textColor
                                pixelSize: Typography.h6
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            SpinBox {
                                from: 1
                                to: 25
                                stepSize: 1
                                value: cipherVM.shift
                                onValueChanged: cipherVM.shift = value
                            }
                        }

                        Row {
                            spacing: LayoutMetrics.spacing.md
                            visible: cipherVM.usesRails

                            Label {
                                bold: false
                                text: "Rails:"
                                textColor: Theme.textColor
                                pixelSize: Typography.h6
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            SpinBox {
                                from: 2
                                to: 15
                                stepSize: 1
                                value: cipherVM.rails
                                onValueChanged: cipherVM.rails = value
                            }
                        }

                        Row {
                            spacing: LayoutMetrics.spacing.md
                            visible: cipherVM.usesTurns

                            Label {
                                bold: false
                                text: "Turns:"
                                textColor: Theme.textColor
                                pixelSize: Typography.h6
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            SpinBox {
                                from: 2
                                to: 20
                                stepSize: 1
                                value: cipherVM.turns
                                onValueChanged: cipherVM.turns = value
                            }
                        }

                        Row {
                            spacing: LayoutMetrics.spacing.md
                            visible: cipherVM.usesPeriod

                            Label {
                                bold: false
                                text: "Period:"
                                textColor: Theme.textColor
                                pixelSize: Typography.h6
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            SpinBox {
                                from: 1
                                to: 20
                                stepSize: 1
                                value: cipherVM.period
                                onValueChanged: cipherVM.period = value
                            }
                        }

                        Label {
                            bold: false
                            width: parent.width
                            visible: text !== ""
                            text: cipherVM.cipherHint
                            textColor: Theme.dividerColor
                            pixelSize: Typography.h6
                            wrapMode: Text.WordWrap
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: LayoutMetrics.spacing.sm
                            Button { buttonText: "Process"; primary: true; isometric: true; heightMultiplier: 1.3; onPressed: cipherVM.processCipher() }
                            Button { buttonText: "Swap"; onPressed: cipherVM.swapCipher() }
                            Button { buttonText: "Clear"; iconPath: SVGLibrary.eraser; onPressed: cipherVM.clearCipher() }
                        }

                        CipherIO {
                            viewModel: cipherVM
                            inputProperty: "cipherInput"
                            outputProperty: "cipherOutput"
                            placeholderText: "Enter text to encrypt or decrypt with a classical cipher"
                            onClearRequested: cipherVM.clearCipher()
                        }
                    }

                    // Encryption ----------------------------------------
                    Column {
                        id: encryptionControls
                        width: parent.width
                        spacing: LayoutMetrics.spacing.md
                        visible: toolTabs.currentIndex === 2

                        Label {
                            bold: false
                            horizontalAlignment: Text.AlignHCenter
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

                            Switch {
                                id: revealPassphrase
                                text: "Show passphrase"
                            }
                        }

                        Label {
                            bold: false
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: "Anyone with the passphrase can decrypt the payload. There is no recovery if it is lost."
                            textColor: Theme.dividerColor
                            pixelSize: Typography.h6
                            wrapMode: Text.WordWrap
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: LayoutMetrics.spacing.sm
                            Button { buttonText: "Encrypt"; primary: true; isometric: true; heightMultiplier: 1.3; onPressed: cipherVM.encrypt() }
                            Button { buttonText: "Decrypt"; onPressed: cipherVM.decrypt() }
                            Button { buttonText: "Clear"; iconPath: SVGLibrary.eraser; onPressed: cipherVM.clearEncryption() }
                        }

                        CipherIO {
                            viewModel: cipherVM
                            inputProperty: "encryptionInput"
                            outputProperty: "encryptionOutput"
                            placeholderText: "Enter text to encrypt or an Eazlet payload to decrypt"
                            onClearRequested: cipherVM.clearEncryption()
                        }
                    }

                    // Hashing ------------------------------------------
                    Column {
                        id: hashingControls
                        width: parent.width
                        spacing: LayoutMetrics.spacing.md
                        visible: toolTabs.currentIndex === 3

                        Label {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
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
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: LayoutMetrics.spacing.sm
                            Button { buttonText: "Hash"; primary: true; isometric: true; heightMultiplier: 1.3; onPressed: cipherVM.processHash() }
                            Button { buttonText: "Clear"; iconPath: SVGLibrary.eraser; onPressed: cipherVM.clearHash() }
                        }

                        CipherIO {
                            viewModel: cipherVM
                            inputProperty: "hashTextInput"
                            outputProperty: "hashTextOutput"
                            placeholderText: "Enter text to hash"
                            onClearRequested: cipherVM.clearHash()
                        }
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
