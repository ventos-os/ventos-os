import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic

ApplicationWindow {
    id: win
    visible: true
    width: 1280
    height: 720
    title: "Modo Jogo"
    color: "#0f1220"
    visibility: backend.fullscreen ? Window.FullScreen : Window.Windowed

    function openLibrary(mode, arg) {
        stack.push(libPage, { mode: mode, arg: arg === undefined ? "" : arg })
    }
    function openGame(g) { detail.show(g) }

    // ---------------------------------------------------------------- cabeçalho
    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 28
        height: 64
        Text {
            text: "MODO JOGO"
            color: "#4da3ff"
            font.pixelSize: 30
            font.bold: true
            font.letterSpacing: 4
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            id: clock
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            color: "#e8ecf8"
            font.pixelSize: 28
            text: Qt.formatTime(new Date(), "hh:mm")
        }
        Timer { interval: 15000; running: true; repeat: true; onTriggered: clock.text = Qt.formatTime(new Date(), "hh:mm") }
        Rectangle {
            visible: backend.playing !== ""
            anchors.centerIn: parent
            width: playingText.width + 40
            height: 44
            radius: 22
            color: "#2a6f3d"
            Text {
                id: playingText
                anchors.centerIn: parent
                text: "Jogando: " + backend.playing + "   ·   Start encerra a prioridade"
                color: "#ffffff"
                font.pixelSize: 20
            }
        }
    }

    // ---------------------------------------------------------------- conteúdo
    FocusScope {
        id: root
        anchors.top: header.bottom
        anchors.bottom: footer.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 28
        anchors.rightMargin: 28
        anchors.topMargin: 8
        focus: true

        StackView {
            id: stack
            anchors.fill: parent
            focus: true
            initialItem: homePage
            onCurrentItemChanged: if (currentItem) currentItem.forceActiveFocus()
        }

        Keys.onPressed: function(e) {
            if (e.key === Qt.Key_Escape && stack.depth > 1) { stack.pop(); e.accepted = true }
            else if (e.key === Qt.Key_F1) {                                  // Start
                if (backend.playing !== "") backend.endSession(); else menu.open()
                e.accepted = true
            }
            else if (e.key === Qt.Key_F2) { stack.push(settingsPage); e.accepted = true }   // Select
        }
    }

    Component {
        id: homePage
        Home {
            onOpenLibrary: function(mode) { win.openLibrary(mode) }
            onOpenGame: function(game) { win.openGame(game) }
            onOpenTags: stack.push(tagsPage)
            onOpenSettings: stack.push(settingsPage)
        }
    }
    Component {
        id: libPage
        Library {
            osk: oskDlg
            onOpenGame: function(game) { win.openGame(game) }
            onAddGame: editor.show("")
        }
    }
    Component {
        id: tagsPage
        TagsPage {
            osk: oskDlg
            onOpenTag: function(tag) { win.openLibrary("tag", tag) }
        }
    }
    Component { id: settingsPage; SettingsPage {} }

    // ---------------------------------------------------------------- rodapé com dicas
    Rectangle {
        id: footer
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 56
        color: "#0a0d18"
        Text {
            anchors.centerIn: parent
            color: "#8d96b5"
            font.pixelSize: 20
            text: backend.inputMode === "gamepad"
                  ? "A Selecionar    B Voltar    X Mods / Procurar    Y Favorito    Start Menu    Select Config"
                  : "Enter Selecionar    Esc Voltar    F3 Mods / Procurar    F4 Favorito    F1 Menu    F2 Config"
        }
    }

    // ---------------------------------------------------------------- diálogos
    OSK { id: oskDlg }
    TagPicker { id: tagDlg }
    GameDetail {
        id: detail
        tagPicker: tagDlg
        onEditRequested: function(gid) { editor.show(gid) }
        onModsRequested: function(game) { mods.show(game) }
    }
    GameEditor { id: editor; osk: oskDlg; tagPicker: tagDlg }
    ModsDialog { id: mods; osk: oskDlg }

    Popup {
        id: menu
        modal: true
        dim: true
        focus: true
        closePolicy: Popup.CloseOnEscape
        anchors.centerIn: Overlay.overlay
        width: 560
        height: 400
        padding: 24
        readonly property var items: [
            { id: "refresh", label: "Atualizar bibliotecas" },
            { id: "settings", label: "Configurações" },
            { id: "end", label: "Encerrar prioridade de jogo" },
            { id: "quit", label: "Sair do Modo Jogo" }
        ]
        onOpened: menuList.forceActiveFocus()
        function run(id) {
            close()
            if (id === "refresh") { backend.refresh(); backend.notify("Atualizando bibliotecas…") }
            else if (id === "settings") stack.push(settingsPage)
            else if (id === "end") backend.endSession()
            else if (id === "quit") backend.quit()
        }
        background: Rectangle { radius: 18; color: "#1a1f36"; border.color: "#4da3ff"; border.width: 2 }
        contentItem: ListView {
            id: menuList
            spacing: 8
            model: menu.items
            focus: true
            keyNavigationEnabled: true
            delegate: Rectangle {
                width: menuList.width
                height: 64
                radius: 10
                color: ListView.isCurrentItem && menuList.activeFocus ? "#4da3ff" : "#232a4a"
                Text { x: 20; anchors.verticalCenter: parent.verticalCenter; text: modelData.label; color: "#ffffff"; font.pixelSize: 26 }
                MouseArea { anchors.fill: parent; onClicked: menu.run(modelData.id) }
            }
            Keys.onReturnPressed: if (currentIndex >= 0) menu.run(menu.items[currentIndex].id)
        }
    }

    // ---------------------------------------------------------------- aviso temporário
    Rectangle {
        id: toast
        opacity: 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: footer.top
        anchors.bottomMargin: 16
        width: toastText.width + 48
        height: 52
        radius: 26
        color: "#34407a"
        z: 100
        Text { id: toastText; anchors.centerIn: parent; color: "#ffffff"; font.pixelSize: 22 }
        SequentialAnimation {
            id: toastAnim
            NumberAnimation { target: toast; property: "opacity"; to: 1; duration: 150 }
            PauseAnimation { duration: 2800 }
            NumberAnimation { target: toast; property: "opacity"; to: 0; duration: 400 }
        }
    }
    Connections {
        target: backend
        function onToast(message) { toastText.text = message; toastAnim.restart() }
    }
}
