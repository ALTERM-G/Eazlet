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
            anchors.right: parent.right
            anchors.rightMargin: LayoutMetrics.spacing.xxl * 1.5
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    SideBar {
        id: sidebar
        anchors.top: topBar.bottom
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        z: 100
        onNavigationClicked: function(index) { stackLayout.currentIndex = index }
    }

    MouseArea {
        anchors.top: topBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        enabled: sidebar.expanded && sidebar.autoCollapse
        propagateComposedEvents: true
        onPressed: function (mouse) {
            sidebar.expanded = false
            mouse.accepted = false
        }
    }

    Rectangle {
        id: contentArea
        color: Theme.backgroundColor
        anchors.top: topBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: contentArea.forceActiveFocus()
        }

        StackLayout {
            id: stackLayout
            anchors.fill: parent
            currentIndex: sidebar.currentIndex >= 0 ? sidebar.currentIndex : 0

            Home {}
            DownloadUnified {}
            Converter {}
        }
    }
}
