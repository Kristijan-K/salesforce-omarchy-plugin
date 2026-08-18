#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ID="$(jq -r '.id' "$ROOT_DIR/manifest.json")"
TARGET_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"

# The repository root is the plugin folder: manifest.json sits beside the
# entry points so the marketplace validation sees the same layout users get.
PLUGIN_FILES=(manifest.json BarWidget.qml Service.qml Model.js SalesforceIcon.qml auth-web-login.sh README.md LICENSE)

omarchy plugin validate "$ROOT_DIR"
mkdir -p "$TARGET_DIR"
find "$TARGET_DIR" -maxdepth 1 -type f -delete
cp "${PLUGIN_FILES[@]/#/$ROOT_DIR/}" "$TARGET_DIR/"

# Rescanning does not reconstruct an already enabled QML component. Disable
# first so local installs always load the files that were just copied.
if omarchy plugin list --json | jq -e --arg id "$PLUGIN_ID" '.[] | select(.id == $id and .enabled == true)' >/dev/null; then
  omarchy plugin disable "$PLUGIN_ID"
fi
omarchy-shell shell rescanPlugins

omarchy plugin enable "$PLUGIN_ID"

omarchy bar put "$PLUGIN_ID" --section right
omarchy-restart-shell
echo "Installed $PLUGIN_ID from $ROOT_DIR"
