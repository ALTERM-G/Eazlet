import QtQuick
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
                Layout.preferredHeight: LayoutMetrics.spacing.xxs
                color: Theme.dividerColor
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

            TextEdit {
                id: dictionaryOutput
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.fillHeight: true
                visible: dictionaryVM.hasResult
                readOnly: true
                wrapMode: Text.Wrap
                fontPixelSize: Typography.body
                text: dictionaryVM.output
                showCopyButton: true
            }
        }
    }
}
