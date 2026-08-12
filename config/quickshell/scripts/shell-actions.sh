#!/usr/bin/env bash
set -euo pipefail

action=${1:-}

wifi_device() {
  local path
  for path in /sys/class/net/wl*; do
    [[ -e $path ]] || continue
    basename "$path"
    return 0
  done
  return 1
}

wifi_status() {
  local state=off
  local network='Wi-Fi off'
  local device

  if ! rfkill list wifi 2>/dev/null | grep -q 'Soft blocked: yes'; then
    state=on
    network='Not connected'
  fi

  if [[ $state == on ]] && device=$(wifi_device); then
    local connected
    connected=$(iwctl station "$device" show 2>/dev/null \
      | sed $'s/\033\[[0-9;]*m//g' \
      | sed -n 's/^[[:space:]]*Connected network[[:space:]]*//p' \
      | head -n 1 \
      | sed 's/[[:space:]]*$//')
    [[ -n $connected ]] && network=$connected
  fi

  printf '%s\t%s\n' "$state" "$network"
}

capture_path() {
  local directory=${XDG_PICTURES_DIR:-"$HOME/Pictures"}/Screenshots
  mkdir -p "$directory"
  printf '%s/screenshot-%(%Y%m%d-%H%M%S)T.png' "$directory" -1
}

case "$action" in
  wifi-status)
    wifi_status
    ;;
  wifi-toggle)
    if rfkill list wifi 2>/dev/null | grep -q 'Soft blocked: yes'; then
      rfkill unblock wifi
    else
      rfkill block wifi
    fi
    ;;
  brightness-get)
    brightnessctl -m | awk -F, '{ gsub(/%/, "", $4); print $4; exit }'
    ;;
  brightness-set)
    brightnessctl set "${2:?brightness percentage required}%" >/dev/null
    ;;
  clipboard-list)
    cliphist list | head -n 50
    ;;
  clipboard-copy)
    [[ ${2:-} =~ ^[0-9]+$ ]]
    cliphist decode "$2" | wl-copy
    ;;
  capture)
    mode=${2:-region}
    output=$(capture_path)
    case "$mode" in
      full)
        grim "$output"
        ;;
      window)
        geometry=$(hyprctl -j activewindow | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
        grim -g "$geometry" "$output"
        ;;
      region)
        geometry=$(slurp)
        [[ -n $geometry ]]
        grim -g "$geometry" "$output"
        ;;
      *)
        printf 'unknown capture mode: %s\n' "$mode" >&2
        exit 2
        ;;
    esac
    wl-copy < "$output"
    printf '%s\n' "$output"
    ;;
  record-toggle)
    if pgrep -x wf-recorder >/dev/null; then
      pkill -INT -x wf-recorder
      printf 'recording-stopped\n'
    else
      command -v wf-recorder >/dev/null || {
        printf 'wf-recorder is required for screen recording\n' >&2
        exit 127
      }
      directory=${XDG_VIDEOS_DIR:-"$HOME/Videos"}/Recordings
      mkdir -p "$directory"
      output="$directory/recording-$(date +%Y%m%d-%H%M%S).mp4"
      wf-recorder -f "$output" >/dev/null 2>&1 &
      printf 'recording-started\n'
    fi
    ;;
  power)
    case "${2:-}" in
      lock)
        if command -v hyprlock >/dev/null; then
          hyprlock --config "$HOME/.config/hypr/hyprlock.conf"
        else
          loginctl lock-session
        fi
        ;;
      suspend) systemctl suspend ;;
      logout) hyprctl dispatch exit ;;
      reboot) systemctl reboot ;;
      shutdown) systemctl poweroff ;;
      *) exit 2 ;;
    esac
    ;;
  *)
    printf 'unknown action: %s\n' "$action" >&2
    exit 2
    ;;
esac
