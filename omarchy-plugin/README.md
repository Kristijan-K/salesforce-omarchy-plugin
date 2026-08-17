# Salesforce Orgs Omarchy Plugin

An Omarchy Quattro Salesforce org manager with a transient popup and bar icon.

## Features

- Lists all orgs returned by `sf org list --json`
- Sorts connected orgs first, then sorts by name
- Shows alias, username, login URL, connection status, environment, and default-org marker
- Opens the selected org in a browser
- Reauthenticates the selected org with a live `sf org login web` process
- Removes an org after confirmation
- Adds production, sandbox, or custom-url orgs
- Loads the last cached snapshot and refreshes manually with `G` or middle-click
- Supports keyboard and mouse navigation
- Opens from the bar icon or `SUPER CTRL ALT S`

## Keyboard shortcuts

Inside the panel:

- Up/down arrows or `j`/`k`: move through orgs
- `Enter` or `o`: open the selected org
- `r`: start the selected org's Salesforce browser login
- `g`: refresh all orgs and update the cached snapshot
- `a`: add an org
- `X`: remove the selected org after confirmation
- `/`: search by org name, alias, or username
- `a`: add an org, then press Enter to choose the environment and Enter again to enter details
- `Esc`: close the popup
- `p`/`s`/`c`: choose production, sandbox, or custom URL in the add form

## Requirements

- Omarchy Quattro
- Salesforce CLI (`sf`) on `PATH`
- A Salesforce CLI installation with permission to launch browser authentication

## Local installation

From this repository:

```bash
PLUGIN_ID="io.github.kkosu.salesforce-orgs"
mkdir -p "$HOME/.config/omarchy/plugins/$PLUGIN_ID"
cp omarchy-plugin/* "$HOME/.config/omarchy/plugins/$PLUGIN_ID/"
omarchy plugin validate "$HOME/.config/omarchy/plugins/$PLUGIN_ID"
omarchy-shell shell rescanPlugins
omarchy plugin enable "$PLUGIN_ID"
omarchy bar move "$PLUGIN_ID" --section right
```

The plugin executes Salesforce CLI commands directly and does not store credentials itself.
