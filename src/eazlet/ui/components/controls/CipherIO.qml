import QtQuick
import QtQuick.Controls
import components

// A self-contained Input/Output pair for one Code Tools tab. The view model
// property names are supplied by the page so every tab can keep its own state.
Column {
    id: root
    width: parent ? parent.width : 0
    spacing: LayoutMetrics.spacing.md

    property var viewModel: null
    property string inputProperty: ""
    property string outputProperty: ""
    property string placeholderText: "Enter text or a payload here"

    readonly property string inputText: (viewModel && inputProperty !== "")
                                        ? viewModel[inputProperty] : ""
    readonly property string outputText: (viewModel && outputProperty !== "")
                                         ? viewModel[outputProperty] : ""
    readonly property string statusText: viewModel ? viewModel.status : ""
    readonly property string errorText: viewModel ? viewModel.error : ""

    signal clearRequested()

    function setInput(value) {
        if (root.viewModel && root.inputProperty !== ""
                && root.viewModel[root.inputProperty] !== value)
            root.viewModel[root.inputProperty] = value
    }

    function copyOutput() {
        if (root.outputText.length === 0)
            return
        if (root.viewModel && typeof root.viewModel.copyText === "function")
            root.viewModel.copyText(root.outputText)
        else
            outputBox.copy()
    }

    Row {
        width: parent.width
        spacing: LayoutMetrics.spacing.sm

        Label {
            text: "Input"
            textColor: Theme.textColor
            pixelSize: Typography.h4
            anchors.verticalCenter: parent.verticalCenter
        }

        Button {
            buttonText: "Paste"
            iconPath: SVGLibrary.paste
            onPressed: inputBox.paste()
        }

        Button {
            buttonText: "Clear"
            iconPath: SVGLibrary.eraser
            onPressed: root.clearRequested()
        }
    }

    TextEdit {
        id: inputBox
        width: parent.width
        height: 150
        text: root.inputText
        placeholderText: root.placeholderText
        onTextChanged: root.setInput(text)
    }

    Row {
        width: parent.width
        spacing: LayoutMetrics.spacing.sm

        Label {
            text: "Output"
            textColor: Theme.textColor
            pixelSize: Typography.h4
            anchors.verticalCenter: parent.verticalCenter
        }

        Button {
            buttonText: "Copy"
            iconPath: SVGLibrary.copy
            enabled: root.outputText.length > 0
            onPressed: root.copyOutput()
        }
    }

    TextEdit {
        id: outputBox
        width: parent.width
        height: 150
        text: root.outputText
        readOnly: true
        showCopyButton: true
    }

    Row {
        spacing: LayoutMetrics.spacing.sm
        visible: root.statusText !== ""

        SVGObject {
            anchors.verticalCenter: parent.verticalCenter
            width: LayoutMetrics.size.iconS
            height: LayoutMetrics.size.iconS
            path: SVGLibrary.checkMark
            color: Theme.textColor
            visible: root.statusText !== "Failed"
        }
        Label {
            bold: false
            anchors.verticalCenter: parent.verticalCenter
            text: root.statusText
            textColor: Theme.textColor
            pixelSize: Typography.h6
        }
    }

    Row {
        width: parent.width
        spacing: LayoutMetrics.spacing.sm
        visible: root.errorText !== ""

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
            width: Math.max(0, parent.width - LayoutMetrics.size.iconS - parent.spacing)
            text: root.errorText
            textColor: "red"
            pixelSize: Typography.h6
            wrapMode: Text.WordWrap
        }
    }
}
