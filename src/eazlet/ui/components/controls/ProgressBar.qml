import QtQuick
import QtQuick.Controls as QQC
import components

QQC.ProgressBar {
    id: control

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)

    padding: 0

    background: Rectangle {
        implicitWidth: 200
        implicitHeight: LayoutMetrics.unit * 1.6
        radius: Math.min(height / 2, LayoutMetrics.radius.m)
        color: Theme.inputBackgroundColor
        border.color: Theme.borderColor
        border.width: LayoutMetrics.border.m
        clip: true
    }

    contentItem: Item {
        implicitWidth: 200
        implicitHeight: LayoutMetrics.unit * 1.6

        Rectangle {
            width: control.visualPosition * parent.width
            height: parent.height
            radius: Math.min(height / 2, LayoutMetrics.radius.m)
            color: Theme.themeColor

            Behavior on width {
                enabled: LayoutMetrics.animationsEnabled && !control.indeterminate
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
