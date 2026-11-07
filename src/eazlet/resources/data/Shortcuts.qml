import QtQuick


QtObject {
    id: root
    property bool capturing: false
    property bool overlayOpen: false

    readonly property var definitions: [
        { id: "openSettings",  def: ["Ctrl+,"],            label: "Open settings",  scope: "app" },
        { id: "toggleSidebar", def: ["Ctrl+B"],            label: "Toggle sidebar", scope: "app" },
        { id: "zoomIn",        def: ["Ctrl+=", "Ctrl++"],  label: "Zoom in",        scope: "app" },
        { id: "zoomOut",       def: ["Ctrl+-"],            label: "Zoom out",       scope: "app" },
        { id: "processAction", def: ["Ctrl+Return"],       label: "Process / Run",  scope: "app" },
        { id: "nextTab",       def: ["Ctrl+Tab"],          label: "Next tab",       scope: "app" },
        { id: "prevTab",       def: ["Ctrl+Shift+Tab"],    label: "Previous tab",   scope: "app" },
        { id: "applyChanges",  def: ["Return"],            label: "Apply changes",  scope: "settings", editable: false },
        { id: "closeSidebar",  def: ["Escape"],            label: "Close sidebar",  scope: "panel",     editable: false }
    ]

    property var overrides: ({})

    function load(payload) {
        overrides = payload ? payload : ({})
    }

    function defaultFor(id) {
        for (var i = 0; i < definitions.length; i++)
            if (definitions[i].id === id) return definitions[i].def
        return []
    }

    function chords(id) {
        return overrides[id] !== undefined ? overrides[id] : defaultFor(id)
    }

    function primary(id) {
        var c = chords(id)
        return c.length > 0 ? c[0] : ""
    }

    function isCustom(id) {
        return overrides[id] !== undefined
    }

    function setPrimary(id, sequence) {
        var o = Object.assign({}, overrides)
        var current = chords(id).slice()
        if (current.length > 0) current[0] = sequence
        else current = [sequence]
        o[id] = current
        overrides = o
        _persist()
    }

    function reset(id) {
        if (!isCustom(id)) return
        var o = Object.assign({}, overrides)
        delete o[id]
        overrides = o
        _persist()
    }

    function resetAll() {
        overrides = ({})
        _persist()
    }

    function ownerOf(sequence, exceptId) {
        for (var i = 0; i < definitions.length; i++) {
            var d = definitions[i]
            if (d.id === exceptId) continue
            var c = chords(d.id)
            for (var j = 0; j < c.length; j++)
                if (c[j] === sequence) return d.id
        }
        return ""
    }

    function eventMatches(sequence, event) {
        if (!sequence || !event)
            return false
        var wantCtrl = sequence.indexOf("Ctrl+") !== -1
        var wantAlt = sequence.indexOf("Alt+") !== -1
        var wantShift = sequence.indexOf("Shift+") !== -1
        var wantMeta = sequence.indexOf("Meta+") !== -1
        var hasCtrl = !!(event.modifiers & Qt.ControlModifier)
        var hasAlt = !!(event.modifiers & Qt.AltModifier)
        var hasShift = !!(event.modifiers & Qt.ShiftModifier)
        var hasMeta = !!(event.modifiers & Qt.MetaModifier)
        if (wantCtrl !== hasCtrl || wantAlt !== hasAlt || wantShift !== hasShift || wantMeta !== hasMeta)
            return false
        var key = sequence.split("+").pop()
        if (key === "Return" || key === "Enter")
            return event.key === Qt.Key_Return || event.key === Qt.Key_Enter
        if (key === "Tab")
            return event.key === Qt.Key_Tab
        if (key === "Backtab")
            return event.key === Qt.Key_Backtab
        if (key === "Space")
            return event.key === Qt.Key_Space
        if (key === "Escape")
            return event.key === Qt.Key_Escape
        if (key.length === 1)
            return event.key === key.charCodeAt(0) || event.key === key.toLowerCase().charCodeAt(0)
        if (/^F\d+$/.test(key)) {
            var n = parseInt(key.substring(1))
            return event.key === Qt.Key_F1 + (n - 1)
        }
        return false
    }

    function matchesAction(id, event) {
        var c = chords(id)
        for (var i = 0; i < c.length; i++)
            if (eventMatches(c[i], event))
                return true
        return false
    }

    function _persist() {
        if (typeof controller !== "undefined")
            controller.save_shortcuts(overrides)
    }

    readonly property var list: {
        var out = []
        for (var i = 0; i < definitions.length; i++) {
            var d = definitions[i]
            if (d.editable === false) continue
            out.push({
                id: d.id,
                label: d.label,
                scope: d.scope,
                chords: chords(d.id).slice(),
                custom: isCustom(d.id)
            })
        }
        return out
    }
}
