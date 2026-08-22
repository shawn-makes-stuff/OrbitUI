#!/bin/sh
# OrbitUI installer — CosmosWeb (web dashboard) + the Orbit screen UI, in one
# shot, for COSMOS firmware on the Elegoo Centauri Carbon.
# Run as root on the printer:  sh install.sh
# Non-destructive: the rootfs stays read-only; everything lives under
# /user-resource plus the /etc overlay. uninstall.sh reverts both parts fully.
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
HOME_DIR="/user-resource/orbitui"
WEB_DIR="/user-resource/cosmosweb"
SCREEN_DIR="/user-resource/cosmosui"
WEBUI="/etc/webui"
NAVI_DIR="/etc/klipper/config/.theme"
INIT="/etc/init.d/cosmosui"

fail() { echo "ERROR: $1" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || fail "Run as root."
command -v config-manager >/dev/null 2>&1 || fail "config-manager not found. Is this a COSMOS install?"
[ -x /etc/init.d/gui-switcher ] || fail "gui-switcher not found. Is this a COSMOS install?"
[ -f "${SCRIPT_DIR}/web/app/index.html" ] || fail "web app files missing from the package."
[ -f "${SCRIPT_DIR}/screen/cosmosui-renderer" ] || fail "screen renderer binary missing from the package."
[ -f "${SCRIPT_DIR}/screen/theme/ui.json" ] || fail "screen theme missing from the package."

mkdir -p "$HOME_DIR"
cp "${SCRIPT_DIR}/uninstall.sh" "${HOME_DIR}/uninstall.sh"
chmod 0755 "${HOME_DIR}/uninstall.sh"
# The screen's "EJECT ORBITUI" button runs /user-resource/cosmosui/uninstall.sh
# (hardcoded in the renderer) — put the combined uninstaller there too, so the
# on-screen eject removes both the screen and the web UI.
mkdir -p "$SCREEN_DIR"
cp "${SCRIPT_DIR}/uninstall.sh" "${SCREEN_DIR}/uninstall.sh"
chmod 0755 "${SCREEN_DIR}/uninstall.sh"

# ============ Part 1: CosmosWeb (web dashboard) ============
STOCK_UI="$(config-manager ui web_ui 2>/dev/null || echo mainsail)"
STOCK="/var/www/${STOCK_UI}"
[ -d "$STOCK" ] || fail "stock webroot ${STOCK} not found."
for n in cosmosweb ui.html mainsail.html; do
    if [ -e "${STOCK}/${n}" ]; then
        fail "stock webroot already contains '${n}' — name collision, aborting."
    fi
done

echo "Installing CosmosWeb to ${WEB_DIR}..."
mkdir -p "$WEB_DIR"
rm -rf "${WEB_DIR}/app"
cp -r "${SCRIPT_DIR}/web/app" "${WEB_DIR}/app"

# Union webroot: a real directory (moonraker's init does 'rm -f' which cannot
# remove a directory, so this survives every moonraker restart and reboot)
# holding links to the stock UI's top-level entries plus our app.
echo "Building union webroot at ${WEBUI}..."
rm -rf "$WEBUI"
mkdir "$WEBUI"
for f in "$STOCK"/*; do
    ln -s "$f" "${WEBUI}/"
done
ln -s "${WEB_DIR}/app" "${WEBUI}/cosmosweb"
ln -s "${WEB_DIR}/app/ui.html" "${WEBUI}/ui.html"

# '/' lands on CosmosWeb; the stock UI stays reachable at /mainsail.html.
rm "${WEBUI}/index.html"
ln -s "${STOCK}/index.html" "${WEBUI}/mainsail.html"
cat > "${WEBUI}/index.html" <<'EOF'
<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><meta http-equiv="refresh" content="0;url=/cosmosweb/index.html"><title>CosmosWeb</title></head><body><a href="/cosmosweb/index.html">CosmosWeb</a></body></html>
EOF

# Mainsail sidebar link to CosmosWeb (existing navi.json is backed up and
# restored on uninstall).
mkdir -p "$NAVI_DIR"
if [ -f "${NAVI_DIR}/navi.json" ] && [ ! -f "${HOME_DIR}/navi.json.bak" ]; then
    cp "${NAVI_DIR}/navi.json" "${HOME_DIR}/navi.json.bak"
fi
cat > "${NAVI_DIR}/navi.json" <<'EOF'
[
    { "title": "CosmosWeb", "icon": "mdi-orbit", "href": "/cosmosweb/index.html", "target": "_blank", "position": 5 }
]
EOF

# ============ Part 2: Orbit screen UI ============
echo "Installing the Orbit screen UI to ${SCREEN_DIR}..."
mkdir -p "$SCREEN_DIR"
cp "${SCRIPT_DIR}/screen/cosmosui-renderer" "${SCREEN_DIR}/cosmosui-renderer"
chmod 0755 "${SCREEN_DIR}/cosmosui-renderer"
rm -rf "${SCREEN_DIR}/theme"
cp -r "${SCRIPT_DIR}/screen/theme" "${SCREEN_DIR}/theme"

# Init script into the /etc overlay (rc 97: after gui-switcher at 96, which
# sets brightness 0 when screen_ui=none — we restore it).
cat > "$INIT" <<'EOF'
#!/bin/sh
### BEGIN INIT INFO
# Provides:          cosmosui
# Required-Start:    $local_fs $remote_fs $network
# Required-Stop:     $local_fs $remote_fs $network
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: CosmosUI screen renderer
### END INIT INFO
PIDFILE=/var/run/gui.pid
BIN=/user-resource/cosmosui/cosmosui-renderer
THEME=/user-resource/cosmosui/theme
case "$1" in
    start)
        brightness "$(config-manager ui screen_brightness)" 2>/dev/null || true
        start-stop-daemon -S -b -m -p "$PIDFILE" -x "$BIN" -- --theme "$THEME"
        ;;
    stop)
        start-stop-daemon -K -p "$PIDFILE" -R 10 2>/dev/null || true
        dd if=/dev/zero of=/dev/fb0 2>/dev/null || true
        ;;
    restart|force-reload) $0 stop; sleep 1; $0 start ;;
    status)
        if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
            echo "cosmosui running (PID $(cat "$PIDFILE"))"
        else
            echo "cosmosui not running"; exit 1
        fi ;;
    *) echo "Usage: $0 {start|stop|restart|status}"; exit 1 ;;
esac
EOF
chmod 0755 "$INIT"
for rl in 2 3 4 5; do ln -sf ../init.d/cosmosui "/etc/rc${rl}.d/S97cosmosui"; done
for rl in 0 1 6; do ln -sf ../init.d/cosmosui "/etc/rc${rl}.d/K05cosmosui"; done

# Remember the previous screen UI so uninstall can restore it, then take over.
PREV="$(config-manager ui screen_ui 2>/dev/null || echo grumpyscreen)"
echo "$PREV" > "${SCREEN_DIR}/previous_screen_ui"
if [ "$PREV" != "none" ]; then
    echo "Stopping ${PREV} and switching screen_ui to none..."
    "/etc/init.d/${PREV}" stop 2>/dev/null || true
    sed -i 's/^screen_ui *=.*/screen_ui = none/' /etc/klipper/config/cosmos.conf 2>/dev/null \
        || echo "NOTE: set 'screen_ui = none' in cosmos.conf manually, then reboot."
fi

echo "Starting the Orbit screen..."
"$INIT" start

IP="$(ip route get 1 2>/dev/null | sed -n 's/.*src \([0-9.]*\).*/\1/p')"
echo ""
echo "OrbitUI installed — no reboot needed (one recommended to confirm boot-time startup)."
echo "  Web UI:    http://${IP:-<printer-ip>}/          (Mainsail still at /mainsail.html)"
echo "  Screen:    Orbit is live on the printer display"
echo "  Revert:    sh ${HOME_DIR}/uninstall.sh"
