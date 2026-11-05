import QtQuick
import QtQuick.VectorImage
import QtQuick.Effects

Item {
    id: root
    property string path: ""
    property color color: "black"
    width: LayoutMetrics.size.iconL
    height: LayoutMetrics.size.iconL

    VectorImage {
        id: svg
        anchors.fill: parent
        source: root.path
        fillMode: VectorImage.PreserveAspectFit
        preferredRendererType: VectorImage.CurveRenderer
        antialiasing: true
        layer.enabled: true
        layer.smooth: true
        layer.textureSize: Qt.size(Math.max(1, Math.round(width * 2)),
                                   Math.max(1, Math.round(height * 2)))
        layer.effect: MultiEffect {
            brightness: 1.0
            colorization: 1.0
            colorizationColor: root.color
        }
    }
}
