import QtQuick
import QtQuick.Controls.Basic

FocusScope {
    id: home
    signal openLibrary(string mode)
    signal openGame(var game)
    signal openTags()
    signal openSettings()

    property var recent: backend.games
        .filter(function(g) { return g.lastPlayed > 0 })
        .sort(function(a, b) { return b.lastPlayed - a.lastPlayed })
        .slice(0, 12)
    property var favs: backend.games.filter(function(g) { return g.favorite })
    readonly property var tiles: [
        { label: "Todas as bibliotecas", action: "all" },
        { label: "Favoritos", action: "favorites" },
        { label: "Tags", action: "tags" },
        { label: "Emuladores", action: "emulators" },
        { label: "Android", action: "android" },
        { label: "Configurações", action: "settings" }
    ]
    property var order: [recentList, favList, tileList]

    function move(from, dir) {
        var i = order.indexOf(from) + dir
        while (i >= 0 && i < order.length) {
            var l = order[i]
            if (l.visible && l.count > 0) { l.forceActiveFocus(); return }
            i += dir
        }
    }
    function reveal(item) {
        flick.contentY = Math.max(0, Math.min(item.y - 10, Math.max(0, flick.contentHeight - flick.height)))
    }
    function tileAction(a) {
        if (a === "tags") openTags()
        else if (a === "settings") openSettings()
        else openLibrary(a)
    }
    Component.onCompleted: tileList.forceActiveFocus()

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: col.height
        clip: true
        interactive: false

        Column {
            id: col
            width: flick.width
            spacing: 18

            Item {
                id: recentSec
                width: parent.width
                height: visible ? 330 : 0
                visible: home.recent.length > 0
                Text { text: "Jogos recentes"; color: "#e8ecf8"; font.pixelSize: 30; font.bold: true }
                ListView {
                    id: recentList
                    y: 44
                    width: parent.width
                    height: 280
                    orientation: ListView.Horizontal
                    model: home.recent
                    spacing: 8
                    clip: true
                    keyNavigationEnabled: true
                    onActiveFocusChanged: if (activeFocus) home.reveal(recentSec)
                    delegate: GameCard {
                        width: 190
                        height: 280
                        game: modelData
                        focusRing: ListView.isCurrentItem && ListView.view.activeFocus
                        onActivated: home.openGame(modelData)
                    }
                    Keys.onReturnPressed: if (currentIndex >= 0) home.openGame(home.recent[currentIndex])
                    Keys.onUpPressed: home.move(recentList, -1)
                    Keys.onDownPressed: home.move(recentList, 1)
                }
            }

            Item {
                id: favSec
                width: parent.width
                height: visible ? 330 : 0
                visible: home.favs.length > 0
                Text { text: "Favoritos"; color: "#e8ecf8"; font.pixelSize: 30; font.bold: true }
                ListView {
                    id: favList
                    y: 44
                    width: parent.width
                    height: 280
                    orientation: ListView.Horizontal
                    model: home.favs
                    spacing: 8
                    clip: true
                    keyNavigationEnabled: true
                    onActiveFocusChanged: if (activeFocus) home.reveal(favSec)
                    delegate: GameCard {
                        width: 190
                        height: 280
                        game: modelData
                        focusRing: ListView.isCurrentItem && ListView.view.activeFocus
                        onActivated: home.openGame(modelData)
                    }
                    Keys.onReturnPressed: if (currentIndex >= 0) home.openGame(home.favs[currentIndex])
                    Keys.onUpPressed: home.move(favList, -1)
                    Keys.onDownPressed: home.move(favList, 1)
                }
            }

            Item {
                id: tileSec
                width: parent.width
                height: 200
                Text { text: "Explorar"; color: "#e8ecf8"; font.pixelSize: 30; font.bold: true }
                ListView {
                    id: tileList
                    y: 44
                    width: parent.width
                    height: 140
                    orientation: ListView.Horizontal
                    model: home.tiles
                    spacing: 14
                    clip: true
                    keyNavigationEnabled: true
                    onActiveFocusChanged: if (activeFocus) home.reveal(tileSec)
                    delegate: Rectangle {
                        width: 270
                        height: 130
                        radius: 16
                        color: ListView.isCurrentItem && ListView.view.activeFocus ? "#4da3ff" : "#232a4a"
                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: "#ffffff"
                            font.pixelSize: 28
                            font.bold: true
                        }
                        MouseArea { anchors.fill: parent; onClicked: home.tileAction(modelData.action) }
                    }
                    Keys.onReturnPressed: if (currentIndex >= 0) home.tileAction(home.tiles[currentIndex].action)
                    Keys.onUpPressed: home.move(tileList, -1)
                    Keys.onDownPressed: home.move(tileList, 1)
                }
            }
            Text {
                visible: backend.games.length === 0
                width: parent.width
                text: "Nenhum jogo encontrado ainda. Abra “Todas as bibliotecas” e use Adicionar, ou instale jogos na Steam, Heroic, Lutris ou Bottles."
                color: "#8d96b5"
                font.pixelSize: 22
                wrapMode: Text.WordWrap
            }
        }
    }
}
