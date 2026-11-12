import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import components

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
        controller.apply_saved_settings()
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
                    { source: "pages/Generators.qml" }
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
