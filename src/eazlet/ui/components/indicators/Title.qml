import QtQuick
import QtQuick.Controls

Text {
    id: text
    property int pixelSize: Typography.h1
    property color textColor: Theme.themeColor
    font.pixelSize: pixelSize
    font.family: Typography.fontBold
    font.weight: Font.Bold
    color: textColor
}
