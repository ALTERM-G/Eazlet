import QtQuick
import QtQuick.Controls
import components as Components

ComboBox {
    id: control
    width: LayoutMetrics.size.comboBoxWidth
    height: LayoutMetrics.size.controlHeight * 2
    hoverEnabled: true
    focusPolicy: Qt.TabFocus
    property int optionHeight: LayoutMetrics.size.controlHeight
    property int popupPadding: 6

    contentItem: Text {
        text: control.displayText !== "" ? control.displayText : "Select"
        anchors.verticalCenter: parent.verticalCenter
        font.pixelSize: Typography.h4
        font.family: Typography.fontBold
        font.weight: Font.Bold
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: mouseArea.containsMouse
               ? Theme.hoverTextColor
               : Theme.textColor

        Behavior on color { enabled: LayoutMetrics.animationsEnabled; ColorAnimation { duration: 150 } }
    }

    indicator: Components.SVGObject {
        id: arrow
        path: SVGLibrary.dropDown
        color: contentItem.color
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        transformOrigin: Item.Center
        rotation: control.popup.opened ? 180 : 0

        Behavior on rotation {
            enabled: LayoutMetrics.animationsEnabled
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }
        }
    }


    background: Rectangle {
        anchors.fill: parent
        radius: LayoutMetrics.radius.m
        border.color: Theme.borderColor
        border.width: LayoutMetrics.border.l
        color: mouseArea.containsMouse
               ? Theme.hoverBackgroundColor
               : Theme.backgroundColor
        Behavior on color { enabled: LayoutMetrics.animationsEnabled; ColorAnimation { duration: 150 } }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (control.count <= 1) {
                    if (control.count === 1 && control.currentIndex < 0)
                        control.currentIndex = 0
                    return
                }
                if (control.popup.opened)
                    control.popup.close()
                else
                    control.open()
            }
        }
    }

    popup: Popup {
        id: dropdownPopup
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
        property int horizontalMargin: 0
        readonly property real delegateHeight: control.optionHeight * 1.8
        readonly property int visibleOptionCount: control.count
        property int highlightedIndex: -1

        function firstVisible() {
            return control.count > 0 ? 0 : -1
        }

        function lastVisible() {
            return control.count > 0 ? control.count - 1 : -1
        }

        function stepVisible(from, dir) {
            if (control.count <= 0)
                return -1
            var i = from < 0 ? (dir > 0 ? 0 : control.count - 1) : (from + dir + control.count) % control.count
            return i
        }

        function acceptHighlighted() {
            if (highlightedIndex >= 0)
                control.currentIndex = highlightedIndex
            dropdownPopup.close()
        }

        width: control.width
        implicitHeight: visibleOptionCount * delegateHeight + control.popupPadding * 2

        x: 0
        y: control.height + LayoutMetrics.spacing.xs
        clip: true

        onVisibleChanged: {
            if (visible) {
                highlightedIndex = control.currentIndex >= 0 ? control.currentIndex : firstVisible()
            }
        }

        enter: LayoutMetrics.animationsEnabled ? dropdownFadeEnter : dropdownInstantEnter
        exit: LayoutMetrics.animationsEnabled ? dropdownFadeExit : dropdownInstantExit

        Transition {
            id: dropdownInstantEnter
            ParallelAnimation {
                NumberAnimation { property: "height"; from: 0; to: dropdownPopup.implicitHeight; duration: 0 }
                NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 0 }
            }
        }

        Transition {
            id: dropdownInstantExit
            ParallelAnimation {
                NumberAnimation { property: "height"; from: dropdownPopup.implicitHeight; to: 0; duration: 0 }
                NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 0 }
            }
        }

        Transition {
            id: dropdownFadeEnter
            ParallelAnimation {
                NumberAnimation { property: "height"; from: 0; to: dropdownPopup.implicitHeight; duration: 150; easing.type: Easing.OutQuad }
                NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 150 }
            }
        }

        Transition {
            id: dropdownFadeExit
            ParallelAnimation {
                NumberAnimation { property: "height"; from: dropdownPopup.implicitHeight; to: 0; duration: 150; easing.type: Easing.InQuad }
                NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 150 }
            }
        }
        padding: 0
        topPadding: 0
        bottomPadding: 0
        leftPadding: 0
        rightPadding: 0

        background: Rectangle {
            anchors.fill: parent
            radius: LayoutMetrics.radius.m

            color: Theme.backgroundColor
            border.color: Theme.borderColor
            border.width: LayoutMetrics.border.l
        }

        contentItem: Item {
            id: dropdownContent
            focus: true

            Keys.onUpPressed: dropdownPopup.highlightedIndex = dropdownPopup.stepVisible(dropdownPopup.highlightedIndex, -1)
            Keys.onDownPressed: dropdownPopup.highlightedIndex = dropdownPopup.stepVisible(dropdownPopup.highlightedIndex, 1)
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Home) {
                    dropdownPopup.highlightedIndex = dropdownPopup.firstVisible()
                    event.accepted = true
                } else if (event.key === Qt.Key_End) {
                    dropdownPopup.highlightedIndex = dropdownPopup.lastVisible()
                    event.accepted = true
                }
            }
            Keys.onReturnPressed: dropdownPopup.acceptHighlighted()
            Keys.onEnterPressed: dropdownPopup.acceptHighlighted()
            Keys.onSpacePressed: dropdownPopup.acceptHighlighted()
            Keys.onShortcutOverride: (event) => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
                    event.accepted = true
            }

            Column {
                anchors.fill: parent
                anchors.margins: control.popupPadding
                spacing: 0

                Repeater {
                    model: control.model

                    delegate: Rectangle {
                        visible: true
                        width: parent.width
                        height: dropdownPopup.delegateHeight
                        radius: LayoutMetrics.radius.m
                        color: index === dropdownPopup.highlightedIndex
                               ? Theme.hoverBackgroundColor
                               : "transparent"

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: dropdownPopup.highlightedIndex = index
                            onClicked: {
                                control.currentIndex = index
                                dropdownPopup.close()
                            }
                        }

                        Text {
                            anchors.fill: parent
                            anchors.margins: 4
                            text: {
                                if (control.textRole) {
                                    if (model && model[control.textRole] !== undefined) return model[control.textRole]
                                    if (typeof modelData === 'object' && modelData[control.textRole] !== undefined) return modelData[control.textRole]
                                    return ""
                                }
                                return modelData !== undefined ? modelData : ""
                            }
                            font.pixelSize: Typography.h4
                            font.family: Typography.fontBold
                            font.weight: Font.Bold
                            color: index === dropdownPopup.highlightedIndex ? Theme.hoverTextColor : Theme.textColor
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }

    Keys.onPressed: (event) => {
        if (control.count <= 1
            && (event.key === Qt.Key_Down || event.key === Qt.Key_Up
                || event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                || event.key === Qt.Key_Space)) {
            if (control.count === 1 && control.currentIndex < 0)
                control.currentIndex = 0
            event.accepted = true
        }
    }

    Components.FocusRing {}
}
