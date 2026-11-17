import QtQuick

Rectangle {
    id: root
    objectName: "workplaceSurface"
    radius: LayoutMetrics.radius.m
    color: Theme.backgroundColor
    border.color: Theme.dividerColor
    border.width: LayoutMetrics.border.m
    clip: true
}
