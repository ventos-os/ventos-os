import QtQuick
import QtQuick.Controls.Basic

// Formulário navegável por controle: linhas de texto, escolha, caminho, tags, liga/desliga e botões.
// rows: [{k, label, t: text|choice|bool|path|dir|tags|button, opts, labels}]
FocusScope {
    id: fv
    property var rows: []
    property var values: ({})
    signal valueChanged2(string key, var value)
    signal editText(string key, string label)
    signal pick(string key, string type)
    signal editTags(string key)
    signal pressed(string key)

    property alias list: list

    function display(row) {
        var v = values[row.k]
        if (row.t === "bool") return v ? "Ligado" : "Desligado"
        if (row.t === "tags") return (v && v.length) ? v.join(", ") : "—"
        if (row.t === "choice") return (row.labels && row.labels[v]) ? row.labels[v] : (v === undefined ? "—" : String(v))
        return (v === undefined || v === "") ? "—" : String(v)
    }
    function cycle(row, dir) {
        var o = row.opts
        if (!o || o.length === 0) return
        var i = o.indexOf(values[row.k])
        i = (i + dir + o.length) % o.length
        valueChanged2(row.k, o[i])
    }
    function activate(row) {
        if (row.t === "text") editText(row.k, row.label)
        else if (row.t === "path" || row.t === "dir") editText(row.k, row.label)
        else if (row.t === "choice") cycle(row, 1)
        else if (row.t === "bool") valueChanged2(row.k, !values[row.k])
        else if (row.t === "tags") editTags(row.k)
        else if (row.t === "button") pressed(row.k)
    }

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        model: fv.rows
        spacing: 8
        focus: true
        keyNavigationEnabled: true
        highlightMoveDuration: 80

        delegate: Rectangle {
            property var row: modelData
            width: list.width
            height: 70
            radius: 10
            color: row.t === "button"
                   ? (ListView.isCurrentItem && list.activeFocus ? "#4da3ff" : "#2f3868")
                   : (ListView.isCurrentItem && list.activeFocus ? "#34407a" : "#232a4a")
            border.width: ListView.isCurrentItem && list.activeFocus ? 2 : 0
            border.color: "#4da3ff"

            Text {
                visible: row.t === "button"
                anchors.centerIn: parent
                text: row.label
                color: "#ffffff"
                font.pixelSize: 26
                font.bold: true
            }
            Text {
                visible: row.t !== "button"
                x: 20
                width: 430
                anchors.verticalCenter: parent.verticalCenter
                text: row.label
                color: "#8d96b5"
                font.pixelSize: 22
                elide: Text.ElideRight
            }
            Text {
                visible: row.t !== "button"
                x: 470
                width: parent.width - 470 - ((row.t === "path" || row.t === "dir") ? 110 : 20)
                anchors.verticalCenter: parent.verticalCenter
                text: (row.t === "choice" ? "◀  " : "") + fv.display(row) + (row.t === "choice" ? "  ▶" : "")
                color: "#e8ecf8"
                font.pixelSize: 24
                elide: Text.ElideMiddle
            }
            Rectangle {
                visible: row.t === "path" || row.t === "dir"
                width: 90
                height: 46
                radius: 8
                color: "#4da3ff"
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                Text { anchors.centerIn: parent; text: "Procurar"; color: "#ffffff"; font.pixelSize: 18 }
                MouseArea { anchors.fill: parent; onClicked: fv.pick(row.k, row.t) }
            }
            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: { list.currentIndex = index; fv.activate(row) }
            }
        }

        Keys.onReturnPressed: if (currentIndex >= 0) fv.activate(fv.rows[currentIndex])
        Keys.onEnterPressed: if (currentIndex >= 0) fv.activate(fv.rows[currentIndex])
        Keys.onLeftPressed: if (currentIndex >= 0 && fv.rows[currentIndex].t === "choice") fv.cycle(fv.rows[currentIndex], -1)
        Keys.onRightPressed: if (currentIndex >= 0 && fv.rows[currentIndex].t === "choice") fv.cycle(fv.rows[currentIndex], 1)
        Keys.onPressed: function(e) {      // X / F3: procurar arquivo ou pasta
            if (e.key === Qt.Key_F3 && currentIndex >= 0) {
                var r = fv.rows[currentIndex]
                if (r.t === "path" || r.t === "dir") { fv.pick(r.k, r.t); e.accepted = true }
            }
        }
    }
}
