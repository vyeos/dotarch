#!/usr/bin/env bash
set -euo pipefail

action=${1:-}
recording_pid_file=${XDG_RUNTIME_DIR:-/run/user/$UID}/quickshell-wf-recorder.pid
night_light_state_file=${XDG_STATE_HOME:-"$HOME/.local/state"}/quickshell/night-light-temperature

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

clipboard_list() {
  local cache_dir line id preview extension image_path
  cache_dir=${XDG_RUNTIME_DIR:-/run/user/$UID}/quickshell-clipboard
  mkdir -p "$cache_dir"

  while IFS= read -r line; do
    id=${line%%$'\t'*}
    preview=${line#*$'\t'}
    if [[ $id =~ ^[0-9]+$ && $preview =~ \ (png|jpg|jpeg|webp|gif|bmp)\  ]]; then
      extension=${BASH_REMATCH[1]}
      image_path=$cache_dir/$id.$extension
      if [[ ! -s $image_path ]]; then
        cliphist decode "$id" > "$image_path"
      fi
      printf '%s\t%s\tfile://%s\n' "$id" "$preview" "$image_path"
    else
      printf '%s\n' "$line"
    fi
  done < <(cliphist list | head -n 50)
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

brightness_device() {
  local path device maximum best_device= best_maximum=-1

  for path in /sys/class/backlight/*; do
    [[ -r $path/max_brightness ]] || continue
    read -r maximum < "$path/max_brightness"
    [[ $maximum =~ ^[0-9]+$ ]] || continue
    if (( maximum > best_maximum )); then
      device=${path##*/}
      best_device=$device
      best_maximum=$maximum
    fi
  done

  [[ -n $best_device ]] || return 1
  printf '%s\n' "$best_device"
}

case "$action" in
  brightness-get)
    device=$(brightness_device)
    brightnessctl -d "$device" -m | awk -F, '{ gsub(/%/, "", $4); print $4; exit }'
    ;;
  brightness-set)
    percentage=${2:?brightness percentage required}
    [[ $percentage =~ ^[0-9]+$ ]] && (( percentage >= 0 && percentage <= 100 ))
    device=$(brightness_device)
    brightnessctl -d "$device" set "$percentage%" >/dev/null
    ;;
  night-light-status)
    command -v hyprsunset >/dev/null || { echo unavailable; exit; }
    pgrep -x hyprsunset >/dev/null && echo on || echo off
    ;;
  night-light-temperature-get)
    temperature=4500
    if [[ -r $night_light_state_file ]]; then
      read -r saved_temperature < "$night_light_state_file"
      if [[ $saved_temperature =~ ^[0-9]+$ ]] && (( saved_temperature >= 2500 && saved_temperature <= 6000 )); then
        temperature=$saved_temperature
      fi
    fi
    printf '%s\n' "$temperature"
    ;;
  night-light-toggle)
    command -v hyprsunset >/dev/null || exit 1
    temperature=${2:-4500}
    [[ $temperature =~ ^[0-9]+$ ]] && (( temperature >= 2500 && temperature <= 6000 ))
    mkdir -p -- "${night_light_state_file%/*}"
    printf '%s\n' "$temperature" > "$night_light_state_file"
    if pgrep -x hyprsunset >/dev/null; then
      pkill -x hyprsunset
    else
      hyprsunset -t "$temperature" >/dev/null 2>&1 &
    fi
    ;;
  night-light-set)
    command -v hyprsunset >/dev/null || exit 1
    temperature=${2:?night light temperature required}
    [[ $temperature =~ ^[0-9]+$ ]] && (( temperature >= 2500 && temperature <= 6000 ))
    mkdir -p -- "${night_light_state_file%/*}"
    printf '%s\n' "$temperature" > "$night_light_state_file"
    if pgrep -x hyprsunset >/dev/null; then
      hyprctl hyprsunset temperature "$temperature" >/dev/null
    fi
    ;;
  power-profile-status)
    command -v powerprofilesctl >/dev/null || { echo unavailable; exit; }
    if profile=$(powerprofilesctl get 2>/dev/null); then
      echo "$profile"
    else
      echo unavailable
    fi
    ;;
  power-profile-cycle)
    command -v powerprofilesctl >/dev/null || exit 1
    current=$(powerprofilesctl get 2>/dev/null) || exit 1
    case "$current" in
      power-saver) next=balanced ;;
      balanced) next=performance ;;
      *) next=power-saver ;;
    esac
    powerprofilesctl set "$next"
    ;;
  clipboard-list)
    clipboard_list
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
      logout) hyprctl dispatch 'hl.dsp.exit()' ;;
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
