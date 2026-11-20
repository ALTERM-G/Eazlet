import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import components

Window {
    id: window
    visible: true
    // Home is a single flat surface with no card, so use the text field colour
    // across the whole content area while it is active.
    readonly property bool homeActive: stackLayout && stackLayout.currentIndex === 0
    property bool writerMode: false
    color: homeActive ? Theme.inputBackgroundColor : Theme.backgroundColor
    width: 1280
    height: 720
    readonly property bool animationsEnabled: LayoutMetrics.animationsEnabled
    onAnimationsEnabledChanged: Theme.animationsEnabled = animationsEnabled
    readonly property var crossfade: fontCrossfade
    title: Lang.titles.appName
    Component.onCompleted: {
        LayoutMetrics.bindToWindow(window)
        Typography.setWindow(window)
        Theme.animationsEnabled = animationsEnabled
        controller.apply_saved_settings()
        controller.apply_app_icon(Theme.currentTheme)
        var startupPage = controller.get_startup_page()
        if (startupPage >= 0 && startupPage <= 14)
            sidebar.currentIndex = startupPage
    }

    Connections {
        target: Theme
        function onCurrentThemeChanged() {
            controller.apply_app_icon(Theme.currentTheme)
        }
    }

    function currentPage() {
        if (!stackLayout || stackLayout.currentIndex < 0
                || stackLayout.currentIndex >= stackLayout.count)
            return null

        var item = stackLayout.itemAt(stackLayout.currentIndex)
        // Pages are wrapped in lazy Loaders, so unwrap the created item.
        return item && item.item !== undefined ? item.item : item
    }

    function triggerProcessAction() {
        var page = currentPage()
        if (page && typeof page.processAction === "function")
            page.processAction()
    }

    FontCrossfade {
        id: fontCrossfade
    }

    TopBar {
        id: topBar
        showAppTitle: !window.homeActive
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        onSidebarToggleClicked: sidebar.toggle()

        IconButton {
            id: writerToggleButton
            iconPath: SVGLibrary.textTools
            buttonWidth: LayoutMetrics.size.iconButton
            buttonHeight: LayoutMetrics.size.iconButton
            anchors.right: settings.left
            anchors.rightMargin: LayoutMetrics.spacing.sm
            anchors.verticalCenter: parent.verticalCenter
            activeFocusOnTab: true
            onPressed: window.writerMode = !window.writerMode

            ToolTip {
                text: Lang.labels.writer
                visible: writerToggleButton.hovered
                delay: 600
            }
        }

        Settings {
            id: settings
            width: LayoutMetrics.size.iconButton
            height: LayoutMetrics.size.iconButton
            anchors.right: parent.right
            anchors.rightMargin: Math.max(0, (LayoutMetrics.size.topBarHeight - height) / 2)
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    SideBar {
        id: sidebar
        anchors.top: topBar.bottom
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        z: 200
        onNavigationClicked: function(index) { stackLayout.currentIndex = index; sidebar.expanded = false }
    }

    MouseArea {
        anchors.top: topBar.bottom
        anchors.left: sidebar.right
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        z: 999
        visible: sidebar.expanded
        onPressed: function (mouse) {
            sidebar.expanded = false
            mouse.accepted = false
        }
    }

    Shortcut {
        id: processShortcut
        context: Qt.ApplicationShortcut
        sequence: {
            var _dep = Shortcuts.overrides
            return Shortcuts.primary("processAction")
        }
        enabled: !Shortcuts.capturing
        onActivated: window.triggerProcessAction()
    }

    Rectangle {
        id: writerOverlay
        width: parent ? parent.width : 0
        height: parent ? parent.height : 0
        y: 0
        x: window.writerMode ? 0 : width
        z: 500
        visible: x < width || window.writerMode
        color: Theme.appBackgroundColor

        Behavior on x {
            enabled: LayoutMetrics.animationsEnabled
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }

        property string lastSavedText: ""
        property bool closingAfterSave: false
        readonly property bool dirty: writerTextArea.text !== lastSavedText

        function requestClose() {
            if (dirty)
                unsavedPopup.open()
            else
                window.writerMode = false
        }

        function saveText(url) {
            var result = controller.save_text_file(url.toString(), writerTextArea.text)
            if (result && result.length > 0) {
                lastSavedText = writerTextArea.text
                if (closingAfterSave) {
                    closingAfterSave = false
                    window.writerMode = false
                }
            }
        }

        FileDialog {
            id: writerSaveDialog
            title: Lang.labels.saveFile
            fileMode: FileDialog.SaveFile
            nameFilters: ["Markdown (*.md)", "Text (*.txt)", "All files (*)"]
            defaultSuffix: "md"
            onAccepted: writerOverlay.saveText(selectedFile)
            onRejected: writerOverlay.closingAfterSave = false
        }

        Shortcut {
            sequences: [StandardKey.Save]
            enabled: window.writerMode
            onActivated: writerSaveDialog.open()
        }

        Popup {
            id: unsavedPopup
            modal: true
            focus: true
            parent: Overlay.overlay
            anchors.centerIn: Overlay.overlay
            padding: LayoutMetrics.spacing.lg
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

            background: Rectangle {
                color: Theme.appBackgroundColor
                radius: LayoutMetrics.radius.m
                border.color: Theme.borderColor
                border.width: Math.max(1, LayoutMetrics.border.m)
            }

            contentItem: ColumnLayout {
                spacing: LayoutMetrics.spacing.md

                Label {
                    text: Lang.labels.unsavedChanges
                    style_2: true
                    Layout.fillWidth: true
                }

                Label {
                    text: Lang.labels.unsavedChangesPrompt
                    bold: false
                    textColor: Theme.dividerColor
                    pixelSize: Typography.h6
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    Layout.maximumWidth: LayoutMetrics.unit * 36
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: LayoutMetrics.spacing.sm

                    Button {
                        buttonText: Lang.labels.dontSave
                        onPressed: {
                            unsavedPopup.close()
                            window.writerMode = false
                        }
                    }

                    Button {
                        buttonText: Lang.common.cancel
                        onPressed: unsavedPopup.close()
                    }

                    Button {
                        buttonText: Lang.common.save
                        onPressed: {
                            writerOverlay.closingAfterSave = true
                            unsavedPopup.close()
                            writerSaveDialog.open()
                        }
                    }
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: LayoutMetrics.spacing.lg
            spacing: LayoutMetrics.spacing.lg

            RowLayout {
                Layout.fillWidth: true
                spacing: LayoutMetrics.spacing.md

                IconButton {
                    iconPath: SVGLibrary.back
                    buttonWidth: LayoutMetrics.size.iconButton
                    buttonHeight: LayoutMetrics.size.iconButton
                    onPressed: writerOverlay.requestClose()
                    ToolTip { text: Lang.common.back; visible: parent.hovered; delay: 600 }
                }

                Label {
                    text: Lang.labels.writer
                    bold: true
                    pixelSize: Typography.h2
                    textColor: Theme.textColor
                    Layout.fillWidth: true
                }

                Button {
                    buttonText: Lang.labels.saveFile
                    onPressed: writerSaveDialog.open()
                }
            }

            ScrollView {
                id: writerScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                TextArea {
                    id: writerTextArea
                    width: writerScroll.availableWidth
                    placeholderText: Lang.labels.writerPlaceholder
                    placeholderTextColor: Theme.dividerColor
                    textFormat: TextEdit.MarkdownText
                    wrapMode: TextEdit.Wrap
                    selectByMouse: true
                    color: Theme.textColor
                    selectedTextColor: Theme.appBackgroundColor
                    selectionColor: Theme.themeColor
                    font.family: Typography.fontRegular
                    font.pixelSize: Typography.body
                    focus: window.writerMode
                    padding: 0
                    leftPadding: 0
                    rightPadding: 0
                    topPadding: 0
                    bottomPadding: 0
                    background: Rectangle { color: "transparent" }
                }
            }
        }
    }

    Rectangle {
        id: contentArea
        color: Theme.backgroundColor
        anchors.top: topBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        focus: true

        Keys.onPressed: function(event) {
            if (typeof Shortcuts !== "undefined" && !Shortcuts.capturing
                    && Shortcuts.matchesAction("processAction", event)) {
                window.triggerProcessAction()
                event.accepted = true
            }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: function(mouse) {
                if (sidebar.expanded) {
                    sidebar.expanded = false
                }
                contentArea.forceActiveFocus()
            }
        }

        StackLayout {
            id: stackLayout
            anchors.fill: parent
            currentIndex: sidebar.currentIndex >= 0 ? sidebar.currentIndex : 0

            // Pages are created on first visit and then kept alive so their
            // state (including text inputs) survives switching workspaces.
            // Loading them lazily keeps startup and page switches responsive.
            property var loaded: ({})
            function markLoaded(index) {
                if (index < 0 || loaded[index] === true)
                    return
                var next = Object.assign({}, loaded)
                next[index] = true
                loaded = next
            }
            Component.onCompleted: markLoaded(currentIndex)
            onCurrentIndexChanged: markLoaded(currentIndex)

            Repeater {
                model: [
                    { source: "pages/Home.qml" },
                    { source: "pages/DownloadUnified.qml" },
                    { source: "pages/Converter.qml" },
                    { source: "pages/Archive.qml" },
                    { source: "pages/Organizer.qml" },
                    { source: "pages/Cipher.qml" },
                    { source: "pages/TextAnalysis.qml" },
                    { source: "pages/AsciiArt.qml" },
                    { source: "pages/NumberTools.qml" },
                    { source: "pages/Mathematics.qml" },
                    { source: "pages/Generators.qml" },
                    { source: "pages/Dictionary.qml" },
                    { source: "pages/Colors.qml" },
                    { source: "pages/TierList.qml" },
                    { source: "pages/TextTools.qml" }
                ]

                delegate: Loader {
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    active: stackLayout.loaded[index] === true
                    asynchronous: false
                    source: modelData.source
                }
            }
        }
    }
}
