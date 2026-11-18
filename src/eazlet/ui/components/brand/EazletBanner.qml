import QtQuick

Item {
    id: root

    property color fillColor: Theme.themeColor
    property string svgText: EazletBannerSvg || ""

    readonly property real sourceWidth: 399
    readonly property real sourceHeight: 96

    // The SVG uses a black style fill. Rewrite it to the current theme colour,
    // then let Qt's SVG image provider render the file normally. Shape/PathSvg
    // cannot reproduce this SVG's even-odd holes.
    readonly property string themedSvg:
        svgText.replace("fill:#000000", "fill:" + fillColor.toString())
    readonly property string sourceUri:
        "data:image/svg+xml;utf8," + encodeURIComponent(themedSvg)

    Image {
        anchors.fill: parent
        source: root.sourceUri
        fillMode: Image.PreserveAspectFit
        // Keep the SVG raster size fixed so resizing only scales the texture.
        // Re-rasterising on every size change makes the banner flicker.
        sourceSize: Qt.size(root.sourceWidth * 6, root.sourceHeight * 6)
        antialiasing: true
        mipmap: true
        cache: true
    }
}
