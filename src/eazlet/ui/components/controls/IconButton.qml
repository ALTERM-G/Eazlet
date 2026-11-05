import QtQuick
import QtQuick.Controls
import components

Rectangle {
    id: iconButton
    property string iconPath: ""
    property real buttonWidth: LayoutMetrics.size.iconL
    property real buttonHeight: LayoutMetrics.size.iconL
    width: buttonWidth
    height: buttonHeight
    color: "transparent"
    property bool hovered: mouseArea.containsMouse
    signal pressed
    activeFocusOnTab: true
    Keys.onReturnPressed: doPress()
    Keys.onEnterPressed: doPress()
    function doPress() { pressed(); }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: iconButton.doPress()
    }

    SVGObject {
        id: iconSvg
        anchors.centerIn: parent
        path: iconPath
        width: buttonWidth
        height: buttonHeight
        color: mouseArea.containsMouse ? Theme.themeColor : Theme.textColor

        Behavior on color {
            enabled: LayoutMetrics.animationsEnabled
            ColorAnimation { duration: 150 }
        }
    }

    FocusRing {
        cornerRadius: LayoutMetrics.radius.s
    }
}
