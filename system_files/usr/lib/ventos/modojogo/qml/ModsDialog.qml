import QtQuick
import QtQuick.Controls.Basic

Popup {
    id: m
    property var osk
    property var tagPicker
    property string gid: ""
    property string gname: ""
    property var mods: []
    property var newMod: ({ name: "", kind: "exe", path: "", args: "" })

    modal: true
    dim: true
    focus: true
    closePolicy: Popup.CloseOnEscape
    anchors.centerIn: Overlay.overlay
    width: Math.min(Overlay.overlay ? Overlay.overlay.width - 60 : 1100, 1180)
    height: 700
    padding: 24

    function show(game) {
        gid = game.id
        gname = game.name
        reload()
        open()
    }
    function reload() { mods = backend.modsFor(gid) }
    function current() { return (modList.currentIndex >= 0 && modList.currentIndex < mods.length) ? mods[modList.currentIndex] : null }
    function setNew(k, v) {
        var o = Object.assign({}, newMod)
        o[k] = v
        newMod = o
    }
    onOpened: modList.forceActiveFocus()

    Connections {
        target: backend
        function onPathPicked(field, path) {
            if (field !== "path" || !addPopup.opened) return
            m.setNew("path", path)
        }
    }

    background: Rectangle { radius: 18; color: "#1a1f36"; border.color: "#4da3ff"; border.width: 2 }

    contentItem: Column {
        spacing: 12
        Text { text: "Mods de " + m.gname; color: "#ffffff"; font.pixelSize: 32; font.bold: true; elide: Text.ElideRight; width: parent.width }
        Row {
            spacing: 22
            ListView {
                id: modList
                width: 720
                height: 470
                clip: true
                spacing: 6
                model: m.mods
                focus: true
                keyNavigationEnabled: true
                KeyNavigation.right: btnAdd
                delegate: Rectangle {
                    width: modList.width
                    height: 68
                    radius: 10
                    color: ListView.isCurrentItem && modList.activeFocus ? "#34407a" : "#232a4a"
                    border.width: ListView.isCurrentItem && modList.activeFocus ? 2 : 0
                    border.color: "#4da3ff"
                    Text {
                        x: 18
                        y: 8
                        width: parent.width - 36
                        text: (modelData.enabled ? "☑  " : "☐  ") + modelData.name + "   [" + modelData.kind + "]"
                        color: "#ffffff"
                        font.pixelSize: 24
                        elide: Text.ElideRight
                    }
                    Text { x: 18; y: 40; width: parent.width - 36; text: modelData.path; color: "#8d96b5"; font.pixelSize: 16; elide: Text.ElideMiddle }
                    MouseArea { anchors.fill: parent; onClicked: modList.currentIndex = index }
                }
                Keys.onReturnPressed: { var c = m.current(); if (c) { backend.toggleMod(m.gid, c.id); m.reload() } }
                Keys.onPressed: function(e) {
                    var c = m.current()
                    if (e.key === Qt.Key_F3 && c) { backend.runMod(m.gid, c.id); e.accepted = true }
                }
                Text {
                    visible: m.mods.length === 0
                    anchors.centerIn: parent
                    text: "Nenhum mod. Use “Adicionar mod”."
                    color: "#8d96b5"
                    font.pixelSize: 24
                }
            }
            Column {
                spacing: 12
                width: 340
                GButton {
                    id: btnAdd
                    width: parent.width
                    text: "Adicionar mod"
                    KeyNavigation.left: modList
                    KeyNavigation.down: btnRun
                    onClicked: { m.newMod = { name: "", kind: "exe", path: "", args: "" }; addPopup.open() }
                }
                GButton {
                    id: btnRun
                    width: parent.width
                    text: "Executar / abrir"
                    KeyNavigation.left: modList
                    KeyNavigation.up: btnAdd
                    KeyNavigation.down: btnDolphin
                    onClicked: { var c = m.current(); if (c) backend.runMod(m.gid, c.id) }
                }
                GButton {
                    id: btnDolphin
                    width: parent.width
                    text: "Abrir no Dolphin"
                    KeyNavigation.left: modList
                    KeyNavigation.up: btnRun
                    KeyNavigation.down: btnDel
                    onClicked: { var c = m.current(); if (c) backend.openInDolphin(c.path) }
                }
                GButton {
                    id: btnDel
                    width: parent.width
                    text: "Remover mod"
                    KeyNavigation.left: modList
                    KeyNavigation.up: btnDolphin
                    KeyNavigation.down: btnClose
                    onClicked: { var c = m.current(); if (c) { backend.removeMod(m.gid, c.id); m.reload() } }
                }
                GButton {
                    id: btnClose
                    width: parent.width
                    text: "Fechar"
                    KeyNavigation.left: modList
                    KeyNavigation.up: btnDel
                    onClicked: m.close()
                }
            }
        }
        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            color: "#8d96b5"
            font.pixelSize: 17
            text: "Mods ativos que são executáveis (.exe, .bat via Wine/Bottles, .sh no terminal, .jar, scripts, comandos) rodam antes do jogo. "
                  + "Para mods .zip ou pastas que substituem arquivos, use “Abrir no Dolphin” e copie manualmente."
        }
    }

    Popup {
        id: addPopup
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape
        anchors.centerIn: Overlay.overlay
        width: Math.min(Overlay.overlay ? Overlay.overlay.width - 100 : 1000, 1000)
        height: 560
        padding: 20
        onOpened: addForm.forceActiveFocus()
        background: Rectangle { radius: 18; color: "#1a1f36"; border.color: "#ffd24d"; border.width: 2 }
        contentItem: Column {
            spacing: 10
            Text { text: "Novo mod"; color: "#ffffff"; font.pixelSize: 30; font.bold: true }
            FormView {
                id: addForm
                width: parent.width
                height: parent.height - 50
                values: m.newMod
                rows: [
                    { k: "name", label: "Nome do mod", t: "text" },
                    { k: "kind", label: "Tipo", t: "choice", opts: backend.modKinds },
                    { k: "path", label: "Arquivo / pasta / comando", t: "path" },
                    { k: "args", label: "Argumentos", t: "text" },
                    { k: "__add", label: "Adicionar", t: "button" },
                    { k: "__cancel", label: "Cancelar", t: "button" }
                ]
                focus: true
                onValueChanged2: function(key, value) { m.setNew(key, value) }
                onEditText: function(key, label) { m.osk.show(label, m.newMod[key], function(v) { m.setNew(key, v) }) }
                onPick: function(key, type) { backend.pickPath("path", "file") }
                onPressed: function(key) {
                    if (key === "__cancel") addPopup.close()
                    else if (key === "__add") {
                        if (m.newMod.name.trim() === "") { backend.notify("Dê um nome ao mod."); return }
                        backend.addMod(m.gid, m.newMod)
                        m.reload()
                        addPopup.close()
                    }
                }
            }
        }
    }
}
