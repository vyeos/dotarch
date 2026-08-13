#!/usr/bin/env bash
set -euo pipefail

theme_dir=${XDG_CONFIG_HOME:-"$HOME/.config"}/vyeos/themes
cache_dir=${XDG_CACHE_HOME:-"$HOME/.cache"}/vyeos/theme
state_dir=${XDG_STATE_HOME:-"$HOME/.local/state"}/vyeos

# This setup deliberately uses ~/Pictures/Wallpapers. xdg-user-dir may resolve
# PICTURES to $HOME when XDG user directories have not been configured.
pictures_dir=${XDG_PICTURES_DIR:-"$HOME/Pictures"}
wallpaper_root=$pictures_dir/Wallpapers

die() {
  printf 'theme-system: %s\n' "$*" >&2
  exit 1
}

theme_file() {
  local slug=$1
  [[ $slug =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "invalid theme name: $slug"
  [[ -f $theme_dir/$slug.json ]] || die "unknown theme: $slug"
  printf '%s\n' "$theme_dir/$slug.json"
}

current_theme() {
  local slug=everforest
  if [[ -s $state_dir/current-theme ]]; then
    IFS= read -r slug < "$state_dir/current-theme"
  fi
  if [[ ! -f $theme_dir/$slug.json ]]; then
    slug=everforest
  fi
  printf '%s\n' "$slug"
}

list_themes() {
  jq -s 'map({name, slug, appearance, colors}) | sort_by(.name)' "$theme_dir"/*.json
}

list_wallpapers() {
  local slug=${1:-$(current_theme)} directory path first=true
  theme_file "$slug" >/dev/null
  directory=$wallpaper_root/$slug
  printf '['
  if [[ -d $directory ]]; then
    while IFS= read -r -d '' path; do
      $first || printf ','
      first=false
      jq -cn --arg path "$path" --arg name "$(basename "$path")" '{name:$name,path:$path}'
    done < <(find "$directory" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \) -print0 | sort -z)
  fi
  printf ']\n'
}

open_wallpaper_folder() {
  local slug=${1:-$(current_theme)} directory
  theme_file "$slug" >/dev/null
  directory=$wallpaper_root/$slug
  mkdir -p "$directory"
  xdg-open "$directory" >/dev/null 2>&1
}

apply_folder_icons() {
  local file=$1 color source_root icon_root theme_name size source_dir target_dir source path name target
  color=$(jq -er '.applications.folder_color // "blue"' "$file")
  source_root=/usr/share/icons/Papirus-Dark
  icon_root=${XDG_DATA_HOME:-"$HOME/.local/share"}/icons
  theme_name=Vyeos-Papirus-Dark
  [[ -d $source_root ]] || return 0

  mkdir -p "$icon_root/$theme_name"
  {
    printf '[Icon Theme]\nName=Vyeos Papirus Dark\nComment=Theme-managed Papirus folder colors\n'
    printf 'Inherits=Papirus-Dark,hicolor\nDirectories='
    local separator=
    for size in 16 22 24 32 48 64; do
      printf '%s%sx%s/places' "$separator" "$size" "$size"
      separator=,
    done
    printf '\n\n'
    for size in 16 22 24 32 48 64; do
      printf '[%sx%s/places]\nContext=Places\nSize=%s\nType=Fixed\n\n' "$size" "$size" "$size"
    done
  } > "$icon_root/$theme_name/index.theme"

  for size in 16 22 24 32 48 64; do
    source_dir=$(realpath -- "$source_root/${size}x${size}/places")
    target_dir=$icon_root/$theme_name/${size}x${size}/places
    mkdir -p "$target_dir"
    find "$target_dir" -mindepth 1 -maxdepth 1 -delete
    while IFS= read -r -d '' source; do
      [[ -L $source ]] && continue
      name=$(basename "$source")
      cp -- "$source" "$target_dir/$name"
      target=${name/-$color/}
      ln -sfn -- "$name" "$target_dir/$target"
    done < <(find -L "$source_dir" -maxdepth 1 -type f \( -name "folder-$color*.svg" -o -name "user-$color*.svg" \) -print0)
  done
  gtk-update-icon-cache -qf "$icon_root/$theme_name" >/dev/null 2>&1 || true
  gsettings set org.gnome.desktop.interface icon-theme "$theme_name" >/dev/null 2>&1 || true
}

write_generated_files() {
  local file=$1 slug name appearance
  slug=$(jq -er '.slug' "$file")
  name=$(jq -er '.name' "$file")
  appearance=$(jq -er '.appearance' "$file")
  mkdir -p "$cache_dir"

  jq -e '
    .colors as $c |
    ["bg_dim","bg0","bg1","bg2","bg3","bg4","primary_container",
     "secondary_container","foreground","muted","muted_dark","red","yellow",
     "green","primary","blue","aqua","orange","purple"] |
    all(. as $key | $c[$key] | strings | test("^#[0-9a-fA-F]{6}$"))
  ' "$file" >/dev/null || die "$slug has missing or invalid colors"

  local tmp
  tmp=$(mktemp -d "$cache_dir/.generate.XXXXXX")
  trap 'rm -rf -- "$tmp"' RETURN
  cp -- "$file" "$tmp/current.json"

  {
    printf 'return {\n  name = %s,\n  slug = %s,\n' \
      "$(jq -Rn --arg value "$name" '$value')" "$(jq -Rn --arg value "$slug" '$value')"
    while IFS=$'\t' read -r key value; do
      value=${value#\#}
      printf '  %s = "rgba(%see)",\n' "$key" "$value"
    done < <(jq -r '.colors | to_entries[] | [.key,.value] | @tsv' "$file")
    printf '}\n'
  } > "$tmp/hyprland.lua"

  {
    while IFS=$'\t' read -r key value; do
      printf '$%s = rgb(%s)\n' "$key" "${value#\#}"
    done < <(jq -r '.colors | to_entries[] | [.key,.value] | @tsv' "$file")
  } > "$tmp/hyprlock.conf"

  {
    printf '[colors.primary]\nbackground = "%s"\nforeground = "%s"\n\n' \
      "$(jq -r '.colors.bg0' "$file")" "$(jq -r '.colors.foreground' "$file")"
    printf 'dim_foreground = "%s"\nbright_foreground = "%s"\n\n' \
      "$(jq -r '.colors.muted_dark' "$file")" "$(jq -r '.colors.foreground' "$file")"
    printf '[colors.cursor]\ntext = "%s"\ncursor = "%s"\n\n' \
      "$(jq -r '.colors.bg0' "$file")" "$(jq -r '.colors.primary' "$file")"
    printf '[colors.selection]\ntext = "%s"\nbackground = "%s"\n\n' \
      "$(jq -r '.colors.foreground' "$file")" "$(jq -r '.colors.bg3' "$file")"
    printf '[colors.normal]\nblack = "%s"\nred = "%s"\ngreen = "%s"\nyellow = "%s"\nblue = "%s"\nmagenta = "%s"\ncyan = "%s"\nwhite = "%s"\n\n' \
      "$(jq -r '.colors.bg_dim' "$file")" "$(jq -r '.colors.red' "$file")" \
      "$(jq -r '.colors.green' "$file")" "$(jq -r '.colors.yellow' "$file")" \
      "$(jq -r '.colors.blue' "$file")" "$(jq -r '.colors.purple' "$file")" \
      "$(jq -r '.colors.aqua' "$file")" "$(jq -r '.colors.foreground' "$file")"
    printf '[colors.bright]\nblack = "%s"\nred = "%s"\ngreen = "%s"\nyellow = "%s"\nblue = "%s"\nmagenta = "%s"\ncyan = "%s"\nwhite = "%s"\n' \
      "$(jq -r '.colors.bg4' "$file")" "$(jq -r '.colors.red' "$file")" \
      "$(jq -r '.colors.green' "$file")" "$(jq -r '.colors.yellow' "$file")" \
      "$(jq -r '.colors.blue' "$file")" "$(jq -r '.colors.purple' "$file")" \
      "$(jq -r '.colors.aqua' "$file")" "$(jq -r '.colors.foreground' "$file")"
  } > "$tmp/alacritty.toml"

  {
    printf '/* Generated from %s. */\n' "$slug"
    while IFS=$'\t' read -r key value; do
      printf '@define-color vyeos_%s %s;\n' "$key" "$value"
    done < <(jq -r '.colors | to_entries[] | [.key,.value] | @tsv' "$file")
    printf '\n@define-color accent_color @vyeos_primary;\n@define-color accent_bg_color @vyeos_primary;\n'
    printf '@define-color accent_fg_color @vyeos_bg_dim;\n@define-color destructive_color @vyeos_red;\n'
    printf '@define-color destructive_bg_color @vyeos_red;\n@define-color destructive_fg_color @vyeos_bg_dim;\n'
    printf '@define-color success_color @vyeos_green;\n@define-color warning_color @vyeos_yellow;\n@define-color error_color @vyeos_red;\n'
    printf '@define-color window_bg_color @vyeos_bg0;\n@define-color window_fg_color @vyeos_foreground;\n'
    printf '@define-color view_bg_color @vyeos_bg0;\n@define-color view_fg_color @vyeos_foreground;\n'
    printf '@define-color headerbar_bg_color @vyeos_bg1;\n@define-color headerbar_fg_color @vyeos_foreground;\n'
    printf '@define-color headerbar_border_color @vyeos_bg2;\n@define-color border_color @vyeos_bg2;\n'
    printf '@define-color popover_bg_color @vyeos_bg1;\n@define-color popover_fg_color @vyeos_foreground;\n'
    printf '@define-color tooltip_bg_color @vyeos_bg3;\n@define-color tooltip_fg_color @vyeos_foreground;\n'
    printf '@define-color sidebar_bg_color @vyeos_bg1;\n@define-color sidebar_fg_color @vyeos_foreground;\n'
    printf '@define-color menu_bg_color @vyeos_bg1;\n@define-color menu_fg_color @vyeos_foreground;\n'
    printf '@define-color card_bg_color @vyeos_bg1;\n@define-color card_fg_color @vyeos_foreground;\n'
  } > "$tmp/gtk.css"

  local primary foreground green aqua yellow red
  primary=$(jq -r '.colors.primary[1:]' "$file")
  foreground=$(jq -r '.colors.foreground[1:]' "$file")
  green=$(jq -r '.colors.green[1:]' "$file")
  aqua=$(jq -r '.colors.aqua[1:]' "$file")
  yellow=$(jq -r '.colors.yellow[1:]' "$file")
  red=$(jq -r '.colors.red[1:]' "$file")
  {
    printf 'set -gx VYEOS_THEME %s\n' "$slug"
    printf 'set -gx VYEOS_PRIMARY %s\n' "$primary"
    printf 'set -gx EZA_COLORS "di=38;2;%s:fi=38;2;%s:ex=38;2;%s:ln=38;2;%s:or=38;2;%s"\n' \
      "$(printf '%d;%d;%d' "0x${green:0:2}" "0x${green:2:2}" "0x${green:4:2}")" \
      "$(printf '%d;%d;%d' "0x${foreground:0:2}" "0x${foreground:2:2}" "0x${foreground:4:2}")" \
      "$(printf '%d;%d;%d' "0x${primary:0:2}" "0x${primary:2:2}" "0x${primary:4:2}")" \
      "$(printf '%d;%d;%d' "0x${aqua:0:2}" "0x${aqua:2:2}" "0x${aqua:4:2}")" \
      "$(printf '%d;%d;%d' "0x${red:0:2}" "0x${red:2:2}" "0x${red:4:2}")"
    printf 'set -gx VYEOS_PROMPT_PATH %s\nset -gx VYEOS_PROMPT_GIT %s\nset -gx VYEOS_PROMPT_OK %s\nset -gx VYEOS_PROMPT_ERROR %s\n' \
      "$aqua" "$yellow" "$green" "$red"
  } > "$tmp/fish.fish"

  {
    printf 'vim.cmd("highlight clear")\nvim.o.termguicolors = true\nvim.g.colors_name = "vyeos-%s"\n' "$slug"
    while IFS=$'\t' read -r group fg bg extra; do
      printf 'vim.api.nvim_set_hl(0, "%s", {' "$group"
      [[ $fg != - ]] && printf ' fg = "%s",' "$(jq -r ".colors.$fg" "$file")"
      [[ $bg != - ]] && printf ' bg = "%s",' "$(jq -r ".colors.$bg" "$file")"
      [[ $extra != - ]] && printf ' %s = true,' "$extra"
      printf ' })\n'
    done <<'HIGHLIGHTS'
Normal	foreground	bg0	-
NormalFloat	foreground	bg1	-
FloatBorder	primary	bg1	-
Comment	muted_dark	-	italic
Identifier	blue	-	-
Function	green	-	-
Statement	purple	-	-
Keyword	purple	-	-
Type	yellow	-	-
String	green	-	-
Number	orange	-	-
Constant	orange	-	-
Special	aqua	-	-
Error	red	-	bold
Visual	-	bg3	-
Search	bg_dim	yellow	-
CursorLine	-	bg1	-
LineNr	muted_dark	-	-
CursorLineNr	primary	-	bold
Pmenu	foreground	bg1	-
PmenuSel	bg_dim	primary	-
StatusLine	foreground	bg2	-
DiagnosticError	red	-	-
DiagnosticWarn	yellow	-	-
DiagnosticInfo	blue	-	-
DiagnosticHint	aqua	-	-
HIGHLIGHTS
  } > "$tmp/nvim.lua"

  for generated in "$tmp"/*; do
    mv -f -- "$generated" "$cache_dir/$(basename "$generated")"
  done
  trap - RETURN
  rmdir -- "$tmp"

  mkdir -p "$state_dir" "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"
  printf '%s\n' "$slug" > "$state_dir/current-theme"
  ln -sfn -- "$cache_dir/gtk.css" "$HOME/.config/gtk-3.0/vyeos-theme.css"
  ln -sfn -- "$cache_dir/gtk.css" "$HOME/.config/gtk-4.0/vyeos-theme.css"
  gsettings set org.gnome.desktop.interface color-scheme "prefer-$appearance" >/dev/null 2>&1 || true
}

set_wallpaper() {
  local path=${1:?wallpaper path required} slug directory resolved
  slug=$(current_theme)
  directory=$wallpaper_root/$slug
  [[ -f $path ]] || die "wallpaper does not exist: $path"
  resolved=$(realpath -- "$path")
  [[ $resolved == "$(realpath -m -- "$directory")/"* ]] || die "wallpaper is not in the $slug theme folder"
  display_wallpaper "$resolved"
  mkdir -p "$state_dir"
  printf '%s\n' "$resolved" > "$state_dir/current-wallpaper"
  mkdir -p "$state_dir/wallpapers"
  printf '%s\n' "$resolved" > "$state_dir/wallpapers/$slug"
}

display_wallpaper() {
  awww img "$1" \
    --transition-type fade \
    --transition-duration 1.4 \
    --transition-fps 60 \
    --transition-bezier 0.22,1,0.36,1
}

restore_wallpaper() {
  local slug directory saved first
  slug=$(current_theme)
  directory=$wallpaper_root/$slug
  saved=
  if [[ -s $state_dir/wallpapers/$slug ]]; then
    IFS= read -r saved < "$state_dir/wallpapers/$slug"
  elif [[ -s $state_dir/current-wallpaper ]]; then
    IFS= read -r saved < "$state_dir/current-wallpaper"
  fi
  if [[ -n $saved && -f $saved && $(realpath -- "$saved") == "$(realpath -m -- "$directory")/"* ]]; then
    display_wallpaper "$saved"
    return
  fi
  first=$(find "$directory" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \) -print -quit 2>/dev/null || true)
  if [[ -n $first ]]; then
    set_wallpaper "$first"
  else
    awww clear "$(jq -r '.colors.bg0[1:]' "$(theme_file "$slug")")" >/dev/null 2>&1 || true
  fi
}

apply_theme() {
  local slug=$1 file nautilus_was_running=false
  file=$(theme_file "$slug")
  pgrep -x nautilus >/dev/null 2>&1 && nautilus_was_running=true
  write_generated_files "$file"
  apply_folder_icons "$file"
  hyprctl reload >/dev/null 2>&1 || true
  qs ipc call theme reload >/dev/null 2>&1 || true
  restore_wallpaper || true
  if $nautilus_was_running; then
    nautilus -q >/dev/null 2>&1 || true
    setsid -f nautilus >/dev/null 2>&1 || true
  fi
  command -v notify-send >/dev/null && notify-send "Theme changed" "$(jq -r .name "$file")" >/dev/null 2>&1 || true
}

case ${1:-} in
  apply) apply_theme "${2:?theme name required}" ;;
  current) current_theme ;;
  current-json) cat "$(theme_file "$(current_theme)")" ;;
  list) list_themes ;;
  wallpapers) list_wallpapers "${2:-}" ;;
  open-wallpapers) open_wallpaper_folder "${2:-}" ;;
  wallpaper) set_wallpaper "${2:?wallpaper path required}" ;;
  restore-wallpaper) restore_wallpaper ;;
  generate) write_generated_files "$(theme_file "${2:-$(current_theme)}")" ;;
  *) die "usage: $0 {apply THEME|current|current-json|list|wallpapers [THEME]|open-wallpapers [THEME]|wallpaper PATH|restore-wallpaper|generate [THEME]}" ;;
esac
