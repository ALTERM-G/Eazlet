import QtQuick
import QtQuick.Shapes
import components

Item {
    id: root

    property string title: "Drop files here"
    property string description: "Drag and drop files, or click to browse"
    property string hint: ""
    property string iconPath: ""
    property var acceptedExtensions: []
    property bool clickable: true
    property real cornerRadius: LayoutMetrics.radius.m
    property real borderWidth: LayoutMetrics.border.l
    property real dashLength: LayoutMetrics.unit * 1.1
    property real dashGap: LayoutMetrics.unit * 0.7

    readonly property bool hovered: mouseArea.containsMouse
    readonly property bool dragActive: dropArea.containsDrag
    readonly property color primaryTextColor: Theme.textColor
    readonly property color secondaryTextColor: Theme.dividerColor
    readonly property color borderColor: dragActive ? Theme.themeColor : (hovered ? Theme.themeColor : Theme.borderColor)
    readonly property real pathInset: borderWidth / 2
    readonly property real pathRadius: cornerRadius

    signal clicked()
    signal filesDropped(var urls)

    implicitWidth: LayoutMetrics.unit * 50
    implicitHeight: LayoutMetrics.size.dropZoneHeight
    activeFocusOnTab: true

    Accessible.role: Accessible.Button
    Accessible.name: title
    Accessible.description: description
    Accessible.onPressAction: root.triggerClick()

    function triggerClick() {
        if (clickable)
            clicked()
    }

    function acceptsUrl(url) {
        if (acceptedExtensions.length === 0)
            return true
        var path = String(url).toLowerCase()
        for (var i = 0; i < acceptedExtensions.length; i++) {
            var ext = String(acceptedExtensions[i]).toLowerCase()
            if (ext.charAt(0) !== ".")
                ext = "." + ext
            if (path.endsWith(ext))
                return true
        }
        return false
    }

    Keys.onReturnPressed: root.triggerClick()
    Keys.onEnterPressed: root.triggerClick()
    Keys.onSpacePressed: root.triggerClick()

    Rectangle {
        id: background
        anchors.fill: parent
        radius: root.cornerRadius
        color: root.dragActive
               ? Qt.rgba(Theme.themeColor.r, Theme.themeColor.g, Theme.themeColor.b, 0.10)
               : Theme.inputBackgroundColor

        Behavior on color {
            enabled: LayoutMetrics.animationsEnabled
            ColorAnimation { duration: 150 }
        }
    }

    Shape {
        anchors.fill: parent
        z: 1

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.borderColor
            strokeWidth: root.borderWidth
            strokeStyle: ShapePath.DashLine
            dashPattern: [root.dashLength, root.dashGap]
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.RoundJoin

            startX: root.pathRadius
            startY: root.pathInset

            PathLine { x: root.width - root.pathRadius; y: root.pathInset }
            PathArc {
                x: root.width - root.pathInset
                y: root.pathRadius
                radiusX: root.pathRadius
                radiusY: root.pathRadius
                direction: PathArc.Clockwise
            }
            PathLine { x: root.width - root.pathInset; y: root.height - root.pathRadius }
            PathArc {
                x: root.width - root.pathRadius
                y: root.height - root.pathInset
                radiusX: root.pathRadius
                radiusY: root.pathRadius
                direction: PathArc.Clockwise
            }
            PathLine { x: root.pathRadius; y: root.height - root.pathInset }
            PathArc {
                x: root.pathInset
                y: root.height - root.pathRadius
                radiusX: root.pathRadius
                radiusY: root.pathRadius
                direction: PathArc.Clockwise
            }
            PathLine { x: root.pathInset; y: root.pathRadius }
            PathArc {
                x: root.pathRadius
                y: root.pathInset
                radiusX: root.pathRadius
                radiusY: root.pathRadius
                direction: PathArc.Clockwise
            }
        }
    }

    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - LayoutMetrics.spacing.xl * 2, LayoutMetrics.unit * 50)
        spacing: LayoutMetrics.spacing.xs

        SVGObject {
            anchors.horizontalCenter: parent.horizontalCenter
            width: LayoutMetrics.size.iconL
            height: LayoutMetrics.size.iconL
            path: root.iconPath
            color: root.primaryTextColor
            visible: root.iconPath !== ""
        }

        Label {
            width: parent.width
            text: root.title
            textColor: root.primaryTextColor
            pixelSize: Typography.h3
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        Label {
            bold: false
            width: parent.width
            text: root.description
            textColor: root.secondaryTextColor
            pixelSize: Typography.h6
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: text !== ""
        }

        Label {
            bold: false
            width: parent.width
            text: root.hint
            textColor: root.secondaryTextColor
            pixelSize: Typography.caption
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: text !== ""
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: root.clickable ? Qt.LeftButton : Qt.NoButton
        onClicked: if (root.clickable) root.triggerClick()
    }

    DropArea {
        id: dropArea
        anchors.fill: parent

        onEntered: (drag) => drag.acceptProposedAction()
        onDropped: (drop) => {
            if (!drop.hasUrls)
                return

            var urls = []
            for (var i = 0; i < drop.urls.length; i++) {
                if (root.acceptsUrl(drop.urls[i]))
                    urls.push(drop.urls[i].toString())
            }
            if (urls.length > 0) {
                root.filesDropped(urls)
                drop.acceptProposedAction()
            }
        }
    }

    FocusRing {
        focusItem: root
        cornerRadius: root.cornerRadius
    }
}
