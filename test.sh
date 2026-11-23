#!/usr/bin/env bash
# Tests for install.sh in a throwaway HOME with a fake herdr-app. Run: ./test.sh
set -u
here=$(cd "$(dirname "$0")" && pwd)
pass=0
fail=0

check() {
  local name=$1; shift
  if "$@"; then pass=$((pass + 1)); else echo "FAIL: $name"; fail=$((fail + 1)); fi
}

setup() {
  tmp=$(mktemp -d)
  export HOME=$tmp/home HERDR_APP_HOME=$tmp/home/.config/herdr-app HERDR_CONF_DIR=$tmp/home/.config/herdr
  mkdir -p "$HOME" "$tmp/bin"
  printf '#!/usr/bin/env bash\necho "$@" >> "%s/checks"\necho "check passed: $2"\n' "$tmp" > "$tmp/bin/herdr-app"
  chmod +x "$tmp/bin/herdr-app"
  export PATH="$tmp/bin:$PATH"
  unset FAKE_OS
}

run() { "$here/install.sh" "$@" > "$tmp/out" 2>&1; echo $? > "$tmp/rc"; }
rc() { [[ $(<"$tmp/rc") == "$1" ]]; }
out_has() { grep -qF -- "$1" "$tmp/out"; }
same() { cmp -s "$1" "$2"; }

# Fresh install copies our mods, layouts, themes, settings and the terminal config.
setup; run
check "fresh rc" rc 0
check "mod installed" test -f "$HERDR_APP_HOME/mods/drucial-spaces/main.js"
check "layout installed" same "$here/herdr-app/layouts/drucial.json" "$HERDR_APP_HOME/layouts/drucial.json"
check "theme installed" test -n "$(ls "$HERDR_APP_HOME/themes")"
check "settings installed" same "$here/herdr-app/settings.json" "$HERDR_APP_HOME/settings.json"
check "terminal config installed" same "$here/herdr/config.toml" "$HERDR_CONF_DIR/config.toml"
check "archive not installed" test ! -e "$HERDR_APP_HOME/mods/skillshare"

# Every installed mod is checked.
check "mods checked" bash -c "[[ \$(grep -c '^check ' '$tmp/checks') -eq \$(ls -d '$here'/herdr-app/mods/*/ | wc -l) ]]"

# Rerun: nothing changes, no backup made.
run
check "rerun rc" rc 0
check "rerun reports no changes" out_has "already up to date"
check "rerun makes no backup" bash -c "! ls -d '$HERDR_APP_HOME'/.backup-* >/dev/null 2>&1"

# Files Herdr generates inside mod folders (editor typings) don't count as differences.
touch "$HERDR_APP_HOME/mods/drucial-spaces/gpui-kit.d.ts" "$HERDR_APP_HOME/mods/drucial-spaces/jsconfig.json"
run
check "generated files ignored" out_has "already up to date"
check "generated files kept" test -e "$HERDR_APP_HOME/mods/drucial-spaces/jsconfig.json"

# A locally edited file is backed up before being replaced.
echo "// local edit" >> "$HERDR_APP_HOME/mods/drucial-spaces/main.js"
run
check "edit replaced" same "$here/herdr-app/mods/drucial-spaces/main.js" "$HERDR_APP_HOME/mods/drucial-spaces/main.js"
check "edit backed up" bash -c "grep -rq 'local edit' '$HERDR_APP_HOME'/.backup-*/mods/drucial-spaces/main.js"

# Herdr's own built-in mods are never touched.
setup; mkdir -p "$HERDR_APP_HOME/mods/spaces"; echo builtin > "$HERDR_APP_HOME/mods/spaces/main.js"; run
check "built-in mod untouched" grep -qx builtin "$HERDR_APP_HOME/mods/spaces/main.js"

# macOS keys go in as keys.json on a Mac only; Linux keys.json is left alone.
setup; FAKE_OS=Darwin run
check "mac keys installed" same "$here/herdr-app/keys.macos.json" "$HERDR_APP_HOME/keys.json"
setup; mkdir -p "$HERDR_APP_HOME"; echo '{"linux":true}' > "$HERDR_APP_HOME/keys.json"; FAKE_OS=Linux run
check "linux keys untouched" grep -q linux "$HERDR_APP_HOME/keys.json"

# Theme and appearance are per machine: kept from the existing settings, everything else from the repo.
setup; mkdir -p "$HERDR_APP_HOME"; echo '{"theme":"omarchy","appearance":"light","zoom":3}' > "$HERDR_APP_HOME/settings.json"; run
check "local theme kept" bash -c "[[ \$(jq -r .theme '$HERDR_APP_HOME/settings.json') == omarchy ]]"
check "local appearance kept" bash -c "[[ \$(jq -r .appearance '$HERDR_APP_HOME/settings.json') == light ]]"
check "repo font applied" bash -c "[[ \$(jq -r .font '$HERDR_APP_HOME/settings.json') == \"\$(jq -r .font '$here/herdr-app/settings.json')\" ]]"
check "repo zoom applied" bash -c "[[ \$(jq -r .zoom '$HERDR_APP_HOME/settings.json') == \"\$(jq -r .zoom '$here/herdr-app/settings.json')\" ]]"
run
check "merged settings rerun is clean" out_has "already up to date"

