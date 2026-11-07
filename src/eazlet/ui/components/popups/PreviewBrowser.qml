import QtQuick
import QtQuick.Controls
import QtQuick.Controls as Controls
import components

Controls.Popup {
    id: browser

    parent: Overlay.overlay
    modal: true
    focus: true
    clip: true
    padding: 0
    closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside

    width: {
        var available = LayoutMetrics.window ? LayoutMetrics.window.width : 1280
        return Math.round(Math.max(LayoutMetrics.unit * 80, Math.min(1150, available * 0.88)))
    }
    height: {
        var available = LayoutMetrics.window ? LayoutMetrics.window.height : 720
        return Math.round(Math.max(LayoutMetrics.unit * 50, Math.min(760, available * 0.9)))
    }
    x: parent ? Math.round((parent.width - width) / 2) : 0
    y: parent ? Math.round((parent.height - height) / 2) : 0

    property string title: "Select"
    property string searchPlaceholderText: "Search…"
    property string allLabel: "All"
    property string favoritesLabel: "Favorites"
    property string recentLabel: "Recent"
    property string emptyLabel: "Nothing here yet"
    property string noFavoritesLabel: "No favorites yet"
    property string noRecentsLabel: "No recent items yet"
    property string noMatchesLabel: "No matches"
    property string itemNameSingular: "item"
    property string itemNamePlural: "items"
    property string previewLabel: "Preview"
    property string previewPlaceholderText: "Select an item from the list"
    property string nothingSelectedLabel: "Nothing selected"
    property string favoriteLabel: "Favorite"
    property string favoritedLabel: "Favorited"
    property string cancelLabel: "Cancel"
    property string applyLabel: "Apply"

    property var items: []
    property string currentItem: ""
    property var favorites: []
    property var recents: []
    property string sampleText: ""

    // itemLabel and previewProvider make this component reusable for any
    // searchable collection. previewProvider returns the text shown in a tile.
    property var itemLabel: function(item) {
        return String(item)
    }
    property var previewProvider: function(item, text) {
        return ""
    }

    signal applied(string item)
    signal favoriteToggled(string item)

    property string selectedItem: ""
    property string searchText: ""
    property int filterMode: 0
    readonly property real toolbarHeight: LayoutMetrics.size.controlHeight * 1.6
    readonly property string effectiveSample: {
        var cleaned = String(browser.sampleText || "").replace(/\s+/g, " ").trim()
        return cleaned.length > 0 ? cleaned.substring(0, 32) : "Abc"
    }
    readonly property var filteredItems: {
        var source
        if (browser.filterMode === 1)
            source = browser.favorites || []
        else if (browser.filterMode === 2)
            source = browser.recents || []
        else
            source = browser.items || []

        var query = browser.searchText.trim().toLowerCase()
        var result = []
        for (var i = 0; i < source.length; i++) {
            var item = source[i]
            if ((browser.items || []).indexOf(item) === -1)
                continue
            if (query.length > 0
                    && String(browser.itemLabel(item)).toLowerCase().indexOf(query) === -1)
                continue
            result.push(item)
        }
        return result
    }
    readonly property string selectedPreview: {
        if (browser.selectedItem === "" || !browser.previewProvider)
            return ""
        return browser.previewProvider(browser.selectedItem, browser.effectiveSample)
    }
    readonly property bool selectedIsFavorite: browser.favorites
                                                   && browser.favorites.indexOf(browser.selectedItem) !== -1

    function previewFor(item) {
        return browser.previewProvider ? browser.previewProvider(item, browser.effectiveSample) : ""
    }

    function setFilter(mode) {
        browser.filterMode = mode
        browser.searchText = ""
        searchField.text = ""
        Qt.callLater(browser.revealSelection)
    }

    function selectItem(item) {
        browser.selectedItem = item
    }

    function revealSelection() {
        var index = browser.filteredItems.indexOf(browser.selectedItem)
        if (index >= 0)
            grid.positionViewAtIndex(index, GridView.Contain)
    }

    function applySelected() {
        if (browser.selectedItem === "")
            return
        var item = browser.selectedItem
        browser.close()
        browser.applied(item)
    }

    function toggleSelectedFavorite() {
        if (browser.selectedItem !== "")
            browser.favoriteToggled(browser.selectedItem)
    }

    function emptyText() {
        if (browser.searchText.trim().length > 0)
            return browser.noMatchesLabel + " for \"" + browser.searchText.trim() + "\""
        if (browser.filterMode === 1)
            return browser.noFavoritesLabel
        if (browser.filterMode === 2)
            return browser.noRecentsLabel
        return browser.emptyLabel
    }

    onOpened: {
        if (typeof Shortcuts !== "undefined")
            Shortcuts.overlayOpen = true
        browser.selectedItem = browser.currentItem !== "" ? browser.currentItem
                                                           : (browser.items.length > 0 ? browser.items[0] : "")
        browser.filterMode = 0
        browser.searchText = ""
        searchField.text = ""
        Qt.callLater(function() {
            searchField.forceActiveFocus()
            browser.revealSelection()
        })
    }

    onClosed: {
        if (typeof Shortcuts !== "undefined")
            Shortcuts.overlayOpen = false
    }

    enter: LayoutMetrics.animationsEnabled ? browserFadeEnter : browserInstantEnter
    exit: LayoutMetrics.animationsEnabled ? browserFadeExit : browserInstantExit

    Transition {
        id: browserInstantEnter
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 0 }
            NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: 0 }
        }
    }

    Transition {
        id: browserInstantExit
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 0 }
            NumberAnimation { property: "scale"; from: 1; to: 0.94; duration: 0 }
        }
    }

    Transition {
        id: browserFadeEnter
        ParallelAnimation {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: 180
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                property: "scale"
                from: 0.94
                to: 1
                duration: 180
                easing.type: Easing.OutCubic
            }
        }
    }

    Transition {
        id: browserFadeExit
        ParallelAnimation {
            NumberAnimation {
                property: "opacity"
                from: 1
                to: 0
                duration: 150
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                property: "scale"
                from: 1
                to: 0.94
                duration: 150
                easing.type: Easing.InQuad
            }
        }
    }

    background: Item {}

    Surface {
        anchors.fill: parent

        Title {
            id: titleLabel
            anchors.top: parent.top
            anchors.topMargin: LayoutMetrics.spacing.xl
            anchors.left: parent.left
            anchors.leftMargin: LayoutMetrics.spacing.xl
            text: browser.title
            textColor: Theme.textColor
            pixelSize: Typography.h2
        }

        IconButton {
            id: closeButton
            anchors.top: parent.top
            anchors.topMargin: LayoutMetrics.spacing.lg
            anchors.right: parent.right
            anchors.rightMargin: LayoutMetrics.spacing.lg
            buttonWidth: LayoutMetrics.size.iconButton * 0.85
            buttonHeight: LayoutMetrics.size.iconButton * 0.85
            iconPath: SVGLibrary.cross
            onPressed: browser.close()
        }

        Row {
            id: toolbar
            anchors.top: titleLabel.bottom
            anchors.topMargin: LayoutMetrics.spacing.lg
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: LayoutMetrics.spacing.xl
            anchors.rightMargin: LayoutMetrics.spacing.xl
            height: browser.toolbarHeight
            spacing: LayoutMetrics.spacing.sm

            LineEdit {
                id: searchField
                width: Math.max(0, toolbar.width - filterRow.width - toolbar.spacing)
                height: browser.toolbarHeight
                placeholderText: browser.searchPlaceholderText
                onTextChanged: browser.searchText = text
                onAccepted: browser.applySelected()
            }

            Row {
                id: filterRow
                height: parent.height
                spacing: LayoutMetrics.spacing.xs

                Button {
                    anchors.verticalCenter: parent.verticalCenter
                    buttonText: browser.allLabel
                    primary: browser.filterMode === 0
                    horizontalPadding: LayoutMetrics.spacing.md
                    width: Math.max(LayoutMetrics.unit * 8, implicitWidth)
                    height: browser.toolbarHeight
                    onPressed: browser.setFilter(0)
                }
                Button {
                    anchors.verticalCenter: parent.verticalCenter
                    buttonText: browser.favoritesLabel
                    primary: browser.filterMode === 1
                    horizontalPadding: LayoutMetrics.spacing.md
                    width: Math.max(LayoutMetrics.unit * 10, implicitWidth)
                    height: browser.toolbarHeight
                    onPressed: browser.setFilter(1)
                }
                Button {
                    anchors.verticalCenter: parent.verticalCenter
                    buttonText: browser.recentLabel
                    primary: browser.filterMode === 2
                    horizontalPadding: LayoutMetrics.spacing.md
                    width: Math.max(LayoutMetrics.unit * 9, implicitWidth)
                    height: browser.toolbarHeight
                    onPressed: browser.setFilter(2)
                }
            }
        }

        Rectangle {
            id: headerDivider
            anchors.top: toolbar.bottom
            anchors.topMargin: LayoutMetrics.spacing.md
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: LayoutMetrics.spacing.xl
            anchors.rightMargin: LayoutMetrics.spacing.xl
            height: LayoutMetrics.border.m
            color: Theme.dividerColor
        }

        Item {
            id: content
            anchors.top: headerDivider.bottom
            anchors.topMargin: LayoutMetrics.spacing.md
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: footer.top
            anchors.bottomMargin: LayoutMetrics.spacing.md
            anchors.leftMargin: LayoutMetrics.spacing.xl
            anchors.rightMargin: LayoutMetrics.spacing.xl

            Item {
                id: gridPane
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: previewPane.top
                anchors.bottomMargin: LayoutMetrics.spacing.md

                GridView {
                    id: grid
                    anchors.fill: parent
                    clip: true
                    focus: true
                    activeFocusOnTab: true
                    boundsBehavior: Flickable.StopAtBounds
                    reuseItems: true
                    cacheBuffer: LayoutMetrics.unit * 8
                    readonly property int columns: Math.max(2, Math.floor(width / (LayoutMetrics.unit * 16)))
                    cellWidth: Math.floor(width / columns)
                    cellHeight: LayoutMetrics.unit * 11
                    model: browser.filteredItems

                    Keys.onReturnPressed: browser.applySelected()
                    Keys.onEnterPressed: browser.applySelected()

                    ScrollBar.vertical: ScrollBar {
                        id: gridBar
                        parent: content
                        x: gridPane.width + LayoutMetrics.spacing.xs
                        y: LayoutMetrics.spacing.xs
                        height: Math.max(0, gridPane.height - LayoutMetrics.spacing.xs * 2)
                        policy: ScrollBar.AsNeeded
                        padding: 0
                        implicitWidth: LayoutMetrics.unit * 1.2

                        contentItem: Rectangle {
                            implicitWidth: LayoutMetrics.unit * 1.2
                            radius: Math.min(width / 2, LayoutMetrics.radius.m)
                            color: gridBar.pressed ? Theme.themeColor
                                 : gridBar.hovered ? Theme.borderColor
                                 : Theme.dividerColor
                            opacity: (gridBar.active || gridBar.hovered) ? 1.0 : 0.55

                            Behavior on color {
                                enabled: LayoutMetrics.animationsEnabled
                                ColorAnimation { duration: 120 }
                            }

                            Behavior on opacity {
                                enabled: LayoutMetrics.animationsEnabled
                                NumberAnimation { duration: 120 }
                            }
                        }
                    }

                    delegate: Rectangle {
                        id: tile
                        width: grid.cellWidth
                        height: grid.cellHeight
                        radius: LayoutMetrics.radius.m
                        color: tile.selected || tileMouse.containsMouse
                               ? Theme.hoverBackgroundColor
                               : "transparent"
                        border.width: tile.selected
                                      ? LayoutMetrics.border.l
                                      : LayoutMetrics.border.s
                        border.color: tile.selected
                                      ? Theme.hoverTextColor
                                      : Theme.dividerColor

                        readonly property bool selected: browser.selectedItem === modelData
                        readonly property bool highlighted: selected || tileMouse.containsMouse
                        readonly property bool favorite: browser.favorites
                                                         && browser.favorites.indexOf(modelData) !== -1
                        readonly property string previewText: browser.previewFor(modelData)

                        Behavior on color {
                            enabled: LayoutMetrics.animationsEnabled
                            ColorAnimation { duration: 120 }
                        }

                        MouseArea {
                            id: tileMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: browser.selectItem(modelData)
                            onDoubleClicked: {
                                browser.selectItem(modelData)
                                browser.applySelected()
                            }
                        }

                        Column {
                            anchors.fill: parent
                            anchors.margins: LayoutMetrics.spacing.sm
                            spacing: LayoutMetrics.spacing.xxs

                            Item {
                                width: parent.width
                                height: Math.max(0, parent.height - tileLabel.implicitHeight - parent.spacing)

                                Text {
                                    anchors.fill: parent
                                    text: tile.previewText
                                    textFormat: Text.PlainText
                                    wrapMode: Text.NoWrap
                                    fontSizeMode: Text.Fit
                                    minimumPixelSize: 2
                                    clip: true
                                    color: tile.highlighted ? Theme.hoverTextColor : Theme.textColor
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: Math.max(6, Math.round(Typography.caption * 0.85))
                                    lineHeight: 0.9
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter

                                    Behavior on color {
                                        enabled: LayoutMetrics.animationsEnabled
                                        ColorAnimation { duration: 120 }
                                    }
                                }
                            }

                            Text {
                                id: tileLabel
                                width: parent.width
                                text: browser.itemLabel(modelData)
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                color: tile.highlighted ? Theme.hoverTextColor : Theme.textColor
                                font.family: Typography.fontBold
                                font.weight: Font.Bold
                                font.pixelSize: Typography.caption

                                Behavior on color {
                                    enabled: LayoutMetrics.animationsEnabled
                                    ColorAnimation { duration: 120 }
                                }
                            }
                        }

                        SVGObject {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.topMargin: LayoutMetrics.spacing.xs
                            anchors.rightMargin: LayoutMetrics.spacing.xs
                            width: LayoutMetrics.size.iconS * 0.72
                            height: width
                            visible: tile.favorite
                            path: SVGLibrary.star
                            color: Theme.themeColor
                        }
                    }
                }

                Label {
                    anchors.centerIn: parent
                    width: parent.width * 0.85
                    visible: browser.filteredItems.length === 0
                    text: browser.emptyText()
                    textColor: Theme.dividerColor
                    bold: false
                    pixelSize: Typography.h6
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }

            Surface {
                id: previewPane
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Math.round(Math.max(LayoutMetrics.unit * 14, parent.height * 0.44))

                Item {
                    id: previewHeader
                    anchors.top: parent.top
                    anchors.topMargin: LayoutMetrics.spacing.md
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: LayoutMetrics.spacing.md
                    anchors.rightMargin: LayoutMetrics.spacing.md
                    height: previewName.implicitHeight

                    Label {
                        id: previewTitle
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: browser.previewLabel
                        textColor: Theme.dividerColor
                        bold: false
                        pixelSize: Typography.caption
                    }

                    Label {
                        id: previewName
                        anchors.left: previewTitle.right
                        anchors.leftMargin: LayoutMetrics.spacing.md
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: browser.selectedItem !== "" ? browser.itemLabel(browser.selectedItem)
                                                          : browser.nothingSelectedLabel
                        textColor: Theme.textColor
                        pixelSize: Typography.h4
                        elide: Text.ElideRight
                    }
                }

                TextEdit {
                    anchors.top: previewHeader.bottom
                    anchors.topMargin: LayoutMetrics.spacing.sm
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: LayoutMetrics.spacing.md
                    anchors.rightMargin: LayoutMetrics.spacing.md
                    anchors.bottomMargin: LayoutMetrics.spacing.md
                    readOnly: true
                    wrapMode: Text.NoWrap
                    horizontalScroll: true
                    fontFamily: "JetBrains Mono"
                    fontPixelSize: Typography.body
                    text: browser.selectedPreview
                    placeholderText: browser.previewPlaceholderText
                    showCopyButton: true
                }
            }
        }

        Rectangle {
            id: footerDivider
            anchors.bottom: footer.top
            anchors.bottomMargin: LayoutMetrics.spacing.md
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: LayoutMetrics.spacing.xl
            anchors.rightMargin: LayoutMetrics.spacing.xl
            height: LayoutMetrics.border.m
            color: Theme.dividerColor
        }

        Item {
            id: footer
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: LayoutMetrics.spacing.xl
            anchors.rightMargin: LayoutMetrics.spacing.xl
            anchors.bottomMargin: LayoutMetrics.spacing.lg
            height: LayoutMetrics.size.controlHeight * 1.15

            Button {
                id: favoriteButton
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                buttonText: browser.selectedIsFavorite ? browser.favoritedLabel
                                                       : browser.favoriteLabel
                iconPath: SVGLibrary.star
                primary: browser.selectedIsFavorite
                enabled: browser.selectedItem !== ""
                onPressed: browser.toggleSelectedFavorite()
            }

            Label {
                anchors.left: favoriteButton.right
                anchors.leftMargin: LayoutMetrics.spacing.md
                anchors.verticalCenter: parent.verticalCenter
                text: browser.filteredItems.length
                      + " "
                      + (browser.filteredItems.length === 1 ? browser.itemNameSingular
                                                            : browser.itemNamePlural)
                textColor: Theme.dividerColor
                bold: false
                pixelSize: Typography.caption
            }

            Button {
                id: applyButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                buttonText: browser.applyLabel
                primary: true
                enabled: browser.selectedItem !== ""
                onPressed: browser.applySelected()
            }

            Button {
                id: cancelButton
                anchors.right: applyButton.left
                anchors.rightMargin: LayoutMetrics.spacing.sm
                anchors.verticalCenter: parent.verticalCenter
                buttonText: browser.cancelLabel
                onPressed: browser.close()
            }
        }
    }
}
