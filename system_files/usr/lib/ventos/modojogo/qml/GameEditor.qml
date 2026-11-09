import QtQuick
import QtQuick.Controls.Basic

Popup {
    id: ed
    property var osk
    property var tagPicker
    property var values: ({})

    modal: true
    dim: true
    focus: true
    closePolicy: Popup.CloseOnEscape
    anchors.centerIn: Overlay.overlay
    width: Math.min(Overlay.overlay ? Overlay.overlay.width - 60 : 1100, 1180)
    height: Math.min(Overlay.overlay ? Overlay.overlay.height - 50 : 760, 800)
    padding: 22

    readonly property var kindLabels: ({
        exe: "Executável (.exe / binário)", bat: "Arquivo .bat (Wine/Bottles)", sh: "Script .sh",
        flatpak: "Comando Flatpak", url: "URL", command: "Comando", emulator: "Jogo de emulador"
    })
    function consoleLabels() {
        var m = {}
        var c = backend.consoles
        for (var i = 0; i < c.length; i++) m[c[i].id] = c[i].label
        return m
    }
    function consoleIds() {
        var a = []
        var c = backend.consoles
        for (var i = 0; i < c.length; i++) a.push(c[i].id)
        return a
    }
    function targetRow() {
        var k = values.kind
        if (k === "exe") return { k: "target", label: "Executável (.exe)", t: "path" }
        if (k === "bat") return { k: "target", label: "Arquivo .bat", t: "path" }
        if (k === "sh") return { k: "target", label: "Script .sh", t: "path" }
        if (k === "flatpak") return { k: "target", label: "Comando Flatpak (flatpak run org.x.Y)", t: "text" }
        if (k === "url") return { k: "target", label: "URL", t: "text" }
        return { k: "target", label: "Comando", t: "text" }
    }
    function buildRows() {
        var r = [{ k: "name", label: "Nome do jogo", t: "text" }]
        if (values.manual) {
            r.push({ k: "kind", label: "Tipo", t: "choice", opts: backend.kinds, labels: kindLabels })
            if (values.kind === "emulator") {
                r.push({ k: "console", label: "Console", t: "choice", opts: consoleIds(), labels: consoleLabels() })
                r.push({ k: "file", label: "ROM / ISO / .pkg / eboot.bin", t: "path" })
                r.push({ k: "emulator", label: "Emulador (vazio = automático)", t: "text" })
            } else {
                r.push(targetRow())
            }
            r.push({ k: "args", label: "Argumentos de inicialização", t: "text" })
            r.push({ k: "installDir", label: "Pasta de instalação", t: "dir" })
        }
        r.push({ k: "cover", label: "Capa / ícone", t: "path" })
        r.push({ k: "savesDir", label: "Pasta de saves", t: "dir" })
        r.push({ k: "tags", label: "Tags", t: "tags" })
        r.push({ k: "__save", label: "Salvar", t: "button" })
        r.push({ k: "__cancel", label: "Cancelar", t: "button" })
        return r
    }
    function setVal(k, v) {
        var o = Object.assign({}, values)
        o[k] = v
        values = o
    }
    function show(gid) {
        values = backend.gameForEdit(gid)
        open()
    }
    onOpened: form.forceActiveFocus()

    Connections {
        target: backend
        function onPathPicked(field, path) {
            if (field === "scan" || !ed.opened) return
            ed.setVal(field, path)
        }
    }

    background: Rectangle { radius: 18; color: "#1a1f36"; border.color: "#4da3ff"; border.width: 2 }

    contentItem: Column {
        spacing: 10
        Text {
            text: values.id ? "Editar jogo" : "Adicionar jogo"
            color: "#ffffff"
            font.pixelSize: 32
            font.bold: true
        }
        FormView {
            id: form
            width: parent.width
            height: parent.height - 52
            rows: ed.buildRows()
            values: ed.values
            focus: true
            onValueChanged2: function(key, value) { ed.setVal(key, value) }
            onEditText: function(key, label) { ed.osk.show(label, ed.values[key], function(v) { ed.setVal(key, v) }) }
            onPick: function(key, type) { backend.pickPath(key, type === "dir" ? "dir" : "file") }
            onEditTags: function(key) { ed.tagPicker.show(ed.values.tags, function(list) { ed.setVal("tags", list) }) }
            onPressed: function(key) {
                if (key === "__cancel") ed.close()
                else if (key === "__save") { if (backend.saveGame(ed.values) !== "") ed.close() }
            }
        }
    }
}
