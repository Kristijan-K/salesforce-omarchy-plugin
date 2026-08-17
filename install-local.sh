#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$ROOT_DIR/omarchy-plugin"
PLUGIN_ID="$(jq -r '.id' "$SOURCE_DIR/manifest.json")"
TARGET_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"

omarchy plugin validate "$SOURCE_DIR"
mkdir -p "$TARGET_DIR"
cp "$SOURCE_DIR"/* "$TARGET_DIR/"

omarchy-shell shell rescanPlugins

if ! omarchy plugin list --json | jq -e --arg id "$PLUGIN_ID" '.[] | select(.id == $id and .enabled == true)' >/dev/null; then
  omarchy plugin enable "$PLUGIN_ID"
fi

omarchy bar move "$PLUGIN_ID" --section right
echo "Installed $PLUGIN_ID from $SOURCE_DIR"
