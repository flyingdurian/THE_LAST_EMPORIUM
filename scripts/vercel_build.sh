#!/usr/bin/env bash
set -euo pipefail

GODOT_VERSION="4.3"
GODOT_TAG="${GODOT_VERSION}-stable"
TOOLS_DIR="$PWD/.vercel-tools"
TEMPLATE_DIR="$HOME/.local/share/godot/export_templates/${GODOT_TAG}"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TOOLS_DIR" "$TEMPLATE_DIR" "$PWD/build/web"

echo "Downloading Godot ${GODOT_TAG} headless export binary..."
curl --fail --location --retry 3 --output "$TMP_DIR/godot.zip" \
  "https://github.com/godotengine/godot/releases/download/${GODOT_TAG}/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
unzip -oq "$TMP_DIR/godot.zip" -d "$TOOLS_DIR"
GODOT_BIN="$TOOLS_DIR/Godot_v${GODOT_VERSION}-stable_linux.x86_64"
chmod +x "$GODOT_BIN"

echo "Installing matching Godot Web export templates..."
curl --fail --location --retry 3 --output "$TMP_DIR/templates.tpz" \
  "https://github.com/godotengine/godot/releases/download/${GODOT_TAG}/Godot_v${GODOT_VERSION}-stable_export_templates.tpz"
mkdir -p "$TMP_DIR/templates"
unzip -oq "$TMP_DIR/templates.tpz" -d "$TMP_DIR/templates"
if [[ -d "$TMP_DIR/templates/templates" ]]; then
  cp -a "$TMP_DIR/templates/templates/." "$TEMPLATE_DIR/"
else
  cp -a "$TMP_DIR/templates/." "$TEMPLATE_DIR/"
fi

echo "Importing project and exporting Web build..."
"$GODOT_BIN" --headless --path "$PWD" --editor --quit
"$GODOT_BIN" --headless --path "$PWD" --export-release "Web" "$PWD/build/web/index.html"

test -s "$PWD/build/web/index.html"
test -n "$(find "$PWD/build/web" -maxdepth 1 -type f -name '*.wasm' -print -quit)"
test -n "$(find "$PWD/build/web" -maxdepth 1 -type f -name '*.pck' -print -quit)"
echo "Godot Web export complete: build/web"
