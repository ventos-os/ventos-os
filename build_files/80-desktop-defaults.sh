#!/usr/bin/env bash
# Desktop estilo Windows: grava os padrões em /etc/skel (usuários novos já nascem configurados)
set -euo pipefail

chmod +x /usr/bin/ventos-*
python3 -m compileall -q /usr/lib/ventos                 # bytecode pré-compilado do Modo Jogo
mkdir -p /etc/skel/.config
VENTOS_CFG_DIR=/etc/skel/.config bash /usr/bin/ventos-desktop-setup
ls -la /etc/skel/.config
