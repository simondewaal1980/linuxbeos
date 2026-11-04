#!/usr/bin/env bash
# Acceptatietest: volledige Calamares-installatie in een UEFI-VM (OVMF),
# gevolgd door een zelfstandige boot van het geïnstalleerde systeem.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/lib/run-install-test.sh" uefi "$@"
