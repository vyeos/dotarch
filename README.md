# vyeos Arch setup

This repository captures the portable parts of this Arch Linux setup: explicit
packages, desktop and shell configuration, and the system configuration that is
not tied to a particular disk or account. It intentionally excludes credentials,
browser profiles, caches, histories, SSH/GPG keys, and host-specific filesystem
UUIDs.

Fish universal variables are also excluded: they are application-managed state
and currently contain an account-specific path.

## Fresh Arch installation

1. Install `git` before cloning (for example, include it in the initial
   `pacstrap` package list). Partition the disk, create the Btrfs subvolumes documented in
   `system/templates/fstab.template`, mount the target, and generate its own
   `/etc/fstab` with `genfstab -U`.
2. Clone this repository as the target user and run `scripts/install-packages.sh`.
   It installs the explicit pacman packages. For the AUR packages, bootstrap
   `yay` with the [AUR instructions](https://aur.archlinux.org/packages/yay),
   then rerun the script.
3. Run `scripts/install-system.sh`, then `sudo locale-gen` and
   `sudo mkinitcpio -P`. The installer enables SDDM, iwd, and Bluetooth.
4. Run `scripts/install-dotfiles.sh`. It creates symlinks and moves any replaced
   files to `~/.dotfiles-backups/<timestamp>/`.

`config/alacritty/alacritty.toml` expects the upstream
[`alacritty-theme`](https://github.com/alacritty/alacritty-theme) repository;
the dotfiles installer clones it automatically.

The T3 Code desktop entry is retained only as a local reference: it is not
installed because it points to a version-specific AppImage path.

The dotfiles installer creates a persistent PipeWire software-volume sink for
the laptop speakers. The physical ALC285 sink must remain at 100% because its
hardware volume affects the main speakers but not the bass-speaker DAC. Volume
keys control the virtual sink, attenuating both paths equally.

The installer also enables a user service that restores the built-in
Ryzen/ALC285 microphone to its 0 dB hardware baseline (shown as 10%) and unmutes it whenever the
audio session starts. The WirePlumber soft-mixer workaround is limited to
playback so it does not force the microphone's hardware gain to maximum.
