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
    readonly property bool modeOps: numberToolsVM.mode === "Operations"

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        Column {
            id: pageColumn
            anchors.fill: parent
            anchors.margins: LayoutMetrics.spacing.lg
            spacing: LayoutMetrics.spacing.md

            Title {
                id: pageTitle
                text: "Number Tools"
                textColor: Theme.textColor
                pixelSize: Typography.h2
            }

            Label {
                id: pageSubtitle
                bold: false
                width: parent.width
                text: "Base conversion, GCD/LCM, factors, and integer operations."
                textColor: Theme.dividerColor
                pixelSize: Typography.h6
                wrapMode: Text.WordWrap
            }

            TabBar {
                id: modeTabs
                anchors.horizontalCenter: parent.horizontalCenter
                tabData: numberToolsVM.modes
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
                height: LayoutMetrics.spacing.xxs
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
                interactive: false

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: function(wheel) {
                        var step = wheel.pixelDelta.y !== 0
                                   ? wheel.pixelDelta.y * 2
                                   : wheel.angleDelta.y / 120 * LayoutMetrics.unit * 24
                        var maxY = Math.max(0, pageFlickable.contentHeight - pageFlickable.height)
                        pageFlickable.contentY = Math.max(0, Math.min(maxY, pageFlickable.contentY - step))
                        wheel.accepted = true
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    parent: pageFlickable
                    x: pageFlickable.mirrored ? 0 : pageFlickable.width - width
                    y: 0
                    height: pageFlickable.height
                    policy: ScrollBar.AsNeeded
                    visible: size < 1.0
                    padding: 0
                    implicitWidth: LayoutMetrics.unit * 1.2
                    minimumSize: 0.14

                    contentItem: Rectangle {
                        implicitWidth: LayoutMetrics.unit * 1.2
                        radius: 0
                        color: (parent.pressed || parent.hovered) ? Theme.textColor : Theme.dividerColor
                        Behavior on color {
                            enabled: LayoutMetrics.animationsEnabled
                            ColorAnimation { duration: 120 }
                        }
                    }
                }

                Column {
                    id: contentColumn
                    width: parent.width
                    spacing: LayoutMetrics.spacing.lg

                    Row {
                        width: parent.width
                        spacing: LayoutMetrics.spacing.md
                        visible: page.modeBase || page.modeOps || page.modeGcd

                        Label {
                            bold: false
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Input base"
                            textColor: Theme.textColor
                            pixelSize: Typography.h6
                        }

                        ComboBox {
                            width: Math.min(LayoutMetrics.unit * 22, parent.width * 0.38)
                            model: numberToolsVM.fromBases
                            scrollablePopup: true
                            maxVisibleItems: 10
                            currentIndex: {
                                var idx = numberToolsVM.fromBases.indexOf(numberToolsVM.fromBase)
                                return idx >= 0 ? idx : 0
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

                    Row {
                        width: parent.width
                        spacing: LayoutMetrics.spacing.md
                        visible: (page.modeBase || page.modeOps || page.modeGcd) && numberToolsVM.fromBase === "Custom"

                        Label {
                            bold: false
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Custom input base"
                            textColor: Theme.textColor
                            pixelSize: Typography.h6
                        }

                        LineEdit {
                            width: Math.min(LayoutMetrics.unit * 18, parent.width * 0.3)
                            placeholderText: "e.g. 43"
                            text: numberToolsVM.customFromBase
                            onTextEdited: numberToolsVM.setCustomFromBase(text)
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: LayoutMetrics.spacing.md
                        visible: page.modeBase

                        Label {
                            bold: false
                            anchors.verticalCenter: parent.verticalCenter
                            text: "To base"
                            textColor: Theme.textColor
                            pixelSize: Typography.h6
                        }

                        ComboBox {
                            width: Math.min(LayoutMetrics.unit * 22, parent.width * 0.38)
                            model: numberToolsVM.toBases
                            scrollablePopup: true
                            maxVisibleItems: 10
                            currentIndex: {
                                var idx = numberToolsVM.toBases.indexOf(numberToolsVM.toBase)
                                return idx >= 0 ? idx : 0
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

                    Row {
                        width: parent.width
                        spacing: LayoutMetrics.spacing.md
                        visible: page.modeBase && numberToolsVM.toBase === "Custom"

                        Label {
                            bold: false
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Custom base"
                            textColor: Theme.textColor
                            pixelSize: Typography.h6
                        }

                        LineEdit {
                            width: Math.min(LayoutMetrics.unit * 18, parent.width * 0.3)
                            placeholderText: "e.g. 43"
                            text: numberToolsVM.customToBase
                            onTextEdited: numberToolsVM.setCustomToBase(text)
                        }
                    }

                    Label {
                        bold: false
                        text: page.modeGcd ? "Integers (space/comma separated)" : (page.modeOps ? "A" : "Value")
                        textColor: Theme.textColor
                        pixelSize: Typography.h4
                    }

                    LineEdit {
                        width: parent.width
                        placeholderText: page.modeBase ? "e.g. 255, FF, 11111111"
                                      : page.modeGcd ? "e.g. 48 18 30"
                                      : page.modeFactors ? "e.g. 360"
                                      : "e.g. 12"
                        text: numberToolsVM.inputA
                        onTextEdited: numberToolsVM.setInputA(text)
                    }

                    Row {
                        width: parent.width
                        spacing: LayoutMetrics.spacing.md
                        visible: page.modeOps

                        Label {
                            bold: false
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Operation"
                            textColor: Theme.textColor
                            pixelSize: Typography.h6
                        }

                        ComboBox {
                            width: Math.min(LayoutMetrics.unit * 16, parent.width * 0.3)
                            model: numberToolsVM.operations
                            scrollablePopup: true
                            maxVisibleItems: 10
                            currentIndex: {
                                var idx = numberToolsVM.operations.indexOf(numberToolsVM.operation)
                                return idx >= 0 ? idx : 0
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

                    Label {
                        bold: false
                        visible: page.modeOps || page.modeGcd
                        text: page.modeGcd ? "Extra integer (optional)" : "B"
                        textColor: Theme.textColor
                        pixelSize: Typography.h4
                    }

                    LineEdit {
                        width: parent.width
                        visible: page.modeOps || page.modeGcd
                        placeholderText: page.modeOps ? "e.g. 5" : "e.g. 12 (optional)"
                        text: numberToolsVM.inputB
                        onTextEdited: numberToolsVM.setInputB(text)
                    }

                    Row {
                        spacing: LayoutMetrics.spacing.sm

                        Button {
                            buttonText: "Compute"
                            primary: true
                            isometric: true
                            heightMultiplier: 1.3
                            enabled: !numberToolsVM.computing
                            onPressed: numberToolsVM.process()
                        }
                        Button {
                            buttonText: "Clear"
                            iconPath: SVGLibrary.eraser
                            enabled: !numberToolsVM.computing
                            onPressed: numberToolsVM.clear()
                        }
                    }

                    ProgressBar {
                        width: parent.width
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
                            visible: numberToolsVM.status === "Done" || numberToolsVM.status === "Copied"
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
                        text: "Result"
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
                        placeholderText: "Results will appear here"
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
