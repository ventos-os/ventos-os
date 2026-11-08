# syntax=docker/dockerfile:1
# =====================================================================
# Ventos OS: Fedora Kinoite (KDE Plasma) imutável, via Universal Blue
#
#   AMD / Intel : BASE_IMAGE=ghcr.io/ublue-os/kinoite-main     (padrão)
#   Nvidia      : BASE_IMAGE=ghcr.io/ublue-os/kinoite-nvidia
#
#   podman build -t ventos-os .
#   podman build -t ventos-os-nvidia \
#       --build-arg BASE_IMAGE=ghcr.io/ublue-os/kinoite-nvidia .
# =====================================================================
ARG BASE_IMAGE="ghcr.io/ublue-os/kinoite-main"
# "latest" acompanha o Fedora atual; fixe (ex.: 44) para builds reprodutíveis
ARG FEDORA_VERSION="latest"

FROM ${BASE_IMAGE}:${FEDORA_VERSION}

# Fixe um commit validado do waydroid_script para builds reprodutíveis
ARG WAYDROID_SCRIPT_REF="main"

# Scripts, units systemd, .desktop, MIME, repositórios e configs
COPY system_files/ /
COPY build_files/ /tmp/build_files/

# 1. Repositórios de terceiros (Chrome, Brave) e RPM Fusion
RUN bash /tmp/build_files/10-repos.sh

# 2. Codecs multimídia completos (RPM Fusion + ffmpeg + GStreamer)
RUN bash /tmp/build_files/20-codecs.sh

# 3. Pacotes: Python, Git, Java, Chrome, Brave, Tor, Waydroid, umu-launcher...
RUN bash /tmp/build_files/30-packages.sh

# 4. Waydroid: waydroid_script (tradução ARM Houdini/libndk)
RUN WAYDROID_SCRIPT_REF="${WAYDROID_SCRIPT_REF}" bash /tmp/build_files/40-waydroid.sh

# 5. Torna o /opt (Chrome, Brave) compatível com o sistema imutável
RUN bash /tmp/build_files/50-opt-relocate.sh

# 6. Permissões, tipos MIME, associações de arquivo e serviços
RUN bash /tmp/build_files/90-finalize.sh
