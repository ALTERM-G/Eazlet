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

    readonly property var loremTypeOptions: [
        { id: "Paragraphs", label: Lang.pages.generators.paragraphs },
        { id: "Sentences", label: Lang.pages.generators.sentences },
        { id: "Words", label: Lang.pages.generators.words }
    ]
    readonly property var randomSortOptions: [
        { id: "As generated", label: Lang.pages.generators.asGenerated },
        { id: "Ascending", label: Lang.options.textTools.sortOrder.ascending },
        { id: "Descending", label: Lang.options.textTools.sortOrder.descending }
    ]

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
                text: Lang.pages.generators.title
                textColor: Theme.textColor
                pixelSize: Typography.h2
            }

            Label {
                id: pageSubtitle
                bold: false
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: Lang.pages.generators.subtitle
                textColor: Theme.dividerColor
                pixelSize: Typography.h6
                wrapMode: Text.WordWrap
            }

            TabBar {
                id: tabs
                anchors.horizontalCenter: parent.horizontalCenter
                tabData: [Lang.pages.generators.tabPassword, Lang.pages.generators.tabLorem, Lang.pages.generators.tabRandom, Lang.pages.generators.tabQr]
                active: page.visible
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
                                 - tabs.height - divider.height
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
                    tabBar: tabs
                    target: contentColumn
                }

                Column {
                    id: contentColumn
                    width: parent.width
                    spacing: LayoutMetrics.spacing.md

                    // Password ------------------------------------------------
                    Column {
                        id: passwordPanel
                        width: parent.width
                        spacing: LayoutMetrics.spacing.md
                        visible: tabs.currentIndex === 0

                        Label {
                            bold: false
                            width: parent.width
                            text: Lang.pages.generators.passwordDesc
                            textColor: Theme.dividerColor
                            pixelSize: Typography.h6
                            wrapMode: Text.WordWrap
                        }

                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: LayoutMetrics.spacing.xxs

                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                bold: false
                                text: Lang.common.length
                                textColor: Theme.textColor
                                pixelSize: Typography.h6
                            }

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: LayoutMetrics.spacing.md

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
                                    text: Lang.pages.generators.charactersUnit
                                    textColor: Theme.dividerColor
                                    pixelSize: Typography.h6
                                }
                            }
                        }

                        Flow {
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
                            spacing: LayoutMetrics.spacing.md

                            Switch {
                                text: Lang.pages.generators.uppercase
                                checked: generatorsVM.includeUppercase
                                onCheckedChanged: generatorsVM.includeUppercase = checked
                            }
                            Switch {
                                text: Lang.pages.generators.lowercase
                                checked: generatorsVM.includeLowercase
                                onCheckedChanged: generatorsVM.includeLowercase = checked
                            }
                            Switch {
                                text: Lang.pages.generators.digits
                                checked: generatorsVM.includeDigits
                                onCheckedChanged: generatorsVM.includeDigits = checked
                            }
                            Switch {
                                text: Lang.pages.generators.symbols
                                checked: generatorsVM.includeSymbols
                                onCheckedChanged: generatorsVM.includeSymbols = checked
                            }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: LayoutMetrics.spacing.sm

                            Button {
                                buttonText: Lang.common.generate
                                primary: true
                                isometric: true
                                heightMultiplier: 1.3
                                onPressed: generatorsVM.generatePassword()
                            }
                            Button {
                                buttonText: Lang.common.copy
                                iconPath: SVGLibrary.copy
                                enabled: generatorsVM.password.length > 0
                                onPressed: generatorsVM.copyPassword()
                            }
                        }

                        LineEdit {
                            width: parent.width
                            readOnly: true
                            text: generatorsVM.password
                            placeholderText: Lang.pages.generators.passwordPlaceholder
                            font.family: "JetBrains Mono"
                        }

                        Row {
                            spacing: LayoutMetrics.spacing.sm
                            visible: generatorsVM.password.length > 0

                            Label {
                                bold: false
                                text: Lang.pages.generators.strength
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
                                text: "·  " + generatorsVM.passwordEntropy + " " + Lang.pages.generators.bitsOfEntropy
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
                            text: Lang.pages.generators.loremDesc
                            textColor: Theme.dividerColor
                            pixelSize: Typography.h6
                            wrapMode: Text.WordWrap
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: LayoutMetrics.spacing.lg

                            Column {
                                width: Math.min(LayoutMetrics.unit * 22, contentColumn.width * 0.3)
                                spacing: LayoutMetrics.spacing.xxs

                                Label {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    bold: false
                                    text: Lang.pages.generators.type
                                    textColor: Theme.textColor
                                    pixelSize: Typography.h6
                                }

                                ComboBox {
                                    id: loremTypeCombo
                                    width: parent.width
                                    model: page.loremTypeOptions
                                    textRole: "label"
                                    valueRole: "id"
                                    Component.onCompleted: {
                                        var idx = generatorsVM.loremTypes.indexOf(generatorsVM.loremType)
                                        if (idx >= 0) currentIndex = idx
                                    }
                                    onActivated: function(index) {
                                        if (index >= 0 && index < generatorsVM.loremTypes.length) {
                                            var type = generatorsVM.loremTypes[index]
                                            if (type && type !== generatorsVM.loremType) {
                                                generatorsVM.loremType = type
                                                generatorsVM.generateLorem()
                                            }
                                        }
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
                            }

                            Column {
                                spacing: LayoutMetrics.spacing.xxs

                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    bold: false
                                    text: Lang.pages.generators.amount
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
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: LayoutMetrics.spacing.sm

                            Button {
                                buttonText: Lang.common.generate
                                primary: true
                                isometric: true
                                heightMultiplier: 1.3
                                onPressed: generatorsVM.generateLorem()
                            }
                            Button {
                                buttonText: Lang.common.copy
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
                            placeholderText: Lang.pages.generators.loremPlaceholder
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
                            text: Lang.pages.generators.randomDesc
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
                                buttonText: Lang.pages.generators.numbers
                                primary: page.randomMode === "numbers"
                                onPressed: page.randomMode = "numbers"
                            }
                            Button {
                                width: randomModeGrid.cellWidth
                                buttonText: Lang.pages.generators.strings
                                primary: page.randomMode === "strings"
                                onPressed: page.randomMode = "strings"
                            }
                            Button {
                                width: randomModeGrid.cellWidth
                                buttonText: Lang.pages.generators.ips
                                primary: page.randomMode === "ips"
                                onPressed: page.randomMode = "ips"
                            }
                            Button {
                                width: randomModeGrid.cellWidth
                                buttonText: Lang.pages.generators.ids
                                primary: page.randomMode === "ids"
                                onPressed: page.randomMode = "ids"
                            }
                            Button {
                                width: randomModeGrid.cellWidth
                                buttonText: Lang.pages.generators.colors
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
                            spacing: LayoutMetrics.spacing.md

                            Column {
                                spacing: LayoutMetrics.spacing.xxs

                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    bold: false
                                    text: Lang.pages.generators.minimum
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

                            Column {
                                spacing: LayoutMetrics.spacing.xxs

                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    bold: false
                                    text: Lang.pages.generators.maximum
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

                            Column {
                                spacing: LayoutMetrics.spacing.xxs

                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    bold: false
                                    text: Lang.common.count
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

                        Flow {
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

                            Item {
                                width: uniqueSwitch.implicitWidth
                                height: orderColumn.implicitHeight

                                Switch {
                                    id: uniqueSwitch
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Lang.pages.generators.uniqueNumbers
                                    checked: generatorsVM.randomUnique
                                    onCheckedChanged: generatorsVM.randomUnique = checked
                                }
                            }

                            Column {
                                id: orderColumn
                                spacing: LayoutMetrics.spacing.xxs

                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    bold: false
                                    text: Lang.pages.generators.order
                                    textColor: Theme.textColor
                                    pixelSize: Typography.h6
                                }

                                ComboBox {
                                    width: LayoutMetrics.size.comboBoxWidth * 0.8
                                    model: page.randomSortOptions
                                    textRole: "label"
                                    valueRole: "id"
                                    Component.onCompleted: {
                                        var idx = generatorsVM.randomSorts.indexOf(generatorsVM.randomSort)
                                        if (idx >= 0) currentIndex = idx
                                    }
                                    onActivated: function(index) {
                                        if (index >= 0 && index < generatorsVM.randomSorts.length) {
                                            var sort = generatorsVM.randomSorts[index]
                                            if (sort && sort !== generatorsVM.randomSort)
                                                generatorsVM.randomSort = sort
                                        }
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
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: LayoutMetrics.spacing.sm

                            Button {
                                buttonText: Lang.common.generate
                                primary: true
                                isometric: true
                                heightMultiplier: 1.3
                                onPressed: generatorsVM.generateRandom()
                            }
                            Button {
                                buttonText: Lang.common.copy
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
                            placeholderText: Lang.pages.generators.numbersPlaceholder
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
                            spacing: LayoutMetrics.spacing.md

                            Column {
                                spacing: LayoutMetrics.spacing.xxs

                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    bold: false
                                    text: Lang.common.length
                                    textColor: Theme.textColor
                                    pixelSize: Typography.h6
                                }

                                Row {
                                    spacing: LayoutMetrics.spacing.md

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
                                        text: Lang.pages.generators.charactersUnit
                                        textColor: Theme.dividerColor
                                        pixelSize: Typography.h6
                                    }
                                }
                            }

                            Column {
                                spacing: LayoutMetrics.spacing.xxs

                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    bold: false
                                    text: Lang.common.count
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
                            spacing: LayoutMetrics.spacing.md

                            Switch {
                                text: Lang.pages.generators.uppercase
                                checked: generatorsVM.randomStringUppercase
                                onCheckedChanged: generatorsVM.randomStringUppercase = checked
                            }
                            Switch {
                                text: Lang.pages.generators.lowercase
                                checked: generatorsVM.randomStringLowercase
                                onCheckedChanged: generatorsVM.randomStringLowercase = checked
                            }
                            Switch {
                                text: Lang.pages.generators.digits
                                checked: generatorsVM.randomStringDigits
                                onCheckedChanged: generatorsVM.randomStringDigits = checked
                            }
                            Switch {
                                text: Lang.pages.generators.symbols
                                checked: generatorsVM.randomStringSymbols
                                onCheckedChanged: generatorsVM.randomStringSymbols = checked
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: LayoutMetrics.spacing.xxs

                            Switch {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Lang.pages.generators.excludeAmbiguous
                                checked: generatorsVM.randomStringExcludeAmbiguous
                                onCheckedChanged: generatorsVM.randomStringExcludeAmbiguous = checked
                            }

                            Label {
                                bold: false
                                width: Math.min(parent.width, parent.parent ? parent.parent.width : parent.width)
                                horizontalAlignment: Text.AlignHCenter
                                text: Lang.pages.generators.excludeAmbiguousHint
                                textColor: Theme.dividerColor
                                pixelSize: Typography.h6
                                wrapMode: Text.WordWrap
                            }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: LayoutMetrics.spacing.sm

                            Button {
                                buttonText: Lang.common.generate
                                primary: true
                                isometric: true
                                heightMultiplier: 1.3
                                onPressed: generatorsVM.generateRandomString()
                            }
                            Button {
                                buttonText: Lang.common.copy
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
                            placeholderText: Lang.pages.generators.stringsPlaceholder
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
                            spacing: LayoutMetrics.spacing.md

                            Column {
                                spacing: LayoutMetrics.spacing.xxs

                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    bold: false
                                    text: Lang.common.count
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
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width
                            spacing: LayoutMetrics.spacing.xxs

                            Switch {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Lang.pages.generators.privateIpsOnly
                                checked: generatorsVM.randomIpPrivate
                                onCheckedChanged: generatorsVM.randomIpPrivate = checked
                            }

                            Label {
                                bold: false
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: Lang.pages.generators.privateIpsHint
                                textColor: Theme.dividerColor
                                pixelSize: Typography.h6
                                wrapMode: Text.WordWrap
                            }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: LayoutMetrics.spacing.sm

                            Button {
                                buttonText: Lang.common.generate
                                primary: true
                                isometric: true
                                heightMultiplier: 1.3
                                onPressed: generatorsVM.generateRandomIp()
                            }
                            Button {
                                buttonText: Lang.common.copy
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
                            placeholderText: Lang.pages.generators.ipsPlaceholder
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
                                buttonText: Lang.pages.generators.uuidV4
                                primary: generatorsVM.randomIdFormat === "UUID v4"
                                onPressed: generatorsVM.randomIdFormat = "UUID v4"
                            }
                            Button {
                                buttonText: Lang.pages.generators.shortId
                                primary: generatorsVM.randomIdFormat === "Short ID"
                                onPressed: generatorsVM.randomIdFormat = "Short ID"
                            }
                            Button {
                                buttonText: Lang.pages.generators.numericId
                                primary: generatorsVM.randomIdFormat === "Numeric"
                                onPressed: generatorsVM.randomIdFormat = "Numeric"
                            }
                        }

                        Flow {
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
                            spacing: LayoutMetrics.spacing.md

                            Column {
                                spacing: LayoutMetrics.spacing.xxs

                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    bold: false
                                    text: Lang.common.count
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

                            Column {
                                spacing: LayoutMetrics.spacing.xxs
                                visible: generatorsVM.randomIdFormat !== "UUID v4"

                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    bold: false
                                    text: generatorsVM.randomIdFormat === "Numeric" ? Lang.pages.generators.digitsCount : Lang.common.length
                                    textColor: Theme.textColor
                                    pixelSize: Typography.h6
                                }

                                Row {
                                    spacing: LayoutMetrics.spacing.md

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
                                        text: generatorsVM.randomIdFormat === "Numeric" ? Lang.pages.generators.digitsUnit : Lang.pages.generators.charactersUnit
                                        textColor: Theme.dividerColor
                                        pixelSize: Typography.h6
                                    }
                                }
                            }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: LayoutMetrics.spacing.sm

                            Button {
                                buttonText: Lang.common.generate
                                primary: true
                                isometric: true
                                heightMultiplier: 1.3
                                onPressed: generatorsVM.generateRandomId()
                            }
                            Button {
                                buttonText: Lang.common.copy
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
                            placeholderText: Lang.pages.generators.idsPlaceholder
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
                            spacing: LayoutMetrics.spacing.md

                            Column {
                                spacing: LayoutMetrics.spacing.xxs

                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    bold: false
                                    text: Lang.common.count
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
                                buttonText: Lang.common.generate
                                primary: true
                                isometric: true
                                heightMultiplier: 1.3
                                onPressed: generatorsVM.generateRandomColor()
                            }
                            Button {
                                id: copyAllColorsButton
                                property bool copyConfirmed: false
                                buttonText: Lang.common.copy
                                iconPath: copyConfirmed ? SVGLibrary.checkMark : SVGLibrary.copy
                                enabled: generatorsVM.randomColorOutput.length > 0
                                onPressed: {
                                    generatorsVM.copyRandomColor()
                                    copyConfirmed = true
                                    copyAllColorsTimer.restart()
                                }

                                Timer {
                                    id: copyAllColorsTimer
                                    interval: 1200
                                    onTriggered: copyAllColorsButton.copyConfirmed = false
                                }
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
                                    property bool copyConfirmed: false
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
                                                path: colorRow.copyConfirmed ? SVGLibrary.checkMark : SVGLibrary.copy
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
                                        onClicked: {
                                            generatorsVM.copyColorCode(
                                                        generatorsVM.randomColorCodes[index]
                                                        || modelData)
                                            colorRow.copyConfirmed = true
                                            rowCopyTimer.restart()
                                        }
                                    }

                                    Timer {
                                        id: rowCopyTimer
                                        interval: 1200
                                        onTriggered: colorRow.copyConfirmed = false
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
                            text: Lang.pages.generators.qrDesc
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
                                    text: Lang.pages.generators.urlOrText
                                    textColor: Theme.textColor
                                    pixelSize: Typography.h6
                                }

                                LineEdit {
                                    width: parent.width
                                    text: generatorsVM.qrUrl
                                    placeholderText: Lang.pages.generators.qrPlaceholder
                                    onTextEdited: generatorsVM.qrUrl = text
                                    onEditingFinished: generatorsVM.generateQr()
                                }

                                Flow {
                                    width: parent.width
                                    spacing: LayoutMetrics.spacing.md

                                    Button {
                                        buttonText: Lang.pages.generators.generateQr
                                        primary: true
                                        isometric: true
                                        heightMultiplier: 1.3
                                        onPressed: generatorsVM.generateQr()
                                    }

                                    Button {
                                        buttonText: Lang.common.download
                                        iconPath: SVGLibrary.downloader
                                        enabled: generatorsVM.qrImageSource !== ""
                                        onPressed: qrFileDialog.open()
                                    }
                                }

                                Column {
                                    id: qrResolutionColumn
                                    width: parent.width
                                    spacing: LayoutMetrics.spacing.xxs

                                    Label {
                                        bold: false
                                        text: Lang.pages.generators.resolution
                                        textColor: Theme.textColor
                                        pixelSize: Typography.h6
                                    }

                                    Row {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: LayoutMetrics.spacing.md

                                        ComboBox {
                                            width: Math.min(LayoutMetrics.unit * 12,
                                                            qrResolutionColumn.width * 0.24)
                                            model: generatorsVM.qrResolutions
                                            Component.onCompleted: {
                                                var idx = generatorsVM.qrResolutions.indexOf(generatorsVM.qrResolution)
                                                if (idx >= 0) currentIndex = idx
                                            }
                                            onActivated: function(index) {
                                                if (index >= 0 && index < generatorsVM.qrResolutions.length) {
                                                    var resolution = generatorsVM.qrResolutions[index]
                                                    if (resolution && resolution !== generatorsVM.qrResolution)
                                                        generatorsVM.qrResolution = resolution
                                                }
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
                                            text: Lang.pages.generators.px
                                            textColor: Theme.dividerColor
                                            pixelSize: Typography.h6
                                        }
                                    }
                                }

                                Label {
                                    bold: false
                                    width: parent.width
                                    text: Lang.pages.generators.qrHint
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
                                        text: Lang.pages.generators.qrPreviewPlaceholder
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
        title: Lang.pages.generators.saveQrDialogTitle
        fileMode: FileDialog.SaveFile
        defaultSuffix: "png"
        nameFilters: [Lang.common.fileFilters.pngImages]
        onAccepted: generatorsVM.saveQr(selectedFile.toString())
    }
}
