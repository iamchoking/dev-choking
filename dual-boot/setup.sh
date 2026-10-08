#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo 'Run with sudo: sudo ./dual-boot/setup.sh' >&2
    exit 1
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
"$script_dir/install-grub-customizer.sh"
"$script_dir/configure-grub.sh"

echo 'Setup complete. Reboot and test Ubuntu and Windows from GRUB.'
