#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Vell"
BUNDLE_ID="com.bovmii.vell"
EXECUTABLE="Vell"
BUILD_DIR=".build/apple/Products/Release"
APP_DIR="build/${APP_NAME}.app"
ICON_SRC="icone.png"

echo "→ Compilation (release, universal)…"
swift build -c release --arch arm64 --arch x86_64

echo "→ Génération de l'icône .icns (zoom 115% pour combler les bords)…"
ICONSET_DIR="build/AppIcon.iconset"
rm -rf "${ICONSET_DIR}"
mkdir -p "${ICONSET_DIR}"
ZOOM_PCT=115   # 115% : agrandit l'icône puis recadre au centre
make_icon() {
    local target=$1 out=$2
    local zoom=$(( target * ZOOM_PCT / 100 ))
    local tmp="${ICONSET_DIR}/.tmp_${target}.png"
    sips -z "$zoom" "$zoom" "${ICON_SRC}" --out "$tmp" >/dev/null
    sips -c "$target" "$target" "$tmp" --out "$out" >/dev/null
    rm -f "$tmp"
}
for size in 16 32 64 128 256 512; do
    make_icon "$size" "${ICONSET_DIR}/icon_${size}x${size}.png"
    double=$((size * 2))
    make_icon "$double" "${ICONSET_DIR}/icon_${size}x${size}@2x.png"
done
iconutil -c icns "${ICONSET_DIR}" -o "build/AppIcon.icns"
rm -rf "${ICONSET_DIR}"

echo "→ Création du bundle .app…"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "${BUILD_DIR}/${EXECUTABLE}" "${APP_DIR}/Contents/MacOS/${EXECUTABLE}"
cp "build/AppIcon.icns" "${APP_DIR}/Contents/Resources/AppIcon.icns"

cat > "${APP_DIR}/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key>
    <string>${EXECUTABLE}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 @bovmii. PolyForm Noncommercial 1.0.0. Resale prohibited.</string>
</dict>
</plist>
EOF

codesign --force --deep --sign - "${APP_DIR}" >/dev/null 2>&1 || true

echo "→ Création du DMG…"
DMG_PATH="build/${APP_NAME}.dmg"
DMG_TMP="build/${APP_NAME}-tmp.dmg"
rm -f "${DMG_PATH}" "${DMG_TMP}"
DMG_STAGE="build/dmg-stage"
rm -rf "${DMG_STAGE}"
mkdir -p "${DMG_STAGE}"
cp -R "${APP_DIR}" "${DMG_STAGE}/"
ln -s /Applications "${DMG_STAGE}/Applications"

# Hidden background folder + custom background image
mkdir -p "${DMG_STAGE}/.background"
swift make_dmg_background.swift "${DMG_STAGE}/.background/bg.png" >/dev/null

# Create a read-write DMG so we can tweak the Finder view.
hdiutil create -volname "${APP_NAME}" -srcfolder "${DMG_STAGE}" -ov -fs HFS+ -format UDRW "${DMG_TMP}" >/dev/null

# Mount it.
MOUNT_DIR="/Volumes/${APP_NAME}"
hdiutil attach -readwrite -noverify -noautoopen "${DMG_TMP}" >/dev/null
sleep 3

# Tell Finder: window size, icon size, icon positions.
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "${APP_NAME}"
        open
        delay 2
        tell container window
            set current view to icon view
            set toolbar visible to false
            set statusbar visible to false
            set the bounds to {200, 200, 720, 540}
        end tell
        delay 1
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 112
        set text size of viewOptions to 13
        set background picture of viewOptions to file ".background:bg.png"
        delay 1
        set position of item "${APP_NAME}.app" of container window to {140, 150}
        set position of item "Applications" of container window to {380, 150}
        update without registering applications
        delay 2
        close
    end tell
end tell
APPLESCRIPT

sync
hdiutil detach "${MOUNT_DIR}" >/dev/null

# Compress to final read-only DMG.
hdiutil convert "${DMG_TMP}" -format UDZO -imagekey zlib-level=9 -o "${DMG_PATH}" >/dev/null
rm -f "${DMG_TMP}"
rm -rf "${DMG_STAGE}"
echo "✓ DMG créé : ${DMG_PATH}"

echo "✓ Bundle créé : ${APP_DIR}"
echo
echo "Pour installer :"
echo "  cp -R \"${APP_DIR}\" /Applications/"
echo "  open \"/Applications/${APP_NAME}.app\""
