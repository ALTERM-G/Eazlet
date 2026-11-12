import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import components

Item {
    id: page

    function processAction() {
        mathVM.process()
    }

    readonly property bool latexMode: mathVM.mode === "LaTeX → PNG"

    function isTransparent(value) {
        return String(value || "").trim().toLowerCase() === "transparent"
    }

    function isSuccessStatus(value) {
        return ["Simplified", "Expanded", "Factored", "Solved", "Differentiated",
                "Integrated", "Evaluated"].indexOf(value) >= 0
    }

    function previewColor(value) {
        var text = String(value || "").trim()
        if (text.toLowerCase() === "transparent")
            return Theme.inputBackgroundColor
        if (/^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(text))
            return text
        return Theme.inputBackgroundColor
    }

    function colorString(value) {
        function hex(component) {
            var text = Math.round(component * 255).toString(16)
            return text.length < 2 ? "0" + text : text
        }
        return "#" + hex(value.r) + hex(value.g) + hex(value.b)
    }

    function algebraHint() {
        switch (mathVM.mode) {
        case "Solve":
            return "Use a single '=' and choose the variable to solve for."
        case "Derivative":
            return "Differentiates with respect to the chosen variable."
        case "Integral":
            return "Finds an antiderivative with respect to the chosen variable; results include + C."
        case "Limit":
            return "Evaluates the limit as the variable approaches the point. Try oo, -oo, or pi/2."
        case "Factor":
            return "Factors polynomials and integer expressions."
        case "Expand":
            return "Expands products and powers."
        default:
            return "Supported: + - * / ^, implicit multiplication (2x), fractions, sqrt, sin, "
                    + "cos, tan, log, exp, abs, pi, E, and I."
        }
    }

    Surface {
        anchors.centerIn: parent
        width: parent.width * 0.9
        height: parent.height * 0.9

        Column {
            id: pageColumn
            width: Math.max(0, parent.width - LayoutMetrics.spacing.lg * 2)
            height: parent.height - LayoutMetrics.spacing.lg * 2
            x: (parent.width - width) / 2
            y: LayoutMetrics.spacing.lg
            spacing: LayoutMetrics.spacing.md

            Title {
                id: pageTitle
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Math"
                textColor: Theme.textColor
                pixelSize: Typography.h2
            }

            Label {
                id: pageSubtitle
                bold: false
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "A local math workbench: simplify, expand, factor, solve, differentiate, "
                      + "integrate, evaluate limits, and render LaTeX to PNG."
                textColor: Theme.dividerColor
                pixelSize: Typography.h6
                wrapMode: Text.WordWrap
            }

            TabBar {
                id: modeTabs
                anchors.horizontalCenter: parent.horizontalCenter
                tabData: mathVM.modes
                active: page.visible
                currentIndex: 0
                enabled: !mathVM.computing && !mathVM.latexRendering
                Component.onCompleted: {
                    var idx = mathVM.modes.indexOf(mathVM.mode)
                    if (idx >= 0)
                        modeTabs.currentIndex = idx
                }
                onCurrentIndexChanged: {
                    if (currentIndex >= 0 && currentIndex < mathVM.modes.length) {
                        var m = mathVM.modes[currentIndex]
                        if (m && m !== mathVM.mode)
                            mathVM.setMode(m)
                    }
                }
            }

            Connections {
                target: mathVM
                function onModeChanged() {
                    var idx = mathVM.modes.indexOf(mathVM.mode)
                    if (idx >= 0 && idx !== modeTabs.currentIndex)
                        modeTabs.currentIndex = idx
                }
            }

            Rectangle {
                id: divider
                width: parent.width
                height: LayoutMetrics.spacing.xxs
                color: Theme.dividerColor
            }

            Flickable {
                id: pageFlickable
                width: parent.width
                height: Math.max(0, parent.height - pageTitle.height - pageSubtitle.height
                                 - modeTabs.height - divider.height
                                 - pageColumn.spacing * 4)
                contentWidth: width
                contentHeight: contentColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: false

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: function(wheel) {
                        var step = wheel.pixelDelta.y !== 0
                                   ? wheel.pixelDelta.y * 2
                                   : wheel.angleDelta.y / 120 * LayoutMetrics.unit * 24
                        var maxY = Math.max(0, pageFlickable.contentHeight - pageFlickable.height)
                        pageFlickable.contentY = Math.max(0, Math.min(maxY,
                                                                    pageFlickable.contentY - step))
                        wheel.accepted = true
                    }
                }

                ScrollBar.vertical: AppScrollBar {}

                TabSlide {
                    id: tabSlide
                    tabBar: modeTabs
                    target: contentColumn
                }

                Column {
                    id: contentColumn
                    width: Math.max(0, parent.width - LayoutMetrics.unit * 1.6)
                    spacing: LayoutMetrics.spacing.md

                    // Algebra tools ------------------------------------------------
                    Column {
                        id: algebraPanel
                        width: parent.width
                        spacing: LayoutMetrics.spacing.md
                        visible: !page.latexMode

                        Label {
                            bold: false
                            text: mathVM.inputLabel
                            textColor: Theme.textColor
                            pixelSize: Typography.h4
                        }

                        TextEdit {
                            id: expressionInput
                            width: parent.width
                            height: LayoutMetrics.unit * 12
                            text: mathVM.expression
                            placeholderText: mathVM.mode === "Solve"
                                             ? "e.g. x^2 - 4 = 0"
                                             : "e.g. (x^2 - 1)/(x - 1) or sin(x)^2 + cos(x)^2"
                            fontFamily: "JetBrains Mono"
                            fontPixelSize: Typography.body
                            wrapMode: Text.Wrap
                            onTextChanged: mathVM.setExpression(text)
                        }

                        Connections {
                            target: mathVM
                            function onExpressionChanged() {
                                if (expressionInput.text !== mathVM.expression)
                                    expressionInput.text = mathVM.expression
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: LayoutMetrics.spacing.md
                            visible: mathVM.requiresVariable

                            Label {
                                bold: false
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Variable"
                                textColor: Theme.textColor
                                pixelSize: Typography.h6
                            }

                            LineEdit {
                                width: Math.min(LayoutMetrics.unit * 14, parent.width * 0.2)
                                text: mathVM.variable
                                placeholderText: "x"
                                onTextEdited: mathVM.setVariable(text)
                            }

                            Label {
                                bold: false
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Point"
                                textColor: Theme.textColor
                                pixelSize: Typography.h6
                                visible: mathVM.requiresPoint
                            }

                            LineEdit {
                                width: Math.min(LayoutMetrics.unit * 14, parent.width * 0.2)
                                text: mathVM.point
                                placeholderText: "0"
                                visible: mathVM.requiresPoint
                                onTextEdited: mathVM.setPoint(text)
                            }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: LayoutMetrics.spacing.sm

                            Button {
                                buttonText: mathVM.actionLabel
                                primary: true
                                isometric: true
                                heightMultiplier: 1.3
                                enabled: !mathVM.computing
                                onPressed: mathVM.process()
                            }
                            Button {
                                buttonText: "Example"
                                enabled: !mathVM.computing
                                onPressed: mathVM.loadExample()
                            }
                            Button {
                                buttonText: "Clear"
                                iconPath: SVGLibrary.eraser
                                enabled: !mathVM.computing
                                onPressed: mathVM.clear()
                            }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: LayoutMetrics.spacing.sm
                            visible: mathVM.status !== ""

                            SVGObject {
                                anchors.verticalCenter: parent.verticalCenter
                                width: LayoutMetrics.size.iconS
                                height: LayoutMetrics.size.iconS
                                path: SVGLibrary.checkMark
                                color: Theme.textColor
                                visible: page.isSuccessStatus(mathVM.status)
                            }
                            Label {
                                bold: false
                                anchors.verticalCenter: parent.verticalCenter
                                text: mathVM.status
                                textColor: Theme.textColor
                                pixelSize: Typography.h6
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: LayoutMetrics.spacing.sm
                            visible: mathVM.error !== ""

                            SVGObject {
                                anchors.verticalCenter: parent.verticalCenter
                                width: LayoutMetrics.size.iconS
                                height: LayoutMetrics.size.iconS
                                path: SVGLibrary.cross
                                color: "red"
                            }
                            Label {
                                bold: false
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.max(0, parent.width - LayoutMetrics.size.iconS
                                                - parent.spacing)
                                text: mathVM.error
                                textColor: "red"
                                pixelSize: Typography.h6
                                wrapMode: Text.WordWrap
                            }
                        }

                        Label {
                            bold: false
                            text: "Result"
                            textColor: Theme.textColor
                            pixelSize: Typography.h4
                        }

                        TextEdit {
                            width: parent.width
                            height: LayoutMetrics.unit * 16
                            readOnly: true
                            wrapMode: Text.Wrap
                            fontFamily: "JetBrains Mono"
                            fontPixelSize: Typography.body
                            text: mathVM.result
                            placeholderText: "The result will appear here"
                            showCopyButton: true
                        }

                        Label {
                            bold: false
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: page.algebraHint()
                            textColor: Theme.dividerColor
                            pixelSize: Typography.caption
                            wrapMode: Text.WordWrap
                        }
                    }

                    // LaTeX to PNG -------------------------------------------------
                    Column {
                        id: latexPanel
                        width: parent.width
                        spacing: LayoutMetrics.spacing.md
                        visible: page.latexMode

                        Label {
                            bold: false
                            text: "LaTeX code"
                            textColor: Theme.textColor
                            pixelSize: Typography.h4
                        }

                        TextEdit {
                            id: latexInput
                            width: parent.width
                            height: LayoutMetrics.unit * 16
                            text: mathVM.latexSource
                            placeholderText: "e.g. \\frac{x^2 - 1}{x - 1} = x + 1"
                            fontFamily: "JetBrains Mono"
                            fontPixelSize: Typography.body
                            wrapMode: Text.Wrap
                            onTextChanged: mathVM.setLatexSource(text)
                        }

                        Connections {
                            target: mathVM
                            function onLatexSourceChanged() {
                                if (latexInput.text !== mathVM.latexSource)
                                    latexInput.text = mathVM.latexSource
                            }
                            function onLatexBackgroundChanged() {
                                if (backgroundField.text !== mathVM.latexBackground)
                                    backgroundField.text = mathVM.latexBackground
                            }
                            function onLatexForegroundChanged() {
                                if (foregroundField.text !== mathVM.latexForeground)
                                    foregroundField.text = mathVM.latexForeground
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: LayoutMetrics.spacing.md

                            Label {
                                bold: false
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Resolution"
                                textColor: Theme.textColor
                                pixelSize: Typography.h6
                            }

                            ComboBox {
                                width: Math.min(LayoutMetrics.unit * 16, parent.width * 0.25)
                                model: mathVM.latexResolutions
                                scrollablePopup: true
                                maxVisibleItems: 8
                                currentIndex: {
                                    var idx = mathVM.latexResolutions.indexOf(mathVM.latexResolution)
                                    return idx >= 0 ? idx : 0
                                }
                                onActivated: function(index) {
                                    if (index >= 0 && index < mathVM.latexResolutions.length)
                                        mathVM.setLatexResolution(
                                            mathVM.latexResolutions[index])
                                }
                                onCurrentIndexChanged: {
                                    if (currentIndex >= 0
                                            && currentIndex < mathVM.latexResolutions.length) {
                                        var value = mathVM.latexResolutions[currentIndex]
                                        if (value && value !== mathVM.latexResolution)
                                            mathVM.setLatexResolution(value)
                                    }
                                }
                            }

                            Label {
                                bold: false
                                anchors.verticalCenter: parent.verticalCenter
                                text: "DPI"
                                textColor: Theme.dividerColor
                                pixelSize: Typography.h6
                            }
                        }

                        Flow {
                            width: parent.width
                            spacing: LayoutMetrics.spacing.md

                            Row {
                                spacing: LayoutMetrics.spacing.sm

                                Label {
                                    bold: false
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Background"
                                    textColor: Theme.textColor
                                    pixelSize: Typography.h6
                                }

                                Rectangle {
                                    width: LayoutMetrics.size.controlHeight
                                    height: width
                                    radius: LayoutMetrics.radius.m
                                    color: page.previewColor(mathVM.latexBackground)
                                    border.color: Theme.borderColor
                                    border.width: LayoutMetrics.border.m

                                    Label {
                                        anchors.centerIn: parent
                                        visible: page.isTransparent(mathVM.latexBackground)
                                        text: "T"
                                        textColor: Theme.textColor
                                        pixelSize: Typography.caption
                                    }
                                }

                                LineEdit {
                                    id: backgroundField
                                    width: LayoutMetrics.unit * 18
                                    text: mathVM.latexBackground
                                    placeholderText: "#FFFFFF"
                                    onTextEdited: mathVM.setLatexBackground(text)
                                }

                                Button {
                                    buttonText: "Pick"
                                    onPressed: {
                                        backgroundDialog.selectedColor =
                                            page.previewColor(mathVM.latexBackground)
                                        backgroundDialog.open()
                                    }
                                }
                            }

                            Button {
                                buttonText: page.isTransparent(mathVM.latexBackground)
                                            ? "Transparent: On" : "Transparent: Off"
                                onPressed: mathVM.setLatexBackground(
                                    page.isTransparent(mathVM.latexBackground)
                                    ? "#FFFFFF" : "Transparent")
                            }
                        }

                        Flow {
                            width: parent.width
                            spacing: LayoutMetrics.spacing.md

                            Row {
                                spacing: LayoutMetrics.spacing.sm

                                Label {
                                    bold: false
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Text colour"
                                    textColor: Theme.textColor
                                    pixelSize: Typography.h6
                                }

                                Rectangle {
                                    width: LayoutMetrics.size.controlHeight
                                    height: width
                                    radius: LayoutMetrics.radius.m
                                    color: page.previewColor(mathVM.latexForeground)
                                    border.color: Theme.borderColor
                                    border.width: LayoutMetrics.border.m
                                }

                                LineEdit {
                                    id: foregroundField
                                    width: LayoutMetrics.unit * 18
                                    text: mathVM.latexForeground
                                    placeholderText: "#000000"
                                    onTextEdited: mathVM.setLatexForeground(text)
                                }

                                Button {
                                    buttonText: "Pick"
                                    onPressed: {
                                        foregroundDialog.selectedColor =
                                            page.previewColor(mathVM.latexForeground)
                                        foregroundDialog.open()
                                    }
                                }
                            }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: LayoutMetrics.spacing.sm

                            Button {
                                buttonText: "Render PNG"
                                primary: true
                                isometric: true
                                heightMultiplier: 1.3
                                enabled: mathVM.latexAvailable && !mathVM.latexRendering
                                onPressed: mathVM.renderLatex()
                            }
                            Button {
                                buttonText: "Example"
                                enabled: !mathVM.latexRendering
                                onPressed: mathVM.loadExample()
                            }
                            Button {
                                buttonText: "Clear"
                                iconPath: SVGLibrary.eraser
                                enabled: !mathVM.latexRendering
                                onPressed: mathVM.clear()
                            }
                            Button {
                                buttonText: "Download"
                                iconPath: SVGLibrary.downloader
                                enabled: mathVM.latexImageSource !== ""
                                onPressed: latexFileDialog.open()
                            }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: LayoutMetrics.spacing.sm
                            visible: mathVM.latexStatus !== ""

                            SVGObject {
                                anchors.verticalCenter: parent.verticalCenter
                                width: LayoutMetrics.size.iconS
                                height: LayoutMetrics.size.iconS
                                path: SVGLibrary.checkMark
                                color: Theme.textColor
                                visible: mathVM.latexStatus === "Rendered"
                            }
                            Label {
                                bold: false
                                anchors.verticalCenter: parent.verticalCenter
                                text: mathVM.latexStatus
                                textColor: Theme.textColor
                                pixelSize: Typography.h6
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: LayoutMetrics.spacing.sm
                            visible: mathVM.latexError !== ""

                            SVGObject {
                                anchors.verticalCenter: parent.verticalCenter
                                width: LayoutMetrics.size.iconS
                                height: LayoutMetrics.size.iconS
                                path: SVGLibrary.cross
                                color: "red"
                            }
                            Label {
                                bold: false
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.max(0, parent.width - LayoutMetrics.size.iconS
                                                - parent.spacing)
                                text: mathVM.latexError
                                textColor: "red"
                                pixelSize: Typography.h6
                                wrapMode: Text.WordWrap
                            }
                        }

                        Label {
                            bold: false
                            width: parent.width
                            text: mathVM.latexSavedMessage
                            textColor: Theme.themeColor
                            pixelSize: Typography.h6
                            wrapMode: Text.WordWrap
                            visible: mathVM.latexSavedMessage !== ""
                        }

                        Row {
                            width: parent.width
                            spacing: LayoutMetrics.spacing.md

                            Label {
                                bold: false
                                text: "Preview"
                                textColor: Theme.textColor
                                pixelSize: Typography.h4
                            }

                            Label {
                                bold: false
                                anchors.verticalCenter: parent.verticalCenter
                                text: mathVM.latexDimensions
                                textColor: Theme.dividerColor
                                pixelSize: Typography.caption
                            }
                        }

                        Rectangle {
                            id: latexPreview
                            width: parent.width
                            height: Math.min(LayoutMetrics.unit * 44,
                                             Math.max(LayoutMetrics.unit * 20, width * 0.42))
                            radius: LayoutMetrics.radius.m
                            color: Theme.inputBackgroundColor
                            border.color: Theme.borderColor
                            border.width: LayoutMetrics.border.m
                            clip: true

                            Canvas {
                                anchors.fill: parent
                                visible: page.isTransparent(mathVM.latexBackground)
                                onVisibleChanged: if (visible) requestPaint()
                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()
                                Component.onCompleted: requestPaint()

                                onPaint: {
                                    var ctx = getContext("2d")
                                    var square = LayoutMetrics.unit * 2
                                    var columns = Math.ceil(width / square)
                                    var rows = Math.ceil(height / square)
                                    ctx.fillStyle = page.colorString(Theme.backgroundColor)
                                    ctx.fillRect(0, 0, width, height)
                                    ctx.fillStyle = page.colorString(Theme.inputBackgroundColor)
                                    for (var row = 0; row < rows; row++) {
                                        for (var column = 0; column < columns; column++) {
                                            if ((row + column) % 2 === 0)
                                                ctx.fillRect(column * square, row * square,
                                                             square, square)
                                        }
                                    }
                                }
                            }

                            Image {
                                anchors.fill: parent
                                anchors.margins: latexPreview.border.width
                                source: mathVM.latexImageSource
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                asynchronous: true
                                visible: source !== ""
                            }

                            Label {
                                anchors.centerIn: parent
                                width: parent.width * 0.8
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                bold: false
                                visible: mathVM.latexImageSource === ""
                                text: mathVM.latexAvailable
                                      ? "Render LaTeX to preview the PNG"
                                      : mathVM.latexToolchainError
                                textColor: Theme.dividerColor
                                pixelSize: Typography.h6
                            }
                        }

                        Label {
                            bold: false
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: "Rendered locally with LaTeX and dvipng. Use math-mode commands such "
                                  + "as \\frac, \\sqrt, \\sum, \\int, and \\alpha. Dollar delimiters "
                                  + "are optional."
                            textColor: Theme.dividerColor
                            pixelSize: Typography.caption
                            wrapMode: Text.WordWrap
                        }
                    }

                    Item {
                        width: 1
                        height: LayoutMetrics.spacing.xl
                    }
                }
            }
        }
    }

    ColorDialog {
        id: backgroundDialog
        title: "Background colour"
        onAccepted: mathVM.setLatexBackground(selectedColor.toString())
    }

    ColorDialog {
        id: foregroundDialog
        title: "Text colour"
        onAccepted: mathVM.setLatexForeground(selectedColor.toString())
    }

    FileDialog {
        id: latexFileDialog
        title: "Save LaTeX PNG"
        fileMode: FileDialog.SaveFile
        defaultSuffix: "png"
        nameFilters: ["PNG images (*.png)"]
        onAccepted: mathVM.saveLatex(selectedFile.toString())
    }
}
