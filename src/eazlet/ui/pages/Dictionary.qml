import QtQuick
import QtQuick as QQ
import QtQuick.Controls
import QtQuick.Layouts
import components

Item {
    id: page

    Layout.fillWidth: true
    Layout.fillHeight: true

    function processAction() {
        dictionaryVM.search()
    }

    Surface {
        anchors.centerIn: parent
        width: parent.width * 0.9
        height: parent.height * 0.9

        ColumnLayout {
            id: contentLayout
            width: Math.max(0, parent.width - LayoutMetrics.spacing.lg * 2)
            height: parent.height - LayoutMetrics.spacing.lg * 2
            x: (parent.width - width) / 2
            y: LayoutMetrics.spacing.lg
            spacing: LayoutMetrics.spacing.md

            Title {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: contentLayout.width
                Layout.maximumWidth: contentLayout.width
                horizontalAlignment: Text.AlignHCenter
                text: "Dictionary"
                textColor: Theme.textColor
                pixelSize: Typography.h2
                elide: Text.ElideRight
            }

            Label {
                Layout.fillWidth: true
                Layout.preferredWidth: contentLayout.width
                Layout.maximumWidth: contentLayout.width
                horizontalAlignment: Text.AlignHCenter
                bold: false
                text: "Look up meanings, examples, and synonyms for any English word."
                textColor: Theme.dividerColor
                pixelSize: Typography.h6
                wrapMode: Text.WordWrap
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredHeight: LayoutMetrics.spacing.xxs
                color: Theme.dividerColor
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: LayoutMetrics.spacing.sm

                LineEdit {
                    id: wordInput
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: dictionaryVM.word
                    placeholderText: "Type a word, then press Search"
                    onTextEdited: dictionaryVM.word = text
                    onAccepted: dictionaryVM.search()
                }

                Button {
                    buttonText: dictionaryVM.searching ? "Searching…" : "Search"
                    primary: true
                    isometric: true
                    heightMultiplier: 1.3
                    enabled: !dictionaryVM.searching
                    onPressed: dictionaryVM.search()
                }

                Button {
                    buttonText: "Example"
                    enabled: !dictionaryVM.searching
                    onPressed: dictionaryVM.loadExample()
                }

                Button {
                    buttonText: "Clear"
                    iconPath: SVGLibrary.eraser
                    enabled: !dictionaryVM.searching
                    onPressed: dictionaryVM.clear()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: LayoutMetrics.spacing.sm

                Label {
                    bold: false
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: dictionaryVM.status
                    textColor: Theme.dividerColor
                    pixelSize: Typography.body
                    elide: Text.ElideRight
                }

                Label {
                    bold: false
                    visible: dictionaryVM.hasResult && dictionaryVM.phonetic !== ""
                    text: dictionaryVM.phonetic
                    textColor: Theme.dividerColor
                    pixelSize: Typography.body
                    elide: Text.ElideRight
                }

                Label {
                    bold: false
                    text: "Source: dictionaryapi.dev"
                    textColor: Theme.dividerColor
                    pixelSize: Typography.caption
                    elide: Text.ElideRight
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: LayoutMetrics.spacing.sm
                visible: dictionaryVM.error !== ""

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
                    text: dictionaryVM.error
                    textColor: "red"
                    pixelSize: Typography.body
                    wrapMode: Text.WordWrap
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.topMargin: LayoutMetrics.spacing.xs
                Layout.bottomMargin: LayoutMetrics.spacing.xs
                height: LayoutMetrics.border.m
                radius: height / 2
                color: Theme.dividerColor
                opacity: 0.6
            }

            Item {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.fillHeight: true
                visible: !dictionaryVM.hasResult && !dictionaryVM.searching

                Column {
                    width: Math.min(parent.width * 0.8, LayoutMetrics.unit * 60)
                    anchors.centerIn: parent
                    spacing: LayoutMetrics.spacing.md

                    Label {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: "No word yet"
                        textColor: Theme.textColor
                        pixelSize: Typography.h3
                    }

                    Label {
                        bold: false
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: "Type an English word above and press Search to see its parts of speech, definitions, examples, and synonyms."
                        textColor: Theme.dividerColor
                        pixelSize: Typography.h6
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Flickable {
                id: resultsFlick
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.fillHeight: true
                visible: dictionaryVM.hasResult
                contentHeight: resultsColumn.implicitHeight
                clip: true
                interactive: false
                flickableDirection: Flickable.VerticalFlick
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: AppScrollBar {}

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
                    width: Math.max(0, resultsFlick.width - LayoutMetrics.unit * 1.6)
                    spacing: LayoutMetrics.spacing.md

                    Label {
                        bold: false
                        width: parent.width
                        visible: dictionaryVM.origin !== ""
                        text: "Origin: " + dictionaryVM.origin
                        textColor: Theme.dividerColor
                        pixelSize: Typography.caption
                        wrapMode: Text.WordWrap
                    }

                    Repeater {
                        model: dictionaryVM.entries

                        delegate: Rectangle {
                            width: resultsColumn.width
                            height: meaningColumn.implicitHeight
                                    + LayoutMetrics.spacing.md * 2
                            radius: LayoutMetrics.radius.m
                            color: Theme.inputBackgroundColor
                            border.color: Theme.borderColor
                            border.width: LayoutMetrics.border.m
                            clip: true

                            Column {
                                id: meaningColumn
                                x: LayoutMetrics.spacing.md
                                y: LayoutMetrics.spacing.md
                                width: Math.max(0, parent.width
                                                - LayoutMetrics.spacing.md * 2)
                                spacing: LayoutMetrics.spacing.sm

                                Row {
                                    width: parent.width
                                    spacing: LayoutMetrics.spacing.sm

                                    Label {
                                        bold: false
                                        text: modelData.partOfSpeech
                                        textColor: Theme.themeColor
                                        pixelSize: Typography.h4
                                        elide: Text.ElideRight
                                    }

                                    Label {
                                        bold: false
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.definitions.length === 1
                                            ? "1 definition"
                                            : modelData.definitions.length + " definitions"
                                        textColor: Theme.dividerColor
                                        pixelSize: Typography.caption
                                    }
                                }

                                Repeater {
                                    model: modelData.definitions

                                    delegate: Column {
                                        width: parent.width
                                        spacing: LayoutMetrics.unit * 0.35

                                        QQ.TextEdit {
                                            readOnly: true
                                            selectByMouse: true
                                            cursorVisible: false
                                            width: parent.width
                                            text: (index + 1) + ". " + modelData.definition
                                            color: Theme.textColor
                                            font.pixelSize: Typography.body
                                            font.family: Typography.fontRegular
                                            font.weight: Font.Normal
                                            wrapMode: TextEdit.WordWrap
                                            height: implicitHeight
                                        }

                                        QQ.TextEdit {
                                            visible: modelData.example !== ""
                                            readOnly: true
                                            selectByMouse: true
                                            cursorVisible: false
                                            width: parent.width
                                            text: "\u201C" + modelData.example + "\u201D"
                                            color: Theme.dividerColor
                                            font.pixelSize: Typography.caption
                                            font.family: Typography.fontRegular
                                            font.weight: Font.Normal
                                            wrapMode: TextEdit.WordWrap
                                            height: implicitHeight
                                        }

                                        QQ.TextEdit {
                                            visible: modelData.synonyms.length > 0
                                            readOnly: true
                                            selectByMouse: true
                                            cursorVisible: false
                                            width: parent.width
                                            text: "Synonyms: " + modelData.synonyms.join(", ")
                                            color: Theme.dividerColor
                                            font.pixelSize: Typography.caption
                                            font.family: Typography.fontRegular
                                            font.weight: Font.Normal
                                            wrapMode: TextEdit.WordWrap
                                            height: implicitHeight
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
