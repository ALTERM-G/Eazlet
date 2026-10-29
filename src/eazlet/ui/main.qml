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

            Home {}
            DownloadUnified {}
            Converter {}
        }
    }
}
