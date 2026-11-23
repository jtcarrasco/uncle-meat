#!/usr/bin/env bash
# Install this repo's Herdr config: our mods, layouts, themes and settings into the Herdr
# app's folder, plus herdr's terminal config. Herdr's own built-in mods are never touched.
# Anything we'd overwrite that differs is backed up first. Rerun after every `git pull`.
#   ./install.sh            install
#   ./install.sh --dry-run  show what would change, change nothing
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)

APP=${HERDR_APP_HOME:-$HOME/.config/herdr-app}
TERMCONF=${HERDR_CONF_DIR:-$HOME/.config/herdr}
OS=${FAKE_OS:-$(uname -s)}
DRY=0
[[ ${1:-} == --dry-run ]] && DRY=1

backup=$APP/.backup-$(date +%Y%m%d-%H%M%S)
changed=0

# install SRC DEST: copy a file or folder into place unless it is already identical.
install_item() {
  local src=$1 dest=$2 rel=${2#"$APP"/}
  # Herdr writes editor typings into each mod folder; they aren't part of our config.
  if [[ -e $dest ]] && diff -rq -x gpui-kit.d.ts -x jsconfig.json "$src" "$dest" > /dev/null 2>&1; then
    return
  fi
  changed=$((changed + 1))
  if [[ $DRY == 1 ]]; then
    echo "would install: $rel"
    return
  fi
  if [[ -e $dest ]]; then
    mkdir -p "$backup/$(dirname "$rel")"
    cp -a "$dest" "$backup/$rel"
    rm -rf "$dest"
  fi
  mkdir -p "$(dirname "$dest")"
  cp -a "$src" "$dest"
  echo "installed: $rel"
}

for mod in "$here"/herdr-app/mods/*/; do
  install_item "${mod%/}" "$APP/mods/$(basename "$mod")"
done
# On Omarchy, the theme-set hook writes themes/omarchy.json from the current Omarchy theme.
omarchy_hook=$HOME/.config/omarchy/hooks/theme-set.d/20-herdr-app-sync
for f in "$here"/herdr-app/layouts/* "$here"/herdr-app/themes/*; do
  [[ $f == */themes/omarchy.json && -e $omarchy_hook ]] && continue
  install_item "$f" "$APP/$(basename "$(dirname "$f")")/$(basename "$f")"
done

# Herdr has no "follow the system font size" setting, so install sets the terminals'
# font_size from the system's: Omarchy's shell [font] base-size, else Ghostty's font-size.
omarchy_font_size() {
  local f=$HOME/.config/omarchy/shell.toml
  [[ -f $f ]] || return 0
  awk '/^[[:space:]]*\[/ { in_font = ($0 ~ /^[[:space:]]*\[font\][[:space:]]*$/) }
    in_font && match($0, /^[[:space:]]*base-size[[:space:]]*=[[:space:]]*"?[0-9]+(\.[0-9]+)?/) {
      v = substr($0, RSTART, RLENGTH); sub(/.*=[[:space:]]*"?/, "", v); size = v
    }
    END { print size }' "$f"
}

# Ghostty reads these in order; the last setting wins.
ghostty_font_size() {
  local f s size=
  for f in "$HOME/.config/ghostty/config" "$HOME/.config/ghostty/config.ghostty" \
    "$HOME/Library/Application Support/com.mitchellh.ghostty/config" \
    "$HOME/Library/Application Support/com.mitchellh.ghostty/config.ghostty"; do
    [[ -f $f ]] || continue
    s=$(sed -nE 's/^[[:space:]]*font-size[[:space:]]*=[[:space:]]*([0-9]+(\.[0-9]+)?)[[:space:]]*$/\1/p' "$f" | tail -n 1)
    [[ -n $s ]] && size=$s
  done
  echo "$size"
}

# Theme, appearance and font_size are per machine (Omarchy's hook sets the theme), so keep
# the local values; a system font size replaces the local font_size.
settings=$here/herdr-app/settings.json
font_size=$(omarchy_font_size)
[[ -n $font_size ]] || font_size=$(ghostty_font_size)
if command -v jq > /dev/null && [[ -f $APP/settings.json || -n $font_size ]]; then
  merged=$(mktemp)
  trap 'rm -f "$merged"' EXIT
  { cat "$APP/settings.json" 2> /dev/null || echo '{}'; } |
    jq -s --arg size "$font_size" --slurpfile repo "$settings" '$repo[0]
      + (.[0] | {theme, appearance, font_size} | with_entries(select(.value != null)))
      + (if $size == "" then {} else {font_size: ($size | tonumber)} end)' > "$merged"
  settings=$merged
elif [[ -f $APP/settings.json || -n $font_size ]]; then
  echo "jq not found: settings.json installed without the local theme or Ghostty font size"
fi
install_item "$settings" "$APP/settings.json"
# Keys: drucial's cmd- bindings are macOS-only; Linux keeps Herdr's defaults (its own keys.json).
[[ $OS == Darwin ]] && install_item "$here/herdr-app/keys.macos.json" "$APP/keys.json"
install_item "$here/herdr/config.toml" "$TERMCONF/config.toml"

if [[ $DRY == 1 ]]; then
  [[ $changed == 0 ]] && echo "already up to date"
  exit 0
fi
[[ $changed == 0 ]] && echo "already up to date"
[[ -d $backup ]] && echo "replaced files backed up to $backup"

# Load each of our mods once; a failure means Herdr would refuse it too.
status=0
if command -v herdr-app > /dev/null; then
  for mod in "$here"/herdr-app/mods/*/; do
    herdr-app check "$APP/mods/$(basename "$mod")" || status=1
  done
else
  echo "herdr-app not on PATH; skipped mod checks"
fi
exit $status
