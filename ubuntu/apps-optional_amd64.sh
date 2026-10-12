#!/usr/bin/env bash
# Optional desktop apps for Ubuntu 22.04 (jammy) and 24.04 (noble), amd64.
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: bash apps-optional_amd64.sh [--repair-korean | --create-launcher]

Install WineHQ Stable and KakaoTalk for Windows on Ubuntu 22.04/24.04 LTS.
Run as your normal user from a desktop terminal; APT uses sudo as needed.
Complete the KakaoTalk setup wizard using its default installation folder.

  --repair-korean   Install and configure Korean fonts in the existing prefix.
                    Restart KakaoTalk after repairing; no reinstall is needed.
  --create-launcher Create application-menu and desktop shortcuts for an
                    existing KakaoTalk installation, without reinstalling it.
EOF
}

configure_korean_fonts() {
    local nanum_dir=${1:-/usr/share/fonts/truetype/nanum}
    local fonts_dir="$WINEPREFIX/drive_c/windows/Fonts"
    local substitutes='HKLM\Software\Microsoft\Windows NT\CurrentVersion\FontSubstitutes'
    local system_link='HKLM\Software\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink'
    local font_registry='HKLM\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    local backup="$WINEPREFIX/dev-choking-font-substitutes.reg"
    local links_backup="$WINEPREFIX/dev-choking-font-links.reg"
    local font

    for font in NanumGothic.ttf NanumGothicBold.ttf; do
        if [[ ! -f $nanum_dir/$font ]]; then
            echo "Missing Korean font: $nanum_dir/$font. Install fonts-nanum first." >&2
            return 1
        fi
    done
    # Save the original mappings once, including when repairing an existing prefix.
    if [[ ! -f $backup ]]; then
        wine reg export "$substitutes" "$backup" /y > /dev/null
    fi
    if [[ ! -f $links_backup ]]; then
        wine reg export "$system_link" "$links_backup" /y > /dev/null
    fi
    mkdir -p "$fonts_dir"
    install -m 0644 "$nanum_dir/NanumGothic.ttf" "$nanum_dir/NanumGothicBold.ttf" "$fonts_dir/"
    fc-cache -f "$fonts_dir"
    wine reg add "$font_registry" /v 'NanumGothic (TrueType)' \
        /t REG_SZ /d NanumGothic.ttf /f > /dev/null
    wine reg add "$font_registry" /v 'NanumGothic Bold (TrueType)' \
        /t REG_SZ /d NanumGothicBold.ttf /f > /dev/null

    # Installing host fonts alone does not redirect Wine's Windows font names.
    # Use a Korean TTF for dialog fonts and the families requested by KakaoTalk.
    for font in 'MS Shell Dlg' 'MS Shell Dlg 2' 'Segoe UI' 'Malgun Gothic' \
        Gulim GulimChe Dotum DotumChe \
        Batang BatangChe Gungsuh GungsuhChe \
        '맑은 고딕' 굴림 굴림체 돋움 돋움체 바탕 바탕체 궁서 궁서체; do
        wine reg add "$substitutes" /v "$font" /t REG_SZ /d NanumGothic /f > /dev/null
    done
    # Existing Latin font faces also need a Hangul fallback for direct GDI requests.
    for font in Tahoma Arial 'Microsoft Sans Serif'; do
        wine reg add "$system_link" /v "$font" /t REG_MULTI_SZ \
            /d 'NanumGothic.ttf,NanumGothic' /f > /dev/null
    done
    printf 'Original Wine font mappings saved to: %s\n' "$backup"
    printf 'Original Wine font links saved to: %s\n' "$links_backup"
}

