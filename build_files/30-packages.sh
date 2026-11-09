#!/usr/bin/env bash
set -euo pipefail

try_install() {   # opcionais: avisa e segue se o pacote não existir nesta versão do Fedora
    for p in "$@"; do
        rpm -q "$p" >/dev/null 2>&1 && continue
        rpm-ostree install "$p" || echo "AVISO: não consegui instalar $p (seguindo)" >&2
    done
}

# Java: "latest" = versão estável mais recente do Fedora (para o LTS use java-25-openjdk-devel)
JAVA_PKG="java-latest-openjdk-devel"

# --- obrigatórios (se algum faltar, o build falha de forma visível) ---
rpm-ostree install \
    python3 python3-pip python3-devel python3-pyyaml \
    git git-lfs \
    "${JAVA_PKG}" \
    google-chrome-stable \
    brave-browser \
    torbrowser-launcher \
    umu-launcher \
    waydroid lzip wl-clipboard python3-dbus python3-gobject \
    unzip jq curl libnotify xdg-user-dirs xdg-utils \
    python3-pyside6 \
    gamescope gamemode mangohud cage \
    plasma-systemmonitor

# --- opcionais ---
try_install python3-pysdl2 SDL2 plasma-keyboard kdialog power-profiles-daemon

rpm-ostree cleanup -m
