import QtQuick
import QtQuick.Controls
import components

SpinBox {
    id: spinBox
    width: LayoutMetrics.size.spinBoxWidth
    height: LayoutMetrics.size.controlHeightHuge
    stepSize: 10
    wheelEnabled: false
    focusPolicy: Qt.TabFocus
    leftPadding: LayoutMetrics.spacing.sm
    rightPadding: LayoutMetrics.size.iconS + LayoutMetrics.spacing.sm

    Component.onCompleted: contentItem.activeFocusOnTab = false

    onActiveFocusChanged: {
        if (activeFocus && !contentItem.activeFocus)
            contentItem.forceActiveFocus()
    }

    function setFrom(newFrom) { spinBox.from = newFrom }
    function setTo(newTo) { spinBox.to = newTo }
    function setValue(newValue) { spinBox.value = newValue }

    contentItem: TextInput {
        id: spinInput
        text: spinBox.value.toString()
        activeFocusOnPress: true
        activeFocusOnTab: false
        font.pixelSize: Typography.h4
        font.family: Typography.fontBold
        font.weight: Font.Bold
        color: spinInput.activeFocus ? Theme.textColor : "transparent"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        selectionColor: Theme.themeColor
        selectByMouse: true
        selectedTextColor: Theme.hoverTextColor
        clip: true
        validator: IntValidator {
            bottom: spinBox.from
            top: spinBox.to
        }

        // TextInput cannot elide, so show a read-only elided copy while the
        // field is not being edited and hide the underlying input text.
        Text {
            anchors.fill: parent
            visible: !spinInput.activeFocus
            text: spinInput.text
            font: spinInput.font
            color: Theme.textColor
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            enabled: false
        }

        onActiveFocusChanged: {
            if (activeFocus)
                selectAll()
        }

        onEditingFinished: {
            var v = parseInt(text, 10)
            if (isNaN(v))
                v = spinBox.value
            spinBox.value = Math.min(Math.max(v, spinBox.from), spinBox.to)
            text = Qt.binding(function() { return spinBox.value.toString() })
        }

        onTextChanged: {
            if (text !== "" && !isNaN(parseInt(text, 10))) {
                var newValue = Math.min(Math.max(parseInt(text, 10), spinBox.from), spinBox.to)
                spinBox.value = newValue
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: spinBox.enabled ? Qt.IBeamCursor : Qt.ArrowCursor
            acceptedButtons: Qt.NoButton
            enabled: true
        }
    }

    background: Rectangle {
        anchors.fill: parent
        radius: LayoutMetrics.radius.m
        color: Theme.backgroundColor
        border.color: Theme.borderColor
        border.width: LayoutMetrics.border.l
    }

    up.indicator: Rectangle {
        x: spinBox.width - width
        height: spinBox.height / 4
        width: LayoutMetrics.size.iconS
        color: Theme.backgroundColor
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: LayoutMetrics.spacing.sm
        anchors.rightMargin: LayoutMetrics.spacing.sm

        SVGObject {
            path: SVGLibrary.chevronUp
            anchors.centerIn: parent
            color: upMouseArea.containsMouse ? Theme.themeColor : Theme.textColor
            width: LayoutMetrics.size.iconS
            height: LayoutMetrics.size.iconS
        }

        MouseArea {
            id: upMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: spinBox.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: spinBox.value = Math.min(spinBox.to, spinBox.value + spinBox.stepSize)
        }
    }

    down.indicator: Rectangle {
        width: LayoutMetrics.size.iconS
        height: spinBox.height / 4
        color: Theme.backgroundColor
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.bottomMargin: LayoutMetrics.spacing.sm
        anchors.rightMargin: LayoutMetrics.spacing.sm

        SVGObject {
            path: SVGLibrary.chevronDown
            anchors.centerIn: parent
            color: downMouseArea.containsMouse ? Theme.themeColor : Theme.textColor
            width: LayoutMetrics.size.iconS
            height: LayoutMetrics.size.iconS
        }

        MouseArea {
            id: downMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: spinBox.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: spinBox.value = Math.max(spinBox.from, spinBox.value - spinBox.stepSize)
        }
    }

    FocusRing {}
}
