# Ventos OS

Imagem imutável baseada em **Fedora Kinoite (KDE Plasma)** via **Universal Blue**, com desktop estilo Windows,
jogos, emuladores, Android (Waydroid), o navegador **Ventos Longes** e o **Modo Jogo**.

## Build

```bash
podman build -t ventos-os .                                   # AMD / Intel
podman build -t ventos-os-nvidia \
  --build-arg BASE_IMAGE=ghcr.io/ublue-os/kinoite-nvidia .    # Nvidia
rpm-ostree rebase ostree-unverified-registry:ghcr.io/SEU_USUARIO/ventos-os:latest   # num Kinoite já instalado
```

## Onde fica cada coisa

| No repositório | Vai para (na imagem) | O que é |
|---|---|---|
| `Containerfile` | n/a | orquestra os passos |
| `build_files/*.sh` | executados no build | repositórios, codecs, pacotes, Waydroid, /opt, padrões do KDE, serviços |
| `system_files/**` | `/` (via `COPY system_files/ /`) | tudo o que está abaixo |
| `system_files/usr/lib/ventos/modojogo/` | `/usr/lib/ventos/modojogo/` | app **Modo Jogo** (Python + Qt/QML) |
| `system_files/usr/lib/ventos/welcome/` | `/usr/lib/ventos/welcome/` | tela de boas-vindas (QML) |
| `system_files/usr/bin/*` | `/usr/bin/*` | comandos (ventos-modojogo, ventos-longes, xenia-open, switch2-fetch...) |
| `system_files/usr/share/wayland-sessions/ventos-modojogo.desktop` | idem | sessão **Modo Jogo** no SDDM |
| `system_files/usr/share/plasma/look-and-feel/org.ventos.desktop/` | idem | layout do Plasma (barra inferior, menu à esquerda...) |
| `system_files/usr/share/applications/*.desktop` | idem | atalhos e associações |
| `system_files/usr/share/mime/packages/consoles.xml` | idem | tipos MIME (.xci, .nsp, .xex, .pkg, eboot.bin) |
| `system_files/etc/xdg/mimeapps.list` | `/etc/xdg/` (e cópia `kde-mimeapps.list`) | associações padrão (Dolphin, Bottles, emuladores, APK) |
| `system_files/etc/xdg/autostart/` | idem | boas-vindas no 1º login; desliga o Plasma Welcome |
| `system_files/etc/gamemode.ini` | idem | ajustes do GameMode |
| `system_files/usr/lib/systemd/{system,user}/` | idem | primeiro boot, timers de atualização |
| `/etc/skel/.config/*` | gerado por `80-desktop-defaults.sh` | atalhos, KRunner, tecla Super (usuários novos) |
| `tests/` | só no repositório | testes do núcleo do Modo Jogo (rodam no CI) |

### GitHub Actions
`.github/workflows/build.yml` faz o build com o repositório inteiro como contexto: `system_files/` e `build_files/`
entram na imagem automaticamente pelo `COPY` do `Containerfile`. Qualquer arquivo novo dentro de `system_files/`
vai junto, sem alterar o workflow. O job `lint` roda antes (bash, Python, XML, testes) e bloqueia o build se falhar.

## Primeiro boot / primeiro login

| Quando | Serviço | O que faz |
|---|---|---|
| boot (sistema) | `flatpak-preinstall` | Steam, Heroic, Lutris, Chiaki-ng, Discord, Bottles, ProtonUp-Qt, Eden, Ryubing, RPCS3 |
| boot (sistema) | `waydroid-firstboot` | Android com GApps + tradução ARM |
| boot (sistema) | `emulators-firstboot` | `switch2-fetch --system all`, `shadps4-update --system` |
| login (usuário) | `emulators-firstrun` | Xenia Canary + prefixo Proton, firmware do PS3 |
| login (usuário) | `defaults-firstrun` | Proton no Steam, ícones na área de trabalho, desktop estilo Windows |
| login (usuário) | `ventos-welcome` (autostart) | tela de boas-vindas |
| semanal | `emulators-update.timer`, `xenia-update.timer` | atualizam emuladores baixados do GitHub |

Logs: `journalctl -u flatpak-preinstall -u waydroid-firstboot -u emulators-firstboot`.

## Atalhos

Super: menu · Super+S / Alt+Espaço: pesquisa (KRunner) · **Super+R**: executar comando · Super+E: Dolphin ·
Super+L: bloquear · Super+D: área de trabalho · Alt+Tab / Super+Tab: janelas · Ctrl+Shift+Esc: Gerenciador de Tarefas.

## Configuração

`/etc/emulators.conf`, `/etc/ventos-longes.conf`, `/etc/switch-open.conf`, `/etc/bottles-open.conf`,
`/etc/ventos-modojogo/gamescope.conf` (cada um pode ser sobrescrito em `~/.config/`).

## Não vem na imagem (por escolha ou por não ser possível)

Chaves e firmware do Switch, jogos, firmware do PS3 (vem da Sony, ou do arquivo que você baixar), conta PSN/registro do PS5,
logins de Epic/GOG/Steam/Discord, o instalador do VALORANT (o Vanguard não funciona no Linux).
