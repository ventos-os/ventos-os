import QtQuick
import QtQuick.Controls.Basic

FocusScope {
    id: lib
    property string mode: "all"
    property string arg: ""
    property string consoleId: ""
    property string sourceFilter: ""
    property string query: ""
    property var osk
    signal openGame(var game)
    signal addGame()

    readonly property var titles: ({ all: "Todas as bibliotecas", favorites: "Favoritos", tag: "Tags", emulators: "Emuladores", android: "Android" })
    readonly property var sources: [
        { id: "", label: "Todas" }, { id: "steam", label: "Steam" }, { id: "heroic", label: "Heroic" },
        { id: "lutris", label: "Lutris" }, { id: "bottles", label: "Bottles" }, { id: "emulator", label: "Emuladores" },
        { id: "waydroid", label: "Android" }, { id: "manual", label: "Manual" }
    ]
    property var chips: {
        var out = []
        if (mode === "all") return sources
        if (mode === "emulators") {
            out.push({ id: "", label: "Todos" })
            var cs = backend.consoles
            for (var i = 0; i < cs.length; i++) out.push({ id: cs[i].id, label: cs[i].label })
        } else if (mode === "tag") {
            out.push({ id: "", label: "Todas" })
            var ts = backend.tags
            for (var j = 0; j < ts.length; j++) out.push({ id: ts[j], label: ts[j] })
        }
        return out
    }
    function chipValue() { return mode === "all" ? sourceFilter : (mode === "emulators" ? consoleId : arg) }
    function setChip(id) {
        if (mode === "all") sourceFilter = id
        else if (mode === "emulators") consoleId = id
        else if (mode === "tag") arg = id
    }
    property var filtered: {
        var q = query.toLowerCase()
        return backend.games.filter(function(g) {
            if (mode === "favorites" && !g.favorite) return false
            if (mode === "android" && g.source !== "waydroid") return false
            if (mode === "emulators" && g.source !== "emulator") return false
            if (mode === "emulators" && consoleId !== "" && g.console !== consoleId) return false
            if (mode === "tag" && arg !== "" && g.tags.indexOf(arg) < 0) return false
            if (mode === "all" && sourceFilter !== "" && g.source !== sourceFilter) return false
            if (q !== "" && g.name.toLowerCase().indexOf(q) < 0) return false
            return true
        })
    }
    Component.onCompleted: {
        for (var i = 0; i < chips.length; i++) if (chips[i].id === chipValue()) chipList.currentIndex = i
        grid.forceActiveFocus()
    }

    Connections {
        target: backend
        function onPathPicked(field, path) {
            if (field !== "scan" || !lib.visible) return
            backend.scanFolder(lib.consoleId, path)
        }
    }

    Row {
        id: bar
        spacing: 16
        Text {
            text: lib.titles[lib.mode] + (lib.query !== "" ? "  ·  “" + lib.query + "”" : "")
            color: "#e8ecf8"
            font.pixelSize: 34
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
            width: 520
            elide: Text.ElideRight
        }
        GButton {
            id: btnSearch
            text: "Buscar"
            KeyNavigation.right: btnAdd
            KeyNavigation.down: chipList.visible ? chipList : grid
            onClicked: lib.osk.show("Buscar jogo", lib.query, function(v) { lib.query = v })
        }
        GButton {
            id: btnAdd
            text: "Adicionar"
            KeyNavigation.left: btnSearch
            KeyNavigation.right: btnScan.visible ? btnScan : btnAdd
            KeyNavigation.down: chipList.visible ? chipList : grid
            onClicked: lib.addGame()
        }
        GButton {
            id: btnScan
            visible: lib.mode === "emulators"
            text: "Escanear pasta"
            KeyNavigation.left: btnAdd
            KeyNavigation.down: chipList.visible ? chipList : grid
            onClicked: {
                if (lib.consoleId === "") backend.notify("Escolha um console nos filtros primeiro.")
                else backend.pickPath("scan", "dir")
            }
        }
    }

    ListView {
        id: chipList
        visible: lib.chips.length > 0
        anchors.top: bar.bottom
        anchors.topMargin: 14
        width: parent.width
        height: visible ? 56 : 0
        orientation: ListView.Horizontal
        spacing: 10
        clip: true
        model: lib.chips
        keyNavigationEnabled: true
        onCurrentIndexChanged: if (currentIndex >= 0 && currentIndex < lib.chips.length) lib.setChip(lib.chips[currentIndex].id)
        KeyNavigation.up: btnSearch
        KeyNavigation.down: grid
        delegate: Rectangle {
            width: chipText.width + 36
            height: 48
            radius: 24
            color: ListView.isCurrentItem ? (ListView.view.activeFocus ? "#4da3ff" : "#34407a") : "#232a4a"
            Text { id: chipText; anchors.centerIn: parent; text: modelData.label; color: "#ffffff"; font.pixelSize: 20 }
            MouseArea { anchors.fill: parent; onClicked: chipList.currentIndex = index }
        }
    }

    GridView {
        id: grid
        anchors.top: chipList.visible ? chipList.bottom : bar.bottom
        anchors.topMargin: 14
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        clip: true
        focus: true
        cellWidth: 240
        cellHeight: 350
        model: lib.filtered
        keyNavigationEnabled: true
        delegate: GameCard {
            width: grid.cellWidth
            height: grid.cellHeight
            game: modelData
            focusRing: GridView.isCurrentItem && GridView.view.activeFocus
            onActivated: { grid.currentIndex = index; lib.openGame(modelData) }
        }
        Keys.onReturnPressed: if (currentIndex >= 0 && currentIndex < lib.filtered.length) lib.openGame(lib.filtered[currentIndex])
        Keys.onPressed: function(e) {
            var cols = Math.max(1, Math.floor(width / cellWidth))
            if (e.key === Qt.Key_Up && currentIndex < cols) {
                if (chipList.visible) chipList.forceActiveFocus(); else btnSearch.forceActiveFocus()
                e.accepted = true
            } else if (e.key === Qt.Key_F4 && currentIndex >= 0 && currentIndex < lib.filtered.length) {
                backend.toggleFavorite(lib.filtered[currentIndex].id)    // Y: favorito
                e.accepted = true
            }
        }
        Text {
            visible: lib.filtered.length === 0
            anchors.centerIn: parent
            text: "Nada aqui ainda."
            color: "#8d96b5"
            font.pixelSize: 26
        }
    }
}
