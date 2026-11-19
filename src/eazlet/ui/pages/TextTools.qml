import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import components

Item {
    id: page

    Layout.fillWidth: true
    Layout.fillHeight: true

    property var matchModel: []
    property var regexMatches: []
    property string regexError: ""
    property string regexHintText: ""
    property var whitespaceOptions: []
    property var regexFlags: []
    property string dataDelimiter: ","
    property var replaceRules: []

    readonly property real panelGap: LayoutMetrics.spacing.xl
    readonly property real controlHeight: LayoutMetrics.size.controlHeight * 2.3

    readonly property var caseOptions: [
        { id: "Upper", label: Lang.options.textTools.case.upper },
        { id: "Lower", label: Lang.options.textTools.case.lower },
        { id: "Title", label: Lang.options.textTools.case.title },
        { id: "Sentence", label: Lang.options.textTools.case.sentence },
        { id: "Swap", label: Lang.options.textTools.case.swap },
        { id: "Capitalize", label: Lang.options.textTools.case.capitalize }
    ]
    readonly property var reverseOptions: [
        { id: "Characters", label: Lang.options.textTools.reverse.characters },
        { id: "Words", label: Lang.options.textTools.reverse.words },
        { id: "Lines", label: Lang.options.textTools.reverse.lines }
    ]
    readonly property var lineOpOptions: [
        { id: "Remove blank lines", label: Lang.options.textTools.lineOp.removeBlank },
        { id: "Remove duplicate lines", label: Lang.options.textTools.lineOp.removeDuplicates },
        { id: "Trim each line", label: Lang.options.textTools.lineOp.trimEach },
        { id: "Number lines", label: Lang.options.textTools.lineOp.numberLines },
        { id: "Prefix / suffix", label: Lang.options.textTools.lineOp.prefixSuffix }
    ]
    readonly property var sortUnitOptions: [
        { id: "Lines", label: Lang.options.textTools.sortUnit.lines },
        { id: "Words", label: Lang.options.textTools.sortUnit.words },
        { id: "Characters", label: Lang.options.textTools.sortUnit.characters },
        { id: "Columns", label: Lang.options.textTools.sortUnit.columns }
    ]
    readonly property var sortKeyOptions: [
        { id: "Alphabetic", label: Lang.options.textTools.sortKey.alphabetic },
        { id: "Natural", label: Lang.options.textTools.sortKey.natural },
        { id: "Numeric", label: Lang.options.textTools.sortKey.numeric },
        { id: "Length", label: Lang.options.textTools.sortKey.length }
    ]
    readonly property var sortOrderOptions: [
        { id: "Ascending", label: Lang.options.textTools.sortOrder.ascending },
        { id: "Descending", label: Lang.options.textTools.sortOrder.descending }
    ]
    readonly property var regexFlagOptions: [
        { id: "IgnoreCase", label: Lang.options.textTools.regexFlag.ignoreCase },
        { id: "Multiline", label: Lang.options.textTools.regexFlag.multiline },
        { id: "DotAll", label: Lang.options.textTools.regexFlag.dotAll }
    ]
    readonly property var delimiterOptions: [
        { id: "comma", label: Lang.options.textTools.delimiter.comma, value: "," },
        { id: "tab", label: Lang.options.textTools.delimiter.tab, value: "\t" },
        { id: "semicolon", label: Lang.options.textTools.delimiter.semicolon, value: ";" },
        { id: "pipe", label: Lang.options.textTools.delimiter.pipe, value: "|" },
        { id: "space", label: Lang.options.textTools.delimiter.space, value: " " }
    ]

    function unitLabel(id) {
        for (var i = 0; i < sortUnitOptions.length; i++)
            if (sortUnitOptions[i].id === id) return sortUnitOptions[i].label
        for (var j = 0; j < reverseOptions.length; j++)
            if (reverseOptions[j].id === id) return reverseOptions[j].label
        return id
    }

    function delimiterLabel(val) {
        if (val === "\t") return Lang.options.textTools.delimiter.tab
        for (var i = 0; i < delimiterOptions.length; i++)
            if (delimiterOptions[i].value === val) return delimiterOptions[i].label
        return val
    }

    function applyResult(response, message) {
        outputEdit.text = response.ok ? response.text : ""
        statusLabel.text = response.ok ? (message || Lang.common.done) : Lang.common.error
        statusLabel.color = response.ok ? Theme.dividerColor : "red"
        errorLabel.text = response.ok ? "" : response.error
        errorLabel.visible = !response.ok
        matchModel = response.ok && response.matches ? response.matches : []
    }

    function toggleIn(list, value) {
        var next = list.slice()
        var at = next.indexOf(value)
        if (at >= 0) next.splice(at, 1)
        else next.push(value)
        return next
    }

    function rulePayload() {
        var payload = []
        for (var i = 0; i < replaceRules.length; i++) {
            var rule = replaceRules[i]
            payload.push({
                find: rule.find,
                replace: rule.replace,
                enabled: rule.enabled !== false
            })
        }
        return payload
    }

    function setRuleField(index, key, value) {
        if (index < 0 || index >= replaceRules.length)
            return
        var next = replaceRules.slice()
        var rule = {}
        for (var name in next[index])
            rule[name] = next[index][name]
        if (rule[key] === value)
            return
        rule[key] = value
        next[index] = rule
        replaceRules = next
    }

    function addRule() {
        var next = replaceRules.slice()
        next.push({ find: "", replace: "", enabled: true })
        replaceRules = next
    }

    function removeRule(index) {
        if (index < 0 || index >= replaceRules.length)
            return
        var next = replaceRules.slice()
        next.splice(index, 1)
        replaceRules = next
    }

    function regexResponse() {
        if (!patternField.text)
            return null
        return textToolsVM.findRegex(inputEdit.text, patternField.text,
                                     page.regexFlags)
    }

    function refreshMatches() {
        if (toolTabs.currentIndex !== 1 || !patternField.text) {
            regexMatches = []
            regexError = ""
            regexHintText = ""
            matchModel = []
            return
        }

        var response = regexResponse()
        if (response.ok) {
            regexMatches = response.matches
            regexError = ""
            regexHintText = Lang.pages.textTools.liveMatches.replace("{count}", response.count)
            matchModel = response.matches
        } else {
            regexMatches = []
            regexError = response.error
            regexHintText = response.error
            matchModel = []
        }
    }

    function runCase() {
        applyResult(textToolsVM.applyCase(inputEdit.text, caseCombo.currentValue || "Upper"),
                    Lang.pages.textTools.caseApplied)
    }

    function runWhitespace() {
        applyResult(textToolsVM.applyWhitespace(inputEdit.text, page.whitespaceOptions),
                    Lang.pages.textTools.whitespaceCleaned)
    }

    function updateWhitespace() {
        var selected = []
        if (trimSwitch.checked) selected.push("Trim")
        if (collapseSwitch.checked) selected.push("Collapse")
        if (tabsSwitch.checked) selected.push("Expand tabs")
        page.whitespaceOptions = selected
    }

    function runReverse() {
        var id = reverseCombo.currentValue || "Characters"
        var label = page.unitLabel(id).toLowerCase()
        applyResult(textToolsVM.applyReverse(inputEdit.text, id),
                    Lang.pages.textTools.reversed.replace("{unit}", label))
    }

    function runLineOp() {
        applyResult(textToolsVM.applyLineOp(inputEdit.text, lineOpCombo.currentValue || "Remove blank lines",
                                            prefixField.text, suffixField.text,
                                            numberLinesSwitch.checked, startSpin.value),
                    Lang.pages.textTools.lineOpApplied)
    }

    function runBatchReplace() {
        var response = textToolsVM.multiReplace(inputEdit.text, page.rulePayload(),
                                                batchCaseSwitch.checked,
                                                batchRegexSwitch.checked,
                                                batchWordSwitch.checked)
        applyResult(response, response.ok
                    ? Lang.pages.textTools.replacementsApplied.replace("{count}", response.count)
                    : Lang.common.error)
    }

    function runFind() {
        if (!patternField.text) {
            applyResult({ok: false, error: Lang.pages.textTools.msgEnterPattern}, Lang.common.error)
            return
        }
        var response = regexResponse()
        refreshMatches()
        applyResult(response, response.ok ? Lang.pages.textTools.matchesFound.replace("{count}", response.count) : Lang.common.error)
    }

    function runRegexReplace(all) {
        applyResult(textToolsVM.replaceRegex(inputEdit.text, patternField.text,
                                             regexReplaceField.text,
                                             page.regexFlags, all),
                    all ? Lang.pages.textTools.allMatchesReplaced : Lang.pages.textTools.firstMatchReplaced)
    }

    function runSplit() {
        applyResult(textToolsVM.splitRegex(inputEdit.text, patternField.text,
                                           page.regexFlags, splitSpin.value),
                    Lang.pages.textTools.splitDone)
    }

    function runSort() {
        var unitId = sortUnitCombo.currentValue || "Lines"
        applyResult(textToolsVM.sortTextMulti(
                        inputEdit.text, unitId,
                        sortKeyCombo.currentValue || "Alphabetic",
                        sortOrderCombo.currentValue || "Ascending",
                        caseSensitiveSwitch.checked, uniqueSwitch.checked,
                        dataDelimiter, sortColumnSpin.value,
                        secondaryColumnSpin.value,
                        secondaryOrderCombo.currentValue || "Ascending"),
                    Lang.pages.textTools.sorted.replace("{unit}", page.unitLabel(unitId).toLowerCase()))
    }

    function runShuffle() {
        var unitId = shuffleUnitCombo.currentValue || "Lines"
        applyResult(textToolsVM.shuffleText(inputEdit.text, unitId, seedSpin.value),
                    Lang.pages.textTools.shuffled.replace("{unit}", page.unitLabel(unitId).toLowerCase()))
    }

    function runDelimitedToJson() {
        applyResult(textToolsVM.delimitedToJson(inputEdit.text, dataDelimiter,
                                                headerSwitch.checked, prettySwitch.checked),
                    Lang.pages.textTools.convertedToJson)
    }

    function runJsonToDelimited() {
        applyResult(textToolsVM.jsonToDelimited(inputEdit.text, dataDelimiter,
                                                fieldsField.text),
                    Lang.pages.textTools.convertedToDelimited)
    }

    function runMarkdown() {
        applyResult(textToolsVM.delimitedToMarkdown(inputEdit.text, dataDelimiter,
                                                    headerSwitch.checked),
                    Lang.pages.textTools.markdownBuilt)
    }

    function runExtractColumn() {
        applyResult(textToolsVM.extractColumn(inputEdit.text, dataDelimiter,
                                              extractColumnSpin.value),
                    Lang.pages.textTools.columnExtracted)
    }

    function processAction() {
        if (toolTabs.currentIndex === 0) runCase()
        else if (toolTabs.currentIndex === 1) runFind()
        else if (toolTabs.currentIndex === 2) runSort()
        else if (toolTabs.currentIndex === 3) runDelimitedToJson()
        else runBatchReplace()
    }

    Surface {
        id: workplaceSurface
        objectName: "workplaceSurface"
        anchors.centerIn: parent
        width: parent.width * 0.9
        height: parent.height * 0.9

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: LayoutMetrics.spacing.lg
            spacing: LayoutMetrics.spacing.md

            Title {
                Layout.alignment: Qt.AlignHCenter
                text: Lang.pages.textTools.title
                textColor: Theme.textColor
                pixelSize: Typography.h2
            }

            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                bold: false
                text: Lang.pages.textTools.subtitle
                textColor: Theme.dividerColor
                pixelSize: Typography.h6
            }

            TabBar {
                id: toolTabs
                Layout.alignment: Qt.AlignHCenter
                tabData: [
                    Lang.pages.textTools.tabTransform,
                    Lang.pages.textTools.tabRegex,
                    Lang.pages.textTools.tabSorters,
                    Lang.pages.textTools.tabData,
                    Lang.pages.textTools.tabBatch
                ]
                active: page.visible
                onCurrentIndexChanged: page.refreshMatches()
            }

            Item {
                id: workspace
                Layout.fillWidth: true
                Layout.fillHeight: true

                readonly property real controlsWidth: (width - page.panelGap) * 0.58
                readonly property real outputWidth: (width - page.panelGap) * 0.42

                Rectangle {
                    id: inputCard
                    anchors.left: parent.left
                    anchors.top: parent.top
                    width: workspace.controlsWidth
                    height: LayoutMetrics.unit * 24
                    radius: LayoutMetrics.radius.m
                    color: Theme.inputBackgroundColor
                    border.color: Theme.borderColor
                    border.width: LayoutMetrics.border.m

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: LayoutMetrics.spacing.md
                        spacing: LayoutMetrics.spacing.xs

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: LayoutMetrics.spacing.sm

                            Label {
                                bold: false
                                text: Lang.pages.textTools.inputText
                                textColor: Theme.textColor
                                pixelSize: Typography.h5
                            }

                            Item { Layout.fillWidth: true }

                            Button {
                                height: page.controlHeight
                                Layout.preferredHeight: page.controlHeight
                                buttonText: Lang.common.paste
                                iconPath: SVGLibrary.paste
                                onPressed: inputEdit.paste()
                            }
                            Button {
                                height: page.controlHeight
                                Layout.preferredHeight: page.controlHeight
                                buttonText: Lang.common.clear
                                iconPath: SVGLibrary.eraser
                                onPressed: {
                                    inputEdit.text = ""
                                    outputEdit.text = ""
                                    errorLabel.visible = false
                                    statusLabel.text = Lang.pages.textTools.runHint
                                    statusLabel.color = Theme.dividerColor
                                    matchModel = []
                                    regexMatches = []
                                    regexError = ""
                                    regexHintText = ""
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: LayoutMetrics.border.s
                            color: Theme.dividerColor
                        }

                        ScrollView {
                            id: inputView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            RegexTextEdit {
                                id: inputEdit
                                width: inputView.availableWidth
                                height: Math.max(inputView.availableHeight, implicitHeight)
                                placeholderText: Lang.pages.textTools.inputPlaceholder
                                highlightColor: Qt.rgba(Theme.themeColor.r, Theme.themeColor.g,
                                                        Theme.themeColor.b, 0.35)
                                matches: toolTabs.currentIndex === 1 ? page.regexMatches : []
                                onTextChanged: page.refreshMatches()
                            }
                        }

                        Label {
                            Layout.fillWidth: true
                            visible: toolTabs.currentIndex === 1 && page.regexError !== ""
                            bold: false
                            text: page.regexError
                            textColor: "red"
                            pixelSize: Typography.caption
                            elide: Text.ElideRight
                        }
                    }
                }

                Flickable {
                    id: controlsScroll
                    objectName: "controlsScroll"
                    anchors.left: parent.left
                    anchors.top: inputCard.bottom
                    anchors.topMargin: LayoutMetrics.spacing.md
                    anchors.bottom: parent.bottom
                    width: workspace.controlsWidth
                    contentWidth: controlCard.width
                    contentHeight: controlCard.height + LayoutMetrics.spacing.xs
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    acceptedButtons: Qt.NoButton

                    ScrollBar.vertical: AppScrollBar { autoGutter: false }

                    WheelScrollArea {
                        target: controlsScroll
                    }

                    Rectangle {
                        id: controlCard
                        width: controlsScroll.width
                        height: toolContent.implicitHeight + LayoutMetrics.spacing.md * 2
                        radius: LayoutMetrics.radius.m
                        color: Theme.inputBackgroundColor
                        border.color: Theme.borderColor
                        border.width: LayoutMetrics.border.m

                        Column {
                            id: toolContent
                            x: LayoutMetrics.spacing.md
                            y: LayoutMetrics.spacing.md
                            width: controlCard.width - LayoutMetrics.spacing.md * 2
                            spacing: LayoutMetrics.spacing.lg
                            readonly property real fieldWidth: LayoutMetrics.size.comboBoxWidth
                            readonly property real textWidth: LayoutMetrics.size.lineEditWidth

                        TabSlide {
                            id: tabSlide
                            tabBar: toolTabs
                            target: toolContent
                        }

                        Column {
                            width: parent.width
                            spacing: LayoutMetrics.spacing.lg
                            visible: toolTabs.currentIndex === 0

                            Label {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                bold: false
                                text: Lang.pages.textTools.transformDesc
                                textColor: Theme.dividerColor
                                pixelSize: Typography.h6
                            }

                            Column {
                                width: parent.width
                                spacing: LayoutMetrics.spacing.sm
                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Lang.pages.textTools.case
                                    style_2: true
                                }
                                RowLayout {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: LayoutMetrics.spacing.sm
                                    ComboBox {
                                        id: caseCombo
                                        height: page.controlHeight
                                        Layout.preferredHeight: page.controlHeight
                                        Layout.preferredWidth: toolContent.fieldWidth
                                        Layout.alignment: Qt.AlignVCenter
                                        model: page.caseOptions
                                        textRole: "label"
                                        valueRole: "id"
                                        currentIndex: 0
                                    }
                                    Button {
                                        primary: true
                                        isometric: true
                                        height: page.controlHeight
                                        Layout.preferredHeight: page.controlHeight
                                        Layout.alignment: Qt.AlignVCenter
                                        buttonText: Lang.pages.textTools.changeCase
                                        onPressed: page.runCase()
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: LayoutMetrics.border.s
                                color: Theme.dividerColor
                            }

                            Column {
                                width: parent.width
                                spacing: LayoutMetrics.spacing.sm
                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Lang.pages.textTools.whitespace
                                    style_2: true
                                }
                                RowLayout {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: LayoutMetrics.spacing.md
                                    Switch {
                                        id: trimSwitch
                                        text: Lang.pages.textTools.trim
                                        onToggled: page.updateWhitespace()
                                    }
                                    Switch {
                                        id: collapseSwitch
                                        text: Lang.pages.textTools.collapse
                                        onToggled: page.updateWhitespace()
                                    }
                                    Switch {
                                        id: tabsSwitch
                                        text: Lang.pages.textTools.expandTabs
                                        onToggled: page.updateWhitespace()
                                    }
                                }
                                Button {
                                    primary: true
                                    isometric: true
                                    height: page.controlHeight
                                    Layout.preferredHeight: page.controlHeight
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    buttonText: Lang.pages.textTools.cleanWhitespace
                                    onPressed: page.runWhitespace()
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: LayoutMetrics.border.s
                                color: Theme.dividerColor
                            }

                            Column {
                                width: parent.width
                                spacing: LayoutMetrics.spacing.sm
                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Lang.pages.textTools.reverse
                                    style_2: true
                                }
                                RowLayout {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: LayoutMetrics.spacing.sm
                                    ComboBox {
                                        id: reverseCombo
                                        height: page.controlHeight
                                        Layout.preferredHeight: page.controlHeight
                                        Layout.preferredWidth: toolContent.fieldWidth
                                        Layout.alignment: Qt.AlignVCenter
                                        model: page.reverseOptions
                                        textRole: "label"
                                        valueRole: "id"
                                        currentIndex: 0
                                    }
                                    Button {
                                        primary: true
                                        isometric: true
                                        height: page.controlHeight
                                        Layout.preferredHeight: page.controlHeight
                                        Layout.alignment: Qt.AlignVCenter
                                        buttonText: Lang.pages.textTools.reverseText
                                        onPressed: page.runReverse()
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: LayoutMetrics.border.s
                                color: Theme.dividerColor
                            }

                            Column {
                                width: parent.width
                                spacing: LayoutMetrics.spacing.sm
                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Lang.pages.textTools.lineOperation
                                    style_2: true
                                }
                                ComboBox {
                                    id: lineOpCombo
                                    height: page.controlHeight
                                    Layout.preferredHeight: page.controlHeight
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: toolContent.fieldWidth
                                    model: page.lineOpOptions
                                    textRole: "label"
                                    valueRole: "id"
                                    scrollablePopup: true
                                    currentIndex: 0
                                }
                                RowLayout {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: LayoutMetrics.spacing.sm
                                    LineEdit {
                                        id: prefixField
                                        height: page.controlHeight
                                        Layout.preferredHeight: page.controlHeight
                                        Layout.preferredWidth: toolContent.textWidth
                                        Layout.alignment: Qt.AlignVCenter
                                        placeholderText: Lang.pages.textTools.prefix
                                    }
                                    LineEdit {
                                        id: suffixField
                                        height: page.controlHeight
                                        Layout.preferredHeight: page.controlHeight
                                        Layout.preferredWidth: toolContent.textWidth
                                        Layout.alignment: Qt.AlignVCenter
                                        placeholderText: Lang.pages.textTools.suffix
                                    }
                                    Switch {
                                        id: numberLinesSwitch
                                        text: Lang.pages.textTools.lineNumbers
                                    }
                                    SpinBox {
                                        id: startSpin
                                        height: page.controlHeight
                                        Layout.preferredHeight: page.controlHeight
                                        Layout.preferredWidth: LayoutMetrics.size.spinBoxWidth
                                        Layout.alignment: Qt.AlignVCenter
                                        from: 0
                                        to: 99999
                                        value: 1
                                    }
                                }
                                Button {
                                    primary: true
                                    isometric: true
                                    height: page.controlHeight
                                    Layout.preferredHeight: page.controlHeight
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    buttonText: Lang.pages.textTools.applyToLines
                                    onPressed: page.runLineOp()
                                }
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: LayoutMetrics.spacing.sm
                            visible: toolTabs.currentIndex === 1

                            Label {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                bold: false
                                text: Lang.pages.textTools.regexDesc
                                textColor: Theme.dividerColor
                                pixelSize: Typography.h6
                            }

                            Column {
                                width: parent.width
                                spacing: LayoutMetrics.spacing.xxs
                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Lang.pages.textTools.patternPreset
                                    style_2: true
                                }
                                ComboBox {
                                    id: presetCombo
                                    height: page.controlHeight
                                    Layout.preferredHeight: page.controlHeight
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: toolContent.fieldWidth
                                    model: textToolsVM.regexPresets
                                    scrollablePopup: true
                                    onActivated: function(index) {
                                        var name = model[index]
                                        patternField.text = textToolsVM.presetPattern(name)
                                        presetHint.text = textToolsVM.presetDescription(name)
                                    }
                                }
                                Label {
                                    id: presetHint
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    bold: false
                                    text: Lang.pages.textTools.presetHint
                                    textColor: Theme.dividerColor
                                    pixelSize: Typography.caption
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: LayoutMetrics.border.s
                                color: Theme.dividerColor
                            }

                            Column {
                                width: parent.width
                                spacing: LayoutMetrics.spacing.xxs
                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Lang.pages.textTools.pattern
                                    style_2: true
                                }
                                LineEdit {
                                    id: patternField
                                    height: page.controlHeight
                                    Layout.preferredHeight: page.controlHeight
                                    width: Math.min(parent.width * 0.85,
                                                    LayoutMetrics.size.lineEditWidth)
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    placeholderText: Lang.pages.textTools.patternPlaceholder
                                    onTextChanged: page.refreshMatches()
                                }
                                RowLayout {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: LayoutMetrics.spacing.md
                                    Repeater {
                                        model: page.regexFlagOptions
                                        Switch {
                                            text: modelData.label
                                            onToggled: {
                                                page.regexFlags =
                                                    page.toggleIn(page.regexFlags, modelData.id)
                                                page.refreshMatches()
                                            }
                                        }
                                    }
                                }
                                RowLayout {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: LayoutMetrics.spacing.xs
                                    Button {
                                        primary: true
                                        isometric: true
                                        height: page.controlHeight
                                        Layout.preferredHeight: page.controlHeight
                                        Layout.alignment: Qt.AlignVCenter
                                        buttonText: Lang.pages.textTools.showMatches
                                        onPressed: page.runFind()
                                    }
                                    Button {
                                        primary: true
                                        isometric: true
                                        height: page.controlHeight
                                        Layout.preferredHeight: page.controlHeight
                                        Layout.alignment: Qt.AlignVCenter
                                        buttonText: Lang.pages.textTools.splitByPattern
                                        onPressed: page.runSplit()
                                    }
                                    SpinBox {
                                        id: splitSpin
                                        height: page.controlHeight
                                        Layout.preferredHeight: page.controlHeight
                                        Layout.preferredWidth: LayoutMetrics.size.spinBoxWidth
                                        Layout.alignment: Qt.AlignVCenter
                                        from: 0
                                        to: 9999
                                        value: 0
                                    }
                                }
                                Label {
                                    id: regexHint
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    bold: false
                                    text: page.regexHintText
                                    textColor: page.regexError !== "" ? "red" : Theme.dividerColor
                                    pixelSize: Typography.caption
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: LayoutMetrics.border.s
                                color: Theme.dividerColor
                            }

                            Column {
                                width: parent.width
                                spacing: LayoutMetrics.spacing.xxs
                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Lang.pages.textTools.replacement
                                    style_2: true
                                }
                                LineEdit {
                                    id: regexReplaceField
                                    height: page.controlHeight
                                    Layout.preferredHeight: page.controlHeight
                                    width: Math.min(parent.width * 0.85,
                                                    LayoutMetrics.size.lineEditWidth)
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    placeholderText: Lang.pages.textTools.replacementPlaceholder
                                }
                                RowLayout {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: LayoutMetrics.spacing.xs
                                    Button {
                                        primary: true
                                        isometric: true
                                        height: page.controlHeight
                                        Layout.preferredHeight: page.controlHeight
                                        buttonText: Lang.pages.textTools.replaceAllMatches
                                        onPressed: page.runRegexReplace(true)
                                    }
                                    Button {
                                        primary: true
                                        isometric: true
                                        height: page.controlHeight
                                        Layout.preferredHeight: page.controlHeight
                                        buttonText: Lang.pages.textTools.replaceFirstMatch
                                        onPressed: page.runRegexReplace(false)
                                    }
                                }
                            }

                            Column {
                                width: parent.width
                                spacing: LayoutMetrics.spacing.xxs
                                visible: page.matchModel.length > 0
                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Lang.pages.textTools.matches
                                    style_2: true
                                }
                                Repeater {
                                    model: page.matchModel
                                    Rectangle {
                                        width: parent.width
                                        height: Math.max(LayoutMetrics.unit * 4,
                                                         matchLabel.implicitHeight
                                                         + LayoutMetrics.spacing.xs * 2)
                                        radius: LayoutMetrics.radius.s
                                        color: Theme.backgroundColor
                                        border.color: Theme.borderColor
                                        border.width: LayoutMetrics.border.s
                                        Label {
                                            id: matchLabel
                                            anchors.centerIn: parent
                                            width: parent.width - LayoutMetrics.spacing.sm * 2
                                            bold: false
                                            elide: Text.ElideRight
                                            text: "#" + (index + 1) + "  " + modelData.value
                                                  + "  [" + modelData.start + "-"
                                                  + modelData.end + "]"
                                            textColor: Theme.textColor
                                            pixelSize: Typography.body
                                        }
                                    }
                                }
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: LayoutMetrics.spacing.sm
                            visible: toolTabs.currentIndex === 2

                            Label {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                bold: false
                                text: Lang.pages.textTools.sortersDesc
                                textColor: Theme.dividerColor
                                pixelSize: Typography.h6
                            }

                            Column {
                                width: parent.width
                                spacing: LayoutMetrics.spacing.xxs
                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Lang.pages.textTools.sortBy
                                    style_2: true
                                }
                                RowLayout {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: LayoutMetrics.spacing.sm
                                    ComboBox {
                                        id: sortUnitCombo
                                        height: page.controlHeight
                                        Layout.preferredHeight: page.controlHeight
                                        Layout.preferredWidth: toolContent.fieldWidth
                                        Layout.alignment: Qt.AlignVCenter
                                        model: page.sortUnitOptions
                                        textRole: "label"
                                        valueRole: "id"
                                        currentIndex: 0
                                    }
                                    ComboBox {
                                        id: sortKeyCombo
                                        height: page.controlHeight
                                        Layout.preferredHeight: page.controlHeight
                                        Layout.preferredWidth: toolContent.fieldWidth
                                        Layout.alignment: Qt.AlignVCenter
                                        model: page.sortKeyOptions
                                        textRole: "label"
                                        valueRole: "id"
                                        currentIndex: 0
                                    }
                                    ComboBox {
                                        id: sortOrderCombo
                                        height: page.controlHeight
                                        Layout.preferredHeight: page.controlHeight
                                        Layout.preferredWidth: toolContent.fieldWidth
                                        Layout.alignment: Qt.AlignVCenter
                                        model: page.sortOrderOptions
                                        textRole: "label"
                                        valueRole: "id"
                                        currentIndex: 0
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: LayoutMetrics.border.s
                                color: Theme.dividerColor
                            }

                            Column {
                                width: parent.width
                                spacing: LayoutMetrics.spacing.xxs
                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Lang.common.options
                                    style_2: true
                                }
                                RowLayout {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: LayoutMetrics.spacing.md
                                    Switch {
                                        id: caseSensitiveSwitch
                                        text: Lang.pages.textTools.caseSensitive
                                    }
                                    Switch {
                                        id: uniqueSwitch
                                        text: Lang.pages.textTools.uniqueOnly
                                    }
                                }
                            }

                            Column {
                                width: parent.width
                                spacing: LayoutMetrics.spacing.xxs
                                visible: (sortUnitCombo.currentValue || "Lines") === "Columns"
                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Lang.pages.textTools.columnsZeroBased
                                    style_2: true
                                }
                                RowLayout {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: LayoutMetrics.spacing.sm
                                    SpinBox {
                                        id: sortColumnSpin
                                        height: page.controlHeight
                                        Layout.preferredHeight: page.controlHeight
                                        Layout.preferredWidth: LayoutMetrics.size.spinBoxWidth
                                        Layout.alignment: Qt.AlignVCenter
                                        from: 0
                                        to: 999
                                        value: 0
                                    }
                                    SpinBox {
                                        id: secondaryColumnSpin
                                        height: page.controlHeight
                                        Layout.preferredHeight: page.controlHeight
                                        Layout.preferredWidth: LayoutMetrics.size.spinBoxWidth
                                        Layout.alignment: Qt.AlignVCenter
                                        from: -1
                                        to: 999
                                        value: -1
                                    }
                                    ComboBox {
                                        id: secondaryOrderCombo
                                        height: page.controlHeight
                                        Layout.preferredHeight: page.controlHeight
                                        Layout.preferredWidth: toolContent.fieldWidth
                                        Layout.alignment: Qt.AlignVCenter
                                        model: page.sortOrderOptions
                                        textRole: "label"
                                        valueRole: "id"
                                        currentIndex: 0
                                    }
                                }
                                Label {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    bold: false
                                    text: Lang.pages.textTools.columnsHint.replace("{delimiter}", page.delimiterLabel(page.dataDelimiter))
                                    textColor: Theme.dividerColor
                                    pixelSize: Typography.caption
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: LayoutMetrics.border.s
                                color: Theme.dividerColor
                            }

                            Column {
                                width: parent.width
                                spacing: LayoutMetrics.spacing.xxs
                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Lang.common.sort
                                    style_2: true
                                }
                                Button {
                                    primary: true
                                    isometric: true
                                    height: page.controlHeight
                                    Layout.preferredHeight: page.controlHeight
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    buttonText: Lang.pages.textTools.sortInput
                                    onPressed: page.runSort()
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: LayoutMetrics.border.s
                                color: Theme.dividerColor
                            }

                            Column {
                                width: parent.width
                                spacing: LayoutMetrics.spacing.xxs
                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Lang.pages.textTools.shuffle
                                    style_2: true
                                }
                                RowLayout {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: LayoutMetrics.spacing.sm
                                    ComboBox {
                                        id: shuffleUnitCombo
                                        height: page.controlHeight
                                        Layout.preferredHeight: page.controlHeight
                                        Layout.preferredWidth: toolContent.fieldWidth
                                        Layout.alignment: Qt.AlignVCenter
                                        model: page.sortUnitOptions
                                        textRole: "label"
                                        valueRole: "id"
                                        currentIndex: 0
                                    }
                                    SpinBox {
                                        id: seedSpin
                                        height: page.controlHeight
                                        Layout.preferredHeight: page.controlHeight
                                        Layout.preferredWidth: LayoutMetrics.size.spinBoxWidth
                                        Layout.alignment: Qt.AlignVCenter
                                        from: 0
                                        to: 999999
                                        value: 0
                                    }
                                    Button {
                                        primary: true
                                        isometric: true
                                        height: page.controlHeight
                                        Layout.preferredHeight: page.controlHeight
                                        Layout.alignment: Qt.AlignVCenter
                                        buttonText: Lang.pages.textTools.shuffleInput
                                        onPressed: page.runShuffle()
                                    }
                                }
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: LayoutMetrics.spacing.sm
                            visible: toolTabs.currentIndex === 3

                            Label {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                bold: false
                                text: Lang.pages.textTools.dataDesc
                                textColor: Theme.dividerColor
                                pixelSize: Typography.h6
                            }

                            Column {
                                width: parent.width
                                spacing: LayoutMetrics.spacing.xxs
                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Lang.common.delimiter
                                    style_2: true
                                }
                                ComboBox {
                                    id: delimiterCombo
                                    height: page.controlHeight
                                    Layout.preferredHeight: page.controlHeight
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: toolContent.fieldWidth
                                    model: page.delimiterOptions
                                    textRole: "label"
                                    valueRole: "value"
                                    currentIndex: 0
                                    onCurrentValueChanged: {
                                        if (currentValue !== undefined && currentValue !== null)
                                            page.dataDelimiter = currentValue
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: LayoutMetrics.border.s
                                color: Theme.dividerColor
                            }

                            Column {
                                width: parent.width
                                spacing: LayoutMetrics.spacing.xxs
                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Lang.common.options
                                    style_2: true
                                }
                                RowLayout {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: LayoutMetrics.spacing.md
                                    Switch {
                                        id: headerSwitch
                                        text: Lang.pages.textTools.firstRowHeader
                                        checked: true
                                    }
                                    Switch {
                                        id: prettySwitch
                                        text: Lang.pages.textTools.prettyJson
                                        checked: true
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: LayoutMetrics.border.s
                                color: Theme.dividerColor
                            }

                            Column {
                                width: parent.width
                                spacing: LayoutMetrics.spacing.xxs
                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Lang.pages.textTools.fieldsForJson
                                    style_2: true
                                }
                                LineEdit {
                                    id: fieldsField
                                    height: page.controlHeight
                                    Layout.preferredHeight: page.controlHeight
                                    width: Math.min(parent.width * 0.85,
                                                    LayoutMetrics.size.lineEditWidth)
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    placeholderText: Lang.pages.textTools.fieldsPlaceholder
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: LayoutMetrics.border.s
                                color: Theme.dividerColor
                            }

                            Column {
                                width: parent.width
                                spacing: LayoutMetrics.spacing.xxs
                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Lang.pages.textTools.convert
                                    style_2: true
                                }
                                RowLayout {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: LayoutMetrics.spacing.xs
                                    Button {
                                        primary: true
                                        isometric: true
                                        height: page.controlHeight
                                        Layout.preferredHeight: page.controlHeight
                                        Layout.alignment: Qt.AlignVCenter
                                        buttonText: Lang.pages.textTools.toJson
                                        onPressed: page.runDelimitedToJson()
                                    }
                                    Button {
                                        primary: true
                                        isometric: true
                                        height: page.controlHeight
                                        Layout.preferredHeight: page.controlHeight
                                        Layout.alignment: Qt.AlignVCenter
                                        buttonText: Lang.pages.textTools.toDelimited
                                        onPressed: page.runJsonToDelimited()
                                    }
                                    Button {
                                        primary: true
                                        isometric: true
                                        height: page.controlHeight
                                        Layout.preferredHeight: page.controlHeight
                                        Layout.alignment: Qt.AlignVCenter
                                        buttonText: Lang.pages.textTools.markdownTable
                                        onPressed: page.runMarkdown()
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: LayoutMetrics.border.s
                                color: Theme.dividerColor
                            }

                            Column {
                                width: parent.width
                                spacing: LayoutMetrics.spacing.xxs
                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Lang.pages.textTools.extractColumn
                                    style_2: true
                                }
                                RowLayout {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: LayoutMetrics.spacing.sm
                                    SpinBox {
                                        id: extractColumnSpin
                                        height: page.controlHeight
                                        Layout.preferredHeight: page.controlHeight
                                        Layout.preferredWidth: LayoutMetrics.size.spinBoxWidth
                                        Layout.alignment: Qt.AlignVCenter
                                        from: 0
                                        to: 999
                                        value: 0
                                    }
                                    Button {
                                        primary: true
                                        isometric: true
                                        height: page.controlHeight
                                        Layout.preferredHeight: page.controlHeight
                                        Layout.alignment: Qt.AlignVCenter
                                        buttonText: Lang.pages.textTools.extractColumn
                                        onPressed: page.runExtractColumn()
                                    }
                                }
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: LayoutMetrics.spacing.sm
                            visible: toolTabs.currentIndex === 4

                            Label {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                bold: false
                                text: Lang.pages.textTools.batchDesc
                                textColor: Theme.dividerColor
                                pixelSize: Typography.h6
                            }

                            Column {
                                width: parent.width
                                spacing: LayoutMetrics.spacing.xxs
                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    visible: page.replaceRules.length > 0
                                    text: Lang.pages.textTools.replaceRules
                                    style_2: true
                                }

                                Label {
                                    width: parent.width
                                    visible: page.replaceRules.length === 0
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    bold: false
                                    text: Lang.pages.textTools.noRulesYet
                                    textColor: Theme.dividerColor
                                    pixelSize: Typography.h6
                                }

                                Column {
                                    width: parent.width
                                    spacing: LayoutMetrics.spacing.xs
                                    Repeater {
                                        model: page.replaceRules

                                        Rectangle {
                                            width: parent.width * 0.85
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            height: page.controlHeight
                                                   + LayoutMetrics.spacing.xs * 2
                                            radius: LayoutMetrics.radius.m
                                            color: Theme.backgroundColor
                                            border.color: Theme.borderColor
                                            border.width: LayoutMetrics.border.s

                                            // Accent marks enabled rules at a glance.
                                            Rectangle {
                                                width: LayoutMetrics.border.l
                                                height: parent.height
                                                       - LayoutMetrics.spacing.sm
                                                anchors.left: parent.left
                                                anchors.leftMargin: LayoutMetrics.spacing.xs
                                                anchors.verticalCenter: parent.verticalCenter
                                                radius: width / 2
                                                color: modelData.enabled !== false
                                                       ? Theme.themeColor
                                                       : Theme.dividerColor
                                            }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: LayoutMetrics.spacing.md
                                                anchors.rightMargin: LayoutMetrics.spacing.sm
                                                anchors.topMargin: LayoutMetrics.spacing.xs
                                                anchors.bottomMargin: LayoutMetrics.spacing.xs
                                                spacing: LayoutMetrics.spacing.xs

                                                Switch {
                                                    Layout.preferredWidth: LayoutMetrics.unit * 6
                                                    Component.onCompleted: checked = modelData.enabled !== false
                                                    onToggled: page.setRuleField(index, "enabled", checked)
                                                }
                                                LineEdit {
                                                    height: page.controlHeight
                                                    Layout.preferredHeight: page.controlHeight
                                                    Layout.fillWidth: true
                                                    Layout.minimumWidth: 0
                                                    Layout.alignment: Qt.AlignVCenter
                                                    placeholderText: Lang.pages.textTools.find
                                                    Component.onCompleted: text = modelData.find
                                                    onTextEdited: page.setRuleField(index, "find", text)
                                                }
                                                LineEdit {
                                                    height: page.controlHeight
                                                    Layout.preferredHeight: page.controlHeight
                                                    Layout.fillWidth: true
                                                    Layout.minimumWidth: 0
                                                    Layout.alignment: Qt.AlignVCenter
                                                    placeholderText: Lang.pages.textTools.replaceWith
                                                    Component.onCompleted: text = modelData.replace
                                                    onTextEdited: page.setRuleField(index, "replace", text)
                                                }
                                                Item {
                                                    Layout.preferredWidth: LayoutMetrics.size.iconS
                                                    Layout.preferredHeight: LayoutMetrics.size.iconS
                                                    SVGObject {
                                                        anchors.centerIn: parent
                                                        width: LayoutMetrics.size.iconS
                                                        height: LayoutMetrics.size.iconS
                                                        path: SVGLibrary.cross
                                                        color: removeArea.containsMouse
                                                               ? "red" : Theme.dividerColor
                                                    }
                                                    MouseArea {
                                                        id: removeArea
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: page.removeRule(index)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: LayoutMetrics.spacing.xs
                                    Button {
                                        height: page.controlHeight
                                        Layout.preferredHeight: page.controlHeight
                                        buttonText: Lang.common.addRule
                                        onPressed: page.addRule()
                                    }
                                    Button {
                                        height: page.controlHeight
                                        Layout.preferredHeight: page.controlHeight
                                        buttonText: Lang.common.clearRules
                                        iconPath: SVGLibrary.eraser
                                        onPressed: page.replaceRules = []
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: LayoutMetrics.border.s
                                color: Theme.dividerColor
                            }

                            Column {
                                width: parent.width
                                spacing: LayoutMetrics.spacing.xxs
                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Lang.pages.textTools.ruleOptions
                                    style_2: true
                                }
                                RowLayout {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: LayoutMetrics.spacing.md
                                    Switch {
                                        id: batchCaseSwitch
                                        text: Lang.pages.textTools.caseSensitive
                                    }
                                    Switch {
                                        id: batchRegexSwitch
                                        text: Lang.pages.textTools.regexPatterns
                                    }
                                    Switch {
                                        id: batchWordSwitch
                                        text: Lang.pages.textTools.wholeWords
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: LayoutMetrics.border.s
                                color: Theme.dividerColor
                            }

                            Column {
                                width: parent.width
                                spacing: LayoutMetrics.spacing.xxs
                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Lang.common.apply
                                    style_2: true
                                }
                                Button {
                                    primary: true
                                    isometric: true
                                    height: page.controlHeight
                                    Layout.preferredHeight: page.controlHeight
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    buttonText: Lang.pages.textTools.replaceAllRules
                                    onPressed: page.runBatchReplace()
                                }
                            }
                        }
                    }
                    }
                }

                Rectangle {
                    id: outputPanel
                    objectName: "outputPanel"
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: workspace.outputWidth
                    radius: LayoutMetrics.radius.m
                    color: Theme.inputBackgroundColor
                    border.color: Theme.borderColor
                    border.width: LayoutMetrics.border.m

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: LayoutMetrics.spacing.md
                        spacing: LayoutMetrics.spacing.xs

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: LayoutMetrics.spacing.sm

                            Label {
                                bold: false
                                text: Lang.pages.textTools.output
                                textColor: Theme.textColor
                                pixelSize: Typography.h5
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Item { Layout.fillWidth: true }

                            Button {
                                id: copyOutputButton
                                height: page.controlHeight
                                Layout.preferredHeight: page.controlHeight
                                buttonText: Lang.common.copy
                                iconPath: SVGLibrary.copy
                                onPressed: outputEdit.copy()
                            }
                        }

                        Label {
                            id: statusLabel
                            Layout.fillWidth: true
                            bold: false
                            text: Lang.pages.textTools.runHint
                            textColor: Theme.dividerColor
                            pixelSize: Typography.caption
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: LayoutMetrics.border.s
                            color: Theme.dividerColor
                        }

                        TextEdit {
                            id: outputEdit
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: LayoutMetrics.unit * 10
                            readOnly: true
                            placeholderText: Lang.pages.textTools.outputPlaceholder
                            wrapMode: Text.WrapAnywhere
                        }

                        Label {
                            id: errorLabel
                            Layout.fillWidth: true
                            bold: false
                            visible: false
                            text: ""
                            textColor: "red"
                            pixelSize: Typography.body
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }
}
