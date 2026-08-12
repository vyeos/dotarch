#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
system_root="$repo_root/system/etc"
backup_root="/root/.dotfiles-backups/$(date +%Y%m%d-%H%M%S)"

if [[ $EUID -ne 0 ]]; then
  exec sudo -- "$0" "$@"
fi

install_file() {
  local source=$1 target=$2
  if [[ -e $target ]]; then
    mkdir -p "$backup_root/$(dirname "${target#/}")"
    cp -a -- "$target" "$backup_root/${target#/}"
  fi
  install -Dm644 "$source" "$target"
}

install_file "$system_root/pacman.conf" /etc/pacman.conf
install_file "$system_root/mkinitcpio.conf" /etc/mkinitcpio.conf
install_file "$system_root/locale.conf" /etc/locale.conf
install_file "$system_root/vconsole.conf" /etc/vconsole.conf
install_file "$system_root/sddm.conf.d/10-wayland.conf" /etc/sddm.conf.d/10-wayland.conf
install_file "$system_root/sddm.conf.d/20-theme.conf" /etc/sddm.conf.d/20-theme.conf
install_file "$system_root/NetworkManager/conf.d/20-dns.conf" /etc/NetworkManager/conf.d/20-dns.conf
install_file "$system_root/systemd/zram-generator.conf" /etc/systemd/zram-generator.conf

systemctl disable iwd.service >/dev/null 2>&1 || true
systemctl disable systemd-networkd.service >/dev/null 2>&1 || true
systemctl enable sddm.service NetworkManager.service systemd-resolved.service bluetooth.service

echo 'System configuration installed.'
echo "Replaced files were backed up under: $backup_root"
echo 'Before rebooting: create /etc/fstab for this host, link /etc/resolv.conf to'
echo '/run/systemd/resolve/stub-resolv.conf, then run locale-gen and mkinitcpio -P.'
