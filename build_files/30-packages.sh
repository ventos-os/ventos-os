#!/usr/bin/env bash
set -euo pipefail

# Java: "latest" = versão estável mais recente do Fedora (para o LTS use java-25-openjdk-devel)
JAVA_PKG="java-latest-openjdk-devel"

rpm-ostree install \
    python3 python3-pip python3-devel \
    git git-lfs \
    "${JAVA_PKG}" \
    google-chrome-stable \
    brave-browser \
    torbrowser-launcher \
    umu-launcher \
    waydroid lzip wl-clipboard python3-dbus python3-gobject \
    unzip jq curl libnotify xdg-user-dirs xdg-utils

rpm-ostree cleanup -m
