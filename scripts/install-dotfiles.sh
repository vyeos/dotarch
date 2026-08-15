#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
backup_root="$HOME/.dotfiles-backups/$(date +%Y%m%d-%H%M%S)"

link_file() {
  local source=$1 target=$2
  mkdir -p "$(dirname "$target")"
  if [[ -e $target || -L $target ]]; then
    if [[ $(readlink -f -- "$target") == $(readlink -f -- "$source") ]]; then
      return
    fi
    mkdir -p "$backup_root/$(dirname "${target#$HOME/}")"
    mv -- "$target" "$backup_root/${target#$HOME/}"
  fi
  ln -s -- "$source" "$target"
}

link_file "$repo_root/home/.bashrc" "$HOME/.bashrc"
link_file "$repo_root/home/.bash_profile" "$HOME/.bash_profile"

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
github_known_hosts="$repo_root/home/.ssh/github_known_hosts"
touch "$HOME/.ssh/known_hosts"
if ! grep -Fqx -f "$github_known_hosts" "$HOME/.ssh/known_hosts"; then
  cat "$github_known_hosts" >> "$HOME/.ssh/known_hosts"
fi
chmod 600 "$HOME/.ssh/known_hosts"

for file in \
  alacritty/alacritty.toml \
  fish/config.fish fish/functions/la.fish fish/functions/ll.fish \
  hypr/hyprland.lua hypr/hypridle.conf hypr/hyprlock.conf \
  pipewire/pipewire.conf.d/51-alc285-software-volume.conf \
  systemd/user/restore-internal-mic.service \
  wireplumber/wireplumber.conf.d/51-alc285-soft-volume.conf \
  gtk-3.0/gtk.css gtk-3.0/settings.ini \
  gtk-4.0/gtk.css gtk-4.0/settings.ini; do
  link_file "$repo_root/config/$file" "$HOME/.config/$file"
done

link_file "$repo_root/config/nvim" "$HOME/.config/nvim"
link_file "$repo_root/config/quickshell" "$HOME/.config/quickshell"
link_file "$repo_root/config/vyeos" "$HOME/.config/vyeos"
touch "$HOME/.config/quickshell/.qmlls.ini"

mkdir -p "$HOME/.local/bin"
link_file "$repo_root/scripts/theme-switch" "$HOME/.local/bin/theme-switch"
link_file "$repo_root/scripts/wallpaper-set" "$HOME/.local/bin/wallpaper-set"

for theme in everforest catppuccin-mocha gruvbox nord tokyo-night rose-pine; do
  mkdir -p "${XDG_PICTURES_DIR:-$HOME/Pictures}/Wallpapers/$theme"
done

"$HOME/.config/quickshell/scripts/theme-system.sh" generate

systemctl --user daemon-reload
systemctl --user enable --now restore-internal-mic.service

themes_dir="$HOME/.config/alacritty/themes"
if [[ ! -d $themes_dir/.git ]]; then
  git clone --depth 1 https://github.com/alacritty/alacritty-theme "$themes_dir"
fi

echo "Dotfiles installed. Any replaced files were moved to: $backup_root"