find_kakaotalk_exe() {
    local program_files candidate
    for program_files in 'Program Files' 'Program Files (x86)'; do
        candidate="$WINEPREFIX/drive_c/$program_files/Kakao/KakaoTalk/KakaoTalk.exe"
        if [[ -f $candidate ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    echo 'KakaoTalk was not found in the default folder. Complete setup and rerun this script.' >&2
    return 1
}

desktop_string() {
    local value=$1
    value=${value//\\/\\\\}
    value=${value//$'\n'/\\n}
    value=${value//$'\r'/\\r}
    value=${value//$'\t'/\\t}
    printf '%s' "$value"
}

desktop_exec_arg() {
    local value=$1
    # Desktop Exec quoting is separate from shell quoting and string escaping.
    # https://specifications.freedesktop.org/desktop-entry/latest/exec-variables.html
    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    value=${value//\$/\\$}
    value=${value//\`/\\\`}
    value=${value//%/%%}
    printf '"%s"' "$(desktop_string "$value")"
}

install_kakaotalk_launchers() {
    local kakao_exe=$1
    local data_home=${XDG_DATA_HOME:-$HOME/.local/share}
    local applications_dir desktop_entry desktop_dir desktop_copy icon=system-users
    local size candidate
    [[ $data_home == /* ]] || data_home="$HOME/.local/share"
    applications_dir=$data_home/applications
    desktop_entry=$applications_dir/kakaotalk.desktop
    mkdir -p "$applications_dir" "$data_home/icons"

    # Reuse the application icon extracted by Wine's shortcut builder.
    for size in 256 96 48 32 24 16; do
        for candidate in "$data_home/icons/hicolor/${size}x${size}/apps/"*_KakaoTalk.0.png; do
            if [[ -f $candidate ]]; then
                icon=$data_home/icons/kakaotalk.png
                install -m 0644 "$candidate" "$icon"
                break 2
            fi
        done
    done
    cat > "$desktop_entry" <<EOF
[Desktop Entry]
Type=Application
Name=KakaoTalk
Name[ko]=카카오톡
Comment=Chat with KakaoTalk
Exec=env WINEARCH=win64 $(desktop_exec_arg "WINEPREFIX=$WINEPREFIX") wine $(desktop_exec_arg "$kakao_exe")
TryExec=wine
Path=$(desktop_string "${kakao_exe%/*}")
Icon=$(desktop_string "$icon")
Terminal=false
Categories=Network;InstantMessaging;
Keywords=Kakao;카카오;카카오톡;Chat;Messenger;
StartupNotify=true
StartupWMClass=kakaotalk.exe
EOF
    chmod 0644 "$desktop_entry"
    if command -v desktop-file-validate > /dev/null; then
        desktop-file-validate "$desktop_entry"
    fi
    if command -v update-desktop-database > /dev/null; then
        update-desktop-database "$applications_dir"
    fi
    printf 'Application-menu shortcut created: %s\n' "$desktop_entry"

    desktop_dir=$HOME/Desktop
    if command -v xdg-user-dir > /dev/null; then
        desktop_dir=$(xdg-user-dir DESKTOP)
    fi
    # XDG uses the home directory when the desktop folder has been disabled.
    if [[ $desktop_dir == /* && $desktop_dir != "$HOME" ]]; then
        mkdir -p "$desktop_dir"
        desktop_copy=$desktop_dir/KakaoTalk.desktop
        install -m 0755 "$desktop_entry" "$desktop_copy"
        if ! command -v gio > /dev/null || \
            ! gio set "$desktop_copy" metadata::trusted true > /dev/null 2>&1; then
            echo 'If the desktop asks, right-click KakaoTalk and choose Allow Launching.'
        fi
        printf 'Desktop shortcut created: %s\n' "$desktop_copy"
    fi
}

main() {
    local repair_korean=false create_launcher=false codename installer kakao_exe
    case ${1:-} in
        -h|--help) usage; return 0 ;;
        --repair-korean) repair_korean=true; shift ;;
        --create-launcher) create_launcher=true; shift ;;
        '') ;;
        *) usage >&2; return 1 ;;
    esac
    if (($#)); then
        usage >&2
        return 1
    fi

    if [[ $EUID -eq 0 ]]; then
        echo 'Run as your desktop user, without sudo; package installation uses sudo itself.' >&2
        return 1
    fi
    # shellcheck source=/etc/os-release
    source /etc/os-release
    case ${ID:-}:${VERSION_ID:-} in
        ubuntu:22.04) codename=jammy ;;
        ubuntu:24.04) codename=noble ;;
        *) echo 'This script supports Ubuntu 22.04 and 24.04 LTS only.' >&2; return 1 ;;
    esac
    if [[ $(dpkg --print-architecture) != amd64 ]]; then
        echo 'This script requires an amd64 (x86_64) Ubuntu installation.' >&2
        return 1
    fi

    # Keep KakaoTalk's Windows settings separate from other Wine applications.
    export WINEPREFIX="$HOME/.wine-kakaotalk"
    export WINEARCH=win64
    if $create_launcher; then
        kakao_exe=$(find_kakaotalk_exe)
        install_kakaotalk_launchers "$kakao_exe"
        return 0
    fi
    if $repair_korean; then
        if [[ ! -f $WINEPREFIX/system.reg ]] || ! command -v wine > /dev/null; then
            echo 'Install KakaoTalk with this script before using --repair-korean.' >&2
            return 1
        fi
        sudo apt-get update
        sudo apt-get install -y fontconfig fonts-nanum
        configure_korean_fonts
        echo '<dev-choking> Configured Korean fonts. Fully quit and restart KakaoTalk.'
        return 0
    fi
    if [[ -z ${DISPLAY:-} && -z ${WAYLAND_DISPLAY:-} ]]; then
        echo 'Run from a terminal inside your logged-in desktop to open the setup wizard.' >&2
        return 1
    fi

    download_dir=$(mktemp -d)
    trap 'rm -rf -- "$download_dir"' EXIT

    # WineHQ publishes separate packages for each Ubuntu release.
    # https://gitlab.winehq.org/wine/wine/-/wikis/Debian-Ubuntu
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg software-properties-common
    sudo add-apt-repository --yes --no-update universe
    sudo dpkg --add-architecture i386

    curl --fail --location --retry 3 --output "$download_dir/winehq.asc" \
        https://dl.winehq.org/wine-builds/winehq.key
    gpg --batch --dearmor --output "$download_dir/winehq-archive.key" \
        "$download_dir/winehq.asc"
    curl --fail --location --retry 3 --output "$download_dir/winehq.sources" \
        "https://dl.winehq.org/wine-builds/ubuntu/dists/$codename/winehq-$codename.sources"
    sudo install -d -m 0755 /etc/apt/keyrings
    sudo install -m 0644 "$download_dir/winehq-archive.key" /etc/apt/keyrings/winehq-archive.key
    sudo install -m 0644 "$download_dir/winehq.sources" \
        "/etc/apt/sources.list.d/winehq-$codename.sources"
    sudo apt-get update
    sudo apt-get install -y --install-recommends winehq-stable fontconfig fonts-noto-cjk fonts-nanum \
        xdg-user-dirs desktop-file-utils libglib2.0-bin

    # The non-beta Windows installer linked from Kakao's official download page.
    # https://www.kakaocorp.com/page/service/all
    installer=$download_dir/KakaoTalk_Setup.exe
    curl --fail --location --retry 3 --output "$installer" \
        https://lk.kakaocdn.net/talkpc/talk/win32/x64/KakaoTalk_Setup.exe

    wineboot --init
    winecfg -v win10
    configure_korean_fonts

    echo '<dev-choking> Opening KakaoTalk setup. Keep the default installation folder.'
    echo 'On the final page, uncheck launching KakaoTalk, then finish the wizard.'
    wine "$installer"

    # Cancelling the wizard can return success, so verify the installed application.
    kakao_exe=$(find_kakaotalk_exe)
    install_kakaotalk_launchers "$kakao_exe"

    echo '<dev-choking> Installed Wine and KakaoTalk.'
    printf 'Launch KakaoTalk with: WINEARCH=win64 WINEPREFIX=%q wine %q\n' "$WINEPREFIX" "$kakao_exe"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    main "$@"
fi
