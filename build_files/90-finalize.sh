#!/usr/bin/env bash
set -euo pipefail

# --- Permissões dos nossos executáveis ---
for f in bottles-open switch-open switch2-fetch xenia-setup xenia-open xenia-content \
         rpcs3-setup ps-pkg-open shadps4-update shadps4-open apk-open emulators-firstrun \
         waydroid-extras ventos-longes defaults-firstrun valorant-installer; do
    chmod 0755 "/usr/bin/$f"
done
chmod 0755 /usr/libexec/waydroid-firstboot /usr/libexec/flatpak-preinstall

# --- Tipos MIME e desktop files ---
update-mime-database /usr/share/mime
update-desktop-database /usr/share/applications || true

# --- KDE lê kde-mimeapps.list além do mimeapps.list ---
cp /etc/xdg/mimeapps.list /etc/xdg/kde-mimeapps.list

# --- Serviços de sistema ---
systemctl enable \
    flatpak-setup-flathub.service \
    flatpak-preinstall.service \
    waydroid-container.service \
    waydroid-firstboot.service \
    emulators-firstboot.service \
    emulators-update.timer

# --- Serviços de usuário (todos os usuários) ---
systemctl --global enable \
    waydroid-session.service \
    emulators-firstrun.service \
    defaults-firstrun.service \
    rpcs3-firmware.path \
    xenia-update.timer

# --- Limpeza e commit ---
rm -rf /tmp/* /var/tmp/* /var/cache/* 2>/dev/null || true
ostree container commit
