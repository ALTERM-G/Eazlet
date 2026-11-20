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
                text: Lang.pages.cipher.title
                textColor: Theme.textColor
                pixelSize: Typography.h2
            }

            Label {
                id: pageSubtitle
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                bold: false
                text: Lang.pages.cipher.subtitle
                textColor: Theme.dividerColor
                pixelSize: Typography.h6
                wrapMode: Text.WordWrap
            }

            TabBar {
                id: toolTabs
                anchors.horizontalCenter: parent.horizontalCenter
                tabData: [
                    Lang.pages.cipher.tabEncoding,
                    Lang.pages.cipher.tabCiphers,
                    Lang.pages.cipher.tabEncryption,
                    Lang.pages.cipher.tabHashing
                ]
                active: page.visible
            }

            Rectangle {
                id: divider
                width: parent.width
                height: LayoutMetrics.divider.s
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
                acceptedButtons: Qt.NoButton

                WheelScrollArea {
                    target: toolScroll
                }

                TabSlide {
                    id: tabSlide
                    tabBar: toolTabs
                    target: toolContent
                }

                Column {
                    id: toolContent
                    width: parent.width
                    spacing: LayoutMetrics.spacing.md

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
                            text: Lang.pages.cipher.encodingDesc
                            textColor: Theme.dividerColor
                            pixelSize: Typography.h6
                        }

                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: LayoutMetrics.spacing.xxs

                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                bold: false
                                text: Lang.pages.cipher.encodingLabel
                                textColor: Theme.textColor
                                pixelSize: Typography.h6
                            }

                            Row {
                                spacing: LayoutMetrics.spacing.md

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
                                    text: Lang.pages.cipher.decodeMode
                                    checked: cipherVM.mode === "decode"
                                    onCheckedChanged: cipherVM.mode = checked ? "decode" : "encode"
                                }
                            }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: LayoutMetrics.spacing.xs
                            Button { buttonText: Lang.common.process; primary: true; isometric: true; heightMultiplier: 1.3; onPressed: cipherVM.processEncoding() }
                            Button { buttonText: Lang.common.detect; onPressed: cipherVM.detect() }
                            Button { buttonText: Lang.common.swap; iconPath: SVGLibrary.swap; onPressed: cipherVM.swapEncoding() }
                            Button { buttonText: Lang.common.clear; iconPath: SVGLibrary.eraser; onPressed: cipherVM.clearEncoding() }
                        }

                        CipherIO {
                            viewModel: cipherVM
                            inputProperty: "encodingInput"
                            outputProperty: "encodingOutput"
                            placeholderText: Lang.pages.cipher.encodingPlaceholder
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
                            text: Lang.pages.cipher.ciphersDesc
                            textColor: Theme.dividerColor
                            pixelSize: Typography.h6
                        }

                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: LayoutMetrics.spacing.xxs

                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                bold: false
                                text: Lang.pages.cipher.cipherLabel
                                textColor: Theme.textColor
                                pixelSize: Typography.h6
                            }

                            Row {
                                spacing: LayoutMetrics.spacing.md

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
                                    text: Lang.pages.cipher.decodeMode
                                    checked: cipherVM.mode === "decode"
                                    onCheckedChanged: cipherVM.mode = checked ? "decode" : "encode"
                                }
                            }
                        }

                        Flow {
                            id: cipherParamsFlow
                            anchors.horizontalCenter: parent.horizontalCenter
                            readonly property real naturalContentWidth: {
                                var total = 0, count = 0
                                for (var i = 0; i < children.length; i++) {
                                    var child = children[i]
                                    if (!child || !child.visible)
                                        continue
                                    var w = child.implicitWidth > 0 ? child.implicitWidth : child.width
                                    total += w
                                    count++
                                }
                                return total + Math.max(0, count - 1) * spacing
                            }
                            width: Math.min(parent.width, naturalContentWidth)
                            spacing: LayoutMetrics.spacing.lg

                            Column {
                                spacing: LayoutMetrics.spacing.xxs
                                visible: cipherVM.usesKey

                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    bold: false
                                    text: Lang.pages.cipher.key
                                    textColor: Theme.textColor
                                    pixelSize: Typography.h6
                                }

                                LineEdit {
                                    id: keyInput
                                    width: 260
                                    text: cipherVM.key
                                    placeholderText: cipherVM.keyHint || Lang.pages.cipher.keyPlaceholder
                                    onTextChanged: cipherVM.key = text
                                }
                            }

                            Column {
                                spacing: LayoutMetrics.spacing.xxs
                                visible: cipherVM.usesShift

                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    bold: false
                                    text: Lang.pages.cipher.shift
                                    textColor: Theme.textColor
                                    pixelSize: Typography.h6
                                }

                                SpinBox {
                                    from: 1
                                    to: 25
                                    stepSize: 1
                                    value: cipherVM.shift
                                    onValueChanged: cipherVM.shift = value
                                }
                            }

                            Column {
                                spacing: LayoutMetrics.spacing.xxs
                                visible: cipherVM.usesRails

                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    bold: false
                                    text: Lang.pages.cipher.rails
                                    textColor: Theme.textColor
                                    pixelSize: Typography.h6
                                }

                                SpinBox {
                                    from: 2
                                    to: 15
                                    stepSize: 1
                                    value: cipherVM.rails
                                    onValueChanged: cipherVM.rails = value
                                }
                            }

                            Column {
                                spacing: LayoutMetrics.spacing.xxs
                                visible: cipherVM.usesTurns

                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    bold: false
                                    text: Lang.pages.cipher.turns
                                    textColor: Theme.textColor
                                    pixelSize: Typography.h6
                                }

                                SpinBox {
                                    from: 2
                                    to: 20
                                    stepSize: 1
                                    value: cipherVM.turns
                                    onValueChanged: cipherVM.turns = value
                                }
                            }

                            Column {
                                spacing: LayoutMetrics.spacing.xxs
                                visible: cipherVM.usesPeriod

                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    bold: false
                                    text: Lang.pages.cipher.period
                                    textColor: Theme.textColor
                                    pixelSize: Typography.h6
                                }

                                SpinBox {
                                    from: 1
                                    to: 20
                                    stepSize: 1
                                    value: cipherVM.period
                                    onValueChanged: cipherVM.period = value
                                }
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
                            Button { buttonText: Lang.common.process; primary: true; isometric: true; heightMultiplier: 1.3; onPressed: cipherVM.processCipher() }
                            Button { buttonText: Lang.common.swap; iconPath: SVGLibrary.swap; onPressed: cipherVM.swapCipher() }
                            Button { buttonText: Lang.common.clear; iconPath: SVGLibrary.eraser; onPressed: cipherVM.clearCipher() }
                        }

                        CipherIO {
                            viewModel: cipherVM
                            inputProperty: "cipherInput"
                            outputProperty: "cipherOutput"
                            placeholderText: Lang.pages.cipher.cipherPlaceholder
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
                            text: Lang.pages.cipher.encryptionDesc
                            textColor: Theme.dividerColor
                            pixelSize: Typography.h6
                            width: parent.width
                            wrapMode: Text.WordWrap
                        }

                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: LayoutMetrics.spacing.xxs

                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                bold: false
                                text: Lang.pages.cipher.algorithm
                                textColor: Theme.textColor
                                pixelSize: Typography.h6
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

                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: LayoutMetrics.spacing.xxs

                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                bold: false
                                text: Lang.pages.cipher.passphrase
                                textColor: Theme.textColor
                                pixelSize: Typography.h6
                            }

                            Row {
                                spacing: LayoutMetrics.spacing.md

                                LineEdit {
                                    id: passphraseInput
                                    width: 260
                                    text: cipherVM.passphrase
                                    placeholderText: Lang.pages.cipher.passphrasePlaceholder
                                    echoMode: revealPassphrase.checked ? TextInput.Normal : TextInput.Password
                                    onTextChanged: cipherVM.passphrase = text
                                }

                                Switch {
                                    id: revealPassphrase
                                    text: Lang.pages.cipher.showPassphrase
                                }
                            }
                        }

                        Label {
                            bold: false
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: Lang.pages.cipher.encryptionWarning
                            textColor: Theme.dividerColor
                            pixelSize: Typography.h6
                            wrapMode: Text.WordWrap
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: LayoutMetrics.spacing.sm
                            Button { buttonText: Lang.common.encrypt; primary: true; isometric: true; heightMultiplier: 1.3; onPressed: cipherVM.encrypt() }
                            Button { buttonText: Lang.common.decrypt; onPressed: cipherVM.decrypt() }
                            Button { buttonText: Lang.common.clear; iconPath: SVGLibrary.eraser; onPressed: cipherVM.clearEncryption() }
                        }

                        CipherIO {
                            viewModel: cipherVM
                            inputProperty: "encryptionInput"
                            outputProperty: "encryptionOutput"
                            placeholderText: Lang.pages.cipher.encryptionPlaceholder
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
                            text: Lang.pages.cipher.hashingDesc
                            textColor: Theme.dividerColor
                            pixelSize: Typography.h6
                        }

                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: LayoutMetrics.spacing.xxs

                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                bold: false
                                text: Lang.pages.cipher.hashLabel
                                textColor: Theme.textColor
                                pixelSize: Typography.h6
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
                            Button { buttonText: Lang.common.hash; primary: true; isometric: true; heightMultiplier: 1.3; onPressed: cipherVM.processHash() }
                            Button { buttonText: Lang.common.clear; iconPath: SVGLibrary.eraser; onPressed: cipherVM.clearHash() }
                        }

                        CipherIO {
                            viewModel: cipherVM
                            inputProperty: "hashTextInput"
                            outputProperty: "hashTextOutput"
                            placeholderText: Lang.pages.cipher.hashPlaceholder
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
