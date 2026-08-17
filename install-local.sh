#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$ROOT_DIR/omarchy-plugin"
PLUGIN_ID="$(jq -r '.id' "$SOURCE_DIR/manifest.json")"
TARGET_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"

omarchy plugin validate "$SOURCE_DIR"
mkdir -p "$TARGET_DIR"
find "$TARGET_DIR" -maxdepth 1 -type f -delete
cp "$SOURCE_DIR"/* "$TARGET_DIR/"

# Rescanning does not reconstruct an already enabled QML component. Disable
# first so local installs always load the files that were just copied.
if omarchy plugin list --json | jq -e --arg id "$PLUGIN_ID" '.[] | select(.id == $id and .enabled == true)' >/dev/null; then
  omarchy plugin disable "$PLUGIN_ID"
fi
omarchy-shell shell rescanPlugins

omarchy plugin enable "$PLUGIN_ID"

omarchy bar put "$PLUGIN_ID" --section right
omarchy-restart-shell
echo "Installed $PLUGIN_ID from $SOURCE_DIR"