# Terminal font_size follows this machine's Ghostty font-size (last setting wins, comments ignored).
setup; mkdir -p "$HOME/.config/ghostty"; printf 'font-size = 12\n# font-size = 30\nfont-size = 16\n' > "$HOME/.config/ghostty/config"; run
check "ghostty size applied" bash -c "[[ \$(jq -r .font_size '$HERDR_APP_HOME/settings.json') == 16 ]]"
check "ghostty size is a number" bash -c "[[ \$(jq -r '.font_size | type' '$HERDR_APP_HOME/settings.json') == number ]]"
run
check "ghostty size rerun is clean" out_has "already up to date"
setup; mkdir -p "$HOME/Library/Application Support/com.mitchellh.ghostty"
echo 'font-size = 14.5' > "$HOME/Library/Application Support/com.mitchellh.ghostty/config.ghostty"; FAKE_OS=Darwin run
check "macos ghostty size applied" bash -c "[[ \$(jq -r .font_size '$HERDR_APP_HOME/settings.json') == 14.5 ]]"
setup; mkdir -p "$HOME/.config/ghostty" "$HERDR_APP_HOME"; echo 'font-size = 13' > "$HOME/.config/ghostty/config"
echo '{"font_size":20}' > "$HERDR_APP_HOME/settings.json"; run
check "ghostty size beats local size" bash -c "[[ \$(jq -r .font_size '$HERDR_APP_HOME/settings.json') == 13 ]]"
setup; mkdir -p "$HERDR_APP_HOME"; echo '{"font_size":20}' > "$HERDR_APP_HOME/settings.json"; run
check "no ghostty keeps local size" bash -c "[[ \$(jq -r .font_size '$HERDR_APP_HOME/settings.json') == 20 ]]"

# On Omarchy, the shell's [font] base-size (the system font size) wins over Ghostty.
omarchy_shell() { mkdir -p "$HOME/.config/omarchy"; printf '%s\n' "$@" > "$HOME/.config/omarchy/shell.toml"; }
setup; mkdir -p "$HOME/.config/ghostty"; echo 'font-size = 12' > "$HOME/.config/ghostty/config"
omarchy_shell '[bar]' 'base-size = 99' '' '[font]' '# base-size = 30' 'base-size = 16' '[spacing]' 'base-size = 77'; run
check "omarchy base-size applied" bash -c "[[ \$(jq -r .font_size '$HERDR_APP_HOME/settings.json') == 16 ]]"
setup; mkdir -p "$HOME/.config/ghostty"; echo 'font-size = 12' > "$HOME/.config/ghostty/config"
omarchy_shell '[font]' 'body = 15'; run
check "no omarchy base-size falls back to ghostty" bash -c "[[ \$(jq -r .font_size '$HERDR_APP_HOME/settings.json') == 12 ]]"
setup; omarchy_shell '[font]' 'base-size = "14"  # quoted'; run
check "quoted omarchy base-size applied" bash -c "[[ \$(jq -r .font_size '$HERDR_APP_HOME/settings.json') == 14 ]]"

# On Omarchy the theme-set hook owns themes/omarchy.json; install leaves it alone.
setup; mkdir -p "$HOME/.config/omarchy/hooks/theme-set.d" "$HERDR_APP_HOME/themes"
touch "$HOME/.config/omarchy/hooks/theme-set.d/20-herdr-app-sync"
echo '{"generated":true}' > "$HERDR_APP_HOME/themes/omarchy.json"; run
check "omarchy theme left to hook" grep -q generated "$HERDR_APP_HOME/themes/omarchy.json"
check "other themes still installed" test -f "$HERDR_APP_HOME/themes/win98.json"

# --dry-run reports but changes nothing.
setup; run --dry-run
check "dry-run rc" rc 0
check "dry-run lists changes" out_has "would install"
check "dry-run writes nothing" test ! -e "$HERDR_APP_HOME/mods"

# A failing mod check makes the install fail.
setup; printf '#!/usr/bin/env bash\necho "check failed: $2"; exit 1\n' > "$tmp/bin/herdr-app"; run
check "failed check rc" bash -c "[[ \$(<'$tmp/rc') != 0 ]]"
check "failed check reported" out_has "check failed"

echo "pass=$pass fail=$fail"
[[ $fail -eq 0 ]]
