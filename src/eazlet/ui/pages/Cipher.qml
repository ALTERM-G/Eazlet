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
            cipherVM.hashInput()
    }

    Surface {
        anchors.centerIn: parent
        width: parent.width * 0.9
        height: parent.height * 0.9

        Column {
            id: pageColumn
            anchors.fill: parent
            anchors.margins: LayoutMetrics.spacing.lg
            spacing: LayoutMetrics.spacing.md

            Title {
                id: pageTitle
                text: "Code Tools"
                textColor: Theme.textColor
                pixelSize: Typography.h2
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
                height: parent.height - pageTitle.height - toolTabs.height - divider.height
                        - pageColumn.spacing * 3
                contentHeight: toolContent.implicitHeight
                clip: true
                flickableDirection: Flickable.VerticalFlick
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                implicitWidth: LayoutMetrics.unit * 1.2
            }
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
                            spacing: LayoutMetrics.spacing.sm
                            Button { buttonText: "Process"; primary: true; isometric: true; heightMultiplier: 1.3; onPressed: cipherVM.processEncoding() }
                            Button { buttonText: "Detect"; onPressed: cipherVM.detect() }
                            Button { buttonText: "Swap"; onPressed: cipherVM.swap() }
                            Button { buttonText: "Clear"; iconPath: SVGLibrary.eraser; onPressed: cipherVM.clear() }
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
                            Button { buttonText: "Process"; primary: true; isometric: true; heightMultiplier: 1.3; onPressed: cipherVM.processCipher() }
                            Button { buttonText: "Swap"; onPressed: cipherVM.swap() }
                            Button { buttonText: "Clear"; iconPath: SVGLibrary.eraser; onPressed: cipherVM.clear() }
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

                            Switch {
                                id: revealPassphrase
                                text: "Show passphrase"
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
                            Button { buttonText: "Encrypt"; primary: true; isometric: true; heightMultiplier: 1.3; onPressed: cipherVM.encrypt() }
                            Button { buttonText: "Decrypt"; onPressed: cipherVM.decrypt() }
                            Button { buttonText: "Clear"; iconPath: SVGLibrary.eraser; onPressed: cipherVM.clear() }
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
                            Button { buttonText: "Hash"; primary: true; isometric: true; heightMultiplier: 1.3; onPressed: cipherVM.hashInput() }
                            Button { buttonText: "Clear"; iconPath: SVGLibrary.eraser; onPressed: cipherVM.clear() }
                        }
                    }

                    // Shared input / output ------------------------------------
                    Row {
                        spacing: LayoutMetrics.spacing.sm
                        width: parent.width

                        Label {
                            text: "Input"
                            textColor: Theme.textColor
                            pixelSize: Typography.h4
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Button {
                            buttonText: "Paste"
                            iconPath: SVGLibrary.paste
                            onPressed: toolInput.paste()
                        }

                        Button {
                            buttonText: "Clear"
                            iconPath: SVGLibrary.eraser
                            onPressed: cipherVM.clear()
                        }
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
                                page.processAction()
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

                        Button {
                            buttonText: "Copy"
                            iconPath: SVGLibrary.copy
                            onPressed: cipherVM.copyOutput()
                        }
                    }

                    TextEdit {
                        id: toolOutput
                        width: parent.width
                        height: 150
                        text: cipherVM.output
                        readOnly: true
                        showCopyButton: true
                    }

                    Row {
                        spacing: LayoutMetrics.spacing.sm
                        visible: cipherVM.status !== ""
                        SVGObject {
                            anchors.verticalCenter: parent.verticalCenter
                            width: LayoutMetrics.size.iconS
                            height: LayoutMetrics.size.iconS
                            path: SVGLibrary.checkMark
                            color: Theme.textColor
                            visible: cipherVM.status === "Done"
                        }
                        Label {
                            bold: false
                            anchors.verticalCenter: parent.verticalCenter
                            text: cipherVM.status
                            textColor: Theme.textColor
                            pixelSize: Typography.h6
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: LayoutMetrics.spacing.sm
                        visible: cipherVM.error !== ""
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
                            width: Math.max(0, parent.width - LayoutMetrics.size.iconS - parent.spacing)
                            text: cipherVM.error
                            textColor: "red"
                            pixelSize: Typography.h6
                            wrapMode: Text.WordWrap
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
