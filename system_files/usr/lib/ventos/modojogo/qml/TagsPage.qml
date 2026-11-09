import QtQuick
import QtQuick.Controls.Basic

FocusScope {
    id: tp
    property var osk
    property string confirm: ""
    signal openTag(string tag)

    function countOf(tag) {
        var n = 0
        var g = backend.games
        for (var i = 0; i < g.length; i++) if (g[i].tags.indexOf(tag) >= 0) n++
        return n
    }
    function rename(tag) {
        osk.show("Renomear tag", tag, function(v) {
            if (!backend.renameTag(tag, v)) backend.notify("Nome inválido ou já existe.")
        })
    }
    function remove(tag) {
        if (confirm === tag) { backend.deleteTag(tag); confirm = "" }
        else { confirm = tag; backend.notify("Pressione de novo para excluir a tag “" + tag + "”.") }
    }
    Component.onCompleted: list.forceActiveFocus()

    Column {
        anchors.fill: parent
        spacing: 12
        Row {
            spacing: 16
            Text { text: "Tags"; color: "#e8ecf8"; font.pixelSize: 34; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
            GButton {
                id: btnNew
                text: "Nova tag"
                KeyNavigation.down: list
                onClicked: tp.osk.show("Nome da nova tag", "", function(v) {
                    if (!backend.addTag(v)) backend.notify("Nome inválido ou já existe.")
                })
            }
        }
        ListView {
            id: list
            width: parent.width
            height: parent.height - 90
            clip: true
            spacing: 8
            model: backend.tags
            focus: true
            keyNavigationEnabled: true
            delegate: Rectangle {
                width: list.width
                height: 64
                radius: 10
                color: ListView.isCurrentItem && list.activeFocus ? "#34407a" : "#232a4a"
                border.width: ListView.isCurrentItem && list.activeFocus ? 2 : 0
                border.color: "#4da3ff"
                Text { x: 20; anchors.verticalCenter: parent.verticalCenter; text: modelData; color: "#ffffff"; font.pixelSize: 26 }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    text: tp.countOf(modelData) + " jogo(s)" + (tp.confirm === modelData ? "   · Y de novo: excluir" : "")
                    color: tp.confirm === modelData ? "#ff7a7a" : "#8d96b5"
                    font.pixelSize: 20
                }
                MouseArea { anchors.fill: parent; onClicked: { list.currentIndex = index; tp.openTag(modelData) } }
            }
            Keys.onReturnPressed: if (currentIndex >= 0) tp.openTag(backend.tags[currentIndex])
            Keys.onUpPressed: { if (currentIndex <= 0) btnNew.forceActiveFocus(); else decrementCurrentIndex() }
            Keys.onPressed: function(e) {
                if (currentIndex < 0) return
                if (e.key === Qt.Key_F3) { tp.rename(backend.tags[currentIndex]); e.accepted = true }       // X: renomear
                else if (e.key === Qt.Key_F4) { tp.remove(backend.tags[currentIndex]); e.accepted = true }  // Y: excluir
            }
        }
        Text { text: "A abre · X renomear · Y excluir (duas vezes)"; color: "#8d96b5"; font.pixelSize: 18 }
    }
}
