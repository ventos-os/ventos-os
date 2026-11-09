import QtQuick

FocusScope {
    id: sp
    readonly property var rows: [
        { k: "priority_enabled", label: "Prioridade de jogo (padrão)", t: "bool" },
        { k: "pr_gamemode", label: "GameMode (governador de CPU e prioridade)", t: "bool" },
        { k: "pr_mangohud", label: "MangoHud (contador de FPS)", t: "bool" },
        { k: "pr_power", label: "Perfil de energia “Desempenho”", t: "bool" },
        { k: "pr_dnd", label: "Silenciar notificações do KDE durante o jogo", t: "bool" },
        { k: "switch2_emulator", label: "Emulador de Switch 2", t: "choice", opts: ["lichii", "eglantine"] },
        { k: "fullscreen", label: "Iniciar em tela cheia", t: "bool" },
        { k: "show_hidden", label: "Mostrar jogos ocultos", t: "bool" },
        { k: "__refresh", label: "Atualizar bibliotecas agora", t: "button" },
        { k: "__quit", label: "Sair do Modo Jogo", t: "button" }
    ]
    Component.onCompleted: form.forceActiveFocus()

    Column {
        anchors.fill: parent
        spacing: 12
        Text { text: "Configurações"; color: "#e8ecf8"; font.pixelSize: 34; font.bold: true }
        FormView {
            id: form
            width: parent.width
            height: parent.height - 60
            rows: sp.rows
            values: backend.settings
            focus: true
            onValueChanged2: function(key, value) { backend.setSetting(key, value) }
            onPressed: function(key) {
                if (key === "__refresh") { backend.refresh(); backend.notify("Atualizando bibliotecas…") }
                else if (key === "__quit") backend.quit()
            }
        }
    }
}
