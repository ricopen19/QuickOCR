#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="QuickOCRApp"
DMG_NAME="QuickOCR"
DMG_PATH="$DIST_DIR/${DMG_NAME}.dmg"

# ── 1. .app バンドルビルド ──────────────────────────
bash "$SCRIPT_DIR/build_app.sh"

APP_DIR="$DIST_DIR/${APP_NAME}.app"
if [[ ! -d "$APP_DIR" ]]; then
  echo "Error: app bundle not found at $APP_DIR" >&2
  exit 1
fi

# ── 2. ステージング（.app + /Applications シンボリック）──
STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT

cp -R "$APP_DIR" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

# ── 3. DMG 生成 ─────────────────────────────────────
rm -f "$DMG_PATH"
hdiutil create \
  -srcfolder "$STAGING" \
  -volname   "$DMG_NAME" \
  -format    UDZO \
  -imagekey  zlib-level=9 \
  -o         "$DMG_PATH"

echo ""
echo "=== DMG created: $DMG_PATH ==="
