#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"

mkdir -p "$DIST_DIR"

# ── App Icon ──
echo "=== Generating App Icon ==="
swift "$SCRIPT_DIR/generate_app_icon.swift" "$DIST_DIR"

ICONSET_DIR="$DIST_DIR/AppIcon.iconset"
ICNS_PATH="$DIST_DIR/AppIcon.icns"

iconutil --convert icns --output "$ICNS_PATH" "$ICONSET_DIR"
rm -rf "$ICONSET_DIR"

echo "=== App Icon created: $ICNS_PATH ==="
