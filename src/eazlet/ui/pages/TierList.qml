pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import components

Item {
    id: page

    Layout.fillWidth: true
    Layout.fillHeight: true

    property string selectedItemId: ""
    property string colorTierId: ""
    property bool exporting: false

    property string dragItemId: ""
    property string dragImageUrl: ""
    property bool dragActive: false
    property string hoverZone: "none"
    property string hoverTierId: ""
    property int hoverIndex: -1

    readonly property real thumbSize: LayoutMetrics.unit * 11
    readonly property real labelWidth: LayoutMetrics.unit * 16
    readonly property real exportScale: 2

    function toggleSelection(itemId) {
        selectedItemId = selectedItemId === itemId ? "" : itemId
    }

    function placeSelectedIn(tierId) {
        if (selectedItemId === "")
            return
        tierListVM.assignItem(selectedItemId, tierId)
        selectedItemId = ""
    }

    function beginDrag(itemId, imageUrl, px, py) {
        dragItemId = itemId
        dragImageUrl = imageUrl
        dragActive = false
        hoverZone = "none"
        hoverTierId = ""
        hoverIndex = -1
        dragProxy.width = thumbSize
        dragProxy.height = thumbSize
        dragProxy.x = px - thumbSize / 2
        dragProxy.y = py - thumbSize / 2
    }

    function updateDrag(px, py) {
        if (dragItemId === "")
            return

        dragActive = true
        dragProxy.x = px - dragProxy.width / 2
        dragProxy.y = py - dragProxy.height / 2

        var viewportPoint = flick.mapFromItem(page, px, py)
        var insideBoard = viewportPoint.x >= 0 && viewportPoint.y >= 0
                          && viewportPoint.x <= flick.width
                          && viewportPoint.y <= flick.height
        if (insideBoard) {
            for (var i = 0; i < tierRepeater.count; ++i) {
                var row = tierRepeater.itemAt(i)
                if (!row)
                    continue
                var point = row.mapFromItem(page, px, py)
                if (point.x >= 0 && point.y >= 0
                        && point.x <= row.width && point.y <= row.height) {
                    hoverZone = "tier"
                    hoverTierId = row.tierId
                    hoverIndex = row.insertionIndex(point.x, point.y)
                    return
                }
            }
        }

        var poolPoint = poolTarget.mapFromItem(page, px, py)
        if (poolPoint.x >= 0 && poolPoint.y >= 0
                && poolPoint.x <= poolTarget.width
                && poolPoint.y <= poolTarget.height) {
            hoverZone = "pool"
            hoverTierId = ""
            hoverIndex = -1
            return
        }

        hoverZone = "none"
        hoverTierId = ""
        hoverIndex = -1
    }

    function resetDrag() {
        dragItemId = ""
        dragImageUrl = ""
        dragActive = false
        hoverZone = "none"
        hoverTierId = ""
        hoverIndex = -1
    }

    function endDrag() {
        var itemId = dragItemId
        var zone = hoverZone
        var tierId = hoverTierId
        var index = hoverIndex
        resetDrag()

        if (itemId === "" || zone === "none")
            return

        Qt.callLater(function() {
            if (zone === "tier")
                tierListVM.assignItemAt(itemId, tierId, index)
            else
                tierListVM.assignItem(itemId, "")
        })
    }

    function exportBoard() {
        exporting = true
        board.grabToImage(function(result) {
            exporting = false
            if (!result)
                return
            var target = exportDialog.selectedFile.toString()
            if (target.indexOf("file://") === 0)
                target = decodeURIComponent(target.substring(7))
            if (result.saveToFile(target))
                tierListVM.setMessage(
                    Lang.pages.tierList.msgExported.replace("{path}", target))
            else
                tierListVM.setMessage(Lang.pages.tierList.msgExportFailed)
        }, Qt.size(Math.round(board.width * exportScale),
                   Math.round(board.height * exportScale)))
    }

    DropArea {
        anchors.fill: parent
        onEntered: function(drag) {
            if (drag.hasUrls)
                drag.acceptProposedAction()
        }
        onDropped: function(drop) {
            if (drop.hasUrls)
                tierListVM.addFiles(drop.urls)
        }
    }

    Surface {
        anchors.centerIn: parent
        width: parent.width * 0.9
        height: parent.height * 0.9

        Flickable {
            id: flick
            objectName: "boardFlick"
            ScrollBar.vertical: AppScrollBar {}
            acceptedButtons: Qt.NoButton

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: poolCard.top
            anchors.leftMargin: LayoutMetrics.spacing.lg
            anchors.rightMargin: LayoutMetrics.spacing.lg
            anchors.topMargin: LayoutMetrics.spacing.lg
            anchors.bottomMargin: LayoutMetrics.spacing.md
            contentHeight: tierColumn.implicitHeight
            clip: true
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds

            WheelScrollArea {
                target: flick
            }

            Column {
                id: tierColumn
                width: parent.width
                x: Math.max(0, (parent.width - width) / 2)
                spacing: LayoutMetrics.spacing.md

                Title {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Lang.pages.tierList.title
                    textColor: Theme.textColor
                    pixelSize: Typography.h2
                }

                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    bold: false
                    text: Lang.pages.tierList.subtitle
                    textColor: Theme.dividerColor
                    pixelSize: Typography.h6
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    width: parent.width
                    height: LayoutMetrics.divider.s
                    color: Theme.dividerColor
                }

                RowLayout {
                    width: parent.width
                    spacing: LayoutMetrics.spacing.sm

                    Button {
                        buttonText: Lang.pages.tierList.addImages
                        iconPath: SVGLibrary.browse
                        primary: true
                        isometric: true
                        heightMultiplier: 1.3
                        onPressed: imageDialog.open()
                    }

                    Button {
                        buttonText: Lang.pages.tierList.addTier
                        isometric: true
                        heightMultiplier: 1.3
                        enabled: tierListVM.tierCount < tierListVM.maxTiers
                        onPressed: tierListVM.addTier()
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Button {
                        buttonText: Lang.pages.tierList.exportPng
                        isometric: true
                        heightMultiplier: 1.3
                        enabled: tierListVM.itemCount > 0
                        onPressed: exportDialog.open()
                    }

                    Button {
                        buttonText: Lang.pages.tierList.clearImages
                        iconPath: SVGLibrary.eraser
                        isometric: true
                        heightMultiplier: 1.3
                        enabled: tierListVM.itemCount > 0
                        onPressed: tierListVM.clearItems()
                    }
                }

                Label {
                    width: parent.width
                    bold: false
                    text: tierListVM.message !== ""
                          ? tierListVM.message
                          : Lang.pages.tierList.hintDragOrClick
                    textColor: Theme.dividerColor
                    pixelSize: Typography.caption
                    wrapMode: Text.WordWrap
                }

                // Tier board -------------------------------------------------
                Rectangle {
                    id: board
                    width: parent.width
                    implicitHeight: boardColumn.implicitHeight
                                    + LayoutMetrics.spacing.md * 2
                    radius: LayoutMetrics.radius.m
                    color: Theme.inputBackgroundColor
                    border.color: Theme.borderColor
                    border.width: LayoutMetrics.border.l
                    clip: true

                    Column {
                        id: boardColumn
                        width: parent.width - LayoutMetrics.spacing.md * 2
                        x: LayoutMetrics.spacing.md
                        y: LayoutMetrics.spacing.md
                        spacing: LayoutMetrics.spacing.sm

                        Repeater {
                            id: tierRepeater
                            model: tierListVM.tiers

                            delegate: Item {
                                id: tierRow
                                required property var modelData
                                required property int index

                                readonly property var tierData: modelData
                                readonly property string tierId: tierData.id
                                readonly property color tierColor: tierData.color
                                readonly property bool dropTarget: page.dragActive
                                                                  && page.hoverZone === "tier"
                                                                  && page.hoverTierId === tierId
                                readonly property color labelTextColor: {
                                    var r = tierColor.r * 0.299
                                    var g = tierColor.g * 0.587
                                    var b = tierColor.b * 0.114
                                    return (r + g + b) > 0.55 ? "#141414" : "#FFFFFF"
                                }

                                width: boardColumn.width
                                height: Math.max(page.thumbSize,
                                                 tierFlow.implicitHeight)
                                        + LayoutMetrics.spacing.sm * 2

                                function visibleThumbs() {
                                    var result = []
                                    for (var i = 0; i < tierFlow.children.length; ++i) {
                                        var child = tierFlow.children[i]
                                        if (!child || child.width <= 0 || child.height <= 0)
                                            continue
                                        result.push(child)
                                    }
                                    return result
                                }

                                function insertionIndex(px, py) {
                                    var thumbs = visibleThumbs()
                                    var localX = px - tierFlow.x
                                    var localY = py - tierFlow.y
                                    var nearest = -1
                                    var bestDistance = 1e18
                                    var after = false

                                    for (var i = 0; i < thumbs.length; ++i) {
                                        var child = thumbs[i]
                                        var cx = child.x + child.width / 2
                                        var cy = child.y + child.height / 2
                                        var dx = localX - cx
                                        var dy = localY - cy
                                        var distance = dx * dx + dy * dy
                                        if (distance < bestDistance) {
                                            bestDistance = distance
                                            nearest = i
                                            after = localX > cx
                                        }
                                    }

                                    if (nearest < 0)
                                        return 0
                                    return after ? nearest + 1 : nearest
                                }

                                function insertionThumbX(index) {
                                    var thumbs = visibleThumbs()
                                    if (thumbs.length === 0)
                                        return tierFlow.x
                                    if (index <= 0)
                                        return tierFlow.x + thumbs[0].x
                                    if (index >= thumbs.length) {
                                        var last = thumbs[thumbs.length - 1]
                                        return tierFlow.x + last.x + last.width
                                                         + tierFlow.spacing
                                    }
                                    var previous = thumbs[index - 1]
                                    return tierFlow.x + previous.x + previous.width
                                                     + tierFlow.spacing
                                }

                                Rectangle {
                                    id: rowBackground
                                    anchors.fill: parent
                                    radius: LayoutMetrics.radius.s
                                    color: Theme.backgroundColor
                                    border.width: LayoutMetrics.border.m
                                    border.color: tierRow.dropTarget
                                                  ? Theme.themeColor : Theme.borderColor
                                }

                                Rectangle {
                                    id: labelBlock
                                    width: page.labelWidth
                                    height: parent.height
                                    radius: LayoutMetrics.radius.s
                                    color: tierRow.tierColor
                                    border.width: LayoutMetrics.border.m
                                    border.color: Qt.darker(tierRow.tierColor, 1.18)

                                    HoverHandler {
                                        id: labelHover
                                    }

                                    TextInput {
                                        id: nameInput
                                        anchors.centerIn: parent
                                        width: Math.max(0, parent.width
                                                           - LayoutMetrics.spacing.md * 2)
                                        height: LayoutMetrics.unit * 7
                                        text: tierRow.tierData.name
                                        color: tierRow.labelTextColor
                                        font.pixelSize: Typography.h2
                                        font.family: Typography.fontBold
                                        font.weight: Font.Bold
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        selectByMouse: true
                                        selectionColor: Qt.rgba(0, 0, 0, 0.22)
                                        selectedTextColor: tierRow.labelTextColor
                                        clip: true
                                        onEditingFinished: {
                                            tierListVM.renameTier(tierRow.tierId, text)
                                            text = tierRow.tierData.name
                                        }
                                        onAccepted: {
                                            tierListVM.renameTier(tierRow.tierId, text)
                                            text = tierRow.tierData.name
                                            focus = false
                                        }
                                    }

                                    Rectangle {
                                        id: colorButton
                                        width: LayoutMetrics.size.iconButton * 1.25
                                        height: width
                                        radius: width / 2
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: LayoutMetrics.spacing.xs
                                        visible: labelHover.hovered
                                        color: "transparent"
                                        border.width: LayoutMetrics.border.m
                                        border.color: tierRow.labelTextColor

                                        Rectangle {
                                            anchors.fill: parent
                                            anchors.margins: LayoutMetrics.unit * 0.55
                                            radius: width / 2
                                            color: tierRow.tierColor
                                            border.width: LayoutMetrics.border.m
                                            border.color: tierRow.labelTextColor
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                page.colorTierId = tierRow.tierId
                                                colorDialog.selectedColor = tierRow.tierColor
                                                colorDialog.open()
                                            }
                                        }
                                    }

                                    Row {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: LayoutMetrics.spacing.xxs
                                        spacing: LayoutMetrics.spacing.xxs
                                        visible: labelHover.hovered

                                        Repeater {
                                            model: [
                                                { glyph: "↑", action: "up" },
                                                { glyph: "↓", action: "down" },
                                                { glyph: "×", action: "delete" }
                                            ]

                                            delegate: Rectangle {
                                                required property var modelData

                                                readonly property bool canAct: {
                                                    if (modelData.action === "up")
                                                        return tierRow.index > 0
                                                    if (modelData.action === "down")
                                                        return tierRow.index
                                                               < tierListVM.tierCount - 1
                                                    if (modelData.action === "delete")
                                                        return tierListVM.tierCount > 1
                                                    return true
                                                }

                                                width: LayoutMetrics.size.iconButton * 1.25
                                                height: width
                                                radius: LayoutMetrics.radius.s
                                                enabled: canAct
                                                opacity: canAct ? 1.0 : 0.35
                                                color: controlMouse.containsMouse
                                                       ? Qt.rgba(tierRow.labelTextColor.r,
                                                                 tierRow.labelTextColor.g,
                                                                 tierRow.labelTextColor.b, 0.2)
                                                       : Qt.rgba(tierRow.labelTextColor.r,
                                                                 tierRow.labelTextColor.g,
                                                                 tierRow.labelTextColor.b, 0.08)
                                                border.width: LayoutMetrics.border.m
                                                border.color: Qt.rgba(tierRow.labelTextColor.r,
                                                                      tierRow.labelTextColor.g,
                                                                      tierRow.labelTextColor.b, 0.5)

                                                Label {
                                                    anchors.centerIn: parent
                                                    text: modelData.glyph
                                                    color: tierRow.labelTextColor
                                                    pixelSize: Typography.h5
                                                }

                                                MouseArea {
                                                    id: controlMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: canAct
                                                                 ? Qt.PointingHandCursor
                                                                 : Qt.ArrowCursor
                                                    onClicked: {
                                                        if (modelData.action === "up")
                                                            tierListVM.moveTier(tierRow.tierId, -1)
                                                        else if (modelData.action === "down")
                                                            tierListVM.moveTier(tierRow.tierId, 1)
                                                        else
                                                            tierListVM.removeTier(tierRow.tierId)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Flow {
                                    id: tierFlow
                                    x: page.labelWidth + LayoutMetrics.spacing.sm
                                    y: LayoutMetrics.spacing.sm
                                    width: Math.max(0, tierRow.width - x
                                                       - LayoutMetrics.spacing.sm)
                                    height: implicitHeight
                                    spacing: LayoutMetrics.spacing.sm

                                    Repeater {
                                        model: tierRow.tierData.items
                                        delegate: itemThumbnail
                                    }
                                }

                                Label {
                                    anchors.fill: parent
                                    anchors.leftMargin: page.labelWidth + LayoutMetrics.spacing.sm
                                    anchors.rightMargin: LayoutMetrics.spacing.sm
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    visible: tierRow.tierData.items.length === 0
                                             && !page.exporting
                                    bold: false
                                    text: Lang.pages.tierList.dragImagesHere
                                    textColor: Theme.dividerColor
                                    pixelSize: Typography.h6
                                }

                                Rectangle {
                                    id: insertionGhost
                                    objectName: "insertionGhost"
                                    x: tierRow.insertionThumbX(page.hoverIndex)
                                    y: tierFlow.y
                                    width: page.thumbSize
                                    height: page.thumbSize
                                    radius: LayoutMetrics.radius.s
                                    color: "transparent"
                                    border.width: 0
                                    opacity: 0.45
                                    visible: tierRow.dropTarget && page.hoverIndex >= 0
                                    z: 6
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        source: page.dragImageUrl
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: true
                                        smooth: true
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    z: -1
                                    acceptedButtons: Qt.LeftButton
                                    onClicked: page.placeSelectedIn(tierRow.tierId)
                                }
                            }
                        }

                        Label {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            visible: tierListVM.tierCount === 0
                            bold: false
                            text: Lang.pages.tierList.noTiers
                            textColor: Theme.dividerColor
                            pixelSize: Typography.h6
                        }
                    }
                }


            }
        }

        Rectangle {
            id: poolCard
            objectName: "poolCard"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: LayoutMetrics.spacing.lg
            anchors.rightMargin: LayoutMetrics.spacing.lg
            anchors.bottomMargin: LayoutMetrics.spacing.lg
            implicitHeight: poolColumn.implicitHeight
                            + LayoutMetrics.spacing.md * 2
            height: Math.min(implicitHeight,
                             Math.max(LayoutMetrics.unit * 12, page.height * 0.32))
            radius: LayoutMetrics.radius.m
            color: Theme.inputBackgroundColor
            border.color: page.dragActive && page.hoverZone === "pool"
                          ? Theme.themeColor : Theme.borderColor
            border.width: LayoutMetrics.border.l

            Column {
                id: poolColumn
                width: parent.width - LayoutMetrics.spacing.md * 2
                x: LayoutMetrics.spacing.md
                y: LayoutMetrics.spacing.md
                spacing: LayoutMetrics.spacing.sm

                RowLayout {
                    width: parent.width
                    spacing: LayoutMetrics.spacing.sm

                    Label {
                        text: Lang.pages.tierList.unranked
                        textColor: Theme.textColor
                        pixelSize: Typography.h5
                    }

                    Label {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        bold: false
                        text: tierListVM.poolCount + " "
                              + (tierListVM.poolCount === 1
                                 ? Lang.common.imageSingular
                                 : Lang.common.imagePlural)
                        textColor: Theme.dividerColor
                        pixelSize: Typography.h6
                        elide: Text.ElideRight
                    }

                    Label {
                        bold: false
                        text: Lang.pages.tierList.dropFilesHint
                        textColor: Theme.dividerColor
                        pixelSize: Typography.caption
                    }
                }

                Rectangle {
                    width: parent.width
                    height: LayoutMetrics.divider.s
                    color: Theme.dividerColor
                }

                Item {
                    id: poolTarget
                    width: parent.width
                    height: Math.max(LayoutMetrics.unit * 12,
                                     Math.min(poolFlow.implicitHeight,
                                              Math.max(LayoutMetrics.unit * 12,
                                                       page.height * 0.2)))

                    Flickable {
                        id: poolFlick
                        anchors.fill: parent
                        contentHeight: poolFlow.implicitHeight
                        clip: true
                        acceptedButtons: Qt.NoButton
                        flickableDirection: Flickable.VerticalFlick
                        boundsBehavior: Flickable.StopAtBounds

                        Flow {
                            id: poolFlow
                            width: parent.width
                            height: implicitHeight
                            spacing: LayoutMetrics.spacing.sm

                            Repeater {
                                model: tierListVM.pool
                                delegate: itemThumbnail
                            }
                        }

                        WheelScrollArea {
                            target: poolFlick
                            step: LayoutMetrics.unit * 12
                        }
                    }

                    Label {
                        anchors.centerIn: parent
                        width: Math.max(0, parent.width - LayoutMetrics.spacing.lg)
                        horizontalAlignment: Text.AlignHCenter
                        visible: tierListVM.poolCount === 0
                        bold: false
                        text: tierListVM.itemCount === 0
                              ? Lang.pages.tierList.emptyPoolHint
                              : Lang.pages.tierList.allRankedHint
                        textColor: Theme.dividerColor
                        pixelSize: Typography.h6
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

    }

    Component {
        id: itemThumbnail

        Item {
            id: thumbItem
            required property var modelData

            readonly property string itemId: modelData.id
            readonly property string imageUrl: modelData.url
            readonly property bool hovered: itemMouse.containsMouse
                                                || removeMouse.containsMouse

            width: page.thumbSize
            height: page.thumbSize
            property bool wasDragged: false

            Rectangle {
                id: thumbFrame
                anchors.fill: parent
                radius: LayoutMetrics.radius.s
                color: Theme.backgroundColor
                clip: true
                border.width: page.selectedItemId === thumbItem.itemId
                              ? LayoutMetrics.border.l
                              : (itemMouse.containsMouse ? LayoutMetrics.border.m : 0)
                border.color: page.selectedItemId === thumbItem.itemId
                              || itemMouse.containsMouse
                              ? Theme.themeColor : Theme.borderColor

                Behavior on border.color {
                    enabled: LayoutMetrics.animationsEnabled
                    ColorAnimation { duration: 120 }
                }

                Image {
                    id: thumbImage
                    anchors.fill: parent
                    source: thumbItem.imageUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: true
                }

                Label {
                    anchors.centerIn: parent
                    visible: thumbImage.status === Image.Error
                    text: "?"
                    textColor: Theme.dividerColor
                    pixelSize: Typography.h3
                }
            }

            Rectangle {
                id: removeButton
                width: LayoutMetrics.unit * 2.4
                height: width
                radius: width / 2
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: LayoutMetrics.unit * 0.45
                z: 6
                opacity: thumbItem.hovered && !page.dragActive ? 1.0 : 0.0
                color: removeMouse.containsMouse ? Theme.themeColor : Theme.backgroundColor
                border.width: LayoutMetrics.border.m
                border.color: Theme.borderColor

                Behavior on opacity {
                    enabled: LayoutMetrics.animationsEnabled
                    NumberAnimation { duration: 120 }
                }

                Label {
                    anchors.centerIn: parent
                    text: "×"
                    color: removeMouse.containsMouse ? Theme.hoverTextColor : Theme.textColor
                    pixelSize: Typography.h5
                }

                MouseArea {
                    id: removeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (page.selectedItemId === thumbItem.itemId)
                            page.selectedItemId = ""
                        tierListVM.removeItem(thumbItem.itemId)
                    }
                }
            }

            MouseArea {
                id: itemMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                preventStealing: true

                property real pressX: 0
                property real pressY: 0
                property bool pressing: false

                onPressed: function(mouse) {
                    if (mouse.button !== Qt.LeftButton)
                        return
                    pressing = true
                    thumbItem.wasDragged = false
                    pressX = mouse.x
                    pressY = mouse.y
                    var point = itemMouse.mapToItem(page, mouse.x, mouse.y)
                    page.beginDrag(thumbItem.itemId, thumbItem.imageUrl, point.x, point.y)
                }

                onPositionChanged: function(mouse) {
                    if (!pressing)
                        return
                    if (!thumbItem.wasDragged) {
                        var dx = mouse.x - pressX
                        var dy = mouse.y - pressY
                        if (Math.sqrt(dx * dx + dy * dy) < LayoutMetrics.unit)
                            return
                        thumbItem.wasDragged = true
                    }
                    var point = itemMouse.mapToItem(page, mouse.x, mouse.y)
                    page.updateDrag(point.x, point.y)
                }

                onReleased: {
                    if (!pressing)
                        return
                    pressing = false
                    if (thumbItem.wasDragged) {
                        page.endDrag()
                    } else {
                        page.resetDrag()
                        page.toggleSelection(thumbItem.itemId)
                    }
                }

                onCanceled: {
                    pressing = false
                    page.resetDrag()
                }
            }
        }
    }

    Item {
        id: dragProxy
        property string imageUrl: page.dragImageUrl

        width: page.thumbSize
        height: page.thumbSize
        visible: page.dragActive
        enabled: false
        z: 1000

        Rectangle {
            anchors.fill: parent
            radius: LayoutMetrics.radius.s
            color: Theme.backgroundColor
            clip: true
            border.width: LayoutMetrics.border.m
            border.color: Theme.themeColor
            opacity: 0.92

            Image {
                anchors.fill: parent
                source: dragProxy.imageUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
            }
        }
    }

    FileDialog {
        id: imageDialog
        title: Lang.pages.tierList.addImagesDialogTitle
        fileMode: FileDialog.OpenFiles
        nameFilters: [Lang.common.fileFilters.images]
        onAccepted: {
            var files = selectedFiles && selectedFiles.length > 0
                    ? selectedFiles
                    : (selectedFile ? [selectedFile] : [])
            tierListVM.addFiles(files)
        }
    }

    FileDialog {
        id: exportDialog
        title: Lang.pages.tierList.exportDialogTitle
        fileMode: FileDialog.SaveFile
        defaultSuffix: "png"
        nameFilters: [Lang.common.fileFilters.pngImage]
        onAccepted: page.exportBoard()
    }

    ColorDialog {
        id: colorDialog
        title: Lang.pages.tierList.colorDialogTitle
        onAccepted: {
            if (page.colorTierId !== "")
                tierListVM.setTierColor(page.colorTierId, selectedColor)
        }
    }
}
