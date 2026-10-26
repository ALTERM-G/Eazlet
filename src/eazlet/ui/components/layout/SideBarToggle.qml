import QtQuick
import components

Rectangle {
    id: root
    property bool collapsed: false
    signal toggled()

    width: LayoutMetrics.size.iconButton
    height: LayoutMetrics.size.iconButton
    radius: LayoutMetrics.radius.m
    color: mouseArea.containsMouse ? Theme.hoverBackgroundColor : "transparent"

    Behavior on color {
        enabled: LayoutMetrics.animationsEnabled
        ColorAnimation {
            duration: 150
        }
    }

    SVGObject {
        anchors.centerIn: parent
        width: LayoutMetrics.size.iconS
        height: LayoutMetrics.size.iconS
        path: root.collapsed ? SVGLibrary.chevronRight : SVGLibrary.chevronLeft
        color: mouseArea.containsMouse ? Theme.hoverTextColor : Theme.textColor

        Behavior on color {
            enabled: LayoutMetrics.animationsEnabled
            ColorAnimation {
                duration: 150
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
