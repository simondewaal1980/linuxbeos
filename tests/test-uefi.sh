#!/usr/bin/env bash
# Rooktest: boot de LinuxBeOS-ISO in een UEFI-VM (OVMF) en wacht op de
# Xfce-sessie en netwerkverbinding via de seriële console.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/lib/run-vm-test.sh" uefi "$@"
