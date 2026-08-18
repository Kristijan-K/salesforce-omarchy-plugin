# Salesforce Orgs — Omarchy Quattro Plugin

An Omarchy Quattro plugin that manages Salesforce CLI org connections from the bar: browse connected orgs, open them in a browser, reauthenticate, and add new orgs — all keyboard-driven from a bar popup.

The repository root is the plugin folder (`manifest.json` sits beside the entry points), so it validates with `omarchy plugin validate` exactly as published.

## Features

- Lists all orgs returned by `sf org list --json`
- Sorts connected orgs first, then by name
- Shows alias, username, connection status, environment (production/sandbox), and the default-org marker
- Opens the selected org in a browser
- Reauthenticates the selected org with a live `sf org login web` process
- Adds production, sandbox, or custom-URL orgs
- Logs an org out of the local CLI after confirmation
- Loads the last cached snapshot instantly; refresh manually with `G` or middle-click
- Full keyboard and mouse navigation
- Opens from the bar icon or `SUPER CTRL ALT S`

## Keyboard shortcuts

Inside the panel:

| Key | Action |
| --- | --- |
| `↑` / `↓` or `j` / `k` | Move through orgs |
| `Enter` or `o` | Open the selected org |
| `r` | Start browser login for the selected org |
| `g` | Refresh all orgs and update the cache |
| `a` | Add an org (choose environment, then enter an alias) |
| `/` | Search by org name, alias, or username |
| `x` | Log the selected org out (confirm with `y`, cancel with `n` or `Esc`) |
| `Esc` | Close the popup |

On the bar icon: middle-click refreshes.

## Requirements

- Omarchy Quattro
- Salesforce CLI (`sf`) on `PATH`
- A Salesforce CLI installation with permission to launch browser authentication

The plugin executes Salesforce CLI commands directly and does not store credentials itself.

## Installation

From a checkout of this repository:

```bash
PLUGIN_ID="io.github.kkosu.salesforce-orgs"
mkdir -p "$HOME/.config/omarchy/plugins/$PLUGIN_ID"
cp manifest.json BarWidget.qml Service.qml Model.js SalesforceIcon.qml auth-web-login.sh README.md LICENSE \
  "$HOME/.config/omarchy/plugins/$PLUGIN_ID/"
omarchy plugin validate "$HOME/.config/omarchy/plugins/$PLUGIN_ID"
omarchy-shell shell rescanPlugins
omarchy plugin enable "$PLUGIN_ID"
omarchy bar put "$PLUGIN_ID" --section right
```

Or use the dev installer (validates, copies, rescans, enables, and places the widget):

```bash
./install-local.sh
```

## Removal

```bash
PLUGIN_ID="io.github.kkosu.salesforce-orgs"
omarchy plugin disable "$PLUGIN_ID"
omarchy plugin remove "$PLUGIN_ID"
```

Removing the plugin leaves the Salesforce CLI configuration untouched. To also drop the plugin's cache and login-state files:

```bash
rm -f "$HOME/.cache/omarchy/salesforce-orgs.json"
rm -rf "${XDG_RUNTIME_DIR:-$HOME/.cache/omarchy}/omarchy-sf-plugin"
```

## How it works

The plugin provides two shell entry points:

- `Service.qml` — a headless `service` that owns all `sf` CLI interaction. It refreshes `sf org list --json`, parses the output (`Model.js`), caches the snapshot in `~/.cache/omarchy/salesforce-orgs.json`, and runs open/logout actions with a 120 s timeout and generation-counted state reconciliation.
- `BarWidget.qml` — the `bar-widget` entry point: a Salesforce cloud icon on the bar and the keyboard popup. It is pure UI; every action delegates to the service.

Browser authentication (`sf org login web`) runs detached via `auth-web-login.sh` in `$XDG_RUNTIME_DIR/omarchy-sf-plugin/` so closing the popup or the shell cannot kill the OAuth listener. The service polls the login status file until the browser flow completes, then refreshes the org list.

## Development

```bash
./run-tests.sh       # QML state-machine tests (offscreen qmltestrunner)
./install-local.sh   # validate + copy + rescan + enable + place on bar
```

Edit files at the repository root, run `./install-local.sh`, then test from the bar icon or `SUPER CTRL ALT S`.

## License

[MIT](LICENSE). This plugin depends on Omarchy Quattro and the Salesforce CLI; neither is bundled or modified.
