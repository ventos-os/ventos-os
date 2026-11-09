import QtQuick
import QtQuick.Controls.Basic

// Teclado virtual para controle (e campo de texto para teclado físico): uma só tela para digitar qualquer valor.
Popup {
    id: osk
    property string title: ""
    property string value: ""
    property var callback: null
    property int row: 1
    property int col: 0
    property bool shift: false
    readonly property var rows: [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "_"],
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "/", "."],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l", ":", "~", "\\"],
        ["z", "x", "c", "v", "b", "n", "m", ",", "@", "=", "+", "?"],
        ["SHIFT", "ESPAÇO", "APAGAR", "LIMPAR", "OK", "CANCELAR"]
    ]

    modal: true
    dim: true
    focus: true
    closePolicy: Popup.CloseOnEscape
    anchors.centerIn: Overlay.overlay
    width: Math.min(Overlay.overlay ? Overlay.overlay.width - 60 : 1000, 1100)
    height: 640
    padding: 24

    function show(t, initial, cb) {
        title = t
        value = initial === undefined ? "" : String(initial)
        callback = cb
        row = 1
        col = 0
        shift = false
        open()
    }
    function commit() {
        var cb = callback
        var v = value
        close()
        if (cb) cb(v)
    }
    function move(dr, dc) {
        row = Math.max(0, Math.min(rows.length - 1, row + dr))
        col = Math.max(0, Math.min(rows[row].length - 1, col + dc))
    }
    function pressKey() {
        var k = rows[row][col]
        if (k === "SHIFT") shift = !shift
        else if (k === "ESPAÇO") value += " "
        else if (k === "APAGAR") value = value.slice(0, -1)
        else if (k === "LIMPAR") value = ""
        else if (k === "OK") commit()
        else if (k === "CANCELAR") close()
        else value += shift ? k.toUpperCase() : k
    }

    onOpened: kbd.forceActiveFocus()

    background: Rectangle {
        radius: 18
        color: "#1a1f36"
        border.color: "#4da3ff"
        border.width: 2
    }

    contentItem: FocusScope {
        id: kbd
        Keys.onPressed: function(e) {
            if (e.key === Qt.Key_Up) { osk.move(-1, 0); e.accepted = true }
            else if (e.key === Qt.Key_Down) { osk.move(1, 0); e.accepted = true }
            else if (e.key === Qt.Key_Left) { osk.move(0, -1); e.accepted = true }
            else if (e.key === Qt.Key_Right) { osk.move(0, 1); e.accepted = true }
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                if (backend.inputMode === "gamepad") osk.pressKey(); else osk.commit()
                e.accepted = true
            }
            else if (e.key === Qt.Key_F1) { osk.commit(); e.accepted = true }
            else if (e.key === Qt.Key_F3) { osk.value = osk.value.slice(0, -1); e.accepted = true }
            else if (e.key === Qt.Key_F4) { osk.value += " "; e.accepted = true }
            else if (e.key === Qt.Key_Backspace) { osk.value = osk.value.slice(0, -1); e.accepted = true }
            else if (e.text.length === 1 && e.text >= " " && !(e.modifiers & Qt.ControlModifier)) {
                osk.value += e.text
                e.accepted = true
            }
        }

        Column {
            anchors.fill: parent
            spacing: 14
            Text { text: osk.title; color: "#8d96b5"; font.pixelSize: 24 }
            Rectangle {
                width: parent.width
                height: 70
                radius: 10
                color: "#0f1220"
                border.color: "#4da3ff"
                Text {
                    anchors.fill: parent
                    anchors.margins: 14
                    text: osk.value + "▏"
                    color: "#e8ecf8"
                    font.pixelSize: 28
                    elide: Text.ElideLeft
                    verticalAlignment: Text.AlignVCenter
                }
            }
            Repeater {
                model: osk.rows
                delegate: Row {
                    id: kr
                    property int r: index
                    spacing: 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    Repeater {
                        model: modelData
                        delegate: Rectangle {
                            property bool cur: kr.r === osk.row && index === osk.col
                            width: modelData.length > 1 ? 150 : 70
                            height: 64
                            radius: 10
                            color: cur ? "#4da3ff" : "#232a4a"
                            Text {
                                anchors.centerIn: parent
                                text: modelData.length > 1 ? modelData : (osk.shift ? modelData.toUpperCase() : modelData)
                                color: "#ffffff"
                                font.pixelSize: modelData.length > 1 ? 20 : 28
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: { osk.row = kr.r; osk.col = index; osk.pressKey() }
                            }
                        }
                    }
                }
            }
            Text {
                text: backend.inputMode === "gamepad"
                      ? "A digita · B fecha · X apaga · Y espaço · Start confirma"
                      : "Digite no teclado · Enter confirma · Esc cancela"
                color: "#8d96b5"
                font.pixelSize: 20
            }
        }
    }
}
