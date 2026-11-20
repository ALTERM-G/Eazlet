import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import components
import "tabs"

    Item {
        id: settingsMenu
        property bool isPopupOpen: settingsPopup.opened


    property string appearancePendingTheme: Theme.currentTheme
    property string appearanceCommittedTheme: Theme.currentTheme
    property int appearanceCommittedScale: Math.round((controller.get_scale_factor() - 0.5) * 200)
    property int appearancePendingScale: Math.round((controller.get_scale_factor() - 0.5) * 200)
    property bool appearancePendingResponsive: controller.get_is_continuous()
    property bool appearanceCommittedResponsive: controller.get_is_continuous()
    property int appearanceCommittedRadius: Math.round(controller.get_corner_radius() * 50)
    property int appearancePendingRadius: appearanceCommittedRadius
    property bool appearanceCommittedAnimations: controller.get_animations_enabled()
    property bool appearancePendingAnimations: controller.get_animations_enabled()
    property string appearancePendingFont: Typography.fontFamily
    property string appearanceCommittedFont: Typography.fontFamily
    property int prevTabIndex: 0

    readonly property int scaleMin: 0
    readonly property int scaleMax: 200
    readonly property int scaleStep: 4

    readonly property int radiusMin: 0
    readonly property int radiusMax: 100

    function applyRadius(radius) {
        var factor = radius / 50
        LayoutMetrics.setCornerRadiusFactor(factor)
        controller.save_corner_radius(factor)
    }

    function applyScale(scale, persist) {
        var factor = 0.5 + scale / 200
        LayoutMetrics.scaleFactor = factor
        Typography.scaleFactor = factor
        if (persist === undefined || persist)
            controller.save_scale_factor(factor)
    }

    function applyFont(family) {
        if (family === Typography.fontFamily)
            return
        var crossfade = LayoutMetrics.window ? LayoutMetrics.window.crossfade : null
        var commit = function () {
            Typography.fontFamily = family
            controller.save_font_family(family)
        }
        if (crossfade && LayoutMetrics.animationsEnabled)
            crossfade.run(commit)
        else
            commit()
    }

    function slideToTab(newIndex) {
        var dir = newIndex > prevTabIndex ? 1 : -1
        prevTabIndex = newIndex
        if (!LayoutMetrics.animationsEnabled) {
            tabStage.x = 0
            tabStage.opacity = 1
            return
        }
        tabStage.x = dir * tabStage.width
        tabStage.opacity = 0
        tabSlideX.from = dir * tabStage.width
        tabSlideX.to = 0
        tabSlideOpacity.from = 0
        tabSlideOpacity.to = 1
        tabSlide.start()
    }

    Timer {
        id: scalePersistTimer
        interval: 500
        repeat: false
        onTriggered: settingsMenu.applyScale(settingsMenu.appearanceCommittedScale, true)
    }

    function nudgeScale(direction) {
        var base = settingsPopup.opened ? appearancePendingScale : appearanceCommittedScale
        var next = Math.max(scaleMin, Math.min(scaleMax, base + direction * scaleStep))
        if (next === appearancePendingScale && next === appearanceCommittedScale)
            return
        appearancePendingScale = next
        appearanceCommittedScale = next
        if (settingsPopup.opened)
            appearanceTab.setScaleValue(next)

        applyScale(next, false)
        scalePersistTimer.restart()
    }

    function applyAppearanceChanges() {
        scalePersistTimer.stop()
        Theme.setTheme(appearancePendingTheme)
        applyScale(appearancePendingScale, true)
        LayoutMetrics.isContinuous = appearancePendingResponsive
        Typography.isContinuous = appearancePendingResponsive
        controller.save_is_continuous(appearancePendingResponsive)
        applyFont(appearancePendingFont)
        applyRadius(appearancePendingRadius)
        LayoutMetrics.setAnimationsEnabled(appearancePendingAnimations)
        controller.save_animations_enabled(appearancePendingAnimations)
        appearanceCommittedTheme = appearancePendingTheme
        appearanceCommittedScale = appearancePendingScale
        appearanceCommittedResponsive = appearancePendingResponsive
        appearanceCommittedFont = appearancePendingFont
        appearanceCommittedRadius = appearancePendingRadius
        appearanceCommittedAnimations = appearancePendingAnimations
    }

    function cancelAppearanceChanges() {
        scalePersistTimer.stop()
        appearancePendingTheme = appearanceCommittedTheme
        appearancePendingScale = appearanceCommittedScale
        appearancePendingResponsive = appearanceCommittedResponsive
        appearancePendingAnimations = appearanceCommittedAnimations
        appearancePendingFont = appearanceCommittedFont
        appearancePendingRadius = appearanceCommittedRadius
        appearanceTab.resetControls()
        applyRadius(appearanceCommittedRadius)
        Theme.setTheme(appearanceCommittedTheme)
        applyScale(appearanceCommittedScale, false)
        LayoutMetrics.isContinuous = appearanceCommittedResponsive
        Typography.isContinuous = appearanceCommittedResponsive
        applyFont(appearanceCommittedFont)
    }

    function toggleSettings() {
        if (settingsPopup.opened) {
            cancelAppearanceChanges()
            settingsPopup.close()
        } else {
            settingsPopup.open()
        }
    }

    function resetAllToDefaults() {
        controller.reset_settings()
        Theme.setTheme(controller.get_current_theme())
        var factor = controller.get_scale_factor()
        LayoutMetrics.setScaleFactor(factor)
        Typography.scaleFactor = factor
        var cont = controller.get_is_continuous()
        LayoutMetrics.setIsContinuous(cont)
        Typography.isContinuous = cont
        LayoutMetrics.setCornerRadiusFactor(controller.get_corner_radius())
        LayoutMetrics.setAnimationsEnabled(controller.get_animations_enabled())
        Theme.animationsEnabled = LayoutMetrics.animationsEnabled
        Typography.fontFamily = controller.get_font_family()
        Shortcuts.resetAll()
        scalePersistTimer.stop()
        loadAppearance()
        appearanceTab.resetControls()
        generalTab.resetControls()
    }

    ParallelAnimation {
        id: tabSlide
        NumberAnimation {
            id: tabSlideX
            target: tabStage
            property: "x"
            duration: 220
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            id: tabSlideOpacity
            target: tabStage
            property: "opacity"
            duration: 220
            easing.type: Easing.OutQuad
        }
    }

    Connections {
        target: tabBar
        function onCurrentIndexChanged() {
            settingsMenu.slideToTab(tabBar.currentIndex)
        }
    }

    Connections {
        target: settingsPopup
        function onOpened() {
            settingsMenu.loadAppearance()
            appearanceTab.resetControls()
            generalTab.resetControls()
            settingsBackButton.forceActiveFocus()
        }
    }

    function loadAppearance() {
        appearanceCommittedTheme = Theme.currentTheme
        appearancePendingTheme = appearanceCommittedTheme
        var savedFactor = controller.get_scale_factor()
        appearanceCommittedScale = Math.round((savedFactor - 0.5) * 200)
        appearancePendingScale = appearanceCommittedScale
        appearanceCommittedResponsive = controller.get_is_continuous()
        appearancePendingResponsive = appearanceCommittedResponsive
        appearanceCommittedAnimations = controller.get_animations_enabled()
        appearancePendingAnimations = appearanceCommittedAnimations
        appearanceCommittedFont = Typography.fontFamily
        appearancePendingFont = appearanceCommittedFont
        appearanceCommittedRadius = Math.round(controller.get_corner_radius() * 50)
        appearancePendingRadius = appearanceCommittedRadius
    }

    IconButton {
        id: settingsButton
        anchors.centerIn: parent
        buttonWidth: LayoutMetrics.size.iconButton
        buttonHeight: LayoutMetrics.size.iconButton
        iconPath: SVGLibrary.settings
        activeFocusOnTab: true

        ToolTip {
            text: Lang.titles.settings
            visible: settingsButton.hovered
            delay: 600
        }

        onPressed: settingsMenu.toggleSettings()
    }

    Popup {
        id: settingsPopup
        width: Math.min(LayoutMetrics.unit * 46, LayoutMetrics.window.width - LayoutMetrics.spacing.lg * 2)
        height: Math.min(LayoutMetrics.window.height - LayoutMetrics.size.topBarHeight - LayoutMetrics.spacing.lg * 2,
                         LayoutMetrics.unit * 64)
        x: LayoutMetrics.window.width - width - LayoutMetrics.spacing.sm
        y: LayoutMetrics.size.topBarHeight + LayoutMetrics.spacing.xs
        transformOrigin: Item.TopRight
        padding: 0
        background: Item {}
        focus: true
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onOpened: {
            Shortcuts.overlayOpen = true
            settingsBackButton.forceActiveFocus()
        }
        onClosed: {
            Shortcuts.capturing = false
            Shortcuts.overlayOpen = false
        }

        enter: LayoutMetrics.animationsEnabled ? settingsPopupFadeEnter : settingsPopupInstantEnter
        exit: LayoutMetrics.animationsEnabled ? settingsPopupFadeExit : settingsPopupInstantExit

        Transition {
            id: settingsPopupInstantEnter
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 0 }
                NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: 0 }
            }
        }

        Transition {
            id: settingsPopupInstantExit
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 0 }
                NumberAnimation { property: "scale"; from: 1; to: 0.95; duration: 0 }
            }
        }

        Transition {
            id: settingsPopupFadeEnter
            ParallelAnimation {
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 200
                    easing.type: Easing.InOutQuad
                }
                NumberAnimation {
                    property: "scale"
                    from: 0.95
                    to: 1
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }
        }

        Transition {
            id: settingsPopupFadeExit
            ParallelAnimation {
                NumberAnimation {
                    property: "opacity"
                    from: 1
                    to: 0
                    duration: 200
                    easing.type: Easing.InOutQuad
                }
                NumberAnimation {
                    property: "scale"
                    from: 1
                    to: 0.95
                    duration: 200
                    easing.type: Easing.InQuad
                }
            }
        }

        Surface {
            anchors.fill: parent

            IconButton {
                id: settingsBackButton
                activeFocusOnTab: true
                anchors.top: parent.top
                anchors.topMargin: LayoutMetrics.spacing.xl
                anchors.left: parent.left
                anchors.leftMargin: LayoutMetrics.spacing.xl
                buttonWidth: LayoutMetrics.size.iconButton
                buttonHeight: LayoutMetrics.size.iconButton
                iconPath: SVGLibrary.back
                onPressed: {
                    cancelAppearanceChanges()
                    settingsPopup.close()
                }
            }

            Title {
                id: title
                text: Lang.titles.settings
                anchors.top: parent.top
                anchors.topMargin: LayoutMetrics.spacing.xl
                anchors.horizontalCenter: parent.horizontalCenter
            }

            TabBar {
                id: tabBar
                anchors.top: title.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.topMargin: LayoutMetrics.spacing.lg
                tabData: [Lang.tabs.general, Lang.tabs.appearance, Lang.tabs.shortcuts]
                overlay: true
                active: settingsPopup.opened
            }

            Rectangle {
                anchors.top: tabBar.bottom
                anchors.topMargin: LayoutMetrics.spacing.md
                anchors.left: parent.left
                anchors.right: parent.right
                height: LayoutMetrics.divider.s
                color: Theme.dividerColor
            }

            ScrollView {
                id: scrollView
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: tabBar.bottom
                anchors.topMargin: LayoutMetrics.spacing.md + LayoutMetrics.spacing.xxs
                anchors.bottom: generalFooter.visible ? generalFooter.top : parent.bottom
                anchors.bottomMargin: generalFooter.visible ? LayoutMetrics.spacing.md : 0
                contentHeight: scrollContent.height
                clip: true
                ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                Binding {
                    target: scrollView.contentItem
                    property: "boundsBehavior"
                    value: Flickable.StopAtBounds
                    when: scrollView.contentItem !== null
                    restoreMode: Binding.RestoreNone
                }

                Binding {
                    target: scrollView.contentItem
                    property: "acceptedButtons"
                    value: Qt.NoButton
                    when: scrollView.contentItem !== null
                    restoreMode: Binding.RestoreNone
                }

                WheelScrollArea {
                    target: scrollView.contentItem
                }

                Item {
                    id: scrollContent
                    width: scrollView.width
                    height: LayoutMetrics.spacing.xxl
                            + tabStage.height
                            + LayoutMetrics.spacing.xl * 3

                    Item {
                        id: tabStage
                        anchors.top: parent.top
                        x: 0
                        width: parent.width
                        height: contentColumn.height

                        Column {
                            id: contentColumn
                            x: 0
                            width: tabStage.width
                            anchors.top: parent.top
                            anchors.topMargin: LayoutMetrics.spacing.xxl
                            spacing: LayoutMetrics.spacing.lg

                            GeneralTab {
                                id: generalTab
                                settingsMenu: settingsMenu
                                settingsPopup: settingsPopup
                                settingsTabBar: tabBar
                            }
                            AppearanceTab {
                                id: appearanceTab
                                settingsMenu: settingsMenu
                                settingsPopup: settingsPopup
                                settingsTabBar: tabBar
                            }
                            AdvancedTab {
                                id: advancedTab
                                settingsTabBar: tabBar
                            }
                        }
                    }
                }
            }

            Column {
                id: generalFooter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: LayoutMetrics.spacing.lg
                anchors.horizontalCenter: parent.horizontalCenter
                visible: tabBar.currentIndex === 0
                spacing: LayoutMetrics.spacing.xs

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Lang.labels.version
                    style_2: true
                }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    bold: false
                    text: controller.get_app_version() + " — " + Lang.labels.firstVersion
                    textColor: Theme.dividerColor
                    pixelSize: Typography.h6
                }
            }
        }
    }

    Shortcut {
        sequences: Shortcuts.chords("zoomIn")
        context: Qt.ApplicationShortcut
        enabled: !Shortcuts.capturing
        onActivated: settingsMenu.nudgeScale(1)
    }
    Shortcut {
        sequence: Shortcuts.primary("zoomOut")
        context: Qt.ApplicationShortcut
        enabled: !Shortcuts.capturing
        onActivated: settingsMenu.nudgeScale(-1)
    }
    Shortcut {
        sequence: Shortcuts.primary("openSettings")
        context: Qt.ApplicationShortcut
        enabled: !Shortcuts.capturing
        onActivated: settingsMenu.toggleSettings()
    }
}
