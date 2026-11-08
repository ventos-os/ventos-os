# Ventos OS

Imagem imutável baseada em **Fedora Kinoite (KDE Plasma)** via **Universal Blue**.

## Build

```bash
podman build -t ventos-os .                                   # AMD / Intel
podman build -t ventos-os-nvidia \
  --build-arg BASE_IMAGE=ghcr.io/ublue-os/kinoite-nvidia .    # Nvidia
```

Instalar em um Kinoite já rodando:

```bash
rpm-ostree rebase ostree-unverified-registry:ghcr.io/SEU_USUARIO/ventos-os:latest
systemctl reboot
```

## Estrutura

- `Containerfile`: orquestra os passos.
- `build_files/`: scripts executados no build (repos, codecs, pacotes, Waydroid, /opt, serviços).
- `system_files/`: tudo o que é copiado para `/` (scripts, units systemd, .desktop, MIME, configs).
- `.github/workflows/build.yml`: build automático + ISO.

## Primeiro boot / primeiro login

| Quando | Serviço | O que faz |
|---|---|---|
| boot (sistema) | `flatpak-preinstall` | Steam, Heroic, Lutris, Chiaki-ng, Discord, Bottles, ProtonUp-Qt, Eden, Ryubing, RPCS3 |
| boot (sistema) | `waydroid-firstboot` | Android com GApps + tradução ARM |
| boot (sistema) | `emulators-firstboot` | `switch2-fetch --system all`, `shadps4-update --system` |
| login (usuário) | `emulators-firstrun` | Xenia Canary + prefixo Proton, firmware do PS3 |
| login (usuário) | `defaults-firstrun` | Proton no Steam, atalho do Valorant, aviso do Chiaki-ng |
| semanal | `emulators-update.timer`, `xenia-update.timer` | atualizam emuladores baixados do GitHub |

Logs: `journalctl -u flatpak-preinstall -u waydroid-firstboot -u emulators-firstboot`.

## Configuração

`/etc/emulators.conf`, `/etc/ventos-longes.conf`, `/etc/switch-open.conf`, `/etc/bottles-open.conf`
(cada um pode ser sobrescrito em `~/.config/`).

## Não vem na imagem (por escolha ou por não ser possível)

Chaves e firmware do Switch, jogos, firmware do PS3 (vem da Sony, ou do arquivo que você baixar),
conta PSN/registro do PS5, logins de Epic/GOG/Steam/Discord.
