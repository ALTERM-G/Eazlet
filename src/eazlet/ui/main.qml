import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import components
import "pages"

Window {
    id: window
    visible: true
    color: Theme.backgroundColor
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
    }

    function triggerProcessAction() {
        if (stackLayout && stackLayout.currentIndex >= 0
                && stackLayout.currentIndex < stackLayout.count) {
            var page = stackLayout.itemAt(stackLayout.currentIndex)
            if (page && typeof page.processAction === "function")
                page.processAction()
        }
    }

    FontCrossfade {
        id: fontCrossfade
    }

    TopBar {
        id: topBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        onSidebarToggleClicked: sidebar.toggle()

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

            Home { id: homePage }
            DownloadUnified { id: downloadPage }
            Converter { id: converterPage }
            Archive { id: archivePage }
            Organizer { id: organizerPage }
            Cipher { id: cipherPage }
            TextAnalysis { id: textAnalysisPage }
            AsciiArt { id: asciiArtPage }
            NumberTools { id: numberToolsPage }
        }
    }
}
