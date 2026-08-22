#!/bin/sh
# OrbitUI uninstaller — restores the stock web UI and screen UI. Run as root:
#   sh /user-resource/orbitui/uninstall.sh
set -u

HOME_DIR="/user-resource/orbitui"
WEB_DIR="/user-resource/cosmosweb"
SCREEN_DIR="/user-resource/cosmosui"
NAVI="/etc/klipper/config/.theme/navi.json"

[ "$(id -u)" -eq 0 ] || { echo "Run as root." >&2; exit 1; }

# ---- screen ----
echo "Stopping the Orbit screen..."
/etc/init.d/cosmosui stop 2>/dev/null || true
rm -f /etc/init.d/cosmosui /etc/rc*.d/S97cosmosui /etc/rc*.d/K05cosmosui

PREV="grumpyscreen"
[ -f "${SCREEN_DIR}/previous_screen_ui" ] && PREV="$(cat "${SCREEN_DIR}/previous_screen_ui")"
echo "Restoring screen_ui = ${PREV}..."
sed -i "s/^screen_ui *=.*/screen_ui = ${PREV}/" /etc/klipper/config/cosmos.conf 2>/dev/null \
    || echo "NOTE: set 'screen_ui = ${PREV}' in cosmos.conf manually."

# ---- web ----
WEB_UI="$(config-manager ui web_ui 2>/dev/null || echo mainsail)"
echo "Restoring stock webroot link (${WEB_UI})..."
rm -rf /etc/webui
ln -s "/var/www/${WEB_UI}/" /etc/webui

if [ -f "${HOME_DIR}/navi.json.bak" ]; then
    cp "${HOME_DIR}/navi.json.bak" "$NAVI"
elif [ -f "$NAVI" ] && grep -q cosmosweb "$NAVI" 2>/dev/null; then
    rm -f "$NAVI"
fi

rm -rf "$WEB_DIR" "$SCREEN_DIR" "$HOME_DIR"

echo "Restarting the stock screen..."
/etc/init.d/gui-switcher restart 2>/dev/null || echo "Reboot to bring the stock screen back."
echo "OrbitUI removed. (Dashboard settings remain in the moonraker database"
echo "under namespace 'cosmosweb' — harmless, reused if you reinstall.)"
