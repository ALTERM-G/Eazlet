import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import components

Column {
    id: generalTab

    required property QtObject settingsMenu
    required property QtObject settingsPopup
    required property QtObject settingsTabBar

    visible: settingsTabBar.currentIndex === 0
    height: visible ? implicitHeight : 0
    clip: true
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: LayoutMetrics.spacing.lg

    property bool resetConfirming: false
    property var historyEntries: []

    readonly property var startupPages: [
        { label: Lang.sidebar.home, page: 0 },
        { label: Lang.sidebar.codeTools, page: 5 },
        { label: Lang.sidebar.textTools, page: 14 },
        { label: Lang.sidebar.textAnalysis, page: 6 },
        { label: Lang.sidebar.dictionary, page: 11 },
        { label: Lang.sidebar.downloader, page: 1 },
        { label: Lang.sidebar.converter, page: 2 },
        { label: Lang.sidebar.archive, page: 3 },
        { label: Lang.sidebar.organizer, page: 4 },
        { label: Lang.sidebar.math, page: 9 },
        { label: Lang.sidebar.numberTools, page: 8 },
        { label: Lang.sidebar.tierList, page: 13 },
        { label: Lang.sidebar.colors, page: 12 },
        { label: Lang.sidebar.generators, page: 10 },
        { label: Lang.sidebar.asciiArt, page: 7 }
    ]

    function indexForStartupPage(page) {
        for (var i = 0; i < startupPages.length; i++) {
            if (startupPages[i].page === page)
                return i
        }
        return 0
    }

    function refreshHistory() {
        var list = controller.get_history()
        var out = []
        if (list && list.length !== undefined) {
            for (var i = 0; i < list.length; i++) {
                var e = list[i] || {}
                out.push({
                    time: e.time !== undefined ? String(e.time) : "",
                    tool: e.tool !== undefined ? String(e.tool) : "",
                    action: e.action !== undefined ? String(e.action) : "",
                    input: e.input !== undefined ? String(e.input) : "",
                    output: e.output !== undefined ? String(e.output) : ""
                })
            }
        }
        historyEntries = out
    }

    function resetControls() {
        resetConfirming = false

        languageCombo.initialized = false
        languageCombo.currentIndex = controller.get_language()
        languageCombo.initialized = true

        startupCombo.initialized = false
        startupCombo.currentIndex = indexForStartupPage(controller.get_startup_page())
        startupCombo.initialized = true

        refreshHistory()
    }

    Connections {
        target: controller
        ignoreUnknownSignals: true
        function onHistoryChanged() { generalTab.refreshHistory() }
    }

    onVisibleChanged: {
        if (visible)
            refreshHistory()
    }

    Component.onCompleted: refreshHistory()

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: LayoutMetrics.spacing.xxs

        Label {
            text: Lang.labels.language
            style_2: true
        }

        ComboBox {
            id: languageCombo
            anchors.horizontalCenter: parent.horizontalCenter
            model: controller.get_languages()

            property bool initialized: false

            onCurrentIndexChanged: {
                if (initialized) {
                    controller.save_language(currentIndex)
                }
            }
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: LayoutMetrics.spacing.xxs

        Label {
            text: Lang.labels.startupPage
            style_2: true
        }

        ComboBox {
            id: startupCombo
            anchors.horizontalCenter: parent.horizontalCenter
            model: generalTab.startupPages
            textRole: "label"
            valueRole: "page"
            scrollablePopup: true
            maxVisibleItems: 10

            property bool initialized: false

            onActivated: function(index) {
                if (!initialized || index < 0 || index >= generalTab.startupPages.length)
                    return
                controller.save_startup_page(generalTab.startupPages[index].page)
            }
            onCurrentIndexChanged: {
                if (initialized && currentIndex >= 0 && currentIndex < generalTab.startupPages.length)
                    controller.save_startup_page(generalTab.startupPages[currentIndex].page)
            }
        }
    }

    Button {
        anchors.horizontalCenter: parent.horizontalCenter
        width: LayoutMetrics.size.comboBoxWidth
        height: LayoutMetrics.size.controlHeight * 2
        buttonText: Lang.labels.viewHistory
        onPressed: {
            generalTab.refreshHistory()
            historyPopup.open()
        }
    }

    Rectangle {
        width: Math.max(parent ? parent.width * 0.9 : LayoutMetrics.unit * 40, LayoutMetrics.unit * 36)
        height: LayoutMetrics.border.m
        color: Theme.dividerColor
        anchors.horizontalCenter: parent.horizontalCenter
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: LayoutMetrics.spacing.sm

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: generalTab.resetConfirming
            bold: false
            text: Lang.labels.resetSettingsConfirm
            textColor: Theme.dividerColor
            pixelSize: Typography.h6
            wrapMode: Text.WordWrap
            width: Math.min(implicitWidth, LayoutMetrics.unit * 36)
            horizontalAlignment: Text.AlignHCenter
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: LayoutMetrics.spacing.sm

            Button {
                width: generalTab.resetConfirming ? LayoutMetrics.size.comboBoxWidth * 0.5 : LayoutMetrics.size.comboBoxWidth
                height: LayoutMetrics.size.controlHeight * 2
                buttonText: generalTab.resetConfirming ? Lang.labels.reset : Lang.labels.resetSettings
                onPressed: {
                    if (!generalTab.resetConfirming) {
                        generalTab.resetConfirming = true
                    } else {
                        settingsMenu.resetAllToDefaults()
                        generalTab.resetConfirming = false
                    }
                }
            }

            Button {
                visible: generalTab.resetConfirming
                width: LayoutMetrics.size.comboBoxWidth * 0.5
                height: LayoutMetrics.size.controlHeight * 2
                buttonText: Lang.common.cancel
                onPressed: generalTab.resetConfirming = false
            }
        }
    }

    Popup {
        id: historyPopup
        parent: Overlay.overlay
        modal: true
        focus: true
        padding: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        anchors.centerIn: Overlay.overlay
        width: Math.min(Overlay.overlay ? Overlay.overlay.width - LayoutMetrics.spacing.xl * 2 : 720,
                        LayoutMetrics.unit * 72)
        height: Math.min(Overlay.overlay ? Overlay.overlay.height - LayoutMetrics.spacing.xl * 2 : 520,
                         LayoutMetrics.unit * 80)

        background: Rectangle {
            color: Theme.appBackgroundColor
            radius: LayoutMetrics.radius.m
            border.color: Theme.borderColor
            border.width: Math.max(1, LayoutMetrics.border.m)
        }

        onOpened: generalTab.refreshHistory()

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: LayoutMetrics.spacing.lg
            spacing: LayoutMetrics.spacing.md

            RowLayout {
                Layout.fillWidth: true
                spacing: LayoutMetrics.spacing.sm

                Label {
                    text: Lang.labels.historyTitle
                    style_2: true
                    Layout.fillWidth: true
                }

                Button {
                    buttonText: Lang.labels.clearHistory
                    enabled: generalTab.historyEntries.length > 0
                    onPressed: controller.clear_history()
                }

                Button {
                    buttonText: Lang.common.close
                    onPressed: historyPopup.close()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: LayoutMetrics.border.m
                color: Theme.dividerColor
            }

            Label {
                visible: generalTab.historyEntries.length === 0
                text: Lang.labels.noHistory
                bold: false
                textColor: Theme.dividerColor
                pixelSize: Typography.h6
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            ScrollView {
                id: historyScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: generalTab.historyEntries.length > 0
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                Column {
                    id: historyList
                    width: historyScroll.availableWidth
                    spacing: LayoutMetrics.spacing.sm

                    Repeater {
                        model: Math.min(generalTab.historyEntries.length, 100)

                        delegate: Rectangle {
                            id: historyItem
                            required property int index
                            readonly property var entry: (index >= 0 && index < generalTab.historyEntries.length)
                                                         ? generalTab.historyEntries[index] : ({})
                            width: historyList.width
                            implicitHeight: entryColumn.implicitHeight + LayoutMetrics.spacing.sm * 2
                            radius: LayoutMetrics.radius.s
                            color: Theme.inputBackgroundColor
                            border.color: Theme.borderColor
                            border.width: Math.max(1, LayoutMetrics.border.m)

                            Column {
                                id: entryColumn
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: LayoutMetrics.spacing.sm
                                spacing: LayoutMetrics.spacing.xs

                                Label {
                                    width: parent.width
                                    text: (entry.time || "") + "  ·  " + (entry.tool || "") + "  ·  " + (entry.action || "")
                                    bold: true
                                    pixelSize: Typography.h6
                                    wrapMode: Text.WordWrap
                                }

                                Label {
                                    visible: (entry.input || "").length > 0
                                    width: parent.width
                                    text: Lang.common.input
                                    style_2: true
                                    pixelSize: Typography.h6
                                }

                                Text {
                                    visible: (entry.input || "").length > 0
                                    width: parent.width
                                    text: entry.input || ""
                                    color: Theme.textColor
                                    font.family: Typography.fontRegular
                                    font.pixelSize: Typography.h6
                                    wrapMode: Text.WrapAnywhere
                                    textFormat: Text.PlainText
                                }

                                Label {
                                    visible: (entry.output || "").length > 0
                                    width: parent.width
                                    text: Lang.common.output
                                    style_2: true
                                    pixelSize: Typography.h6
                                }

                                Text {
                                    visible: (entry.output || "").length > 0
                                    width: parent.width
                                    text: entry.output || ""
                                    color: Theme.textColor
                                    font.family: Typography.fontRegular
                                    font.pixelSize: Typography.h6
                                    wrapMode: Text.WrapAnywhere
                                    textFormat: Text.PlainText
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
