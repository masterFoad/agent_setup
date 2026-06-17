#!/usr/bin/env bash
# Build the macOS FOAD Dev Setup DMG.
# Run on macOS from the repository root:
#   ./packaging/macos/build-mac-dmg.sh
#
# Output:
#   dist/macos/FOAD-Dev-Setup-macOS.dmg
#
# Optional signing/notarization should be done after this script if you have
# an Apple Developer ID certificate.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_DIR="$ROOT_DIR/dist/macos/dmg-root"
OUT_DIR="$ROOT_DIR/dist/macos"
DMG_PATH="$OUT_DIR/FOAD-Dev-Setup-macOS.dmg"

if ! command -v hdiutil >/dev/null 2>&1; then
  echo "hdiutil is required. Run this on macOS." >&2
  exit 1
fi

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$OUT_DIR"

cp "$ROOT_DIR/install-mac.sh" "$BUILD_DIR/install-mac.sh"
cp "$ROOT_DIR/README.md" "$BUILD_DIR/README.md"
cp "$ROOT_DIR/packaging/macos/FOAD-Dev-Setup.command.template" "$BUILD_DIR/FOAD Dev Setup.command"
chmod +x "$BUILD_DIR/install-mac.sh" "$BUILD_DIR/FOAD Dev Setup.command"

rm -f "$DMG_PATH"
hdiutil create \
  -volname "FOAD Dev Setup" \
  -srcfolder "$BUILD_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "Built: $DMG_PATH"
echo "Recommended production step: sign and notarize the DMG with an Apple Developer ID."
