import QtQuick

QtObject {
    id: typography

    property var _fontMetrics: Qt.createQmlObject(
        "import QtQuick; FontMetrics {}", typography
    )

    // Fonts
    property string fontFamily: FontFamily || "sans-serif"
    readonly property string fontRegular: fontFamily
    readonly property string fontBold: fontFamily

    // The REPL has to stay monospaced, but the chosen UI font may not be.
    // This is updated imperatively because measuring a font mutates FontMetrics;
    // doing that inside a binding makes Qt detect a binding loop.
    property bool fontIsMonospaced: false
    readonly property string terminalFontFamily: fontIsMonospaced
                                                 ? fontFamily : "JetBrains Mono"

    // Font sizes
    readonly property int iconFontSize: 24
    readonly property int titleFontSize: 24
    readonly property int hugeFontSize: 18
    readonly property int bigFontSize: 16
    readonly property int normalFontSize: 14
    readonly property int smallFontSize: 11

    property var windowRef
    property real scaleFactor: 1.0
    property bool isContinuous: true
    property real unit: (windowRef ? (isContinuous ? Math.min(windowRef.width, windowRef.height) / 100 : 7.2) : 7.2) * scaleFactor

    function updateMonospaced() {
        if (!fontFamily) {
            fontIsMonospaced = false
            return
        }
        _fontMetrics.font.family = fontFamily
        var wide = _fontMetrics.advanceWidth("W")
        var narrow = _fontMetrics.advanceWidth("i")
        var space = _fontMetrics.advanceWidth(" ")
        fontIsMonospaced = wide > 0
                           && Math.abs(wide - narrow) < 0.5
                           && Math.abs(wide - space) < 0.5
    }

    onFontFamilyChanged: updateMonospaced()
    Component.onCompleted: updateMonospaced()

    function round(value) {
        return Math.round(value * baseSize)
    }

    // Modular font sizes
    property real baseSize: unit * 1.9
    property int h1: round(1.7)
    property int h2: round(1.5)
    property int h3: round(1.35)
    property int h4: round(1.2)
    property int h5: round(1.1)
    property int h6: round(1.0)
    property int body: round(0.9)
    property int caption: round(0.7)

    function setWindow(win) {
        windowRef = win
    }

    function setScaleFactor(factor) {
        scaleFactor = factor
    }

    function setIsContinuous(value) {
        isContinuous = value
    }

    function initialize(factor) {
        scaleFactor = factor
    }
}