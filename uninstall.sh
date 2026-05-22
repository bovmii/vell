#!/usr/bin/env bash
# Désinstalle complètement Vell : app, login item, préférences.

set -u

APP_NAME="Vell"
BUNDLE_ID="com.bovmii.vell"
APP_PATH="/Applications/${APP_NAME}.app"

echo "→ Désinstallation de ${APP_NAME}…"

# 1. Quitter l'app si elle tourne
if pgrep -x "${APP_NAME}" >/dev/null 2>&1; then
    echo "  • Arrêt de l'app…"
    osascript -e "tell application \"${APP_NAME}\" to quit" 2>/dev/null || pkill -x "${APP_NAME}" || true
    sleep 1
fi

# 2. Retirer du login item
echo "  • Retrait du login item…"
osascript -e "tell application \"System Events\" to delete login item \"${APP_NAME}\"" 2>/dev/null || true

# 3. Supprimer l'app
if [ -d "${APP_PATH}" ]; then
    echo "  • Suppression de ${APP_PATH}…"
    rm -rf "${APP_PATH}"
fi

# 4. Supprimer les préférences
echo "  • Suppression des préférences…"
defaults delete "${BUNDLE_ID}" 2>/dev/null || true
rm -f "${HOME}/Library/Preferences/${BUNDLE_ID}.plist"

# 5. Restaurer les couleurs natives par sécurité (au cas où le quit n'a pas eu lieu)
echo "  • Restauration des couleurs natives de l'écran…"
osascript -e 'tell application "System Events" to keystroke ""' >/dev/null 2>&1 || true

echo "✓ ${APP_NAME} a été complètement désinstallé."
