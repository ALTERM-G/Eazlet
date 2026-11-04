import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import components

Item {
    id: page

    Layout.fillWidth: true
    Layout.fillHeight: true

    function compositionColor(index) {
        switch (index) {
        case 0: return Theme.themeColor
        case 1: return Qt.lighter(Theme.themeColor, 1.35)
        case 2: return Theme.hoverBackgroundColor
        default: return Theme.borderColor
        }
    }

    Surface {
        anchors.centerIn: parent
        width: parent.width * 0.92
        height: parent.height * 0.92

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: LayoutMetrics.spacing.lg
            spacing: LayoutMetrics.spacing.md

            RowLayout {
                Layout.fillWidth: true
                spacing: LayoutMetrics.spacing.sm

                Title {
                    Layout.fillWidth: true
                    text: "Text Analysis"
                    textColor: Theme.textColor
                    pixelSize: Typography.h2
                }

                Button {
                    buttonText: "Process"
                    primary: true
                    onPressed: textAnalysisVM.process()
                }

                Button {
                    buttonText: "Clear"
                    onPressed: textAnalysisVM.clear()
                }
            }

            TextEdit {
                id: analysisInput
                Layout.fillWidth: true
                Layout.preferredHeight: 120
                text: textAnalysisVM.input
                placeholderText: "Paste or type text here, then press Process..."
                onTextChanged: textAnalysisVM.input = text
                Keys.onShortcutOverride: function(event) {
                    if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                            && (event.modifiers & Qt.ControlModifier))
                        event.accepted = true
                }
                Keys.onPressed: function(event) {
                    if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                            && (event.modifiers & Qt.ControlModifier)) {
                        textAnalysisVM.process()
                        event.accepted = true
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: LayoutMetrics.spacing.sm

                Label {
    bold: false
                    Layout.fillWidth: true
                    text: textAnalysisVM.status
                    textColor: Theme.dividerColor
                    pixelSize: Typography.body
                }

                Label {
    bold: false
                    text: textAnalysisVM.hasResults
                          ? "Readability: " + textAnalysisVM.readabilityLabel
                          : ""
                    textColor: Theme.dividerColor
                    pixelSize: Typography.body
                }
            }

            Label {
    bold: false
                Layout.fillWidth: true
                text: textAnalysisVM.error
                textColor: "red"
                pixelSize: Typography.body
                visible: textAnalysisVM.error !== ""
                wrapMode: Text.WordWrap
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !textAnalysisVM.hasResults

                Column {
                    anchors.centerIn: parent
                    spacing: LayoutMetrics.spacing.sm

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "No analysis yet"
                        textColor: Theme.textColor
                        pixelSize: Typography.h3
                    }

                    Label {
    bold: false
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Add some text above and press Process to see the stats and charts."
                        textColor: Theme.dividerColor
                        pixelSize: Typography.h6
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
                flickableDirection: Flickable.VerticalFlick
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                Column {
                    id: resultsColumn
                    width: resultsFlick.width - LayoutMetrics.spacing.md
                    spacing: LayoutMetrics.spacing.md

                    Grid {
                        id: statsGrid
                        width: parent.width
                        columns: 4
                        spacing: LayoutMetrics.spacing.md

                        Repeater {
                            model: textAnalysisVM.stats

                            delegate: Rectangle {
                                width: (statsGrid.width
                                        - statsGrid.spacing * (statsGrid.columns - 1))
                                       / statsGrid.columns
                                height: 74
                                radius: LayoutMetrics.radius.m
                                color: Theme.inputBackgroundColor
                                border.color: Theme.borderColor
                                border.width: LayoutMetrics.border.m

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 2

                                    Label {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.value
                                        textColor: Theme.textColor
                                        pixelSize: Typography.h3
                                    }

                                    Label {
    bold: false
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.label
                                        textColor: Theme.dividerColor
                                        pixelSize: Typography.caption
                                    }
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: LayoutMetrics.spacing.md

                        Rectangle {
                            id: topWordsCard
                            width: (parent.width - parent.spacing) * 0.55
                            height: 340
                            radius: LayoutMetrics.radius.m
                            color: Theme.inputBackgroundColor
                            border.color: Theme.borderColor
                            border.width: LayoutMetrics.border.m

                            Column {
                                anchors.fill: parent
                                anchors.margins: LayoutMetrics.spacing.md
                                spacing: LayoutMetrics.spacing.sm

                                Label {
                                    text: "Top words"
                                    textColor: Theme.textColor
                                    pixelSize: Typography.h4
                                }

                                Label {
    bold: false
                                    text: "Common stop words are skipped."
                                    textColor: Theme.dividerColor
                                    pixelSize: Typography.caption
                                }

                                Column {
                                    width: parent.width
                                    spacing: 3

                                    Repeater {
                                        model: textAnalysisVM.topWords

                                        delegate: Item {
                                            width: parent.width
                                            height: 20

                                            Label {
    bold: false
                                                width: 92
                                                text: modelData.word
                                                textColor: Theme.textColor
                                                pixelSize: Typography.h6
                                                elide: Text.ElideRight
                                            }

                                            Rectangle {
                                                x: 100
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: parent.width - 150
                                                height: 10
                                                radius: height / 2
                                                color: Theme.dividerColor
                                                opacity: 0.25
                                            }

                                            Rectangle {
                                                x: 100
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: Math.max(
                                                    2,
                                                    (parent.width - 150)
                                                    * modelData.count
                                                    / Math.max(1, textAnalysisVM.topWordMax)
                                                )
                                                height: 10
                                                radius: height / 2
                                                color: Theme.themeColor
                                            }

                                            Label {
    bold: false
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: modelData.count
                                                textColor: Theme.dividerColor
                                                pixelSize: Typography.caption
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width - topWordsCard.width - parent.spacing
                            height: 340
                            radius: LayoutMetrics.radius.m
                            color: Theme.inputBackgroundColor
                            border.color: Theme.borderColor
                            border.width: LayoutMetrics.border.m

                            Column {
                                anchors.fill: parent
                                anchors.margins: LayoutMetrics.spacing.md
                                spacing: LayoutMetrics.spacing.sm

                                Label {
                                    text: "Word length distribution"
                                    textColor: Theme.textColor
                                    pixelSize: Typography.h4
                                }

                                Item {
                                    width: parent.width
                                    height: parent.height - 34

                                    Row {
                                        width: parent.width
                                        height: parent.height
                                        spacing: 4

                                        Repeater {
                                            model: textAnalysisVM.wordLengths

                                            delegate: Item {
                                                width: (parent.width
                                                        - parent.spacing
                                                          * (textAnalysisVM.wordLengths.length - 1))
                                                       / Math.max(1, textAnalysisVM.wordLengths.length)
                                                height: parent.height

                                                Rectangle {
                                                    id: lengthBar
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    anchors.bottom: lengthLabel.top
                                                    width: parent.width * 0.65
                                                    height: Math.max(
                                                        2,
                                                        (parent.height - 38)
                                                        * modelData.count
                                                        / Math.max(1, textAnalysisVM.wordLengthMax)
                                                    )
                                                    radius: 2
                                                    color: Theme.themeColor
                                                }

                                                Label {
    bold: false
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    anchors.bottom: lengthBar.top
                                                    anchors.bottomMargin: 2
                                                    text: modelData.count
                                                    visible: modelData.count > 0
                                                    textColor: Theme.dividerColor
                                                    pixelSize: Typography.caption
                                                }

                                                Label {
    bold: false
                                                    id: lengthLabel
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    anchors.bottom: parent.bottom
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

                    Row {
                        width: parent.width
                        spacing: LayoutMetrics.spacing.md

                        Rectangle {
                            id: compositionCard
                            width: (parent.width - parent.spacing) * 0.55
                            height: 260
                            radius: LayoutMetrics.radius.m
                            color: Theme.inputBackgroundColor
                            border.color: Theme.borderColor
                            border.width: LayoutMetrics.border.m

                            Column {
                                anchors.fill: parent
                                anchors.margins: LayoutMetrics.spacing.md
                                spacing: LayoutMetrics.spacing.sm

                                Label {
                                    text: "Character composition"
                                    textColor: Theme.textColor
                                    pixelSize: Typography.h4
                                }

                                Row {
                                    width: parent.width
                                    height: 24
                                    spacing: 0

                                    Repeater {
                                        model: textAnalysisVM.characterComposition

                                        delegate: Rectangle {
                                            width: parent.width
                                                   * modelData.value
                                                   / Math.max(1, textAnalysisVM.characterTotal)
                                            height: parent.height
                                            color: compositionColor(index)
                                        }
                                    }
                                }

                                Column {
                                    width: parent.width
                                    spacing: 3

                                    Repeater {
                                        model: textAnalysisVM.characterComposition

                                        delegate: Row {
                                            width: parent.width
                                            height: 22
                                            spacing: LayoutMetrics.spacing.sm

                                            Rectangle {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 10
                                                height: 10
                                                radius: 2
                                                color: compositionColor(index)
                                            }

                                            Label {
    bold: false
                                                width: 80
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: modelData.name
                                                textColor: Theme.textColor
                                                pixelSize: Typography.h6
                                            }

                                            Item {
                                                width: parent.width - 80 - 90
                                                      - LayoutMetrics.spacing.sm * 3
                                                height: 1
                                            }

                                            Label {
    bold: false
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: modelData.value
                                                textColor: Theme.dividerColor
                                                pixelSize: Typography.caption
                                            }

                                            Label {
    bold: false
                                                width: 52
                                                anchors.verticalCenter: parent.verticalCenter
                                                horizontalAlignment: Text.AlignRight
                                                text: (modelData.value
                                                       / Math.max(1, textAnalysisVM.characterTotal)
                                                       * 100).toFixed(1) + "%"
                                                textColor: Theme.dividerColor
                                                pixelSize: Typography.caption
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width - compositionCard.width - parent.spacing
                            height: 260
                            radius: LayoutMetrics.radius.m
                            color: Theme.inputBackgroundColor
                            border.color: Theme.borderColor
                            border.width: LayoutMetrics.border.m

                            Column {
                                anchors.fill: parent
                                anchors.margins: LayoutMetrics.spacing.md
                                spacing: LayoutMetrics.spacing.sm

                                Label {
                                    text: "Longest words"
                                    textColor: Theme.textColor
                                    pixelSize: Typography.h4
                                }

                                Label {
    bold: false
                                    text: "Unique words, longest first."
                                    textColor: Theme.dividerColor
                                    pixelSize: Typography.caption
                                }

                                Column {
                                    width: parent.width
                                    spacing: 3

                                    Repeater {
                                        model: textAnalysisVM.longestWords

                                        delegate: Row {
                                            width: parent.width
                                            height: 22
                                            spacing: LayoutMetrics.spacing.sm

                                            Label {
    bold: false
                                                width: parent.width - 70
                                                text: modelData.word
                                                textColor: Theme.textColor
                                                pixelSize: Typography.h6
                                                elide: Text.ElideRight
                                            }

                                            Label {
    bold: false
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: modelData.length + " chars"
                                                textColor: Theme.dividerColor
                                                pixelSize: Typography.caption
                                            }
                                        }
                                    }
                                }
                            }
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
