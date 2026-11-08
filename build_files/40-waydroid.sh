#!/usr/bin/env bash
# waydroid_script (tradução ARM): código em /usr (somente leitura) + venv com dependências
set -euo pipefail
REF="${WAYDROID_SCRIPT_REF:-main}"

git clone https://github.com/casualsnek/waydroid_script /usr/share/waydroid_script
git -C /usr/share/waydroid_script checkout "$REF"
rm -rf /usr/share/waydroid_script/.git

python3 -m venv --system-site-packages /usr/lib/waydroid-extras-venv
grep -vi '^dbus-python' /usr/share/waydroid_script/requirements.txt > /tmp/req.txt
/usr/lib/waydroid-extras-venv/bin/pip install --no-cache-dir -r /tmp/req.txt
