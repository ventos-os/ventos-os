#!/usr/bin/env bash
# Codecs multimídia completos (RPM Fusion). Idempotente: imagens Universal Blue
# já trazem parte disso, então cada passo só age se for necessário.
set -euo pipefail

try_install() {   # extras opcionais: avisa e segue se algum pacote não existir nesta versão do Fedora
    for p in "$@"; do
        rpm -q "$p" >/dev/null 2>&1 && continue
        rpm-ostree install "$p" || echo "AVISO: não consegui instalar $p (seguindo)" >&2
    done
}

swap_freeworld() {   # $1 = pacote do Mesa, $2 = versão "freeworld" (H.264/H.265 por hardware)
    if rpm -q "$1" >/dev/null 2>&1 && ! rpm -q "$2" >/dev/null 2>&1; then
        rpm-ostree override remove "$1" --install="$2" \
            || echo "AVISO: não consegui trocar $1 por $2 (seguindo)" >&2
    fi
}

# 1) ffmpeg completo no lugar das bibliotecas "-free"
if ! rpm -q ffmpeg >/dev/null 2>&1; then
    mapfile -t FREE < <(rpm -qa --qf '%{NAME}\n' \
        | grep -E '^(libavcodec|libavfilter|libavformat|libavutil|libpostproc|libswresample|libswscale)-free$' \
        | sort -u || true)
    if [ "${#FREE[@]}" -gt 0 ]; then
        rpm-ostree override remove "${FREE[@]}" --install=ffmpeg
    else
        rpm-ostree install ffmpeg
    fi
fi

# 2) Decodificação por hardware (AMD/Intel) com codecs completos
swap_freeworld mesa-va-drivers    mesa-va-drivers-freeworld
swap_freeworld mesa-vdpau-drivers mesa-vdpau-drivers-freeworld

# 3) GStreamer (usado pelo KDE e por muitos apps)
try_install gstreamer1-plugin-libav gstreamer1-plugins-bad-freeworld \
            gstreamer1-plugins-ugly gstreamer1-vaapi libva-utils

rpm-ostree cleanup -m
