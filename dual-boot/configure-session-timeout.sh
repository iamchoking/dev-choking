#!/usr/bin/env bash
# Optional workaround; unrelated to GRUB configuration.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo 'Run with sudo: sudo ./configure-session-timeout.sh [--remove]' >&2
    exit 1
fi
if [[ $# -gt 1 || ( $# -eq 1 && $1 != --remove ) ]]; then
    echo 'Usage: sudo ./configure-session-timeout.sh [--remove]' >&2
    exit 1
fi

override=/etc/systemd/system/session-.scope.d/60-shutdown-timeout.conf
if [[ -f $override ]]; then
    cp -a "$override" "$override.backup-$(date +%Y%m%d-%H%M%S)"
fi

if [[ ${1:-} == --remove ]]; then
    rm -f "$override"
    echo 'Removed the 15-second session shutdown limit.'
else
    mkdir -p "$(dirname -- "$override")"
    cat > "$override" <<'EOF'
# dev-choking: limit stuck login sessions during logout/shutdown.
[Scope]
TimeoutStopSec=15s
EOF
    chmod 644 "$override"
    echo 'Login sessions now have 15 seconds to exit before being forcibly closed.'
fi

systemctl daemon-reload
systemctl list-units 'session-*.scope' --no-legend --plain |
    while read -r session_unit _; do
        systemctl show "$session_unit" -p Id -p TimeoutStopUSec
    done
