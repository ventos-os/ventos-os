import QtQuick
import QtQuick.Controls.Basic

ApplicationWindow {
    id: win
    visible: true
    width: 900
    height: 620
    title: "Boas-vindas · Ventos OS"
    color: "#0f1220"
    property int page: 0
    property bool dontShow: true

    Rectangle {
        anchors.fill: parent
        anchors.margins: 28
        color: "transparent"

        Text {
            id: ttl
            text: pages[win.page].title
            color: "#4da3ff"
            font.pixelSize: 36
            font.bold: true
        }
        Text {
            anchors.top: ttl.bottom
            anchors.topMargin: 22
            anchors.left: parent.left
            anchors.right: parent.right
            text: pages[win.page].body
            color: "#e8ecf8"
            font.pixelSize: 21
            lineHeight: 1.25
            wrapMode: Text.WordWrap
        }
        Row {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            spacing: 8
            Repeater {
                model: pages.length
                Rectangle { width: 12; height: 12; radius: 6; color: index === win.page ? "#4da3ff" : "#34407a" }
            }
        }
        CheckBox {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Não mostrar de novo"
            checked: win.dontShow
            onToggled: win.dontShow = checked
            contentItem: Text { text: parent.text; color: "#8d96b5"; leftPadding: 34; font.pixelSize: 18; verticalAlignment: Text.AlignVCenter }
        }
        Row {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            spacing: 10
            Button { text: "Abrir o Modo Jogo"; visible: win.page === pages.length - 2; onClicked: welcome.openGameMode() }
            Button { text: "Voltar"; enabled: win.page > 0; onClicked: win.page-- }
            Button {
                text: win.page < pages.length - 1 ? "Próximo" : "Concluir"
                onClicked: { if (win.page < pages.length - 1) win.page++; else welcome.finish(win.dontShow) }
            }
        }
    }
    onClosing: welcome.finish(false)
}
