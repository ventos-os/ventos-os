notify() {
    echo "$(basename "$0"): $1 ${2:-}" >&2
    command -v notify-send >/dev/null 2>&1 && notify-send -a "Ventos OS" "$1" "${2:-}" || true
}
load_conf() {
    [ -f /etc/emulators.conf ] && . /etc/emulators.conf
    local u="${XDG_CONFIG_HOME:-$HOME/.config}/emulators.conf"
    [ -f "$u" ] && . "$u"
    return 0
}
