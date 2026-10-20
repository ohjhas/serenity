#!/usr/bin/env bash


# ai slop script made by claude to remove calamares shortcut on desktop after installing


# Remove the Calamares installer launcher (calamares.desktop) from users'
# desktops, whatever the user name and whatever the Desktop folder is called
# in their language (Desktop, Escritorio, Schreibtisch, Bureau, Рабочий стол…).
#
#   remove-calamares-desktop.sh            as root: every regular user (+ /etc/skel)
#                                          as a user: only your own home
#   remove-calamares-desktop.sh DIR...     only the given home directories
#
# For each home it checks the folder named in ~/.config/user-dirs.dirs
# (XDG_DESKTOP_DIR) and every translated name of "Desktop" known to
# xdg-user-dirs.  Only files named exactly calamares.desktop are removed.

set -u

FILE="calamares.desktop"

# Every known translation of the Desktop folder name, read from the
# xdg-user-dirs catalogs.  msgunfmt reads them directly; otherwise fall back to
# gettext, which needs a real (non-C) locale for LANGUAGE to take effect.
desktop_names() {
    printf '%s\n' Desktop
    local mo lang loc
    if command -v msgunfmt >/dev/null; then
        for mo in /usr/share/locale/*/LC_MESSAGES/xdg-user-dirs.mo; do
            [ -e "$mo" ] || continue
            msgunfmt "$mo" 2>/dev/null |
                awk '/^msgid "Desktop"$/ { getline; sub(/^msgstr "/, ""); sub(/"$/, ""); print }'
        done
    else
        loc=$(locale -a 2>/dev/null | grep -viE '^(c|posix)([.@]|$)' | grep -iE 'utf-?8' | head -n1)
        [ -n "$loc" ] || return 0
        for mo in /usr/share/locale/*/LC_MESSAGES/xdg-user-dirs.mo; do
            [ -e "$mo" ] || continue
            lang=${mo#/usr/share/locale/}
            lang=${lang%%/*}
            LANGUAGE=$lang LC_ALL=$loc gettext -d xdg-user-dirs Desktop 2>/dev/null
            printf '\n'
        done
    fi
}

# The Desktop folder configured in HOME/.config/user-dirs.dirs, if any.
# The file is parsed, never sourced, so this is safe to run as root.
configured_desktop() {
    local home=$1 conf="$1/.config/user-dirs.dirs" line value
    [ -f "$conf" ] || return 0
    line=$(grep -m1 '^[[:space:]]*XDG_DESKTOP_DIR=' "$conf") || return 0
    value=${line#*=}
    value=${value#\"}
    value=${value%\"}
    case $value in
        '$HOME'/*) printf '%s\n' "$home/${value#\$HOME/}" ;;
        '$HOME') printf '%s\n' "$home" ;;  # desktop is the home folder itself
        /*) printf '%s\n' "$value" ;;
    esac
}

# Regular users' homes: UID 1000-59999 with an existing home, plus /root and
# /etc/skel so new accounts don't get the launcher either.
all_homes() {
    getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 { print $6 }'
    printf '%s\n' /root /etc/skel
}

if [ $# -gt 0 ]; then
    homes=("$@")
elif [ "$(id -u)" -eq 0 ]; then
    mapfile -t homes < <(all_homes)
else
    homes=("$HOME")
fi

mapfile -t names < <(desktop_names | sed '/^$/d' | sort -u)

for home in "${homes[@]}"; do
    [ -d "$home" ] || continue
    {
        configured_desktop "$home"
        for n in "${names[@]}"; do printf '%s\n' "$home/$n"; done
    } | sort -u | while IFS= read -r dir; do
        target="$dir/$FILE"
        # -f also catches a broken symlink; never follow into directories.
        if [ -f "$target" ] || [ -L "$target" ]; then
            if rm -f -- "$target"; then
                printf 'removed %s\n' "$target"
            else
                printf 'could not remove %s\n' "$target" >&2
            fi
        fi
    done
done

exit 0
