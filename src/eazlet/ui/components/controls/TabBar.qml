import QtQuick
import components

Rectangle {
    id: root
    color: Theme.backgroundColor
    border.color: Theme.borderColor
    border.width: LayoutMetrics.border.m
    radius: LayoutMetrics.radius.m

    property var tabData: []
    property alias currentIndex: listView.currentIndex

    property bool resizing: false

    // Tab switching shortcuts are handled here so every tab bar behaves the
    // same way. Page tab bars set `active` to their page's visibility, while
    // the settings tab bar runs inside an overlay.
    property bool active: true
    property bool overlay: false
    readonly property bool shortcutsActive: active && enabled && !Shortcuts.capturing
                                              && (overlay ? Shortcuts.overlayOpen
                                                          : !Shortcuts.overlayOpen)
    readonly property var nextSequences: Shortcuts.chords("nextTab")
    readonly property var previousSequences: {
        var sequences = Shortcuts.chords("prevTab").slice()

        // On X11/Wayland, Shift+Tab is delivered as Key_Backtab while Shift
        // remains in the modifiers. Add the equivalent Backtab spelling so
        // the shortcut still fires on those platforms.
        for (var i = 0; i < sequences.length; i++) {
            var sequence = sequences[i]
            if (sequence.indexOf("Backtab") !== -1)
                continue
            var backtab = sequence.replace("Tab", "Backtab")
            if (backtab !== sequence && sequences.indexOf(backtab) === -1)
                sequences.push(backtab)
        }
        return sequences
    }

    function nextTab() {
        if (tabData.length > 0)
            currentIndex = (currentIndex + 1) % tabData.length
    }

    function previousTab() {
        if (tabData.length > 0)
            currentIndex = (currentIndex - 1 + tabData.length) % tabData.length
    }

    Shortcut {
        sequences: root.nextSequences
        enabled: root.shortcutsActive
        onActivated: root.nextTab()
    }

    Shortcut {
        sequences: root.previousSequences
        enabled: root.shortcutsActive
        onActivated: root.previousTab()
    }

    readonly property real tabPadding: LayoutMetrics.spacing.sm
    readonly property real listMargin: LayoutMetrics.spacing.xs
    property var labelWidths: []

    function labelWidthAt(index) {
        return root.labelWidths[index] || 0
    }

    function tabWidthAt(index) {
        return root.labelWidthAt(index) + root.tabPadding * 2
    }

    function updateLabelWidth(index, width) {
        if (root.labelWidths[index] === width)
            return
        var widths = root.labelWidths.slice()
        widths[index] = width
        root.labelWidths = widths
    }

    readonly property real totalWidth: {
        var total = root.listMargin * 2
        for (var i = 0; i < root.tabData.length; i++)
            total += root.tabWidthAt(i)
        return total
    }

    width: totalWidth
    height: LayoutMetrics.size.controlHeightHuge
    implicitWidth: totalWidth
    implicitHeight: height

    onWidthChanged: {
        resizing = true
        resizeSettle.restart()
    }

    Timer {
        id: resizeSettle
        interval: 180
        onTriggered: root.resizing = false
    }

    function tabLabel(item) {
        return typeof item === "string" ? item : (item && item.name !== undefined ? item.name : "")
    }

    Row {
        id: measureRow
        visible: false
        spacing: 0

        Repeater {
            model: root.tabData

            Label {
                required property var modelData
                required property int index
                text: root.tabLabel(modelData)
                pixelSize: Typography.h6

                onImplicitWidthChanged: root.updateLabelWidth(index, implicitWidth)
                Component.onCompleted: root.updateLabelWidth(index, implicitWidth)
            }
        }
    }

    ListView {
        id: listView
        anchors.fill: parent
        anchors.margins: root.listMargin
        spacing: 0
        currentIndex: 0
        interactive: false
        orientation: Qt.Horizontal
        highlightFollowsCurrentItem: false
        clip: true
        model: root.tabData.length

        delegate: Item {
            id: listDelegate
            width: root.tabWidthAt(index)
            height: listView.height

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: LayoutMetrics.radius.m
                color: Theme.inputBackgroundColor
                opacity: mouseArea.containsMouse && listView.currentIndex !== index ? 1.0 : 0.0

                Behavior on opacity {
                    enabled: LayoutMetrics.animationsEnabled
                    NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
                }
            }

            Row {
                spacing: LayoutMetrics.spacing.sm
                anchors.centerIn: parent

                Label {
                    id: tabText
                    text: root.tabLabel(root.tabData[index])
                    textColor: listView.currentIndex === index ? Theme.hoverTextColor : Theme.textColor
                    pixelSize: Typography.h6

                    Behavior on color {
                        enabled: LayoutMetrics.animationsEnabled
                        ColorAnimation { duration: 150; easing.type: Easing.InOutQuad }
                    }
                }
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: listView.currentIndex = index
                cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            }
        }

        highlight: Item {
            width: listView.currentItem ? listView.currentItem.width : 0
            height: listView.currentItem ? listView.currentItem.height : 0
            x: listView.currentItem ? listView.currentItem.x : 0

            Behavior on x {
                enabled: !root.resizing && LayoutMetrics.animationsEnabled
                NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
            }

            Rectangle {
                anchors.fill: parent
                color: Theme.themeColor
                radius: LayoutMetrics.radius.m
            }
        }
    }
}
