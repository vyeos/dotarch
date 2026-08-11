#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
packages_file="$repo_root/packages/pacman-explicit.txt"
aur_file="$repo_root/packages/aur.txt"

if [[ $EUID -eq 0 ]]; then
  echo 'Run this as the regular user; sudo is requested only where needed.' >&2
  exit 1
fi

mapfile -t packages < "$packages_file"
sudo pacman -Syu --needed -- "${packages[@]}"

if [[ -s $aur_file ]]; then
  if ! command -v yay >/dev/null; then
    echo 'Install yay first, then rerun this script to install the AUR packages:' >&2
    sed 's/^/  /' "$aur_file" >&2
    exit 0
  fi
  mapfile -t aur_packages < "$aur_file"
  yay -S --needed -- "${aur_packages[@]}"
fi
