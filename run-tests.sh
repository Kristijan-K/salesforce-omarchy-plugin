#!/usr/bin/env bash
# CI-runnable QML test entry point. Prefers the Qt 6 qmltestrunner because the
# bare `qmltestrunner` on this system is Qt 5.15, which exits 1 with no output.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -x /usr/lib/qt6/bin/qmltestrunner ]; then
  RUNNER=/usr/lib/qt6/bin/qmltestrunner
else
  RUNNER="$(command -v qmltestrunner)"
fi

export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}"
exec "$RUNNER" -platform offscreen -import "$ROOT_DIR/tests" -input "$ROOT_DIR/tests/tst_service.qml"
