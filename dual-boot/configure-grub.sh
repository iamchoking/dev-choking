#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo 'Run with sudo: sudo ./configure-grub.sh' >&2
    exit 1
fi

# Back up the defaults, generated menu, and GRUB Customizer's menu scripts.
backup_root=/var/backups/dev-choking-dual-boot
mkdir -p "$backup_root"
backup_dir=$(mktemp -d "$backup_root/grub-$(date +%Y%m%d-%H%M%S)-XXXXXX")
chmod 700 "$backup_dir"
cp -a /etc/default/grub "$backup_dir/default-grub"
cp -a /boot/grub/grub.cfg "$backup_dir/grub.cfg"
cp -a /etc/grub.d "$backup_dir/grub.d"
echo "Backup: $backup_dir"

# Replace only the settings managed here, including obsolete hidden timeouts.
sed -i -E '/^[[:space:]]*(export[[:space:]]+)?GRUB_(DEFAULT|SAVEDEFAULT|TIMEOUT_STYLE|TIMEOUT|DISABLE_OS_PROBER|HIDDEN_TIMEOUT|HIDDEN_TIMEOUT_QUIET)[[:space:]]*=/d' /etc/default/grub
cat >> /etc/default/grub <<'EOF'

GRUB_DEFAULT="saved"
GRUB_SAVEDEFAULT="true"
GRUB_TIMEOUT_STYLE="menu"
GRUB_TIMEOUT="300"
GRUB_DISABLE_OS_PROBER="false"
EOF

if ! update-grub ||
    ! grub-script-check /boot/grub/grub.cfg ||
    ! grep -q -- '--class windows' /boot/grub/grub.cfg; then
    cp -a "$backup_dir/default-grub" /etc/default/grub
    cp -a "$backup_dir/grub.cfg" /boot/grub/grub.cfg
    echo 'GRUB generation/check failed or Windows was not detected. Previous settings restored.' >&2
    echo 'Check sudo os-prober and sudo efibootmgr -v before retrying.' >&2
    exit 1
fi

echo 'Configured: visible menu, 300-second countdown, previous selection, Windows detection.'
echo 'Pressing a key cancels the countdown. Reboot when ready to test.'
