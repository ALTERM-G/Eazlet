import QtQuick
import QtQuick.Controls

Text {
    id: text
    property bool style_2: false
    property bool bold: true
    property int pixelSize: style_2 ? Typography.caption : Typography.h6
    property color textColor: style_2 ? Theme.borderColor : Theme.textColor
    font.pixelSize: pixelSize
    font.family: bold ? Typography.fontBold : Typography.fontRegular
    font.weight: bold ? Font.Bold : Font.Normal
    color: textColor
}
