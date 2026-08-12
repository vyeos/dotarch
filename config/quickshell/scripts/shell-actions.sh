#!/usr/bin/env bash
set -euo pipefail

action=${1:-}
recording_pid_file=${XDG_RUNTIME_DIR:-/run/user/$UID}/quickshell-wf-recorder.pid

recording_pid() {
  local pid
  [[ -r $recording_pid_file ]] || return 1
  read -r pid < "$recording_pid_file"
  if [[ ! $pid =~ ^[0-9]+$ ]] || [[ ! -r /proc/$pid/comm ]] || [[ $(<"/proc/$pid/comm") != wf-recorder ]]; then
    rm -f -- "$recording_pid_file"
    return 1
  fi
  printf '%s\n' "$pid"
}

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

  if device=$(wifi_device) && ! rfkill list wifi 2>/dev/null | grep -q 'blocked: yes'; then
    state=on
    network='Not connected'
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

trim() {
  local value=$1
  value=${value#"${value%%[![:space:]]*}"}
  value=${value%"${value##*[![:space:]]}"}
  printf '%s' "$value"
}

wifi_networks() {
  local device line name security signal connected known
  local -A known_networks=()

  device=$(wifi_device) || return 0

  while IFS= read -r line; do
    [[ -n $line ]] || continue
    name=$(trim "${line:2:34}")
    [[ -n $name ]] && known_networks["$name"]=1
  done < <(LC_ALL=C iwctl known-networks list 2>/dev/null \
    | sed $'s/\033\[[0-9;]*m//g' \
    | sed -n '5,$p')

  while IFS= read -r line; do
    [[ -n $line ]] || continue
    name=$(trim "${line:6:34}")
    security=$(trim "${line:40:20}")
    signal=$(trim "${line:60}")
    [[ -n $name ]] || continue

    connected=false
    [[ ${line:2:1} == '>' ]] && connected=true
    known=false
    [[ -n ${known_networks["$name"]+x} ]] && known=true
    printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$security" "$signal" "$connected" "$known"
  done < <(LC_ALL=C iwctl station "$device" get-networks rssi-dbms 2>/dev/null \
    | sed $'s/\033\[[0-9;]*m//g' \
    | sed -n '5,$p')
}

wifi_scanning() {
  local device=$1

  LC_ALL=C iwctl station "$device" show 2>/dev/null \
    | sed $'s/\033\[[0-9;]*m//g' \
    | grep -q '^[[:space:]]*Scanning[[:space:]]*yes[[:space:]]*$'
}

wifi_scan() {
  local device output cleaned
  device=$(wifi_device)

  if ! output=$(LC_ALL=C iwctl station "$device" scan 2>&1); then
    cleaned=$(printf '%s\n' "$output" | sed $'s/\033\[[0-9;]*m//g')
    if [[ $cleaned != *'Operation already in progress'* ]]; then
      printf '%s\n' "$cleaned" >&2
      return 1
    fi
  fi

  # iwctl only starts the scan. Keep the caller busy until iwd finishes so a
  # second request cannot race the operation that is already in progress.
  for _ in {1..80}; do
    wifi_scanning "$device" || return 0
    sleep 0.1
  done
}

capture_path() {
  local directory=${XDG_PICTURES_DIR:-"$HOME/Pictures"}/Screenshots
  mkdir -p "$directory"
  printf '%s/screenshot-%(%Y%m%d-%H%M%S)T.png' "$directory" -1
}

publish_capture() {
  local output=$1
  wl-copy --type image/png < "$output"
  printf '%s\n' "$output"
}

window_candidates() {
  local monitors
  monitors=$(hyprctl -j monitors)

  hyprctl -j clients | jq --argjson monitors "$monitors" '
    [
      .[]
      | select(.mapped and (.hidden | not) and .size[0] > 0 and .size[1] > 0)
      | select(
          .pinned
          or (.workspace.id as $workspace
              | any($monitors[];
                  .activeWorkspace.id == $workspace
                  or (.specialWorkspace.id != 0 and .specialWorkspace.id == $workspace)))
        )
      | {
          x: .at[0],
          y: .at[1],
          width: .size[0],
          height: .size[1],
          title: .title,
          rounded: (.fullscreen == 0 and .fullscreenClient == 0),
          focusOrder: .focusHistoryID
        }
    ]
    | sort_by(-.focusOrder)
  '
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
  wifi-list)
    if ! rfkill list wifi 2>/dev/null | grep -q 'blocked: yes'; then
      wifi_networks
    fi
    ;;
  wifi-scan)
    wifi_scan
    ;;
  wifi-connect)
    device=$(wifi_device)
    network=${2:?network name required}
    if [[ -n ${3:-} ]]; then
      iwctl --passphrase "$3" station "$device" connect "$network"
    else
      iwctl --dont-ask station "$device" connect "$network"
    fi
    ;;
  wifi-disconnect)
    device=$(wifi_device)
    iwctl station "$device" disconnect
    ;;
  brightness-get)
    brightnessctl -m | awk -F, '{ gsub(/%/, "", $4); print $4; exit }'
    ;;
  brightness-set)
    percentage=${2:?brightness percentage required}
    [[ $percentage =~ ^[0-9]+$ ]] && (( percentage >= 0 && percentage <= 100 ))
    brightnessctl set "$percentage%" >/dev/null
    ;;
  clipboard-list)
    cliphist list | head -n 50
    ;;
  clipboard-decode)
    [[ ${2:-} =~ ^[0-9]+$ ]]
    cliphist decode "$2"
    ;;
  clipboard-paste)
    [[ ${2:-} =~ ^[0-9]+$ ]]
    target=$(hyprctl activewindow -j | jq -r '.address // empty')
    [[ $target =~ ^0x[0-9a-fA-F]+$ ]]
    cliphist decode "$2" | wl-copy
    sleep 0.08
    hyprctl eval "hl.dispatch(hl.dsp.send_shortcut({ mods = \"CTRL\", key = \"V\", window = \"address:$target\" }))" >/dev/null
    ;;
  window-list)
    window_candidates
    ;;
  capture)
    mode=${2:-full}
    output=$(capture_path)
    case "$mode" in
      full)
        grim "$output"
        ;;
      *)
        printf 'unknown capture mode: %s\n' "$mode" >&2
        exit 2
        ;;
    esac
    publish_capture "$output"
    ;;
  capture-geometry)
    x=${2:?x coordinate required}
    y=${3:?y coordinate required}
    width=${4:?width required}
    height=${5:?height required}
    [[ $x =~ ^-?[0-9]+$ && $y =~ ^-?[0-9]+$ && $width =~ ^[1-9][0-9]*$ && $height =~ ^[1-9][0-9]*$ ]]
    output=$(capture_path)
    grim -g "$x,$y ${width}x${height}" "$output"
    publish_capture "$output"
    ;;
  record-toggle)
    if pid=$(recording_pid); then
      kill -INT "$pid"
      rm -f -- "$recording_pid_file"
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
      printf '%s\n' "$!" > "$recording_pid_file"
      printf 'recording-started\n'
    fi
    ;;
  record-status)
    if recording_pid >/dev/null; then
      printf 'recording-active\n'
    else
      printf 'recording-inactive\n'
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
