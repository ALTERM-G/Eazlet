import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import components

Item {
    id: page

    Layout.fillWidth: true
    Layout.fillHeight: true

    function processAction() {
        textAnalysisVM.process()
    }

    function compositionColor(index) {
        switch (index) {
        case 0: return Theme.themeColor
        case 1: return Qt.lighter(Theme.themeColor, 1.35)
        case 2: return Theme.hoverBackgroundColor
        default: return Theme.borderColor
        }
    }

    component Panel: Rectangle {
        id: panel

        property string heading: ""
        property string subtitle: ""
        default property alias contentData: body.data
        readonly property real contentHeight: body.implicitHeight
                                               + LayoutMetrics.spacing.md * 2

        radius: LayoutMetrics.radius.m
        color: Theme.inputBackgroundColor
        border.color: Theme.borderColor
        border.width: LayoutMetrics.border.m
        clip: true

        Column {
            id: body
            anchors.fill: parent
            anchors.margins: LayoutMetrics.spacing.md
            spacing: LayoutMetrics.spacing.sm

            Label {
                width: parent.width
                text: panel.heading
                textColor: Theme.textColor
                pixelSize: Typography.h4
                elide: Text.ElideRight
            }

            Label {
                width: parent.width
                visible: panel.subtitle !== ""
                text: panel.subtitle
                bold: false
                textColor: Theme.dividerColor
                pixelSize: Typography.caption
                elide: Text.ElideRight
            }
        }
    }

    Surface {
        anchors.centerIn: parent
        width: parent.width * 0.94
        height: parent.height * 0.94

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: LayoutMetrics.spacing.lg
            spacing: LayoutMetrics.spacing.md

            RowLayout {
                Layout.fillWidth: true
                spacing: LayoutMetrics.spacing.sm

                Title {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: "Text Analysis"
                    textColor: Theme.textColor
                    pixelSize: Typography.h2
                    elide: Text.ElideRight
                }

                Switch {
                    text: "Code / unusual"
                    checked: textAnalysisVM.mode === "code"
                    onCheckedChanged: {
                        var nextMode = checked ? "code" : "text"
                        if (nextMode !== textAnalysisVM.mode)
                            textAnalysisVM.setMode(nextMode)
                    }
                }

                Button {
                    buttonText: "Process"
                    primary: true
                    isometric: true
                    heightMultiplier: 1.3
                    onPressed: textAnalysisVM.process()
                }

                Button {
                    buttonText: "Clear"
                    iconPath: SVGLibrary.eraser
                    onPressed: textAnalysisVM.clear()
                }
            }

            TextEdit {
                id: analysisInput
                Layout.fillWidth: true
                Layout.preferredHeight: LayoutMetrics.unit * 13
                text: textAnalysisVM.input
                placeholderText: textAnalysisVM.mode === "code"
                    ? "Paste code, a random string, or other unusual text, then press Process..."
                    : "Paste or type text here, then press Process..."
                onTextChanged: textAnalysisVM.input = text
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: LayoutMetrics.spacing.sm

                Label {
                    bold: false
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: textAnalysisVM.status
                    textColor: Theme.dividerColor
                    pixelSize: Typography.body
                    elide: Text.ElideRight
                }

                Label {
                    bold: false
                    visible: textAnalysisVM.hasResults
                    text: textAnalysisVM.mode === "code"
                        ? textAnalysisVM.readabilityLabel
                        : "Readability: " + textAnalysisVM.readabilityLabel
                    textColor: Theme.dividerColor
                    pixelSize: Typography.body
                    elide: Text.ElideRight
                }

                Button {
                    buttonText: "Copy report"
                    iconPath: SVGLibrary.copy
                    visible: textAnalysisVM.hasResults
                    onPressed: textAnalysisVM.copyReport()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: LayoutMetrics.spacing.sm
                visible: textAnalysisVM.error !== ""

                SVGObject {
                    Layout.preferredWidth: LayoutMetrics.size.iconS
                    Layout.preferredHeight: LayoutMetrics.size.iconS
                    Layout.alignment: Qt.AlignVCenter
                    path: SVGLibrary.cross
                    color: "red"
                }

                Label {
                    bold: false
                    Layout.fillWidth: true
                    text: textAnalysisVM.error
                    textColor: "red"
                    pixelSize: Typography.body
                    wrapMode: Text.WordWrap
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: LayoutMetrics.spacing.xs
                Layout.bottomMargin: LayoutMetrics.spacing.xs
                height: LayoutMetrics.border.m
                radius: height / 2
                color: Theme.dividerColor
                opacity: 0.6
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !textAnalysisVM.hasResults

                Column {
                    width: Math.min(parent.width * 0.8, LayoutMetrics.unit * 60)
                    anchors.centerIn: parent
                    spacing: LayoutMetrics.spacing.md

                    Label {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: "No analysis yet"
                        textColor: Theme.textColor
                        pixelSize: Typography.h3
                    }

                    Label {
                        bold: false
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: "Paste or type some text above and press Process to see what the analyzer reports."
                        textColor: Theme.dividerColor
                        pixelSize: Typography.h6
                        wrapMode: Text.WordWrap
                    }

                }
            }

            Flickable {
                id: resultsFlick
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: textAnalysisVM.hasResults
                contentHeight: resultsColumn.implicitHeight
                clip: true
                interactive: false
                flickableDirection: Flickable.VerticalFlick
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                implicitWidth: LayoutMetrics.unit * 1.2
            }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: function(wheel) {
                        var delta = wheel.pixelDelta.y !== 0
                            ? wheel.pixelDelta.y * 2
                            : wheel.angleDelta.y / 120 * LayoutMetrics.unit * 24
                        var maxY = Math.max(0, resultsFlick.contentHeight - resultsFlick.height)
                        resultsFlick.contentY = Math.max(0, Math.min(maxY, resultsFlick.contentY - delta))
                        wheel.accepted = true
                    }
                }

                Column {
                    id: resultsColumn
                    width: Math.max(0, resultsFlick.width - LayoutMetrics.spacing.md)
                    spacing: LayoutMetrics.spacing.md

                    readonly property real cardGap: LayoutMetrics.spacing.md
                    readonly property bool twoColumns: width >= LayoutMetrics.unit * 62

                    Grid {
                        id: statsGrid
                        width: parent.width
                        columns: Math.max(2, Math.min(6,
                                  Math.floor(width / Math.max(1, LayoutMetrics.unit * 15))))
                        spacing: LayoutMetrics.spacing.md

                        Repeater {
                            model: textAnalysisVM.stats

                            delegate: Rectangle {
                                width: (statsGrid.width
                                        - statsGrid.spacing * (statsGrid.columns - 1))
                                       / Math.max(1, statsGrid.columns)
                                height: LayoutMetrics.unit * 9
                                radius: LayoutMetrics.radius.m
                                color: Theme.inputBackgroundColor
                                border.color: Theme.borderColor
                                border.width: LayoutMetrics.border.m
                                clip: true

                                Column {
                                    width: Math.max(0, parent.width
                                                         - LayoutMetrics.spacing.sm * 2)
                                    anchors.centerIn: parent
                                    spacing: LayoutMetrics.unit * 0.3

                                    Label {
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                        text: modelData.value
                                        textColor: Theme.textColor
                                        pixelSize: Typography.h3
                                        elide: Text.ElideRight
                                    }

                                    Label {
                                        bold: false
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                        text: modelData.label
                                        textColor: Theme.dividerColor
                                        pixelSize: Typography.caption
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }

                    Grid {
                        id: cardsGrid
                        width: parent.width
                        columns: resultsColumn.twoColumns ? 2 : 1
                        spacing: resultsColumn.cardGap

                        readonly property real cardWidth: columns > 0
                            ? (width - spacing * (columns - 1)) / columns
                            : width
                        readonly property real firstRowHeight: Math.max(
                            topWordsPanel.contentHeight,
                            tokenLengthPanel.contentHeight,
                            LayoutMetrics.unit * 20)
                        readonly property real secondRowHeight: Math.max(
                            characterPanel.contentHeight,
                            longestWordsPanel.contentHeight,
                            LayoutMetrics.unit * 20)

                        Panel {
                            id: topWordsPanel
                            width: cardsGrid.cardWidth
                            height: cardsGrid.columns > 1
                                    ? cardsGrid.firstRowHeight
                                    : Math.max(LayoutMetrics.unit * 20, contentHeight)
                            heading: textAnalysisVM.mode === "code" ? "Top tokens" : "Top words"
                            subtitle: textAnalysisVM.topWords.length === 0
                                      ? (textAnalysisVM.mode === "code"
                                         ? "Run an analysis to see frequent tokens."
                                         : "Run an analysis to see frequent words.")
                                      : (textAnalysisVM.mode === "code"
                                         ? "Most frequent tokens in the input."
                                         : "Common stop words are skipped.")

                            Column {
                                width: parent.width
                                spacing: LayoutMetrics.unit * 0.35

                                Repeater {
                                    model: textAnalysisVM.topWords

                                    delegate: Item {
                                        width: parent.width
                                        height: LayoutMetrics.unit * 2.6

                                        readonly property real labelWidth: LayoutMetrics.unit * 24
                                        readonly property real countWidth: LayoutMetrics.unit * 5
                                        readonly property real barX: labelWidth
                                                                  + LayoutMetrics.spacing.sm
                                        readonly property real barWidth: Math.max(
                                            0, parent.width - labelWidth - countWidth
                                               - LayoutMetrics.spacing.sm * 2)

                                        Label {
                                            bold: false
                                            width: labelWidth
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.word
                                            textColor: Theme.textColor
                                            pixelSize: Typography.h6
                                            elide: Text.ElideRight
                                        }

                                        Rectangle {
                                            x: barX
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: barWidth
                                            height: LayoutMetrics.unit * 1.3
                                            radius: height / 2
                                            color: Theme.dividerColor
                                            opacity: 0.25
                                        }

                                        Rectangle {
                                            x: barX
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: Math.max(2, barWidth * modelData.count
                                                               / Math.max(1, textAnalysisVM.topWordMax))
                                            height: LayoutMetrics.unit * 1.3
                                            radius: height / 2
                                            color: Theme.themeColor
                                        }

                                        Label {
                                            bold: false
                                            width: countWidth
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            horizontalAlignment: Text.AlignRight
                                            text: modelData.count
                                            textColor: Theme.dividerColor
                                            pixelSize: Typography.caption
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }

                        Panel {
                            id: tokenLengthPanel
                            width: cardsGrid.cardWidth
                            height: cardsGrid.columns > 1
                                    ? cardsGrid.firstRowHeight
                                    : Math.max(LayoutMetrics.unit * 20, contentHeight)
                            heading: textAnalysisVM.mode === "code" ? "Token length distribution" : "Word length distribution"
                            subtitle: textAnalysisVM.mode === "code"
                                      ? "Number of tokens by character count."
                                      : "Number of words by character count."

                            Label {
                                bold: false
                                width: parent.width
                                visible: textAnalysisVM.wordLengths.length === 0
                                text: textAnalysisVM.mode === "code" ? "No token length data yet." : "No word length data yet."
                                textColor: Theme.dividerColor
                                pixelSize: Typography.h6
                                wrapMode: Text.WordWrap
                            }

                            Item {
                                width: parent.width
                                height: textAnalysisVM.wordLengths.length > 0 ? LayoutMetrics.unit * 30 : 0
                                visible: textAnalysisVM.wordLengths.length > 0

                                Row {
                                    id: lengthRow
                                    width: parent.width
                                    height: parent.height
                                    spacing: LayoutMetrics.unit * 0.55

                                    Repeater {
                                        model: textAnalysisVM.wordLengths

                                        delegate: Item {
                                            width: Math.max(0,
                                                (lengthRow.width
                                                 - lengthRow.spacing * Math.max(0,
                                                       textAnalysisVM.wordLengths.length - 1))
                                                / Math.max(1, textAnalysisVM.wordLengths.length))
                                            height: parent.height

                                            Rectangle {
                                                id: lengthBar
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                anchors.bottom: lengthLabel.top
                                                anchors.bottomMargin: LayoutMetrics.unit * 0.4
                                                width: Math.max(2, parent.width * 0.64)
                                                height: Math.max(2,
                                                    (parent.height - LayoutMetrics.unit * 24.5)
                                                    * modelData.count
                                                    / Math.max(1, textAnalysisVM.wordLengthMax))
                                                radius: LayoutMetrics.radius.s
                                                color: Theme.themeColor
                                            }

                                            Label {
                                                bold: false
                                                width: parent.width
                                                horizontalAlignment: Text.AlignHCenter
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                anchors.bottom: lengthBar.top
                                                anchors.bottomMargin: LayoutMetrics.unit * 0.4
                                                text: modelData.count
                                                visible: modelData.count > 0
                                                textColor: Theme.dividerColor
                                                pixelSize: Typography.caption
                                                elide: Text.ElideRight
                                            }

                                            Label {
                                                id: lengthLabel
                                                bold: false
                                                width: parent.width
                                                horizontalAlignment: Text.AlignHCenter
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                anchors.bottom: parent.bottom
                                                text: modelData.length
                                                textColor: Theme.dividerColor
                                                pixelSize: Typography.caption
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Panel {
                            id: characterPanel
                            width: cardsGrid.cardWidth
                            height: cardsGrid.columns > 1
                                    ? cardsGrid.secondRowHeight
                                    : Math.max(LayoutMetrics.unit * 20, contentHeight)
                            heading: "Character composition"
                            subtitle: "Letters, digits, whitespace, and punctuation."

                            Column {
                                width: parent.width
                                spacing: LayoutMetrics.spacing.sm

                                Rectangle {
                                    id: compositionBar
                                    width: parent.width
                                    height: LayoutMetrics.unit * 3
                                    radius: LayoutMetrics.radius.s
                                    color: "transparent"
                                    clip: true

                                    Row {
                                        anchors.fill: parent
                                        spacing: 0

                                        Repeater {
                                            model: textAnalysisVM.characterComposition

                                            delegate: Rectangle {
                                                width: compositionBar.width
                                                       * modelData.value
                                                       / Math.max(1, textAnalysisVM.characterTotal)
                                                height: parent.height
                                                color: compositionColor(index)
                                            }
                                        }
                                    }
                                }

                                Column {
                                    width: parent.width
                                    spacing: LayoutMetrics.unit * 0.35

                                    Repeater {
                                        model: textAnalysisVM.characterComposition

                                        delegate: Item {
                                            width: parent.width
                                            height: LayoutMetrics.unit * 2.8

                                            Rectangle {
                                                id: legendSwatch
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: LayoutMetrics.unit * 1.4
                                                height: width
                                                radius: LayoutMetrics.radius.s
                                                color: compositionColor(index)
                                            }

                                            Label {
                                                bold: false
                                                anchors.left: legendSwatch.right
                                                anchors.leftMargin: LayoutMetrics.spacing.sm
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: Math.max(0, parent.width * 0.36)
                                                text: modelData.name
                                                textColor: Theme.textColor
                                                pixelSize: Typography.h6
                                                elide: Text.ElideRight
                                            }

                                            Label {
                                                bold: false
                                                anchors.right: legendPercent.left
                                                anchors.rightMargin: LayoutMetrics.spacing.sm
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: LayoutMetrics.unit * 24
                                                horizontalAlignment: Text.AlignRight
                                                text: modelData.value
                                                textColor: Theme.dividerColor
                                                pixelSize: Typography.caption
                                                elide: Text.ElideRight
                                            }

                                            Label {
                                                id: legendPercent
                                                bold: false
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: LayoutMetrics.unit * 7
                                                horizontalAlignment: Text.AlignRight
                                                text: (modelData.value
                                                       / Math.max(1, textAnalysisVM.characterTotal)
                                                       * 100).toFixed(1) + "%"
                                                textColor: Theme.dividerColor
                                                pixelSize: Typography.caption
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Panel {
                            id: longestWordsPanel
                            width: cardsGrid.cardWidth
                            height: cardsGrid.columns > 1
                                    ? cardsGrid.secondRowHeight
                                    : Math.max(LayoutMetrics.unit * 20, contentHeight)
                            heading: textAnalysisVM.mode === "code" ? "Longest tokens" : "Longest words"
                            subtitle: textAnalysisVM.mode === "code"
                                      ? "Distinct tokens, sorted by length."
                                      : "Distinct words, sorted by length."

                            Label {
                                bold: false
                                width: parent.width
                                visible: textAnalysisVM.longestWords.length === 0
                                text: textAnalysisVM.mode === "code" ? "No token data yet." : "No word data yet."
                                textColor: Theme.dividerColor
                                pixelSize: Typography.h6
                                wrapMode: Text.WordWrap
                            }

                            Column {
                                width: parent.width
                                spacing: LayoutMetrics.unit * 0.35
                                visible: textAnalysisVM.longestWords.length > 0

                                Repeater {
                                    model: textAnalysisVM.longestWords

                                    delegate: Row {
                                        width: parent.width
                                        spacing: LayoutMetrics.spacing.sm

                                        Label {
                                            bold: false
                                            width: parent.width - lengthLabel.implicitWidth - parent.spacing
                                            text: modelData.word
                                            textColor: Theme.textColor
                                            pixelSize: Typography.h6
                                            elide: Text.ElideMiddle
                                            wrapMode: Text.NoWrap
                                        }

                                        Label {
                                            id: lengthLabel
                                            bold: false
                                            text: modelData.length
                                            textColor: Theme.dividerColor
                                            pixelSize: Typography.caption
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
