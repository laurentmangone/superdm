#!/bin/bash

set -e

APP_NAME="SuperDM"
DMG_NAME="superdm"
BUNDLE_ID="com.superdm.app"

BUILD_DIR=".build/release"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"
DMG_PATH="${BUILD_DIR}/${DMG_NAME}.dmg"
STAGING_DIR="${BUILD_DIR}/dmg_staging"
SOURCES_DIR="${BUILD_DIR}/sources"

echo "Building release version..."
swift build -c release

echo "Creating .app bundle..."
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}/${APP_NAME}.app/Contents/MacOS"
mkdir -p "${SOURCES_DIR}"

cp "${BUILD_DIR}/superdm-gui" "${SOURCES_DIR}/"

cat > "${STAGING_DIR}/${APP_NAME}.app/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>sources/superdm-gui</string>
    <key>CFBundleIdentifier</key>
    <string>com.superdm.app</string>
    <key>CFBundleName</key>
    <string>SuperDM</string>
    <key>CFBundleDisplayName</key>
    <string>SuperDM</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

cp "${BUILD_DIR}/superdm-gui" "${STAGING_DIR}/${APP_NAME}.app/Contents/MacOS/"

echo "Creating DMG..."
rm -f "${DMG_PATH}"
hdiutil create -volname "${DMG_NAME}" -srcfolder "${STAGING_DIR}" -ov -format UDZO "${DMG_PATH}"

echo "Done! DMG created at: ${DMG_PATH}"
