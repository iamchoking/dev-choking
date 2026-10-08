#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo 'Run with sudo: sudo ./install-grub-customizer.sh' >&2
    exit 1
fi

# Ubuntu LTS: install add-apt-repository before adding the maintainer's PPA.
apt-get update
apt-get install -y software-properties-common
add-apt-repository --yes --no-update ppa:danielrichter2007/grub-customizer
apt-get update
apt-get install -y grub-customizer os-prober efibootmgr

echo 'Installed GRUB Customizer, os-prober, and efibootmgr.'
