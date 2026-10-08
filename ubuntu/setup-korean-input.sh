#!/usr/bin/env bash
# Ubuntu GNOME CLI equivalent of https://andrewpage.tistory.com/390
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: bash setup-korean-input.sh [--skip-install] [--switch-keys KEYS]

Run as your desktop user in an Ubuntu GNOME terminal (not with sudo).
Installs Korean support and replaces input sources with Korean (Hangul).
English remains available through the Hangul engine's Latin mode.

  --skip-install       Configure only; required packages must already be installed.
  --switch-keys KEYS   IBus key list (default: Hangul,Shift+space).
  -h, --help           Show this help.

Example: bash setup-korean-input.sh --switch-keys 'Hangul,Shift+space,Alt_R'
EOF
}

install=true
switch_keys='Hangul,Shift+space'
while (($#)); do
    case $1 in
        --skip-install) install=false; shift ;;
        --switch-keys)
            if [[ $# -lt 2 || -z $2 || $2 == --* ]]; then
                echo '--switch-keys requires a nonempty IBus key list.' >&2
                exit 1
            fi
            switch_keys=$2
            shift 2
            ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; exit 1 ;;
    esac
done

if [[ $EUID -eq 0 ]]; then
    echo 'Run as your desktop user, without sudo; package installation uses sudo itself.' >&2
    exit 1
fi
desktop=${XDG_CURRENT_DESKTOP:-}
if [[ ${desktop^^} != *GNOME* || -z ${DBUS_SESSION_BUS_ADDRESS:-} ]]; then
    echo 'Run from a terminal inside your logged-in Ubuntu GNOME desktop.' >&2
    exit 1
fi
# shellcheck source=/etc/os-release
source /etc/os-release
if [[ $ID != ubuntu ]]; then
    echo 'This script targets Ubuntu GNOME.' >&2
    exit 1
fi

if $install; then
    sudo apt-get update
    sudo apt-get install -y ibus ibus-hangul im-config language-pack-ko \
        language-pack-gnome-ko fonts-noto-cjk
fi

# Save each setting as a quoted CLI command before making user-level changes.
settings=(
    'org.gnome.desktop.input-sources sources'
    'org.freedesktop.ibus.general preload-engines'
    'org.freedesktop.ibus.engine.hangul switch-keys'
    'org.freedesktop.ibus.engine.hangul initial-input-mode'
    'org.freedesktop.ibus.engine.hangul disable-latin-mode'
)
for setting in "${settings[@]}"; do
    read -r schema key <<< "$setting"
    if [[ $(gsettings writable "$schema" "$key") != true ]]; then
        echo "Missing or locked setting: $setting. Install the required packages first." >&2
        exit 1
    fi
done

backup_root=${XDG_STATE_HOME:-$HOME/.local/state}/dev-choking
mkdir -p "$backup_root"
backup_dir=$(mktemp -d "$backup_root/korean-input-XXXXXXXX")
restore=$backup_dir/restore.sh
printf '#!/usr/bin/env bash\nset -euo pipefail\n' > "$restore"
for setting in "${settings[@]}"; do
    read -r schema key <<< "$setting"
    printf 'gsettings set %q %q %q\n' "$schema" "$key" \
        "$(gsettings get "$schema" "$key")" >> "$restore"
done
if [[ -e $HOME/.xinputrc || -L $HOME/.xinputrc ]]; then
    cp -a -- "$HOME/.xinputrc" "$backup_dir/xinputrc"
    printf 'cp -a -- %q %q\n' "$backup_dir/xinputrc" "$HOME/.xinputrc" >> "$restore"
else
    printf 'rm -f -- %q\n' "$HOME/.xinputrc" >> "$restore"
fi
printf 'Previous settings saved. Restore with: bash %q\n' "$restore"

# im-config refuses to overwrite a manually maintained .xinputrc.
im-config -n ibus
gsettings set org.freedesktop.ibus.general preload-engines "['hangul']"
gsettings set org.freedesktop.ibus.engine.hangul switch-keys "$switch_keys"
gsettings set org.freedesktop.ibus.engine.hangul initial-input-mode 'latin'
gsettings set org.freedesktop.ibus.engine.hangul disable-latin-mode false
gsettings set org.gnome.desktop.input-sources sources "[('ibus', 'hangul')]"

echo 'Configured Korean (Hangul), starting in English mode.'
gsettings get org.gnome.desktop.input-sources sources
gsettings get org.freedesktop.ibus.engine.hangul switch-keys
echo 'Log out and back in, or reboot, to load the installed engine and IBus session settings.'
echo 'Then open a text editor and use Shift+Space (or your chosen keys) to toggle Korean/English.'
