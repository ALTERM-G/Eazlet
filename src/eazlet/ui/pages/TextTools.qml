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
    property var whitespaceOptions: []
    property var regexFlags: []
    property string dataDelimiter: ","
    property var replaceRules: []

    readonly property real panelGap: LayoutMetrics.spacing.xl

    function applyResult(response, message) {
        outputEdit.text = response.ok ? response.text : ""
        statusLabel.text = response.ok ? (message || "Done") : "Error"
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

    // Keeps the highlighter, live counter and match list in step with the
    // input, pattern and flags. No button press is needed.
    function refreshMatches() {
        if (toolTabs.currentIndex !== 1 || !patternField.text) {
            regexMatches = []
            regexError = ""
            matchModel = []
            return
        }

        var response = regexResponse()
        if (response.ok) {
            regexMatches = response.matches
            regexError = ""
            matchModel = response.matches
        } else {
            regexMatches = []
            regexError = response.error
            matchModel = []
        }
    }

    function runCase() {
        applyResult(textToolsVM.applyCase(inputEdit.text, caseCombo.currentText),
                    "Case applied to input")
    }

    function runWhitespace() {
        applyResult(textToolsVM.applyWhitespace(inputEdit.text, page.whitespaceOptions),
                    "Whitespace cleaned")
    }

    function updateWhitespace() {
        var selected = []
        if (trimSwitch.checked) selected.push("Trim")
        if (collapseSwitch.checked) selected.push("Collapse")
        if (tabsSwitch.checked) selected.push("Expand tabs")
        page.whitespaceOptions = selected
    }

    function runReverse() {
        applyResult(textToolsVM.applyReverse(inputEdit.text, reverseCombo.currentText),
                    "Reversed " + reverseCombo.currentText.toLowerCase())
    }

    function runLineOp() {
        applyResult(textToolsVM.applyLineOp(inputEdit.text, lineOpCombo.currentText,
                                            prefixField.text, suffixField.text,
                                            numberLinesSwitch.checked, startSpin.value),
                    "Line operation applied")
    }

    function runLiteralReplace() {
        applyResult(textToolsVM.replaceLiteral(inputEdit.text, literalFindField.text,
                                               literalReplaceField.text,
                                               literalCaseSwitch.checked,
                                               literalAllSwitch.checked),
                    "Literal replacement applied")
    }

    function runBatchReplace() {
        var response = textToolsVM.multiReplace(inputEdit.text, page.rulePayload(),
                                                batchCaseSwitch.checked,
                                                batchRegexSwitch.checked,
                                                batchWordSwitch.checked)
        applyResult(response, response.ok
                    ? response.count + " replacement(s) applied at once"
                    : "Error")
    }

    function runFind() {
        if (!patternField.text) {
            applyResult({ok: false, error: "Enter a pattern"}, "Error")
            return
        }
        var response = regexResponse()
        refreshMatches()
        applyResult(response, response.ok ? response.count + " match(es)" : "Error")
    }

    function runRegexReplace(all) {
        applyResult(textToolsVM.replaceRegex(inputEdit.text, patternField.text,
                                             regexReplaceField.text,
                                             page.regexFlags, all),
                    all ? "All matches replaced" : "First match replaced")
    }

    function runSplit() {
        applyResult(textToolsVM.splitRegex(inputEdit.text, patternField.text,
                                           page.regexFlags, splitSpin.value),
                    "Input split by pattern")
    }

    function runSort() {
        applyResult(textToolsVM.sortTextMulti(
                        inputEdit.text, sortUnitCombo.currentText,
                        sortKeyCombo.currentText, sortOrderCombo.currentText,
                        caseSensitiveSwitch.checked, uniqueSwitch.checked,
                        dataDelimiter, sortColumnSpin.value,
                        secondaryColumnSpin.value, secondaryOrderCombo.currentText),
                    "Sorted " + sortUnitCombo.currentText.toLowerCase())
    }

    function runShuffle() {
        applyResult(textToolsVM.shuffleText(inputEdit.text, shuffleUnitCombo.currentText,
                                            seedSpin.value),
                    "Shuffled " + shuffleUnitCombo.currentText.toLowerCase())
    }

    function runDelimitedToJson() {
        applyResult(textToolsVM.delimitedToJson(inputEdit.text, dataDelimiter,
                                                headerSwitch.checked, prettySwitch.checked),
                    "Converted to JSON")
    }

    function runJsonToDelimited() {
        applyResult(textToolsVM.jsonToDelimited(inputEdit.text, dataDelimiter,
                                                fieldsField.text),
                    "Converted to delimited text")
    }

    function runMarkdown() {
        applyResult(textToolsVM.delimitedToMarkdown(inputEdit.text, dataDelimiter,
                                                    headerSwitch.checked),
                    "Markdown table built")
    }

    function runExtractColumn() {
        applyResult(textToolsVM.extractColumn(inputEdit.text, dataDelimiter,
                                              extractColumnSpin.value),
                    "Column extracted")
    }

    function processAction() {
        if (toolTabs.currentIndex === 0) runCase()
        else if (toolTabs.currentIndex === 1) runFind()
        else if (toolTabs.currentIndex === 2) runSort()
        else if (toolTabs.currentIndex === 3) runDelimitedToJson()
        else runBatchReplace()
    }

    Surface {
        anchors.centerIn: parent
        width: parent.width * 0.9
        height: parent.height * 0.9

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: LayoutMetrics.spacing.lg
            spacing: LayoutMetrics.spacing.md

            Title {
                Layout.alignment: Qt.AlignHCenter
                text: "Text Tools"
                textColor: Theme.textColor
                pixelSize: Typography.h2
            }

            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                bold: false
                text: "Transform text, match patterns, sort anything, and replace in bulk. Results stay visible while you work."
                textColor: Theme.dividerColor
                pixelSize: Typography.h6
            }

            TabBar {
                id: toolTabs
                Layout.alignment: Qt.AlignHCenter
                tabData: ["Transform", "Regex & Patterns", "Sorters", "Text / Data", "Batch Replace"]
                active: page.visible
                onCurrentIndexChanged: page.refreshMatches()
            }

            Item {
                id: workspace
                Layout.fillWidth: true
                Layout.fillHeight: true

                readonly property real controlsWidth: (width - page.panelGap) * 0.58
                readonly property real outputWidth: (width - page.panelGap) * 0.42

                // Shared input stays outside the scroller so a long tool pane
                // can never push it out of view.
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
                                text: "Input text"
                                textColor: Theme.textColor
                                pixelSize: Typography.h5
                            }

                            Item { Layout.fillWidth: true }

                            Label {
                                id: regexHint
                                Layout.fillWidth: true
                                bold: false
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideRight
                                text: toolTabs.currentIndex !== 1
                                      ? ""
                                      : page.regexError !== ""
                                        ? page.regexError
                                        : page.regexMatches.length > 0
                                          ? page.regexMatches.length + " live match(es)"
                                          : "Type a pattern to highlight matches"
                                textColor: page.regexError !== ""
                                           ? "red" : Theme.dividerColor
                                pixelSize: Typography.caption
                            }
                        }

                        RegexTextEdit {
                            id: inputEdit
                            objectName: "textToolsInput"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: LayoutMetrics.unit * 10
                            placeholderText: "Paste or type text here..."
                            matches: toolTabs.currentIndex === 1 ? page.regexMatches : []
                            onTextEdited: page.refreshMatches()
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: LayoutMetrics.spacing.xs

                            Button {
                                buttonText: "Paste"
                                onPressed: {
                                    inputEdit.paste()
                                    page.refreshMatches()
                                }
                            }

                            Button {
                                buttonText: "Clear"
                                onPressed: {
                                    inputEdit.text = ""
                                    page.refreshMatches()
                                }
                            }
                        }
                    }
                }

                Flickable {
                    id: controlsScroll
                    objectName: "controlsScroll"
                    anchors.left: parent.left
                    anchors.top: inputCard.bottom
                    anchors.topMargin: LayoutMetrics.spacing.sm
                    anchors.bottom: parent.bottom
                    width: workspace.controlsWidth
                    contentWidth: controlCard.width
                    contentHeight: controlCard.height + LayoutMetrics.spacing.xs
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    acceptedButtons: Qt.NoButton

                    ScrollBar.vertical: AppScrollBar { autoGutter: false }

                    WheelScrollArea { target: controlsScroll }

                    TabSlide {
                        id: tabSlide
                        tabBar: toolTabs
                        target: toolContent
                    }

                    Rectangle {
                        id: controlCard
                        // Bind to the Flickable, not to its contentItem, to
                        // avoid a contentWidth <-> width binding loop.
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
                            spacing: LayoutMetrics.spacing.sm

                            readonly property real fieldWidth: Math.max(
                                LayoutMetrics.unit * 14,
                                Math.min(LayoutMetrics.size.comboBoxWidth, width * 0.30))
                            readonly property real textWidth: Math.max(
                                LayoutMetrics.unit * 12,
                                Math.min(LayoutMetrics.size.lineEditWidth, width * 0.30))

                            // Transform ---------------------------------------
                            Column {
                                width: parent.width
                                spacing: LayoutMetrics.spacing.sm
                                visible: toolTabs.currentIndex === 0

                                Label {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    bold: false
                                    text: "Change case, clean whitespace, reverse, and rewrite lines."
                                    textColor: Theme.dividerColor
                                    pixelSize: Typography.h6
                                }

                                Column {
                                    width: parent.width
                                    spacing: LayoutMetrics.spacing.xxs
                                    Label {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "Case"
                                        style_2: true
                                    }
                                    RowLayout {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: LayoutMetrics.spacing.sm
                                        ComboBox {
                                            id: caseCombo
                                            Layout.preferredWidth: toolContent.fieldWidth
                                            Layout.alignment: Qt.AlignVCenter
                                            model: textToolsVM.caseModes
                                            scrollablePopup: true
                                        }
                                        Button {
                                            Layout.alignment: Qt.AlignVCenter
                                            buttonText: "Change case"
                                            primary: true
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
                                    spacing: LayoutMetrics.spacing.xxs
                                    Label {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "Whitespace"
                                        style_2: true
                                    }
                                    RowLayout {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: LayoutMetrics.spacing.md
                                        Switch {
                                            id: trimSwitch
                                            text: "Trim"
                                            onToggled: page.updateWhitespace()
                                        }
                                        Switch {
                                            id: collapseSwitch
                                            text: "Collapse"
                                            onToggled: page.updateWhitespace()
                                        }
                                        Switch {
                                            id: tabsSwitch
                                            text: "Expand tabs"
                                            onToggled: page.updateWhitespace()
                                        }
                                        Button {
                                            Layout.alignment: Qt.AlignVCenter
                                            buttonText: "Clean whitespace"
                                            onPressed: page.runWhitespace()
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
                                        text: "Reverse"
                                        style_2: true
                                    }
                                    RowLayout {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: LayoutMetrics.spacing.sm
                                        ComboBox {
                                            id: reverseCombo
                                            Layout.preferredWidth: toolContent.fieldWidth
                                            Layout.alignment: Qt.AlignVCenter
                                            model: textToolsVM.reverseUnits
                                        }
                                        Button {
                                            Layout.alignment: Qt.AlignVCenter
                                            buttonText: "Reverse text"
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
                                    spacing: LayoutMetrics.spacing.xxs
                                    Label {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "Line operation"
                                        style_2: true
                                    }
                                    ComboBox {
                                        id: lineOpCombo
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: toolContent.fieldWidth
                                        model: textToolsVM.lineOperations
                                        scrollablePopup: true
                                    }
                                    RowLayout {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: LayoutMetrics.spacing.sm
                                        LineEdit {
                                            id: prefixField
                                            Layout.preferredWidth: toolContent.textWidth
                                            Layout.alignment: Qt.AlignVCenter
                                            placeholderText: "Prefix"
                                        }
                                        LineEdit {
                                            id: suffixField
                                            Layout.preferredWidth: toolContent.textWidth
                                            Layout.alignment: Qt.AlignVCenter
                                            placeholderText: "Suffix"
                                        }
                                        Switch {
                                            id: numberLinesSwitch
                                            text: "Line numbers"
                                        }
                                        SpinBox {
                                            id: startSpin
                                            Layout.preferredWidth: LayoutMetrics.size.spinBoxWidth
                                            Layout.alignment: Qt.AlignVCenter
                                            from: 0
                                            to: 99999
                                            value: 1
                                        }
                                    }
                                    Button {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        buttonText: "Apply to lines"
                                        onPressed: page.runLineOp()
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
                                        text: "Literal find and replace"
                                        style_2: true
                                    }
                                    RowLayout {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: LayoutMetrics.spacing.sm
                                        LineEdit {
                                            id: literalFindField
                                            Layout.preferredWidth: toolContent.textWidth
                                            Layout.alignment: Qt.AlignVCenter
                                            placeholderText: "Find"
                                        }
                                        LineEdit {
                                            id: literalReplaceField
                                            Layout.preferredWidth: toolContent.textWidth
                                            Layout.alignment: Qt.AlignVCenter
                                            placeholderText: "Replace with"
                                        }
                                    }
                                    RowLayout {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: LayoutMetrics.spacing.md
                                        Switch {
                                            id: literalCaseSwitch
                                            text: "Case sensitive"
                                            checked: true
                                        }
                                        Switch {
                                            id: literalAllSwitch
                                            text: "Replace all"
                                            checked: true
                                        }
                                        Button {
                                            Layout.alignment: Qt.AlignVCenter
                                            buttonText: "Replace literal text"
                                            onPressed: page.runLiteralReplace()
                                        }
                                    }
                                }
                            }

                            // Regex & patterns -------------------------------
                            Column {
                                width: parent.width
                                spacing: LayoutMetrics.spacing.sm
                                visible: toolTabs.currentIndex === 1

                                Label {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    bold: false
                                    text: "Matches highlight in the input as you type. Buttons below write results to the output panel."
                                    textColor: Theme.dividerColor
                                    pixelSize: Typography.h6
                                }

                                Column {
                                    width: parent.width
                                    spacing: LayoutMetrics.spacing.xxs
                                    Label {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "Pattern preset"
                                        style_2: true
                                    }
                                    ComboBox {
                                        id: presetCombo
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: toolContent.fieldWidth
                                        model: textToolsVM.regexPresets
                                        scrollablePopup: true
                                        onActivated: function(index) {
                                            patternField.text = textToolsVM.presetPattern(model[index])
                                            presetHint.text = textToolsVM.presetDescription(model[index])
                                        }
                                    }
                                    Label {
                                        id: presetHint
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                        wrapMode: Text.WordWrap
                                        bold: false
                                        text: "Presets fill the pattern field; you can edit it afterwards."
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
                                        text: "Pattern"
                                        style_2: true
                                    }
                                    LineEdit {
                                        id: patternField
                                        width: parent.width
                                        placeholderText: "Regular expression, e.g. \\b\\w+@\\w+\\.\\w+\\b"
                                        onTextChanged: page.refreshMatches()
                                    }
                                    RowLayout {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: LayoutMetrics.spacing.md
                                        Repeater {
                                            model: textToolsVM.regexFlags
                                            Switch {
                                                text: modelData
                                                onToggled: {
                                                    page.regexFlags =
                                                        page.toggleIn(page.regexFlags, modelData)
                                                    page.refreshMatches()
                                                }
                                            }
                                        }
                                    }
                                    RowLayout {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: LayoutMetrics.spacing.xs
                                        Button {
                                            Layout.alignment: Qt.AlignVCenter
                                            buttonText: "Show matches"
                                            primary: true
                                            onPressed: page.runFind()
                                        }
                                        Button {
                                            Layout.alignment: Qt.AlignVCenter
                                            buttonText: "Split by pattern"
                                            onPressed: page.runSplit()
                                        }
                                        SpinBox {
                                            id: splitSpin
                                            Layout.preferredWidth: LayoutMetrics.size.spinBoxWidth
                                            Layout.alignment: Qt.AlignVCenter
                                            from: 0
                                            to: 9999
                                            value: 0
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
                                        text: "Replacement"
                                        style_2: true
                                    }
                                    LineEdit {
                                        id: regexReplaceField
                                        width: parent.width
                                        placeholderText: "Use \\1 or $1 to reference a capture group"
                                    }
                                    RowLayout {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: LayoutMetrics.spacing.xs
                                        Button {
                                            buttonText: "Replace all matches"
                                            onPressed: page.runRegexReplace(true)
                                        }
                                        Button {
                                            buttonText: "Replace first match"
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
                                        text: "Matches"
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

                            // Sorters -----------------------------------------
                            Column {
                                width: parent.width
                                spacing: LayoutMetrics.spacing.sm
                                visible: toolTabs.currentIndex === 2

                                Label {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    bold: false
                                    text: "Sort lines, words, characters and table columns, or shuffle them with a repeatable seed."
                                    textColor: Theme.dividerColor
                                    pixelSize: Typography.h6
                                }

                                Column {
                                    width: parent.width
                                    spacing: LayoutMetrics.spacing.xxs
                                    Label {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "Sort by"
                                        style_2: true
                                    }
                                    RowLayout {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: LayoutMetrics.spacing.sm
                                        ComboBox {
                                            id: sortUnitCombo
                                            Layout.preferredWidth: toolContent.fieldWidth
                                            Layout.alignment: Qt.AlignVCenter
                                            model: textToolsVM.sortUnits
                                        }
                                        ComboBox {
                                            id: sortKeyCombo
                                            Layout.preferredWidth: toolContent.fieldWidth
                                            Layout.alignment: Qt.AlignVCenter
                                            model: textToolsVM.sortKeys
                                        }
                                        ComboBox {
                                            id: sortOrderCombo
                                            Layout.preferredWidth: toolContent.fieldWidth
                                            Layout.alignment: Qt.AlignVCenter
                                            model: textToolsVM.sortOrders
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
                                        text: "Options"
                                        style_2: true
                                    }
                                    RowLayout {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: LayoutMetrics.spacing.md
                                        Switch {
                                            id: caseSensitiveSwitch
                                            text: "Case sensitive"
                                        }
                                        Switch {
                                            id: uniqueSwitch
                                            text: "Unique only"
                                        }
                                    }
                                }

                                Column {
                                    width: parent.width
                                    spacing: LayoutMetrics.spacing.xxs
                                    visible: sortUnitCombo.currentText === "Columns"
                                    Label {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "Columns (zero based)"
                                        style_2: true
                                    }
                                    RowLayout {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: LayoutMetrics.spacing.sm
                                        SpinBox {
                                            id: sortColumnSpin
                                            Layout.preferredWidth: LayoutMetrics.size.spinBoxWidth
                                            Layout.alignment: Qt.AlignVCenter
                                            from: 0
                                            to: 999
                                            value: 0
                                        }
                                        SpinBox {
                                            id: secondaryColumnSpin
                                            Layout.preferredWidth: LayoutMetrics.size.spinBoxWidth
                                            Layout.alignment: Qt.AlignVCenter
                                            from: -1
                                            to: 999
                                            value: -1
                                        }
                                        ComboBox {
                                            id: secondaryOrderCombo
                                            Layout.preferredWidth: toolContent.fieldWidth
                                            Layout.alignment: Qt.AlignVCenter
                                            model: textToolsVM.sortOrders
                                        }
                                    }
                                    Label {
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                        wrapMode: Text.WordWrap
                                        bold: false
                                        text: "First spin box is the primary column, second is the tie-breaker (-1 disables it). Delimiter: "
                                              + (page.dataDelimiter === "\t" ? "Tab" : page.dataDelimiter)
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
                                        text: "Sort"
                                        style_2: true
                                    }
                                    Button {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        buttonText: "Sort input"
                                        primary: true
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
                                        text: "Shuffle"
                                        style_2: true
                                    }
                                    RowLayout {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: LayoutMetrics.spacing.sm
                                        ComboBox {
                                            id: shuffleUnitCombo
                                            Layout.preferredWidth: toolContent.fieldWidth
                                            Layout.alignment: Qt.AlignVCenter
                                            model: textToolsVM.sortUnits
                                        }
                                        SpinBox {
                                            id: seedSpin
                                            Layout.preferredWidth: LayoutMetrics.size.spinBoxWidth
                                            Layout.alignment: Qt.AlignVCenter
                                            from: 0
                                            to: 999999
                                            value: 0
                                        }
                                        Button {
                                            Layout.alignment: Qt.AlignVCenter
                                            buttonText: "Shuffle input"
                                            onPressed: page.runShuffle()
                                        }
                                    }
                                }
                            }

                            // Text / data -------------------------------------
                            Column {
                                width: parent.width
                                spacing: LayoutMetrics.spacing.sm
                                visible: toolTabs.currentIndex === 3

                                Label {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    bold: false
                                    text: "Convert delimited text and JSON, or pull out a single column."
                                    textColor: Theme.dividerColor
                                    pixelSize: Typography.h6
                                }

                                Column {
                                    width: parent.width
                                    spacing: LayoutMetrics.spacing.xxs
                                    Label {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "Delimiter"
                                        style_2: true
                                    }
                                    ComboBox {
                                        id: delimiterCombo
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: toolContent.fieldWidth
                                        model: textToolsVM.delimiters
                                        textRole: "name"
                                        currentIndex: 0
                                        onCurrentIndexChanged: {
                                            if (currentIndex >= 0
                                                    && currentIndex < textToolsVM.delimiters.length)
                                                page.dataDelimiter =
                                                    textToolsVM.delimiters[currentIndex].value
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
                                        text: "Options"
                                        style_2: true
                                    }
                                    RowLayout {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: LayoutMetrics.spacing.md
                                        Switch {
                                            id: headerSwitch
                                            text: "First row is header"
                                            checked: true
                                        }
                                        Switch {
                                            id: prettySwitch
                                            text: "Pretty JSON"
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
                                        text: "Fields for JSON to delimited"
                                        style_2: true
                                    }
                                    LineEdit {
                                        id: fieldsField
                                        width: parent.width
                                        placeholderText: "Optional, comma separated; leave empty to use the first object's keys"
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
                                        text: "Convert"
                                        style_2: true
                                    }
                                    RowLayout {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: LayoutMetrics.spacing.xs
                                        Button {
                                            Layout.alignment: Qt.AlignVCenter
                                            buttonText: "To JSON"
                                            primary: true
                                            onPressed: page.runDelimitedToJson()
                                        }
                                        Button {
                                            Layout.alignment: Qt.AlignVCenter
                                            buttonText: "To delimited"
                                            onPressed: page.runJsonToDelimited()
                                        }
                                        Button {
                                            Layout.alignment: Qt.AlignVCenter
                                            buttonText: "Markdown table"
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
                                        text: "Extract column"
                                        style_2: true
                                    }
                                    RowLayout {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: LayoutMetrics.spacing.sm
                                        SpinBox {
                                            id: extractColumnSpin
                                            Layout.preferredWidth: LayoutMetrics.size.spinBoxWidth
                                            Layout.alignment: Qt.AlignVCenter
                                            from: 0
                                            to: 999
                                            value: 0
                                        }
                                        Button {
                                            Layout.alignment: Qt.AlignVCenter
                                            buttonText: "Extract column"
                                            onPressed: page.runExtractColumn()
                                        }
                                    }
                                }
                            }

                            // Batch replace ----------------------------------
                            Column {
                                width: parent.width
                                spacing: LayoutMetrics.spacing.sm
                                visible: toolTabs.currentIndex === 4

                                Label {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    bold: false
                                    text: "Add your own rules. All enabled rules run in one pass, so swaps such as X to A and A to X work cleanly."
                                    textColor: Theme.dividerColor
                                    pixelSize: Typography.h6
                                }

                                Column {
                                    width: parent.width
                                    spacing: LayoutMetrics.spacing.xxs
                                    Label {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "Replace rules"
                                        style_2: true
                                    }

                                    Label {
                                        width: parent.width
                                        visible: page.replaceRules.length === 0
                                        horizontalAlignment: Text.AlignHCenter
                                        wrapMode: Text.WordWrap
                                        bold: false
                                        text: "No rules yet. Add one below to get started."
                                        textColor: Theme.dividerColor
                                        pixelSize: Typography.h6
                                    }

                                    Column {
                                        width: parent.width
                                        spacing: LayoutMetrics.spacing.xs
                                        Repeater {
                                            model: page.replaceRules

                                            Rectangle {
                                                width: parent.width
                                                height: LayoutMetrics.size.controlHeightHuge
                                                radius: LayoutMetrics.radius.s
                                                color: Theme.backgroundColor
                                                border.color: Theme.borderColor
                                                border.width: LayoutMetrics.border.s

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: LayoutMetrics.spacing.xs
                                                    spacing: LayoutMetrics.spacing.xs

                                                    Switch {
                                                        Layout.preferredWidth: LayoutMetrics.unit * 6
                                                        Component.onCompleted: checked = modelData.enabled !== false
                                                        onToggled: page.setRuleField(index, "enabled", checked)
                                                    }
                                                    LineEdit {
                                                        Layout.fillWidth: true
                                                        Layout.minimumWidth: 0
                                                        Layout.alignment: Qt.AlignVCenter
                                                        placeholderText: "Find"
                                                        Component.onCompleted: text = modelData.find
                                                        onTextEdited: page.setRuleField(index, "find", text)
                                                    }
                                                    LineEdit {
                                                        Layout.fillWidth: true
                                                        Layout.minimumWidth: 0
                                                        Layout.alignment: Qt.AlignVCenter
                                                        placeholderText: "Replace with"
                                                        Component.onCompleted: text = modelData.replace
                                                        onTextEdited: page.setRuleField(index, "replace", text)
                                                    }
                                                    // Small, borderless remove icon.
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
                                            buttonText: "Add rule"
                                            onPressed: page.addRule()
                                        }
                                        Button {
                                            buttonText: "Clear rules"
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
                                        text: "Rule options"
                                        style_2: true
                                    }
                                    RowLayout {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: LayoutMetrics.spacing.md
                                        Switch {
                                            id: batchCaseSwitch
                                            text: "Case sensitive"
                                        }
                                        Switch {
                                            id: batchRegexSwitch
                                            text: "Regex patterns"
                                        }
                                        Switch {
                                            id: batchWordSwitch
                                            text: "Whole words"
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
                                        text: "Apply"
                                        style_2: true
                                    }
                                    Button {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        buttonText: "Replace all rules"
                                        primary: true
                                        onPressed: page.runBatchReplace()
                                    }
                                }
                            }
                        }
                    }
                }

                // Persistent output panel -------------------------------------
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
                                text: "Output"
                                textColor: Theme.textColor
                                pixelSize: Typography.h5
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Item { Layout.fillWidth: true }

                            Button {
                                id: copyOutputButton
                                buttonText: "Copy"
                                onPressed: outputEdit.copy()
                            }
                        }

                        Label {
                            id: statusLabel
                            Layout.fillWidth: true
                            bold: false
                            text: "Run a tool to see its result here"
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
                            placeholderText: "Results appear here and stay visible."
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
