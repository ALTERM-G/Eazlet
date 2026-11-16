import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import components

Item {
    id: page

    function processAction() {
        mathVM.process()
    }

    readonly property bool latexMode: mathVM.mode === "LaTeX → PNG"

    // Tabs group related tools; the operation picker chooses within a group.
    readonly property var modeGroups: [
        { name: "Algebra", modes: ["Simplify", "Expand", "Factor", "Solve"] },
        { name: "Calculus", modes: ["Derivative", "Integral", "Limit"] },
        { name: "LaTeX → PNG", modes: ["LaTeX → PNG"] }
    ]

    property var rememberedModes: [null, null, null]

    function groupIndexForMode(mode) {
        for (var i = 0; i < modeGroups.length; i++) {
            if (modeGroups[i].modes.indexOf(mode) >= 0)
                return i
        }
        return 0
    }

    readonly property int modeGroupIndex: groupIndexForMode(mathVM.mode)
    readonly property var groupModes: modeGroups[modeGroupIndex].modes
    readonly property bool showOperationPicker: groupModes.length > 1

    function preferredModeForGroup(index) {
        var group = modeGroups[index]
        var remembered = rememberedModes[index]
        if (remembered && group.modes.indexOf(remembered) >= 0)
            return remembered
        return group.modes[0]
    }

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
            return "Write \\int ... dx for an antiderivative, or \\int_{a}^{b} ... dx "
                    + "for a definite integral."
        case "Limit":
            return "Evaluates the two-sided limit at the point; when the two "
                    + "sides differ, their one-sided values are shown."
        case "Factor":
            return "Factors polynomials and integer expressions."
        case "Expand":
            return "Expands products and powers."
        default:
            return "LaTeX only. Supported: \\frac, \\sqrt, powers, implicit multiplication "
                    + "(2x), \\sin, \\cos, \\tan, \\log, \\exp, \\pi, \\infty, and Greek "
                    + "letters such as \\alpha."
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
                text: "A local math workbench: algebra, calculus, equation solving, and LaTeX "
                      + "rendered to PNG at any resolution."
                textColor: Theme.dividerColor
                pixelSize: Typography.h6
                wrapMode: Text.WordWrap
            }

            TabBar {
                id: modeTabs
                anchors.horizontalCenter: parent.horizontalCenter
                tabData: page.modeGroups
                active: page.visible
                currentIndex: 0
                enabled: !mathVM.computing && !mathVM.latexRendering
                Component.onCompleted: modeTabs.currentIndex = page.modeGroupIndex
                onCurrentIndexChanged: {
                    if (currentIndex < 0 || currentIndex >= page.modeGroups.length)
                        return
                    var modes = page.modeGroups[currentIndex].modes
                    if (modes.indexOf(mathVM.mode) < 0)
                        mathVM.setMode(page.preferredModeForGroup(currentIndex))
                }
            }

            Connections {
                target: mathVM
                function onModeChanged() {
                    var idx = page.groupIndexForMode(mathVM.mode)
                    var remembered = page.rememberedModes.slice()
                    remembered[idx] = mathVM.mode
                    page.rememberedModes = remembered
                    if (modeTabs.currentIndex !== idx)
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
                    width: parent.width
                    spacing: LayoutMetrics.spacing.md

                    // Algebra tools ------------------------------------------------
                    Column {
                        id: algebraPanel
                        width: parent.width
                        spacing: LayoutMetrics.spacing.md
                        visible: !page.latexMode

                        Column {
                            width: parent.width
                            spacing: LayoutMetrics.spacing.xxs
                            visible: page.showOperationPicker

                            Label {
                                bold: false
                                text: "Operation"
                                textColor: Theme.textColor
                                pixelSize: Typography.h6
                            }

                            ComboBox {
                                id: operationPicker
                                width: Math.min(LayoutMetrics.unit * 24, parent.width * 0.45)
                                model: page.groupModes
                                currentIndex: page.groupModes.indexOf(mathVM.mode)
                                onActivated: function(index) {
                                    if (index >= 0 && index < page.groupModes.length)
                                        mathVM.setMode(page.groupModes[index])
                                }
                            }
                        }

                        Connections {
                            target: mathVM
                            function onModeChanged() {
                                var idx = page.groupModes.indexOf(mathVM.mode)
                                if (idx >= 0 && operationPicker.currentIndex !== idx)
                                    operationPicker.currentIndex = idx
                            }
                        }

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
                            placeholderText: "Write the LaTeX code"
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
                            spacing: LayoutMetrics.spacing.lg
                            visible: mathVM.requiresVariable

                            Column {
                                spacing: LayoutMetrics.spacing.xxs

                                Label {
                                    bold: false
                                    text: "Variable"
                                    textColor: Theme.textColor
                                    pixelSize: Typography.h6
                                }

                                LineEdit {
                                    width: LayoutMetrics.unit * 14
                                    text: mathVM.variable
                                    placeholderText: "x"
                                    onTextEdited: mathVM.setVariable(text)
                                }
                            }

                            Column {
                                spacing: LayoutMetrics.spacing.xxs
                                visible: mathVM.requiresPoint

                                Label {
                                    bold: false
                                    text: "Point"
                                    textColor: Theme.textColor
                                    pixelSize: Typography.h6
                                }

                                LineEdit {
                                    width: LayoutMetrics.unit * 14
                                    text: mathVM.point
                                    placeholderText: "0"
                                    onTextEdited: mathVM.setPoint(text)
                                }
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
                            placeholderText: "The LaTeX result will appear here"
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
                            height: LayoutMetrics.unit * 8
                            text: mathVM.latexSource
                            placeholderText: "Write the LaTeX code"
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

                        Column {
                            id: latexResolutionColumn
                            width: parent.width
                            spacing: LayoutMetrics.spacing.xxs

                            Label {
                                bold: false
                                text: "Resolution"
                                textColor: Theme.textColor
                                pixelSize: Typography.h6
                            }

                            Row {
                                spacing: LayoutMetrics.spacing.sm

                                ComboBox {
                                    width: Math.min(LayoutMetrics.unit * 16,
                                                    latexResolutionColumn.width * 0.3)
                                    model: mathVM.latexResolutions
                                    scrollablePopup: true
                                    maxVisibleItems: 8
                                    currentIndex: {
                                        var idx =
                                            mathVM.latexResolutions.indexOf(
                                                mathVM.latexResolution)
                                        return idx >= 0 ? idx : 0
                                    }
                                    onActivated: function(index) {
                                        if (index >= 0
                                                && index < mathVM.latexResolutions.length)
                                            mathVM.setLatexResolution(
                                                mathVM.latexResolutions[index])
                                    }
                                    onCurrentIndexChanged: {
                                        if (currentIndex >= 0
                                                && currentIndex
                                                   < mathVM.latexResolutions.length) {
                                            var value =
                                                mathVM.latexResolutions[currentIndex]
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
                        }

                        Flow {
                            width: parent.width
                            spacing: LayoutMetrics.spacing.xl

                            ColumnLayout {
                                spacing: LayoutMetrics.spacing.xxs

                                Label {
                                    bold: false
                                    text: "Background"
                                    textColor: Theme.textColor
                                    pixelSize: Typography.h6
                                }

                                RowLayout {
                                    spacing: LayoutMetrics.spacing.sm

                                    Rectangle {
                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.preferredWidth: LayoutMetrics.size.lineEditHeight
                                        Layout.preferredHeight: LayoutMetrics.size.lineEditHeight
                                        radius: LayoutMetrics.radius.m
                                        color: page.previewColor(mathVM.latexBackground)
                                        border.color: Theme.borderColor
                                        border.width: LayoutMetrics.border.m

                                        Label {
                                            anchors.centerIn: parent
                                            visible: page.isTransparent(
                                                         mathVM.latexBackground)
                                            text: "T"
                                            textColor: Theme.textColor
                                            pixelSize: Typography.body
                                        }
                                    }

                                    LineEdit {
                                        id: backgroundField
                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.preferredWidth: LayoutMetrics.unit * 18
                                        Layout.preferredHeight: LayoutMetrics.size.lineEditHeight
                                        text: mathVM.latexBackground
                                        placeholderText: "#FFFFFF"
                                        onTextEdited: mathVM.setLatexBackground(text)
                                    }

                                    Button {
                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.preferredHeight: LayoutMetrics.size.controlHeight * 1.15
                                        buttonText: "Pick"
                                        onPressed: {
                                            backgroundDialog.selectedColor =
                                                page.previewColor(mathVM.latexBackground)
                                            backgroundDialog.open()
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                spacing: LayoutMetrics.spacing.xxs

                                Label {
                                    bold: false
                                    text: "Text colour"
                                    textColor: Theme.textColor
                                    pixelSize: Typography.h6
                                }

                                RowLayout {
                                    spacing: LayoutMetrics.spacing.sm

                                    Rectangle {
                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.preferredWidth: LayoutMetrics.size.lineEditHeight
                                        Layout.preferredHeight: LayoutMetrics.size.lineEditHeight
                                        radius: LayoutMetrics.radius.m
                                        color: page.previewColor(mathVM.latexForeground)
                                        border.color: Theme.borderColor
                                        border.width: LayoutMetrics.border.m
                                    }

                                    LineEdit {
                                        id: foregroundField
                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.preferredWidth: LayoutMetrics.unit * 18
                                        Layout.preferredHeight: LayoutMetrics.size.lineEditHeight
                                        text: mathVM.latexForeground
                                        placeholderText: "#000000"
                                        onTextEdited: mathVM.setLatexForeground(text)
                                    }

                                    Button {
                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.preferredHeight: LayoutMetrics.size.controlHeight * 1.15
                                        buttonText: "Pick"
                                        onPressed: {
                                            foregroundDialog.selectedColor =
                                                page.previewColor(mathVM.latexForeground)
                                            foregroundDialog.open()
                                        }
                                    }
                                }
                            }
                        }

                        Flow {
                            width: parent.width
                            spacing: LayoutMetrics.spacing.sm

                            Button {
                                buttonText: "Render PNG"
                                primary: true
                                isometric: true
                                heightMultiplier: 1.3
                                enabled: mathVM.latexAvailable
                                         && !mathVM.latexRendering
                                onPressed: mathVM.renderLatex()
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
                            Button {
                                buttonText: page.isTransparent(mathVM.latexBackground)
                                            ? "Transparent: On" : "Transparent: Off"
                                onPressed: mathVM.setLatexBackground(
                                    page.isTransparent(mathVM.latexBackground)
                                    ? "#FFFFFF" : "Transparent")
                            }
                        }

                        Label {
                            bold: false
                            width: parent.width
                            visible: !mathVM.latexAvailable
                            text: mathVM.latexToolchainError
                            textColor: "red"
                            pixelSize: Typography.h6
                            wrapMode: Text.WordWrap
                        }

                        Row {
                            width: parent.width
                            spacing: LayoutMetrics.spacing.md
                            visible: mathVM.latexImageSource !== ""

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
                            // Shown only once an image is actually rendered, sized
                            // to the image so there is no empty framed box.
                            readonly property real naturalWidth: latexPreviewImage.sourceSize.width
                            readonly property real naturalHeight: latexPreviewImage.sourceSize.height
                            readonly property real frame: border.width
                            readonly property real fitScale: naturalWidth > 0
                                ? Math.min(1, (latexPanel.width - 2 * frame) / naturalWidth) : 1

                            visible: mathVM.latexImageSource !== ""
                                     && naturalWidth > 0 && naturalHeight > 0
                            width: Math.max(1, Math.ceil(naturalWidth * fitScale) + 2 * frame)
                            height: Math.max(1, Math.ceil(naturalHeight * fitScale) + 2 * frame)
                            x: Math.round((parent.width - width) / 2)
                            radius: LayoutMetrics.radius.m
                            color: Theme.inputBackgroundColor
                            border.color: Qt.rgba(Theme.textColor.r, Theme.textColor.g,
                                                  Theme.textColor.b, 0.35)
                            border.width: LayoutMetrics.border.m
                            clip: true

                            Canvas {
                                // Inset so the image and the checkerboard do not
                                // paint over the frame.
                                anchors.fill: parent
                                anchors.margins: latexPreview.frame
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
                                    ctx.fillStyle =
                                        page.colorString(Theme.backgroundColor)
                                    ctx.fillRect(0, 0, width, height)
                                    ctx.fillStyle =
                                        page.colorString(Theme.inputBackgroundColor)
                                    for (var row = 0; row < rows; row++) {
                                        for (var column = 0; column < columns; column++) {
                                            if ((row + column) % 2 === 0)
                                                ctx.fillRect(column * square,
                                                             row * square,
                                                             square, square)
                                        }
                                    }
                                }
                            }

                            Image {
                                id: latexPreviewImage
                                anchors.fill: parent
                                anchors.margins: latexPreview.frame
                                source: mathVM.latexImageSource
                                fillMode: Image.Stretch
                                smooth: true
                                asynchronous: true
                            }
                        }

                        Row {
                            spacing: LayoutMetrics.spacing.sm
                            visible: mathVM.latexStatus !== ""
                                     && mathVM.latexStatus !== "Ready"

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
                                width: Math.max(0, parent.width
                                                - LayoutMetrics.size.iconS
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

                        Label {
                            bold: false
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: "Rendered locally with LaTeX and dvipng. Use math-mode commands "
                                  + "such as \\frac, \\sqrt, \\sum, \\int, and \\alpha. Dollar "
                                  + "delimiters are optional."
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
