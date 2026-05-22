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

echo "→ Génération de l'icône .icns…"
ICONSET_DIR="build/AppIcon.iconset"
rm -rf "${ICONSET_DIR}"
mkdir -p "${ICONSET_DIR}"
for size in 16 32 64 128 256 512; do
    sips -z "$size" "$size" "${ICON_SRC}" --out "${ICONSET_DIR}/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" "${ICON_SRC}" --out "${ICONSET_DIR}/icon_${size}x${size}@2x.png" >/dev/null
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
    <string>MIT License. @bovmii</string>
</dict>
</plist>
EOF

codesign --force --deep --sign - "${APP_DIR}" >/dev/null 2>&1 || true

echo "→ Création du DMG…"
DMG_PATH="build/${APP_NAME}.dmg"
rm -f "${DMG_PATH}"
DMG_STAGE="build/dmg-stage"
rm -rf "${DMG_STAGE}"
mkdir -p "${DMG_STAGE}"
cp -R "${APP_DIR}" "${DMG_STAGE}/"
ln -s /Applications "${DMG_STAGE}/Applications"
hdiutil create -volname "${APP_NAME}" -srcfolder "${DMG_STAGE}" -ov -format UDZO "${DMG_PATH}" >/dev/null
rm -rf "${DMG_STAGE}"
echo "✓ DMG créé : ${DMG_PATH}"

echo "✓ Bundle créé : ${APP_DIR}"
echo
echo "Pour installer :"
echo "  cp -R \"${APP_DIR}\" /Applications/"
echo "  open \"/Applications/${APP_NAME}.app\""
