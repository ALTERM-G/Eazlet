import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import components

Item {
    id: page

    Layout.fillWidth: true
    Layout.fillHeight: true

    property string randomMode: "numbers"

    function processAction() {
        if (tabs.currentIndex === 0)
            generatorsVM.generatePassword()
        else if (tabs.currentIndex === 1)
            generatorsVM.generateLorem()
        else if (tabs.currentIndex === 2) {
            if (randomMode === "strings")
                generatorsVM.generateRandomString()
            else if (randomMode === "ips")
                generatorsVM.generateRandomIp()
            else if (randomMode === "ids")
                generatorsVM.generateRandomId()
            else if (randomMode === "colors")
                generatorsVM.generateRandomColor()
            else
                generatorsVM.generateRandom()
        } else
            generatorsVM.generateQr()
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
                text: "Generators"
                textColor: Theme.textColor
                pixelSize: Typography.h2
            }

            Label {
                id: pageSubtitle
                bold: false
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "Generate passwords, placeholder text, random values, IP addresses, IDs, colors, and QR codes."
                textColor: Theme.dividerColor
                pixelSize: Typography.h6
                wrapMode: Text.WordWrap
            }

            TabBar {
                id: tabs
                anchors.horizontalCenter: parent.horizontalCenter
                tabData: ["Password", "Lorem Ipsum", "Random", "QR Code"]
                active: page.visible
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
                                 - tabs.height - divider.height
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

                ScrollBar.vertical: AppScrollBar {}

                TabSlide {
                    id: tabSlide
                    tabBar: tabs
                    target: contentColumn
                }

                Column {
                    id: contentColumn
                    width: Math.max(0, parent.width - LayoutMetrics.unit * 1.6)
                    spacing: LayoutMetrics.spacing.lg

                    // Password ------------------------------------------------
                    Column {
                        id: passwordPanel
                        width: parent.width
                        spacing: LayoutMetrics.spacing.md
                        visible: tabs.currentIndex === 0

                        Label {
                            bold: false
                            width: parent.width
                            text: "Create passwords with the operating system's secure random source."
                            textColor: Theme.dividerColor
                            pixelSize: Typography.h6
                            wrapMode: Text.WordWrap
                        }

                        Row {
                            width: parent.width
                            spacing: LayoutMetrics.spacing.md

                            Label {
                                bold: false
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Length"
                                textColor: Theme.textColor
                                pixelSize: Typography.h6
                            }

                            SpinBox {
                                from: 8
                                to: 128
                                stepSize: 1
                                value: generatorsVM.passwordLength
                                onValueChanged: generatorsVM.passwordLength = value
                            }

                            Label {
                                bold: false
                                anchors.verticalCenter: parent.verticalCenter
                                text: "characters"
                                textColor: Theme.dividerColor
                                pixelSize: Typography.h6
                            }
                        }

                        Flow {
                            width: parent.width
                            spacing: LayoutMetrics.spacing.md

                            Switch {
                                text: "Uppercase"
                                checked: generatorsVM.includeUppercase
                                onCheckedChanged: generatorsVM.includeUppercase = checked
                            }
                            Switch {
                                text: "Lowercase"
                                checked: generatorsVM.includeLowercase
                                onCheckedChanged: generatorsVM.includeLowercase = checked
                            }
                            Switch {
                                text: "Digits"
                                checked: generatorsVM.includeDigits
                                onCheckedChanged: generatorsVM.includeDigits = checked
                            }
                            Switch {
                                text: "Symbols"
                                checked: generatorsVM.includeSymbols
                                onCheckedChanged: generatorsVM.includeSymbols = checked
                            }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: LayoutMetrics.spacing.sm

                            Button {
                                buttonText: "Generate"
                                primary: true
                                isometric: true
                                heightMultiplier: 1.3
                                onPressed: generatorsVM.generatePassword()
                            }
                            Button {
                                buttonText: "Copy"
                                iconPath: SVGLibrary.copy
                                enabled: generatorsVM.password.length > 0
                                onPressed: generatorsVM.copyPassword()
                            }
                        }

                        LineEdit {
                            width: parent.width
                            readOnly: true
                            text: generatorsVM.password
                            placeholderText: "Your password will appear here"
                            font.family: "JetBrains Mono"
                        }

                        Row {
                            spacing: LayoutMetrics.spacing.sm
                            visible: generatorsVM.password.length > 0

                            Label {
                                bold: false
                                text: "Strength:"
                                textColor: Theme.textColor
                                pixelSize: Typography.h6
                            }
                            Label {
                                bold: true
                                text: generatorsVM.passwordStrength
                                textColor: Theme.themeColor
                                pixelSize: Typography.h6
                            }
                            Label {
                                bold: false
                                text: "·  " + generatorsVM.passwordEntropy + " bits of entropy"
                                textColor: Theme.dividerColor
                                pixelSize: Typography.h6
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: LayoutMetrics.spacing.sm
                            visible: generatorsVM.passwordError !== ""

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
                                text: generatorsVM.passwordError
                                textColor: "red"
                                pixelSize: Typography.h6
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    // Lorem Ipsum ---------------------------------------------
                    Column {
                        id: loremPanel
                        width: parent.width
                        spacing: LayoutMetrics.spacing.md
                        visible: tabs.currentIndex === 1

                        Label {
                            bold: false
                            width: parent.width
                            text: "Generate classic filler text in paragraphs, sentences, or individual words."
                            textColor: Theme.dividerColor
                            pixelSize: Typography.h6
                            wrapMode: Text.WordWrap
                        }

                        Row {
                            width: parent.width
                            spacing: LayoutMetrics.spacing.md

                            Label {
                                bold: false
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Type"
                                textColor: Theme.textColor
                                pixelSize: Typography.h6
                            }

                            ComboBox {
                                id: loremTypeCombo
                                width: Math.min(LayoutMetrics.unit * 22, parent.width * 0.3)
                                model: generatorsVM.loremTypes
                                currentIndex: {
                                    var idx = generatorsVM.loremTypes.indexOf(generatorsVM.loremType)
                                    return idx >= 0 ? idx : 0
                                }
                                onCurrentIndexChanged: {
                                    if (currentIndex >= 0
                                            && currentIndex < generatorsVM.loremTypes.length) {
                                        var type = generatorsVM.loremTypes[currentIndex]
                                        if (type && type !== generatorsVM.loremType) {
                                            generatorsVM.loremType = type
                                            generatorsVM.generateLorem()
                                        }
                                    }
                                }
                            }

                            Label {
                                bold: false
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Amount"
                                textColor: Theme.textColor
                                pixelSize: Typography.h6
                            }

                            SpinBox {
                                from: 1
                                to: generatorsVM.loremMaxAmount
                                stepSize: 1
                                value: generatorsVM.loremAmount
                                onValueChanged: generatorsVM.loremAmount = value
                            }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: LayoutMetrics.spacing.sm

                            Button {
                                buttonText: "Generate"
                                primary: true
                                isometric: true
                                heightMultiplier: 1.3
                                onPressed: generatorsVM.generateLorem()
                            }
                            Button {
                                buttonText: "Copy"
                                iconPath: SVGLibrary.copy
                                enabled: generatorsVM.loremText.length > 0
                                onPressed: generatorsVM.copyLorem()
                            }
                        }

                        TextEdit {
                            width: parent.width
                            height: Math.max(LayoutMetrics.unit * 22, page.height * 0.32)
                            readOnly: true
                            wrapMode: Text.Wrap
                            fontFamily: "JetBrains Mono"
                            fontPixelSize: Typography.body
                            text: generatorsVM.loremText
                            placeholderText: "Generated Lorem ipsum will appear here"
                            showCopyButton: true
                        }

                        Row {
                            width: parent.width
                            spacing: LayoutMetrics.spacing.sm
                            visible: generatorsVM.loremError !== ""

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
                                text: generatorsVM.loremError
                                textColor: "red"
                                pixelSize: Typography.h6
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    // Random --------------------------------------------------
                    Column {
                        id: randomHeader
                        width: parent.width
                        spacing: LayoutMetrics.spacing.md
                        visible: tabs.currentIndex === 2

                        Label {
                            bold: false
                            width: parent.width
                            text: "Generate random numbers, strings, IP addresses, IDs, or colors using the operating system's secure random source."
                            textColor: Theme.dividerColor
                            pixelSize: Typography.h6
                            wrapMode: Text.WordWrap
                        }

                        Grid {
                            id: randomModeGrid
                            width: parent.width
                            columns: Math.max(1, Math.min(5,
                                      Math.floor(width / (LayoutMetrics.unit * 12))))
                            spacing: LayoutMetrics.spacing.sm

                            readonly property real cellWidth: (width
                                - spacing * (columns - 1)) / Math.max(1, columns)

                            Button {
                                width: randomModeGrid.cellWidth
                                buttonText: "Numbers"
                                primary: page.randomMode === "numbers"
                                onPressed: page.randomMode = "numbers"
                            }
                            Button {
                                width: randomModeGrid.cellWidth
                                buttonText: "Strings"
                                primary: page.randomMode === "strings"
                                onPressed: page.randomMode = "strings"
                            }
                            Button {
                                width: randomModeGrid.cellWidth
                                buttonText: "IPs"
                                primary: page.randomMode === "ips"
                                onPressed: page.randomMode = "ips"
                            }
                            Button {
                                width: randomModeGrid.cellWidth
                                buttonText: "IDs"
                                primary: page.randomMode === "ids"
                                onPressed: page.randomMode = "ids"
                            }
                            Button {
                                width: randomModeGrid.cellWidth
                                buttonText: "Colors"
                                primary: page.randomMode === "colors"
                                onPressed: page.randomMode = "colors"
                            }
                        }
                    }

                    // Random Numbers ------------------------------------------
                    Column {
                        id: randomPanel
                        width: parent.width
                        spacing: LayoutMetrics.spacing.md
                        visible: tabs.currentIndex === 2 && page.randomMode === "numbers"

                        Flow {
                            width: parent.width
                            spacing: LayoutMetrics.spacing.md

                            Row {
                                spacing: LayoutMetrics.spacing.md

                                Label {
                                    bold: false
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Minimum"
                                    textColor: Theme.textColor
                                    pixelSize: Typography.h6
                                }

                                SpinBox {
                                    from: -1000000
                                    to: 1000000
                                    stepSize: 1
                                    value: generatorsVM.randomMin
                                    onValueChanged: generatorsVM.randomMin = value
                                }
                            }

                            Row {
                                spacing: LayoutMetrics.spacing.md

                                Label {
                                    bold: false
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Maximum"
                                    textColor: Theme.textColor
                                    pixelSize: Typography.h6
                                }

                                SpinBox {
                                    from: -1000000
                                    to: 1000000
                                    stepSize: 1
                                    value: generatorsVM.randomMax
                                    onValueChanged: generatorsVM.randomMax = value
                                }
                            }

                            Row {
                                spacing: LayoutMetrics.spacing.md

                                Label {
                                    bold: false
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Count"
                                    textColor: Theme.textColor
                                    pixelSize: Typography.h6
                                }

                                SpinBox {
                                    from: 1
                                    to: 1000
                                    stepSize: 1
                                    value: generatorsVM.randomCount
                                    onValueChanged: generatorsVM.randomCount = value
                                }
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: LayoutMetrics.spacing.lg

                            Switch {
                                text: "Unique numbers"
                                checked: generatorsVM.randomUnique
                                onCheckedChanged: generatorsVM.randomUnique = checked
                            }

                            Label {
                                bold: false
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Order"
                                textColor: Theme.textColor
                                pixelSize: Typography.h6
                            }

                            ComboBox {
                                width: Math.min(LayoutMetrics.unit * 18, parent.width * 0.22)
                                model: generatorsVM.randomSorts
                                currentIndex: {
                                    var idx = generatorsVM.randomSorts.indexOf(generatorsVM.randomSort)
                                    return idx >= 0 ? idx : 0
                                }
                                onCurrentIndexChanged: {
                                    if (currentIndex >= 0
                                            && currentIndex < generatorsVM.randomSorts.length) {
                                        var sort = generatorsVM.randomSorts[currentIndex]
                                        if (sort && sort !== generatorsVM.randomSort)
                                            generatorsVM.randomSort = sort
                                    }
                                }
                            }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: LayoutMetrics.spacing.sm

                            Button {
                                buttonText: "Generate"
                                primary: true
                                isometric: true
                                heightMultiplier: 1.3
                                onPressed: generatorsVM.generateRandom()
                            }
                            Button {
                                buttonText: "Copy"
                                iconPath: SVGLibrary.copy
                                enabled: generatorsVM.randomOutput.length > 0
                                onPressed: generatorsVM.copyRandom()
                            }
                        }

                        TextEdit {
                            width: parent.width
                            height: Math.max(LayoutMetrics.unit * 18, page.height * 0.26)
                            readOnly: true
                            wrapMode: Text.Wrap
                            fontFamily: "JetBrains Mono"
                            fontPixelSize: Typography.body
                            text: generatorsVM.randomOutput
                            placeholderText: "Generated numbers will appear here"
                            showCopyButton: true
                        }

                        Row {
                            width: parent.width
                            spacing: LayoutMetrics.spacing.sm
                            visible: generatorsVM.randomError !== ""

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
                                text: generatorsVM.randomError
                                textColor: "red"
                                pixelSize: Typography.h6
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    // Random Strings ------------------------------------------
                    Column {
                        id: randomStringPanel
                        width: parent.width
                        spacing: LayoutMetrics.spacing.md
                        visible: tabs.currentIndex === 2 && page.randomMode === "strings"

                        Flow {
                            width: parent.width
                            spacing: LayoutMetrics.spacing.md

                            Row {
                                spacing: LayoutMetrics.spacing.md

                                Label {
                                    bold: false
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Length"
                                    textColor: Theme.textColor
                                    pixelSize: Typography.h6
                                }

                                SpinBox {
                                    from: 1
                                    to: 256
                                    stepSize: 1
                                    value: generatorsVM.randomStringLength
                                    onValueChanged: generatorsVM.randomStringLength = value
                                }

                                Label {
                                    bold: false
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "characters"
                                    textColor: Theme.dividerColor
                                    pixelSize: Typography.h6
                                }
                            }

                            Row {
                                spacing: LayoutMetrics.spacing.md

                                Label {
                                    bold: false
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Count"
                                    textColor: Theme.textColor
                                    pixelSize: Typography.h6
                                }

                                SpinBox {
                                    from: 1
                                    to: 100
                                    stepSize: 1
                                    value: generatorsVM.randomStringCount
                                    onValueChanged: generatorsVM.randomStringCount = value
                                }
                            }
                        }

                        Flow {
                            width: parent.width
                            spacing: LayoutMetrics.spacing.md

                            Switch {
                                text: "Uppercase"
                                checked: generatorsVM.randomStringUppercase
                                onCheckedChanged: generatorsVM.randomStringUppercase = checked
                            }
                            Switch {
                                text: "Lowercase"
                                checked: generatorsVM.randomStringLowercase
                                onCheckedChanged: generatorsVM.randomStringLowercase = checked
                            }
                            Switch {
                                text: "Digits"
                                checked: generatorsVM.randomStringDigits
                                onCheckedChanged: generatorsVM.randomStringDigits = checked
                            }
                            Switch {
                                text: "Symbols"
                                checked: generatorsVM.randomStringSymbols
                                onCheckedChanged: generatorsVM.randomStringSymbols = checked
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: LayoutMetrics.spacing.xxs

                            Switch {
                                text: "Exclude ambiguous characters"
                                checked: generatorsVM.randomStringExcludeAmbiguous
                                onCheckedChanged: generatorsVM.randomStringExcludeAmbiguous = checked
                            }

                            Label {
                                bold: false
                                width: parent.width
                                text: "Removes characters that are easy to confuse, such as O, 0, I, l, 1 and |."
                                textColor: Theme.dividerColor
                                pixelSize: Typography.h6
                                wrapMode: Text.WordWrap
                            }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: LayoutMetrics.spacing.sm

                            Button {
                                buttonText: "Generate"
                                primary: true
                                isometric: true
                                heightMultiplier: 1.3
                                onPressed: generatorsVM.generateRandomString()
                            }
                            Button {
                                buttonText: "Copy"
                                iconPath: SVGLibrary.copy
                                enabled: generatorsVM.randomStringOutput.length > 0
                                onPressed: generatorsVM.copyRandomString()
                            }
                        }

                        TextEdit {
                            width: parent.width
                            height: Math.max(LayoutMetrics.unit * 18, page.height * 0.26)
                            readOnly: true
                            wrapMode: Text.Wrap
                            fontFamily: "JetBrains Mono"
                            fontPixelSize: Typography.body
                            text: generatorsVM.randomStringOutput
                            placeholderText: "Generated strings will appear here"
                            showCopyButton: true
                        }

                        Row {
                            width: parent.width
                            spacing: LayoutMetrics.spacing.sm
                            visible: generatorsVM.randomStringError !== ""

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
                                text: generatorsVM.randomStringError
                                textColor: "red"
                                pixelSize: Typography.h6
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    // Random IPs ----------------------------------------------
                    Column {
                        id: randomIpPanel
                        width: parent.width
                        spacing: LayoutMetrics.spacing.md
                        visible: tabs.currentIndex === 2 && page.randomMode === "ips"

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: LayoutMetrics.spacing.sm

                            Button {
                                buttonText: "IPv4"
                                primary: generatorsVM.randomIpVersion === "IPv4"
                                onPressed: generatorsVM.randomIpVersion = "IPv4"
                            }
                            Button {
                                buttonText: "IPv6"
                                primary: generatorsVM.randomIpVersion === "IPv6"
                                onPressed: generatorsVM.randomIpVersion = "IPv6"
                            }
                        }

                        Flow {
                            width: parent.width
                            spacing: LayoutMetrics.spacing.md

                            Row {
                                spacing: LayoutMetrics.spacing.md

                                Label {
                                    bold: false
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Count"
                                    textColor: Theme.textColor
                                    pixelSize: Typography.h6
                                }

                                SpinBox {
                                    from: 1
                                    to: 100
                                    stepSize: 1
                                    value: generatorsVM.randomIpCount
                                    onValueChanged: generatorsVM.randomIpCount = value
                                }
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: LayoutMetrics.spacing.xxs

                            Switch {
                                text: "Private addresses only"
                                checked: generatorsVM.randomIpPrivate
                                onCheckedChanged: generatorsVM.randomIpPrivate = checked
                            }

                            Label {
                                bold: false
                                width: parent.width
                                text: "Private IPv4 uses 10.0.0.0/8, 172.16.0.0/12, and 192.168.0.0/16; private IPv6 uses fd00::/8."
                                textColor: Theme.dividerColor
                                pixelSize: Typography.h6
                                wrapMode: Text.WordWrap
                            }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: LayoutMetrics.spacing.sm

                            Button {
                                buttonText: "Generate"
                                primary: true
                                isometric: true
                                heightMultiplier: 1.3
                                onPressed: generatorsVM.generateRandomIp()
                            }
                            Button {
                                buttonText: "Copy"
                                iconPath: SVGLibrary.copy
                                enabled: generatorsVM.randomIpOutput.length > 0
                                onPressed: generatorsVM.copyRandomIp()
                            }
                        }

                        TextEdit {
                            width: parent.width
                            height: Math.max(LayoutMetrics.unit * 18, page.height * 0.26)
                            readOnly: true
                            wrapMode: Text.Wrap
                            fontFamily: "JetBrains Mono"
                            fontPixelSize: Typography.body
                            text: generatorsVM.randomIpOutput
                            placeholderText: "Generated IP addresses will appear here"
                            showCopyButton: true
                        }
                    }

                    // Random IDs ----------------------------------------------
                    Column {
                        id: randomIdPanel
                        width: parent.width
                        spacing: LayoutMetrics.spacing.md
                        visible: tabs.currentIndex === 2 && page.randomMode === "ids"

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: LayoutMetrics.spacing.sm

                            Button {
                                buttonText: "UUID v4"
                                primary: generatorsVM.randomIdFormat === "UUID v4"
                                onPressed: generatorsVM.randomIdFormat = "UUID v4"
                            }
                            Button {
                                buttonText: "Short ID"
                                primary: generatorsVM.randomIdFormat === "Short ID"
                                onPressed: generatorsVM.randomIdFormat = "Short ID"
                            }
                            Button {
                                buttonText: "Numeric"
                                primary: generatorsVM.randomIdFormat === "Numeric"
                                onPressed: generatorsVM.randomIdFormat = "Numeric"
                            }
                        }

                        Flow {
                            width: parent.width
                            spacing: LayoutMetrics.spacing.md

                            Row {
                                spacing: LayoutMetrics.spacing.md

                                Label {
                                    bold: false
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Count"
                                    textColor: Theme.textColor
                                    pixelSize: Typography.h6
                                }

                                SpinBox {
                                    from: 1
                                    to: 100
                                    stepSize: 1
                                    value: generatorsVM.randomIdCount
                                    onValueChanged: generatorsVM.randomIdCount = value
                                }
                            }

                            Row {
                                spacing: LayoutMetrics.spacing.md
                                visible: generatorsVM.randomIdFormat !== "UUID v4"

                                Label {
                                    bold: false
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: generatorsVM.randomIdFormat === "Numeric" ? "Digits" : "Length"
                                    textColor: Theme.textColor
                                    pixelSize: Typography.h6
                                }

                                SpinBox {
                                    from: 4
                                    to: 64
                                    stepSize: 1
                                    value: generatorsVM.randomIdLength
                                    onValueChanged: generatorsVM.randomIdLength = value
                                }

                                Label {
                                    bold: false
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: generatorsVM.randomIdFormat === "Numeric" ? "digits" : "characters"
                                    textColor: Theme.dividerColor
                                    pixelSize: Typography.h6
                                }
                            }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: LayoutMetrics.spacing.sm

                            Button {
                                buttonText: "Generate"
                                primary: true
                                isometric: true
                                heightMultiplier: 1.3
                                onPressed: generatorsVM.generateRandomId()
                            }
                            Button {
                                buttonText: "Copy"
                                iconPath: SVGLibrary.copy
                                enabled: generatorsVM.randomIdOutput.length > 0
                                onPressed: generatorsVM.copyRandomId()
                            }
                        }

                        TextEdit {
                            width: parent.width
                            height: Math.max(LayoutMetrics.unit * 18, page.height * 0.26)
                            readOnly: true
                            wrapMode: Text.Wrap
                            fontFamily: "JetBrains Mono"
                            fontPixelSize: Typography.body
                            text: generatorsVM.randomIdOutput
                            placeholderText: "Generated IDs will appear here"
                            showCopyButton: true
                        }
                    }

                    // Random Colors -------------------------------------------
                    Column {
                        id: randomColorPanel
                        width: parent.width
                        spacing: LayoutMetrics.spacing.md
                        visible: tabs.currentIndex === 2 && page.randomMode === "colors"

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: LayoutMetrics.spacing.sm

                            Button {
                                buttonText: "HEX"
                                primary: generatorsVM.randomColorFormat === "HEX"
                                onPressed: generatorsVM.randomColorFormat = "HEX"
                            }
                            Button {
                                buttonText: "RGB"
                                primary: generatorsVM.randomColorFormat === "RGB"
                                onPressed: generatorsVM.randomColorFormat = "RGB"
                            }
                            Button {
                                buttonText: "HSL"
                                primary: generatorsVM.randomColorFormat === "HSL"
                                onPressed: generatorsVM.randomColorFormat = "HSL"
                            }
                        }

                        Flow {
                            width: parent.width
                            spacing: LayoutMetrics.spacing.md

                            Row {
                                spacing: LayoutMetrics.spacing.md

                                Label {
                                    bold: false
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Count"
                                    textColor: Theme.textColor
                                    pixelSize: Typography.h6
                                }

                                SpinBox {
                                    from: 1
                                    to: 24
                                    stepSize: 1
                                    value: generatorsVM.randomColorCount
                                    onValueChanged: generatorsVM.randomColorCount = value
                                }
                            }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: LayoutMetrics.spacing.sm

                            Button {
                                buttonText: "Generate"
                                primary: true
                                isometric: true
                                heightMultiplier: 1.3
                                onPressed: generatorsVM.generateRandomColor()
                            }
                            Button {
                                buttonText: "Copy"
                                iconPath: SVGLibrary.copy
                                enabled: generatorsVM.randomColorOutput.length > 0
                                onPressed: generatorsVM.copyRandomColor()
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: LayoutMetrics.spacing.sm
                            visible: generatorsVM.randomColorList.length > 0

                            Repeater {
                                model: generatorsVM.randomColorList

                                delegate: Rectangle {
                                    id: colorRow
                                    width: parent.width
                                    height: LayoutMetrics.unit * 4.5
                                    radius: LayoutMetrics.radius.s
                                    color: modelData
                                    border.width: LayoutMetrics.border.m
                                    border.color: colorMouse.containsMouse
                                                  ? Theme.themeColor : Theme.borderColor

                                    Rectangle {
                                        id: codeBox
                                        anchors.left: parent.left
                                        anchors.leftMargin: LayoutMetrics.spacing.sm
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: codeRow.implicitWidth + LayoutMetrics.spacing.md
                                        height: LayoutMetrics.unit * 3
                                        radius: LayoutMetrics.radius.s
                                        color: Theme.inputBackgroundColor
                                        border.width: LayoutMetrics.border.m
                                        border.color: colorMouse.containsMouse
                                                      ? Theme.themeColor : Theme.borderColor

                                        Row {
                                            id: codeRow
                                            anchors.centerIn: parent
                                            spacing: LayoutMetrics.spacing.xs

                                            Label {
                                                anchors.verticalCenter: parent.verticalCenter
                                                bold: false
                                                text: generatorsVM.randomColorCodes[index] || modelData
                                                textColor: Theme.textColor
                                                pixelSize: Typography.body
                                                font.family: "JetBrains Mono"
                                            }

                                            SVGObject {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: LayoutMetrics.size.iconS * 0.75
                                                height: width
                                                path: SVGLibrary.copy
                                                color: colorMouse.containsMouse
                                                       ? Theme.themeColor : Theme.dividerColor
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: colorMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: generatorsVM.copyColorCode(
                                                       generatorsVM.randomColorCodes[index]
                                                       || modelData)
                                    }
                                }
                            }
                        }
                    }

                    // QR Code --------------------------------------------------
                    Column {
                        id: qrPanel
                        width: parent.width
                        spacing: LayoutMetrics.spacing.md
                        visible: tabs.currentIndex === 3

                        Label {
                            bold: false
                            width: parent.width
                            text: "Turn a URL or short piece of text into a scannable QR code."
                            textColor: Theme.dividerColor
                            pixelSize: Typography.h6
                            wrapMode: Text.WordWrap
                        }

                        Row {
                            width: parent.width
                            spacing: LayoutMetrics.spacing.xl

                            Column {
                                id: qrControls
                                width: Math.max(0, parent.width - qrPreview.width - parent.spacing)
                                spacing: LayoutMetrics.spacing.md

                                Label {
                                    bold: false
                                    text: "URL or text"
                                    textColor: Theme.textColor
                                    pixelSize: Typography.h6
                                }

                                LineEdit {
                                    width: parent.width
                                    text: generatorsVM.qrUrl
                                    placeholderText: "https://example.com"
                                    onTextEdited: generatorsVM.qrUrl = text
                                    onEditingFinished: generatorsVM.generateQr()
                                }

                                Flow {
                                    width: parent.width
                                    spacing: LayoutMetrics.spacing.md

                                    Button {
                                        buttonText: "Generate QR Code"
                                        primary: true
                                        isometric: true
                                        heightMultiplier: 1.3
                                        onPressed: generatorsVM.generateQr()
                                    }

                                    Button {
                                        buttonText: "Download"
                                        iconPath: SVGLibrary.downloader
                                        enabled: generatorsVM.qrImageSource !== ""
                                        onPressed: qrFileDialog.open()
                                    }
                                }

                                Row {
                                    width: parent.width
                                    spacing: LayoutMetrics.spacing.md

                                    Label {
                                        bold: false
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Resolution"
                                        textColor: Theme.textColor
                                        pixelSize: Typography.h6
                                    }

                                    ComboBox {
                                        width: Math.min(LayoutMetrics.unit * 12, parent.width * 0.24)
                                        model: generatorsVM.qrResolutions
                                        currentIndex: {
                                            var idx = generatorsVM.qrResolutions.indexOf(generatorsVM.qrResolution)
                                            return idx >= 0 ? idx : 0
                                        }
                                        onCurrentIndexChanged: {
                                            if (currentIndex >= 0
                                                    && currentIndex < generatorsVM.qrResolutions.length) {
                                                var resolution = generatorsVM.qrResolutions[currentIndex]
                                                if (resolution && resolution !== generatorsVM.qrResolution)
                                                    generatorsVM.qrResolution = resolution
                                            }
                                        }
                                    }

                                    Label {
                                        bold: false
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "px"
                                        textColor: Theme.dividerColor
                                        pixelSize: Typography.h6
                                    }
                                }

                                Label {
                                    bold: false
                                    width: parent.width
                                    text: "The QR code is generated locally. Error correction level M is used."
                                    textColor: Theme.dividerColor
                                    pixelSize: Typography.h6
                                    wrapMode: Text.WordWrap
                                }

                                Label {
                                    bold: false
                                    width: parent.width
                                    text: generatorsVM.qrSavedMessage
                                    textColor: Theme.themeColor
                                    pixelSize: Typography.h6
                                    wrapMode: Text.WordWrap
                                    visible: generatorsVM.qrSavedMessage !== ""
                                }

                                Row {
                                    width: parent.width
                                    spacing: LayoutMetrics.spacing.sm
                                    visible: generatorsVM.qrError !== ""

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
                                        text: generatorsVM.qrError
                                        textColor: "red"
                                        pixelSize: Typography.h6
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }

                            Rectangle {
                                id: qrPreview
                                width: Math.min(LayoutMetrics.unit * 34, page.width * 0.28)
                                height: width
                                // QR codes must keep square corners so the finder
                                // patterns stay readable and the preview is not clipped.
                                radius: 0
                                color: "white"
                                border.color: Qt.rgba(Theme.textColor.r, Theme.textColor.g,
                                                      Theme.textColor.b, 0.35)
                                border.width: LayoutMetrics.border.m
                                clip: true

                                Image {
                                    id: qrPreviewImage
                                    anchors.fill: parent
                                    anchors.margins: qrPreview.border.width
                                    source: generatorsVM.qrImageSource
                                    fillMode: Image.PreserveAspectFit
                                    smooth: false
                                    mipmap: false
                                    visible: source !== ""
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: qrPreview.border.width
                                    visible: !qrPreviewImage.visible
                                    color: Theme.inputBackgroundColor

                                    Label {
                                        anchors.centerIn: parent
                                        width: parent.width * 0.8
                                        horizontalAlignment: Text.AlignHCenter
                                        wrapMode: Text.WordWrap
                                        bold: false
                                        text: "Enter a URL to preview its QR code"
                                        textColor: Theme.dividerColor
                                        pixelSize: Typography.h6
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    FileDialog {
        id: qrFileDialog
        title: "Save QR Code"
        fileMode: FileDialog.SaveFile
        defaultSuffix: "png"
        nameFilters: ["PNG images (*.png)"]
        onAccepted: generatorsVM.saveQr(selectedFile.toString())
    }
}
