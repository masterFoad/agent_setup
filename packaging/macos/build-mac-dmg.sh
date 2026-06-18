#!/usr/bin/env bash
# Build the macOS FOAD Dev Setup DMG (styled window with background + layout).
# Run on macOS from the repository root:
#   ./packaging/macos/build-mac-dmg.sh
#
# Output:
#   dist/macos/FOAD-Dev-Setup-macOS.dmg
#
# The styled layout (background image + icon positions) is best-effort: it
# needs Pillow (for the background) and Finder automation (osascript). If
# either is unavailable the build still succeeds and produces a plain DMG.
#
# Optional signing/notarization should be done after this script if you have
# an Apple Developer ID certificate.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PKG_DIR="$ROOT_DIR/packaging/macos"
OUT_DIR="$ROOT_DIR/dist/macos"
STAGE_DIR="$OUT_DIR/dmg-root"
RW_DMG="$OUT_DIR/FOAD-Dev-Setup-rw.dmg"
DMG_PATH="$OUT_DIR/FOAD-Dev-Setup-macOS.dmg"
VOLNAME="FOAD Dev Setup"

if ! command -v hdiutil >/dev/null 2>&1; then
  echo "hdiutil is required. Run this on macOS." >&2
  exit 1
fi

# --- stage the payload ------------------------------------------------------
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR/.background" "$OUT_DIR"

cp "$ROOT_DIR/install-mac.sh" "$STAGE_DIR/install-mac.sh"
cp "$ROOT_DIR/README.md" "$STAGE_DIR/README.md"
cp "$PKG_DIR/READ-ME-FIRST.txt" "$STAGE_DIR/READ ME FIRST.txt"
cp "$PKG_DIR/FOAD-Dev-Setup.command.template" "$STAGE_DIR/FOAD Dev Setup.command"
chmod +x "$STAGE_DIR/install-mac.sh" "$STAGE_DIR/FOAD Dev Setup.command"

# --- background image (optional) -------------------------------------------
STYLED=1
if command -v python3 >/dev/null 2>&1 && \
   python3 -c "import PIL" >/dev/null 2>&1; then
  python3 "$PKG_DIR/make-background.py" "$STAGE_DIR/.background/background.png"
else
  echo "[WARN] Pillow not available; building a plain (unstyled) DMG."
  STYLED=0
fi

# --- create a writable image we can style -----------------------------------
rm -f "$RW_DMG" "$DMG_PATH"
hdiutil create -srcfolder "$STAGE_DIR" -volname "$VOLNAME" \
  -fs HFS+ -format UDRW -ov "$RW_DMG" >/dev/null

# Mount at the default /Volumes location (browsable) so Finder can address the
# disk by volume name for AppleScript styling.
ATTACH_OUT="$(hdiutil attach "$RW_DMG" -owners on)"
MOUNT_DIR="$(echo "$ATTACH_OUT" | grep -o '/Volumes/.*$' | head -1)"
if [[ -z "$MOUNT_DIR" || ! -d "$MOUNT_DIR" ]]; then
  echo "Failed to mount writable DMG." >&2
  exit 1
fi
cleanup() { hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || true; }
trap cleanup EXIT

# --- apply Finder window styling (optional) ---------------------------------
if [[ "$STYLED" -eq 1 ]] && command -v osascript >/dev/null 2>&1; then
  if osascript - "$VOLNAME" <<'APPLESCRIPT'
on run argv
  set volName to item 1 of argv
  try
    tell application "Finder"
      tell disk volName
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 860, 540}
        set opts to the icon view options of container window
        set arrangement of opts to not arranged
        set icon size of opts to 96
        set background picture of opts to file ".background:background.png"
        set position of item "FOAD Dev Setup.command" of container window to {175, 250}
        set position of item "READ ME FIRST.txt" of container window to {485, 250}
        set position of item "install-mac.sh" of container window to {175, 380}
        set position of item "README.md" of container window to {485, 380}
        update without registering applications
        delay 1
        close
      end tell
    end tell
  on error errMsg
    log "styling skipped: " & errMsg
  end try
end run
APPLESCRIPT
  then
    echo "[OK] Applied styled Finder layout."
  else
    echo "[WARN] Finder styling failed; DMG will be functional but plain."
  fi
  sync
fi

# --- finalize: compress to read-only ---------------------------------------
cleanup
trap - EXIT
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -ov -o "$DMG_PATH" >/dev/null
rm -f "$RW_DMG"
rm -rf "$STAGE_DIR"

echo "Built: $DMG_PATH"
echo "Recommended production step: sign and notarize the DMG with an Apple Developer ID."
