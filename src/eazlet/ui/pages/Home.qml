import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import components

Item {
    Layout.fillWidth: true
    Layout.fillHeight: true

    Surface {
        anchors.centerIn: parent
        width: parent.width * 0.9
        height: parent.height * 0.9

        Title {
            text: "Home"
            textColor: Theme.textColor
            pixelSize: Typography.h2
            anchors.centerIn: parent
        }
    }
}
