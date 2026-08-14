#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

if [[ $EUID -ne 0 ]]; then
  exec sudo -- "$0" "$@"
fi

desktop_user=${1:-${SUDO_USER:-$(stat -c %U "$repo_root")}}
[[ $desktop_user != root ]] || { echo 'Unable to determine the desktop user for SDDM theme state.' >&2; exit 1; }
desktop_home=$(getent passwd "$desktop_user" | cut -d: -f6)
desktop_group=$(id -gn "$desktop_user")
silent_theme=/usr/share/sddm/themes/silent
shared_cache=/var/cache/vyeos-sddm
backup_root=/root/.dotfiles-backups/$(date +%Y%m%d-%H%M%S)

[[ -d $silent_theme ]] || { echo 'The sddm-silent-theme package must be installed first.' >&2; exit 1; }

install_link() {
  local source=$1 target=$2
  if [[ -e $target || -L $target ]]; then
    if [[ $(readlink -f -- "$target") == $(readlink -f -- "$source") ]]; then
      return
    fi
    mkdir -p "$backup_root/$(dirname "${target#/}")"
    cp -a -- "$target" "$backup_root/${target#/}"
    rm -f -- "$target"
  fi
  mkdir -p "$(dirname "$target")"
  ln -s -- "$source" "$target"
}

install -d -m755 -o "$desktop_user" -g "$desktop_group" "$shared_cache"
install_link "$shared_cache/theme.conf.user" "$silent_theme/configs/everforest.conf.user"
install_link "$shared_cache/vyeos-wallpaper.jpg" "$silent_theme/backgrounds/vyeos-wallpaper.jpg"

theme_helper=$desktop_home/.config/quickshell/scripts/theme-system.sh
if [[ -x $theme_helper ]]; then
  runuser -u "$desktop_user" -- env \
    HOME="$desktop_home" \
    XDG_CONFIG_HOME="$desktop_home/.config" \
    XDG_CACHE_HOME="$desktop_home/.cache" \
    XDG_STATE_HOME="$desktop_home/.local/state" \
    "$theme_helper" generate
fi

echo 'SDDM theme synchronization installed.'
