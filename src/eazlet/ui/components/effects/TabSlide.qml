import QtQuick
import components

// Applies the Settings-style slide/fade transition to a tabbed page. Attach it
// to the tab bar and the item that holds the page content:
//
//     TabSlide { tabBar: tabs; target: contentColumn }
Item {
    id: root
    visible: false
    width: 0
    height: 0

    property var tabBar: null
    property Item target: null
    property int lastIndex: 0

    readonly property Item stage: target !== null ? target : root

    function resetStage() {
        if (!root.stage)
            return
        root.stage.x = 0
        root.stage.opacity = 1
    }

    function slideToTab(newIndex) {
        if (!root.stage)
            return
        var dir = newIndex >= root.lastIndex ? 1 : -1
        root.lastIndex = newIndex
        if (!LayoutMetrics.animationsEnabled) {
            root.resetStage()
            return
        }
        root.stage.x = dir * root.stage.width
        root.stage.opacity = 0
        tabSlideX.from = dir * root.stage.width
        tabSlideX.to = 0
        tabSlideOpacity.from = 0
        tabSlideOpacity.to = 1
        tabSlide.start()
    }

    function syncIndex() {
        if (root.tabBar)
            root.lastIndex = root.tabBar.currentIndex
    }

    onTabBarChanged: root.syncIndex()
    onTargetChanged: root.syncIndex()
    Component.onCompleted: root.syncIndex()

    Connections {
        target: root.tabBar
        function onCurrentIndexChanged() {
            root.slideToTab(root.tabBar.currentIndex)
        }
    }

    ParallelAnimation {
        id: tabSlide
        NumberAnimation {
            id: tabSlideX
            target: root.stage
            property: "x"
            duration: 220
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            id: tabSlideOpacity
            target: root.stage
            property: "opacity"
            duration: 220
            easing.type: Easing.OutQuad
        }
    }
}
