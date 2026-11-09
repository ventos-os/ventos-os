import QtQuick
import QtQuick.Controls.Basic

Popup {
    id: tp
    property var selected: []
    property var callback: null
    modal: true
    dim: true
    focus: true
    closePolicy: Popup.CloseOnEscape
    anchors.centerIn: Overlay.overlay
    width: 720
    height: Math.min(Overlay.overlay ? Overlay.overlay.height - 80 : 700, 760)
    padding: 24

    function show(current, cb) {
        selected = current ? current.slice() : []
        callback = cb
        open()
    }
    function toggle(tag) {
        var i = selected.indexOf(tag)
        var s = selected.slice()
        if (i >= 0) s.splice(i, 1); else s.push(tag)
        selected = s
    }
    function finish() {
        var cb = callback
        var s = selected
        close()
        if (cb) cb(s)
    }
    onOpened: list.forceActiveFocus()

    background: Rectangle { radius: 18; color: "#1a1f36"; border.color: "#4da3ff"; border.width: 2 }

    contentItem: Column {
        spacing: 12
        Text { text: "Tags do jogo"; color: "#e8ecf8"; font.pixelSize: 30; font.bold: true }
        ListView {
            id: list
            width: parent.width
            height: parent.height - 120
            clip: true
            model: backend.tags
            keyNavigationEnabled: true
            focus: true
            highlightMoveDuration: 80
            delegate: Rectangle {
                width: list.width
                height: 58
                radius: 10
                color: ListView.isCurrentItem && list.activeFocus ? "#4da3ff" : "#232a4a"
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 18
                    text: (tp.selected.indexOf(modelData) >= 0 ? "☑  " : "☐  ") + modelData
                    color: "#ffffff"
                    font.pixelSize: 24
                }
                MouseArea { anchors.fill: parent; onClicked: { list.currentIndex = index; tp.toggle(modelData) } }
            }
            Keys.onReturnPressed: if (currentIndex >= 0) tp.toggle(backend.tags[currentIndex])
            Keys.onEnterPressed: if (currentIndex >= 0) tp.toggle(backend.tags[currentIndex])
            Keys.onPressed: function(e) { if (e.key === Qt.Key_F1) { tp.finish(); e.accepted = true } }
        }
        GButton { text: "Concluir (Start)"; onClicked: tp.finish() }
    }
}
