import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import components

Item {
    id: page

    Layout.fillWidth: true
    Layout.fillHeight: true

    function pickFromWheel(px, py) {
        var radius = Math.min(wheel.width, wheel.height) / 2 - 1
        if (radius <= 0)
            return

        var dx = px - wheel.width / 2
        var dy = py - wheel.height / 2
        var distance = Math.sqrt(dx * dx + dy * dy)

        if (distance > radius) {
            dx = dx / distance * radius
            dy = dy / distance * radius
            distance = radius
        }

        var hue = (Math.atan2(dy, dx) * 180 / Math.PI + 360) % 360
        var saturation = Math.min(1, distance / radius) * 100
        colorsVM.setHsv(hue, saturation, colorsVM.value)
    }

    Surface {
        anchors.centerIn: parent
        width: parent.width * 0.9
        height: parent.height * 0.9

        Flickable {
            id: flick
            ScrollBar.vertical: AppScrollBar {}
            interactive: false

            anchors.fill: parent
            anchors.margins: LayoutMetrics.spacing.lg
            contentHeight: colorsColumn.implicitHeight
            clip: true
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: function(wheelEvent) {
                    var delta = wheelEvent.pixelDelta.y !== 0
                        ? wheelEvent.pixelDelta.y * 2
                        : wheelEvent.angleDelta.y / 120 * LayoutMetrics.unit * 24
                    var maxY = Math.max(0, flick.contentHeight - flick.height)
                    flick.contentY = Math.max(0, Math.min(maxY, flick.contentY - delta))
                    wheelEvent.accepted = true
                }
            }

            Column {
                id: colorsColumn
                width: parent.width
                x: Math.max(0, (parent.width - width) / 2)
                spacing: LayoutMetrics.spacing.md

                Title {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Colors"
                    textColor: Theme.textColor
                    pixelSize: Typography.h2
                }

                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    bold: false
                    text: "Pick a color, convert it between formats, and explore harmonious palettes."
                    textColor: Theme.dividerColor
                    pixelSize: Typography.h6
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    width: parent.width
                    height: LayoutMetrics.spacing.xxs
                    color: Theme.dividerColor
                }

                RowLayout {
                    width: parent.width
                    spacing: LayoutMetrics.spacing.md

                    // Picker -------------------------------------------------
                    Rectangle {
                        Layout.preferredWidth: LayoutMetrics.unit * 33
                        Layout.alignment: Qt.AlignTop
                        implicitHeight: pickerColumn.implicitHeight + LayoutMetrics.spacing.lg * 2
                        radius: LayoutMetrics.radius.m
                        color: Theme.inputBackgroundColor
                        border.width: LayoutMetrics.border.l
                        border.color: Theme.borderColor

                        Column {
                            id: pickerColumn
                            width: Math.max(0, parent.width - LayoutMetrics.spacing.lg * 2)
                            x: LayoutMetrics.spacing.lg
                            y: LayoutMetrics.spacing.lg
                            spacing: LayoutMetrics.spacing.sm

                            // Current color preview
                            Rectangle {
                                width: parent.width
                                height: LayoutMetrics.unit * 7
                                radius: LayoutMetrics.radius.s
                                color: colorsVM.hex
                                border.width: LayoutMetrics.border.l
                                border.color: Theme.borderColor

                                Column {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.margins: LayoutMetrics.spacing.sm
                                    spacing: LayoutMetrics.spacing.xxs

                                    Label {
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                        text: colorsVM.colorName
                                        textColor: colorsVM.isLight ? "#1A1A1A" : "#FFFFFF"
                                        pixelSize: Typography.h3
                                    }

                                    Label {
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                        bold: false
                                        text: colorsVM.hex
                                        textColor: colorsVM.isLight ? "#1A1A1A" : "#FFFFFF"
                                        pixelSize: Typography.h6
                                    }
                                }
                            }

                            // Color wheel
                            Item {
                                id: wheelArea
                                width: Math.min(LayoutMetrics.unit * 30,
                                                pickerColumn.width)
                                height: width
                                anchors.horizontalCenter: parent.horizontalCenter

                                Canvas {
                                    id: wheel
                                    anchors.fill: parent
                                    property real brightness: colorsVM.value

                                    onBrightnessChanged: requestPaint()
                                    Component.onCompleted: requestPaint()

                                    onPaint: {
                                        var ctx = getContext("2d")
                                        var size = Math.floor(Math.min(width, height))
                                        if (size <= 0)
                                            return

                                        ctx.reset()
                                        ctx.clearRect(0, 0, width, height)

                                        var centerX = width / 2
                                        var centerY = height / 2
                                        var radius = size / 2 - 1
                                        var step = Math.PI / 180

                                        // Full-saturation hue ring. The white
                                        // radial wash below fades it towards the
                                        // center to create the saturation axis.
                                        for (var hue = 0; hue < 360; hue++) {
                                            ctx.beginPath()
                                            ctx.moveTo(centerX, centerY)
                                            ctx.arc(centerX, centerY, radius,
                                                    hue * step, (hue + 1) * step)
                                            ctx.closePath()
                                            ctx.fillStyle = Qt.hsla(hue / 360, 1, 0.5, 1)
                                            ctx.fill()
                                        }

                                        var wash = ctx.createRadialGradient(
                                            centerX, centerY, 0,
                                            centerX, centerY, radius)
                                        wash.addColorStop(0, "rgba(255, 255, 255, 1)")
                                        wash.addColorStop(1, "rgba(255, 255, 255, 0)")
                                        ctx.fillStyle = wash
                                        ctx.beginPath()
                                        ctx.arc(centerX, centerY, radius, 0, Math.PI * 2)
                                        ctx.fill()

                                        // Brightness is a black overlay, so the
                                        // wheel dims without losing hue/saturation.
                                        var darkness = 1 - Math.max(
                                            0, Math.min(1, brightness / 100))
                                        if (darkness > 0) {
                                            ctx.fillStyle = "rgba(0, 0, 0, " + darkness + ")"
                                            ctx.beginPath()
                                            ctx.arc(centerX, centerY, radius,
                                                    0, Math.PI * 2)
                                            ctx.fill()
                                        }

                                        ctx.beginPath()
                                        ctx.arc(centerX, centerY, radius, 0, Math.PI * 2)
                                        ctx.strokeStyle = Theme.borderColor
                                        ctx.lineWidth = Math.max(1, LayoutMetrics.border.l)
                                        ctx.stroke()
                                    }
                                }

                                // Marker kept outside the Canvas so choosing a
                                // color only moves it instead of repainting the
                                // whole wheel.
                                Item {
                                    id: wheelMarker
                                    readonly property real angle: colorsVM.hue * Math.PI / 180
                                    readonly property real markerSize: Math.max(
                                        LayoutMetrics.unit * 1.8, 10)

                                    readonly property real radius: colorsVM.saturation
                                                                  / 100
                                                                  * (wheelArea.width / 2
                                                                     - markerSize / 2 - 1)

                                    width: markerSize + 2
                                    height: width
                                    x: wheelArea.width / 2
                                       + Math.cos(angle) * radius - width / 2
                                    y: wheelArea.height / 2
                                       + Math.sin(angle) * radius - height / 2

                                    // Dark halo keeps the marker readable on
                                    // both bright and dark parts of the wheel.
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: width / 2
                                        color: "transparent"
                                        border.width: Math.max(1, LayoutMetrics.border.m)
                                        border.color: "#000000"
                                        opacity: 0.5
                                    }

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: wheelMarker.markerSize
                                        height: width
                                        radius: width / 2
                                        color: "transparent"
                                        border.width: Math.max(2, LayoutMetrics.border.m * 3)
                                        border.color: "#FFFFFF"
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.CrossCursor
                                    onPressed: function(mouse) {
                                        page.pickFromWheel(mouse.x, mouse.y)
                                    }
                                    onPositionChanged: function(mouse) {
                                        if (pressed)
                                            page.pickFromWheel(mouse.x, mouse.y)
                                    }
                                }
                            }

                            // Brightness
                            Column {
                                width: parent.width
                                spacing: LayoutMetrics.spacing.xxs

                                Label {
                                    bold: false
                                    text: "Brightness"
                                    textColor: Theme.textColor
                                    pixelSize: Typography.h6
                                }

                                Slider {
                                    id: brightnessSlider
                                    width: parent.width
                                    from: 0
                                    to: 100
                                    discrete: true
                                    step: 1
                                    value: colorsVM.value
                                    onMoved: colorsVM.value = value
                                }
                            }

                            Connections {
                                target: colorsVM
                                function onColorChanged() {
                                    if (!brightnessSlider.pressed)
                                        brightnessSlider.value = colorsVM.value
                                    hexInput.text = colorsVM.hex
                                }
                            }

                            // Hex input
                            Column {
                                width: parent.width
                                spacing: LayoutMetrics.spacing.xxs

                                Label {
                                    bold: false
                                    text: "Hex"
                                    textColor: Theme.textColor
                                    pixelSize: Typography.h6
                                }

                                Row {
                                    width: parent.width
                                    spacing: LayoutMetrics.spacing.sm

                                    LineEdit {
                                        id: hexInput
                                        width: Math.max(0, parent.width - randomButton.width
                                                        - parent.spacing)
                                        text: colorsVM.hex
                                        placeholderText: "#4A90E2"
                                        onEditingFinished: {
                                            if (colorsVM.setColor(text))
                                                text = colorsVM.hex
                                        }
                                        onAccepted: {
                                            if (colorsVM.setColor(text))
                                                text = colorsVM.hex
                                        }
                                    }

                                    Button {
                                        id: randomButton
                                        buttonText: "Random"
                                        isometric: true
                                        onPressed: colorsVM.randomColor()
                                    }
                                }

                                Label {
                                    visible: colorsVM.inputError !== ""
                                    width: parent.width
                                    bold: false
                                    text: colorsVM.inputError
                                    textColor: "red"
                                    pixelSize: Typography.h6
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }

                    // Conversions --------------------------------------------
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.alignment: Qt.AlignTop
                        spacing: LayoutMetrics.spacing.sm

                        Label {
                            Layout.fillWidth: true
                            bold: false
                            text: "Conversions"
                            textColor: Theme.textColor
                            pixelSize: Typography.h6
                        }

                        Repeater {
                            model: colorsVM.conversions

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                implicitHeight: conversionRow.implicitHeight
                                                + LayoutMetrics.spacing.sm * 2
                                radius: LayoutMetrics.radius.s
                                color: Theme.inputBackgroundColor
                                border.width: LayoutMetrics.border.l
                                border.color: Theme.borderColor

                                RowLayout {
                                    id: conversionRow
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: LayoutMetrics.spacing.md
                                    anchors.rightMargin: LayoutMetrics.spacing.sm
                                    spacing: LayoutMetrics.spacing.sm

                                    Label {
                                        Layout.preferredWidth: LayoutMetrics.unit * 9
                                        text: modelData.label
                                        textColor: Theme.dividerColor
                                        pixelSize: Typography.h6
                                    }

                                    Label {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        bold: false
                                        text: modelData.value
                                        textColor: Theme.textColor
                                        pixelSize: Typography.h6
                                        elide: Text.ElideRight
                                    }

                                    IconButton {
                                        Layout.preferredWidth: LayoutMetrics.size.iconS
                                        Layout.preferredHeight: LayoutMetrics.size.iconS
                                        iconPath: SVGLibrary.copy
                                        buttonWidth: LayoutMetrics.size.iconS
                                        buttonHeight: LayoutMetrics.size.iconS
                                        onPressed: colorsVM.copyText(modelData.value)
                                    }
                                }
                            }
                        }
                    }
                }

                // Harmony ---------------------------------------------------
                Rectangle {
                    width: parent.width
                    implicitHeight: harmonyColumn.implicitHeight
                                    + LayoutMetrics.spacing.lg * 2
                    radius: LayoutMetrics.radius.m
                    color: Theme.inputBackgroundColor
                    border.width: LayoutMetrics.border.l
                    border.color: Theme.borderColor

                    Column {
                        id: harmonyColumn
                        width: Math.max(0, parent.width - LayoutMetrics.spacing.lg * 2)
                        x: LayoutMetrics.spacing.lg
                        y: LayoutMetrics.spacing.lg
                        spacing: LayoutMetrics.spacing.md

                        Row {
                            spacing: LayoutMetrics.spacing.md

                            Column {
                                spacing: LayoutMetrics.spacing.xxs

                                Label {
                                    bold: false
                                    text: "Harmony"
                                    textColor: Theme.textColor
                                    pixelSize: Typography.h6
                                }

                                ComboBox {
                                    width: LayoutMetrics.size.comboBoxWidth
                                    model: colorsVM.harmonyTypes
                                    currentIndex: {
                                        var index = colorsVM.harmonyTypes.indexOf(colorsVM.harmonyType)
                                        return index >= 0 ? index : 0
                                    }
                                    onCurrentIndexChanged: {
                                        if (currentIndex >= 0
                                                && currentIndex < colorsVM.harmonyTypes.length) {
                                            var type = colorsVM.harmonyTypes[currentIndex]
                                            if (type && type !== colorsVM.harmonyType)
                                                colorsVM.harmonyType = type
                                        }
                                    }
                                }
                            }

                            Column {
                                spacing: LayoutMetrics.spacing.xxs

                                Label {
                                    bold: false
                                    text: "Colors"
                                    textColor: Theme.textColor
                                    pixelSize: Typography.h6
                                }

                                SpinBox {
                                    from: 2
                                    to: colorsVM.maxHarmonyCount
                                    stepSize: 1
                                    value: colorsVM.harmonyCount
                                    onValueChanged: colorsVM.harmonyCount = value
                                }
                            }
                        }

                        Flow {
                            id: harmonyFlow
                            readonly property int itemCount: colorsVM.harmony.length
                            readonly property real availableWidth: parent ? parent.width : 0
                            readonly property real swatchWidth: Math.max(
                                LayoutMetrics.unit * 12,
                                Math.min(LayoutMetrics.unit * 20,
                                         (availableWidth
                                          - spacing * (itemCount - 1))
                                         / Math.max(1, itemCount)))

                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.min(availableWidth,
                                            itemCount * swatchWidth
                                            + spacing * Math.max(0, itemCount - 1))
                            spacing: LayoutMetrics.spacing.md

                            Repeater {
                                model: colorsVM.harmony

                                Item {
                                    width: harmonyFlow.swatchWidth
                                    height: swatchColumn.implicitHeight

                                    Column {
                                        id: swatchColumn
                                        width: parent.width
                                        spacing: LayoutMetrics.spacing.xxs

                                        Rectangle {
                                            width: parent.width
                                            height: LayoutMetrics.unit * 9
                                            radius: LayoutMetrics.radius.s
                                            color: modelData.hex
                                            border.width: LayoutMetrics.border.l
                                            border.color: Theme.borderColor

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: colorsVM.copyText(modelData.hex)
                                            }
                                        }

                                        Label {
                                            width: parent.width
                                            horizontalAlignment: Text.AlignHCenter
                                            bold: false
                                            text: modelData.label
                                            textColor: Theme.dividerColor
                                            pixelSize: Typography.caption
                                        }

                                        Label {
                                            width: parent.width
                                            horizontalAlignment: Text.AlignHCenter
                                            text: modelData.hex
                                            textColor: Theme.textColor
                                            pixelSize: Typography.h6
                                        }
                                    }
                                }
                            }
                        }

                        Label {
                            width: parent.width
                            bold: false
                            text: "Click a swatch to copy its hex value."
                            textColor: Theme.dividerColor
                            pixelSize: Typography.caption
                        }
                    }
                }
            }
        }
    }
}
