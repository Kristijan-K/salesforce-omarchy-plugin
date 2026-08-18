#!/usr/bin/env bash
# Own the browser OAuth listener outside Quickshell and report completion.
set -u

TARGET="$1"
URL="$2"
TOKEN="$3"
STATE_DIR="${4:-${XDG_RUNTIME_DIR:-$HOME/.cache/omarchy}/omarchy-sf-plugin}"
SAFE="$(printf '%s' "$TARGET" | tr -c 'A-Za-z0-9._-' '_')-$TOKEN"
STATUS="$STATE_DIR/$SAFE.status"
PIDFILE="$STATE_DIR/$SAFE.pid"
LOG="$STATE_DIR/$SAFE.log"

umask 077
mkdir -p "$STATE_DIR"
if [ ! -d "$STATE_DIR" ] || [ -L "$STATE_DIR" ] || [ ! -O "$STATE_DIR" ]; then
  exit 126
fi
chmod 700 "$STATE_DIR"
rm -f "$STATUS" "$PIDFILE"
SF_BIN="$(command -v sf || true)"
if [ -z "$SF_BIN" ]; then
  (set -C; printf '%s\n' 127 > "$STATUS") 2>/dev/null || true
  exit 127
fi

# Chrome may resolve localhost to IPv4 while Node prefers IPv6 on this host.
# Force the CLI callback listener onto 127.0.0.1 so the OAuth redirect reaches it.
export NODE_OPTIONS="${NODE_OPTIONS:-} --dns-result-order=ipv4first"

"$SF_BIN" org login web --alias "$TARGET" --instance-url "$URL" >>"$LOG" 2>&1 &
CHILD="$!"
(set -C; printf '%s\n' "$CHILD" > "$PIDFILE") 2>/dev/null || {
  kill "$CHILD" 2>/dev/null || true
  exit 126
}
trap 'kill "$CHILD" 2>/dev/null || true; wait "$CHILD" 2>/dev/null || true; rm -f "$PIDFILE"; exit 143' TERM INT HUP
wait "$CHILD"
CODE="$?"
rm -f "$PIDFILE"
(set -C; printf '%s\n' "$CODE" > "$STATUS") 2>/dev/null || true
exit "$CODE"
