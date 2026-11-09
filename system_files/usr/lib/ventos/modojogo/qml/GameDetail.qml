import QtQuick
import QtQuick.Controls.Basic

Popup {
    id: d
    property var game: null
    property var tagPicker
    property bool confirmRemove: false
    signal editRequested(string gid)
    signal modsRequested(var game)

    modal: true
    dim: true
    focus: true
    closePolicy: Popup.CloseOnEscape
    anchors.centerIn: Overlay.overlay
    width: Math.min(Overlay.overlay ? Overlay.overlay.width - 80 : 1000, 1100)
    height: 640
    padding: 24

    readonly property var prioLabels: ({ inherit: "padrão do sistema", on: "sempre ligada", off: "desligada" })
    property var actions: game ? [
        { id: "play", label: "▶  Jogar" },
        { id: "fav", label: game.favorite ? "★  Remover dos favoritos" : "☆  Adicionar aos favoritos" },
        { id: "mods", label: "Mods (" + game.modsCount + ")" },
        { id: "tags", label: "Tags" },
        { id: "edit", label: "Editar" },
        { id: "prio", label: "Prioridade de jogo: " + prioLabels[game.priority] },
        { id: "folder", label: "Abrir pasta no Dolphin" },
        { id: "remove", label: confirmRemove ? "Confirmar? (pressione de novo)" : (game.manual ? "Remover jogo" : "Ocultar da biblioteca") }
    ] : []

    function show(g) {
        game = g
        confirmRemove = false
        open()
    }
    function run(id) {
        if (!game) return
        if (id !== "remove") confirmRemove = false
        if (id === "play") { backend.launch(game.id); close() }
        else if (id === "fav") backend.toggleFavorite(game.id)
        else if (id === "mods") { var g = game; close(); modsRequested(g) }
        else if (id === "tags") {
            var gid = game.id
            tagPicker.show(game.tags, function(list) { backend.setTags(gid, list) })
        }
        else if (id === "edit") { var e = game.id; close(); editRequested(e) }
        else if (id === "prio") {
            var next = { inherit: "on", on: "off", off: "inherit" }
            backend.setPriority(game.id, next[game.priority])
        }
        else if (id === "folder") {
            var p = game.installDir !== "" ? game.installDir : game.savesDir
            if (p === "") backend.notify("Este jogo não tem pasta de instalação definida (use Editar).")
            else backend.openInDolphin(p)
        }
        else if (id === "remove") {
            if (!confirmRemove) confirmRemove = true
            else { backend.removeGame(game.id); close() }
        }
    }
    onOpened: actionList.forceActiveFocus()

    Connections {
        target: backend
        function onGamesChanged() {
            if (!d.game || !d.opened) return
            var n = backend.games.find(function(x) { return x.id === d.game.id })
            if (n) d.game = n; else d.close()
        }
    }

    background: Rectangle { radius: 18; color: "#1a1f36"; border.color: "#4da3ff"; border.width: 2 }

    contentItem: Row {
        spacing: 28
        Rectangle {
            width: 300
            height: 450
            radius: 14
            color: "#232a4a"
            clip: true
            Image {
                id: cover
                anchors.fill: parent
                source: d.game ? d.game.cover : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }
            Text {
                visible: cover.status !== Image.Ready
                anchors.centerIn: parent
                text: d.game ? d.game.name.charAt(0).toUpperCase() : ""
                color: "#4da3ff"
                font.pixelSize: 140
                opacity: 0.6
            }
        }
        Column {
            width: parent.width - 328
            spacing: 8
            Text {
                width: parent.width
                text: d.game ? d.game.name : ""
                color: "#ffffff"
                font.pixelSize: 38
                font.bold: true
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: d.game ? (d.game.sourceLabel + (d.game.consoleLabel !== "" ? " · " + d.game.consoleLabel : "")
                                + (d.game.tags.length ? "  ·  " + d.game.tags.join(", ") : "")) : ""
                color: "#8d96b5"
                font.pixelSize: 22
                elide: Text.ElideRight
            }
            ListView {
                id: actionList
                width: parent.width
                height: 470
                clip: true
                spacing: 6
                model: d.actions
                focus: true
                keyNavigationEnabled: true
                highlightMoveDuration: 80
                delegate: Rectangle {
                    width: actionList.width
                    height: 54
                    radius: 10
                    color: ListView.isCurrentItem && actionList.activeFocus ? "#4da3ff" : "#232a4a"
                    Text { x: 20; anchors.verticalCenter: parent.verticalCenter; text: modelData.label; color: "#ffffff"; font.pixelSize: 24 }
                    MouseArea { anchors.fill: parent; onClicked: { actionList.currentIndex = index; d.run(modelData.id) } }
                }
                Keys.onReturnPressed: if (currentIndex >= 0) d.run(d.actions[currentIndex].id)
                Keys.onEnterPressed: if (currentIndex >= 0) d.run(d.actions[currentIndex].id)
                Keys.onPressed: function(e) {
                    if (e.key === Qt.Key_F3) { d.run("mods"); e.accepted = true }        // X
                    else if (e.key === Qt.Key_F4) { d.run("fav"); e.accepted = true }    // Y
                }
            }
        }
    }
}
