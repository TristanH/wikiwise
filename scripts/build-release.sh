#!/bin/bash
set -euo pipefail

VERSION="${1:-0.1.0}"
SIGNING_IDENTITY="Developer ID Application: Readwise, Inc (QV36BMA4LN)"
APP="Wikiwise.app"
ZIP="Wikiwise-${VERSION}-macOS.zip"

echo "Building Wikiwise v${VERSION}..."

# Build optimized release binary
swift build -c release

# Create .app bundle
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Copy binary
cp .build/release/Wikiwise "$APP/Contents/MacOS/Wikiwise"

# Copy resource bundle (contains all JS, CSS, HTML, scaffold, icon)
cp -R .build/release/Wikiwise_Wikiwise.bundle "$APP/Contents/Resources/"

# Copy icon to top level for Finder/Dock
cp .build/release/Wikiwise_Wikiwise.bundle/Wikiwise.icns "$APP/Contents/Resources/Wikiwise.icns"

# Write Info.plist
cat > "$APP/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Wikiwise</string>
    <key>CFBundleDisplayName</key>
    <string>Wikiwise</string>
    <key>CFBundleIdentifier</key>
    <string>com.readwise.wikiwise</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>VERSION_PLACEHOLDER</string>
    <key>CFBundleExecutable</key>
    <string>Wikiwise</string>
    <key>CFBundleIconFile</key>
    <string>Wikiwise</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <false/>
</dict>
</plist>
PLIST

# Inject version
sed -i '' "s/VERSION_PLACEHOLDER/${VERSION}/" "$APP/Contents/Info.plist"

# Code sign
echo "Signing with: $SIGNING_IDENTITY"
codesign --deep --force --options runtime --sign "$SIGNING_IDENTITY" "$APP"
codesign --verify --deep --strict "$APP"
echo "Signature valid."

# Zip for notarization
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

# Notarize
echo "Submitting for notarization..."
xcrun notarytool submit "$ZIP" --keychain-profile "notarytool" --wait

# Staple
xcrun stapler staple "$APP"

# Re-zip with stapled ticket
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo ""
echo "Done: $ZIP ($(du -h "$ZIP" | cut -f1))"
echo "Signed, notarized, and stapled."
echo ""
echo "To publish:"
echo "  gh release create v${VERSION} ${ZIP} --title \"Wikiwise v${VERSION}\" --notes \"...\""
