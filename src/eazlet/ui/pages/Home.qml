import QtQuick
import QtQuick.Layouts
import components

Item {
    Layout.fillWidth: true
    Layout.fillHeight: true

    Surface {
        anchors.centerIn: parent
        width: parent.width * 0.8
        height: parent.height * 0.8

        Title {
            text: Lang.greeting
            anchors.centerIn: parent
        }
    }
}
