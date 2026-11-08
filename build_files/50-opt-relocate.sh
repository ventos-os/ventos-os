#!/usr/bin/env bash
# /opt aponta para /var/opt, que NÃO faz parte da imagem. O que o RPM instalou lá
# (Chrome, Brave) é movido para /usr/lib/opt e religado a cada boot via tmpfiles.
set -euo pipefail

[ -d /var/opt ] || exit 0
mkdir -p /usr/lib/opt /usr/lib/tmpfiles.d
: > /usr/lib/tmpfiles.d/ventos-opt.conf

for d in /var/opt/*; do
    [ -e "$d" ] || continue
    name="$(basename "$d")"
    mv "$d" "/usr/lib/opt/$name"
    echo "L+ /var/opt/$name - - - - /usr/lib/opt/$name" >> /usr/lib/tmpfiles.d/ventos-opt.conf
done
cat /usr/lib/tmpfiles.d/ventos-opt.conf
