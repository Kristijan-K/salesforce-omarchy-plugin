# Salesforce Orgs Omarchy Plugin

This repository is the canonical development source for the Salesforce Orgs Omarchy Quattro plugin.

The plugin source lives in `omarchy-plugin/`. It is copied into the local Omarchy plugin directory for testing; Omarchy does not load files directly from this repository.

## Local Install

```bash
./install-local.sh
```

The installer validates the manifest, copies the plugin to `~/.config/omarchy/plugins/io.github.kkosu.salesforce-orgs/`, rescans the shell, enables it, and places it on the right side of the bar.

## Tests

```bash
./run-tests.sh
```

Runs the QML mock-process suite (Qt 6 `qmltestrunner`, offscreen). Covers logout command construction, reauthentication process launch, timeout reconciliation, and completion cleanup.

## Development Loop

1. Edit files under `omarchy-plugin/` in this repository.
2. Run `./install-local.sh`.
3. Test the widget from the Salesforce icon or `SUPER CTRL ALT S`.

The plugin uses the Salesforce CLI (`sf`) to list, open, reauthenticate, and add orgs.
