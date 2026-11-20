import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import components

Item {
    id: page

    function processAction() {
        numberToolsVM.process()
    }

    readonly property bool modeBase: numberToolsVM.mode === "Base converter"
    readonly property bool modeGcd: numberToolsVM.mode === "GCD / LCM"
    readonly property bool modeFactors: numberToolsVM.mode === "Factors & divisors"
    readonly property bool modeBitwise: numberToolsVM.mode === "Bitwise"
    readonly property bool bitwiseCount: numberToolsVM.operation.indexOf("Shift") === 0
                                          || numberToolsVM.operation.indexOf("Rotate") === 0

    readonly property var modeOptions: [
        { id: "Base converter", label: Lang.pages.numberTools.modes.base },
        { id: "GCD / LCM", label: Lang.pages.numberTools.modes.gcd },
        { id: "Factors & divisors", label: Lang.pages.numberTools.modes.factors },
        { id: "Bitwise", label: Lang.pages.numberTools.modes.bitwise }
    ]
    readonly property var fromBaseOptions: [
        { id: "Auto", label: Lang.pages.numberTools.bases.auto },
        { id: "2 (Binary)", label: Lang.pages.numberTools.bases.binary },
        { id: "8 (Octal)", label: Lang.pages.numberTools.bases.octal },
        { id: "10 (Decimal)", label: Lang.pages.numberTools.bases.decimal },
        { id: "16 (Hex)", label: Lang.pages.numberTools.bases.hex },
        { id: "36", label: "36" },
        { id: "Custom", label: Lang.pages.numberTools.bases.custom }
    ]
    readonly property var toBaseOptions: [
        { id: "All common", label: Lang.pages.numberTools.bases.allCommon },
        { id: "2 (Binary)", label: Lang.pages.numberTools.bases.binary },
        { id: "8 (Octal)", label: Lang.pages.numberTools.bases.octal },
        { id: "10 (Decimal)", label: Lang.pages.numberTools.bases.decimal },
        { id: "16 (Hex)", label: Lang.pages.numberTools.bases.hex },
        { id: "36", label: "36" },
        { id: "Custom", label: Lang.pages.numberTools.bases.custom }
    ]
    readonly property var operationOptions: [
        { id: "AND", label: Lang.pages.numberTools.ops.and },
        { id: "OR", label: Lang.pages.numberTools.ops.or },
        { id: "XOR", label: Lang.pages.numberTools.ops.xor },
        { id: "NOT", label: Lang.pages.numberTools.ops.not },
        { id: "Shift left", label: Lang.pages.numberTools.ops.shl },
        { id: "Shift right", label: Lang.pages.numberTools.ops.shr },
        { id: "Rotate left", label: Lang.pages.numberTools.ops.rol },
        { id: "Rotate right", label: Lang.pages.numberTools.ops.ror }
    ]
    readonly property var bitwiseWidthOptions: [
        { id: "8", label: "8" },
        { id: "16", label: "16" },
        { id: "32", label: "32" },
        { id: "64", label: "64" }
    ]

    function modeLabels() {
        var out = []
        for (var i = 0; i < modeOptions.length; i++) out.push(modeOptions[i].label)
        return out
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
                text: Lang.pages.numberTools.title
                textColor: Theme.textColor
                pixelSize: Typography.h2
            }

            Label {
                id: pageSubtitle
                bold: false
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: Lang.pages.numberTools.subtitle
                textColor: Theme.dividerColor
                pixelSize: Typography.h6
                wrapMode: Text.WordWrap
            }

            TabBar {
                id: modeTabs
                anchors.horizontalCenter: parent.horizontalCenter
                tabData: page.modeLabels()
                active: page.visible
                currentIndex: 0
                Component.onCompleted: {
                    var idx = numberToolsVM.modes.indexOf(numberToolsVM.mode)
                    if (idx >= 0) modeTabs.currentIndex = idx
                }
                onCurrentIndexChanged: {
                    if (currentIndex >= 0 && currentIndex < numberToolsVM.modes.length) {
                        var m = numberToolsVM.modes[currentIndex]
                        if (m && m !== numberToolsVM.mode)
                            numberToolsVM.setMode(m)
                    }
                }
            }

            Connections {
                target: numberToolsVM
                function onModeChanged() {
                    var idx = numberToolsVM.modes.indexOf(numberToolsVM.mode)
                    if (idx >= 0 && idx !== modeTabs.currentIndex)
                        modeTabs.currentIndex = idx
                }
            }

            Rectangle {
                id: divider
                width: parent.width
                height: LayoutMetrics.divider.s
                color: Theme.dividerColor
            }

            Flickable {
                id: pageFlickable
                width: parent.width
                height: Math.max(0, parent.height - pageTitle.height - pageSubtitle.height
                                 - modeTabs.height - divider.height
                                 - pageColumn.spacing * 4)
                contentWidth: width
                contentHeight: contentColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                acceptedButtons: Qt.NoButton

                WheelScrollArea {
                    target: pageFlickable
                }

                ScrollBar.vertical: AppScrollBar {}

                TabSlide {
                    id: tabSlide
                    tabBar: modeTabs
                    target: contentColumn
                }

                Column {
                    id: contentColumn
                    width: parent.width
                    spacing: LayoutMetrics.spacing.md

                    Column {
                        width: parent.width
                        spacing: LayoutMetrics.spacing.xxs
                        visible: page.modeBase || page.modeBitwise || page.modeGcd

                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            bold: false
                            text: Lang.pages.numberTools.inputBase
                            textColor: Theme.textColor
                            pixelSize: Typography.h6
                        }

                        ComboBox {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.min(LayoutMetrics.unit * 22, parent.width * 0.38)
                            model: page.fromBaseOptions
                            textRole: "label"
                            valueRole: "id"
                            scrollablePopup: true
                            maxVisibleItems: 10
                            Component.onCompleted: {
                                var idx = numberToolsVM.fromBases.indexOf(numberToolsVM.fromBase)
                                if (idx >= 0) currentIndex = idx
                            }
                            onActivated: function(index) {
                                if (index >= 0 && index < numberToolsVM.fromBases.length)
                                    numberToolsVM.setFromBase(numberToolsVM.fromBases[index])
                            }
                            onCurrentIndexChanged: {
                                if (currentIndex >= 0 && currentIndex < numberToolsVM.fromBases.length) {
                                    var b = numberToolsVM.fromBases[currentIndex]
                                    if (b && b !== numberToolsVM.fromBase)
                                        numberToolsVM.setFromBase(b)
                                }
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: LayoutMetrics.spacing.xxs
                        visible: (page.modeBase || page.modeBitwise || page.modeGcd) && numberToolsVM.fromBase === "Custom"

                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            bold: false
                            text: Lang.pages.numberTools.customInputBase
                            textColor: Theme.textColor
                            pixelSize: Typography.h6
                        }

                        LineEdit {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.min(LayoutMetrics.unit * 18, parent.width * 0.3)
                            placeholderText: Lang.placeholders.customBase
                            text: numberToolsVM.customFromBase
                            onTextEdited: numberToolsVM.setCustomFromBase(text)
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: LayoutMetrics.spacing.xxs
                        visible: page.modeBase

                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            bold: false
                            text: Lang.pages.numberTools.toBase
                            textColor: Theme.textColor
                            pixelSize: Typography.h6
                        }

                        ComboBox {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.min(LayoutMetrics.unit * 22, parent.width * 0.38)
                            model: page.toBaseOptions
                            textRole: "label"
                            valueRole: "id"
                            scrollablePopup: true
                            maxVisibleItems: 10
                            Component.onCompleted: {
                                var idx = numberToolsVM.toBases.indexOf(numberToolsVM.toBase)
                                if (idx >= 0) currentIndex = idx
                            }
                            onActivated: function(index) {
                                if (index >= 0 && index < numberToolsVM.toBases.length)
                                    numberToolsVM.setToBase(numberToolsVM.toBases[index])
                            }
                            onCurrentIndexChanged: {
                                if (currentIndex >= 0 && currentIndex < numberToolsVM.toBases.length) {
                                    var b = numberToolsVM.toBases[currentIndex]
                                    if (b && b !== numberToolsVM.toBase)
                                        numberToolsVM.setToBase(b)
                                }
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: LayoutMetrics.spacing.xxs
                        visible: page.modeBase && numberToolsVM.toBase === "Custom"

                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            bold: false
                            text: Lang.pages.numberTools.customBase
                            textColor: Theme.textColor
                            pixelSize: Typography.h6
                        }

                        LineEdit {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.min(LayoutMetrics.unit * 18, parent.width * 0.3)
                            placeholderText: Lang.placeholders.customBase
                            text: numberToolsVM.customToBase
                            onTextEdited: numberToolsVM.setCustomToBase(text)
                        }
                    }

                    Label {
                        bold: false
                        text: page.modeGcd ? Lang.pages.numberTools.integersLabel
                                           : (page.modeBitwise ? Lang.pages.numberTools.aLabel
                                                               : Lang.pages.numberTools.valueLabel)
                        textColor: Theme.textColor
                        pixelSize: Typography.h4
                    }

                    LineEdit {
                        width: parent.width
                        placeholderText: page.modeBase ? Lang.pages.numberTools.placeholderBase
                                      : page.modeGcd ? Lang.pages.numberTools.placeholderGcd
                                      : page.modeFactors ? Lang.pages.numberTools.placeholderFactors
                                      : page.modeBitwise ? Lang.pages.numberTools.placeholderBitwiseA
                                      : Lang.pages.numberTools.placeholderDefault
                        text: numberToolsVM.inputA
                        onTextEdited: numberToolsVM.setInputA(text)
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: LayoutMetrics.spacing.lg
                        visible: page.modeBitwise

                        Column {
                            width: LayoutMetrics.unit * 22
                            spacing: LayoutMetrics.spacing.xxs

                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                bold: false
                                text: Lang.common.operation
                                textColor: Theme.textColor
                                pixelSize: Typography.h6
                            }

                            ComboBox {
                                width: parent.width
                                model: page.operationOptions
                                textRole: "label"
                                valueRole: "id"
                                scrollablePopup: true
                                maxVisibleItems: 10
                                Component.onCompleted: {
                                    var idx = numberToolsVM.operations.indexOf(numberToolsVM.operation)
                                    if (idx >= 0) currentIndex = idx
                                }
                                onActivated: function(index) {
                                    if (index >= 0 && index < numberToolsVM.operations.length)
                                        numberToolsVM.setOperation(numberToolsVM.operations[index])
                                }
                                onCurrentIndexChanged: {
                                    if (currentIndex >= 0 && currentIndex < numberToolsVM.operations.length) {
                                        var op = numberToolsVM.operations[currentIndex]
                                        if (op && op !== numberToolsVM.operation)
                                            numberToolsVM.setOperation(op)
                                    }
                                }
                            }
                        }

                        Column {
                            width: LayoutMetrics.unit * 18
                            spacing: LayoutMetrics.spacing.xxs
                            visible: numberToolsVM.operation !== "NOT"

                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                bold: false
                                text: page.bitwiseCount ? Lang.pages.numberTools.shiftRotateCount
                                                        : Lang.pages.numberTools.bLabel
                                textColor: Theme.textColor
                                pixelSize: Typography.h6
                            }

                            LineEdit {
                                width: parent.width
                                placeholderText: page.bitwiseCount ? Lang.pages.numberTools.placeholderCount
                                                                   : Lang.pages.numberTools.placeholderB
                                text: numberToolsVM.inputB
                                onTextEdited: numberToolsVM.setInputB(text)
                            }
                        }

                        Column {
                            width: LayoutMetrics.unit * 12
                            spacing: LayoutMetrics.spacing.xxs

                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                bold: false
                                text: Lang.common.width
                                textColor: Theme.textColor
                                pixelSize: Typography.h6
                            }

                            ComboBox {
                                width: parent.width
                                model: page.bitwiseWidthOptions
                                textRole: "label"
                                valueRole: "id"
                                scrollablePopup: true
                                maxVisibleItems: 4
                                Component.onCompleted: {
                                    var idx = numberToolsVM.bitwiseWidths.indexOf(numberToolsVM.bitwiseWidth)
                                    if (idx >= 0) currentIndex = idx
                                }
                                onActivated: function(index) {
                                    if (index >= 0 && index < numberToolsVM.bitwiseWidths.length)
                                        numberToolsVM.setBitwiseWidth(numberToolsVM.bitwiseWidths[index])
                                }
                                onCurrentIndexChanged: {
                                    if (currentIndex >= 0 && currentIndex < numberToolsVM.bitwiseWidths.length) {
                                        var w = numberToolsVM.bitwiseWidths[currentIndex]
                                        if (w && w !== numberToolsVM.bitwiseWidth)
                                            numberToolsVM.setBitwiseWidth(w)
                                    }
                                }
                            }
                        }
                    }

                    Label {
                        bold: false
                        visible: page.modeGcd
                        text: Lang.pages.numberTools.extraIntegerOptional
                        textColor: Theme.textColor
                        pixelSize: Typography.h4
                    }

                    LineEdit {
                        width: parent.width
                        visible: page.modeGcd
                        placeholderText: Lang.pages.numberTools.placeholderGcdB
                        text: numberToolsVM.inputB
                        onTextEdited: numberToolsVM.setInputB(text)
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: LayoutMetrics.spacing.sm

                        Button {
                            buttonText: Lang.pages.numberTools.compute
                            primary: true
                            isometric: true
                            heightMultiplier: 1.3
                            enabled: !numberToolsVM.computing
                            onPressed: numberToolsVM.process()
                        }
                        Button {
                            buttonText: Lang.common.clear
                            iconPath: SVGLibrary.eraser
                            enabled: !numberToolsVM.computing
                            onPressed: numberToolsVM.clear()
                        }
                    }

                    ProgressBar {
                        width: Math.min(parent.width * 0.8, LayoutMetrics.unit * 60)
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: page.modeFactors && (numberToolsVM.computing || numberToolsVM.progress > 0)
                        value: numberToolsVM.progress
                    }

                    Row {
                        spacing: LayoutMetrics.spacing.sm
                        visible: numberToolsVM.status !== ""

                        SVGObject {
                            anchors.verticalCenter: parent.verticalCenter
                            width: LayoutMetrics.size.iconS
                            height: LayoutMetrics.size.iconS
                            path: SVGLibrary.checkMark
                            color: Theme.textColor
                            visible: numberToolsVM.status === Lang.common.done
                                     || numberToolsVM.status === Lang.pages.numberTools.msgCopied
                                     || numberToolsVM.status === "Done"
                                     || numberToolsVM.status === "Copied"
                        }
                        Label {
                            bold: false
                            anchors.verticalCenter: parent.verticalCenter
                            text: numberToolsVM.status
                            textColor: Theme.textColor
                            pixelSize: Typography.h6
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: LayoutMetrics.spacing.sm
                        visible: numberToolsVM.error !== ""

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
                            text: numberToolsVM.error
                            textColor: "red"
                            pixelSize: Typography.h6
                            wrapMode: Text.WordWrap
                        }
                    }

                    Label {
                        bold: false
                        text: Lang.common.result
                        textColor: Theme.textColor
                        pixelSize: Typography.h4
                    }

                    TextEdit {
                        width: parent.width
                        height: Math.max(LayoutMetrics.unit * 22, page.height * 0.28)
                        readOnly: true
                        wrapMode: Text.Wrap
                        fontFamily: "JetBrains Mono"
                        fontPixelSize: Typography.body
                        text: numberToolsVM.output
                        placeholderText: Lang.pages.numberTools.resultPlaceholder
                        showCopyButton: true
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
