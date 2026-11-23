# Uncle Meat

A [Herdr](https://herdr.dev) config.

My Herdr setup: the Herdr app's layout, mods, themes and keys, plus the
herdr terminal config. One repo, installed the same way on every machine (zomby, thingfish).

Starts from [Drucial/drucial-dots](https://github.com/Drucial/drucial-dots) `configs/herdr-app`
(MIT, commit `2ba6fd72`, 2026-11-11). Thanks to Drew White for the base, and to Tawsif Aqib (munza) for Better Sidebar.

## Layout

| Path | What |
|---|---|
| `herdr-app/layouts/drucial.json` | drucial's original layout (fallback) |
| `herdr-app/mods/drucial-*` | `workspace-chrome` (brand row, sidebar toggle), `spaces` (spaces grouped by machine, git status, reconnect), `agents`, `tabs`, `floats` (pop-up tool windows) |
| `herdr-app/layouts/drucial-better.json` | **Active layout.** drucial with [Better Sidebar](https://github.com/munza/herdr-mods/tree/main/better-sidebar) for spaces + agents (git branch, worktrees, GitHub PR status). Switch with `ctrl-shift-l` |
| `herdr-app/mods/better-sidebar` | munza's Better Sidebar (Apache-2.0; `third-party/munza-herdr-mods/`), plus our change: drag a machine header to reorder machine groups (saved per computer); `settings.machine_order` in its `mod.json` sets a default order for every machine. Changes are marked `herdr-config:` in the code. Runs read-only `git` in space folders and `gh pr list/view` (needs `gh auth login`) |
| `herdr-app/themes/` | Themes. On Omarchy, `themes/omarchy.json` is left to Omarchy's theme-set hook (`20-herdr-app-sync`) |
| `herdr-app/settings.json` | App settings. `theme` and `appearance` are per machine: install keeps the local values (needs `jq`). Herdr can't follow a system font size, so install sets the terminals' `font_size` from the system's: Omarchy's `[font] base-size` in `~/.config/omarchy/shell.toml`, else Ghostty's `font-size` (`~/.config/ghostty/config[.ghostty]`, or on macOS `~/Library/Application Support/com.mitchellh.ghostty/`); with neither, the local `font_size` is kept. Rerun `./install.sh` after changing the system font size. Sidebar text follows `zoom` only |
| `herdr-app/keys.macos.json` | drucial's `cmd-` key bindings, installed as `keys.json` on macOS only. Linux keeps Herdr's defaults |
| `herdr/config.toml` | herdr terminal config |

## Machines

| Machine | OS | Notes |
|---|---|---|
| zomby | macOS (MacBook Air M4) | Gets `keys.macos.json`; font size from Ghostty (16) |
| thingfish | Omarchy (Arch + Hyprland) | Herdr's default Linux keys; font size from Omarchy (16); Omarchy theme hook |

Both clone to `~/Documents/dev/github/uncle-meat`.

Other machines show up in the sidebar over SSH (each runs `herdr-core`). One that's switched off shows
"cannot reach <machine>" until it's back.

## Our changes

On top of drucial's and munza's code. Code changes are marked `herdr-config:` (this repo's earlier name).

- **Machine reordering** in Better Sidebar (2026-11-13): drag a machine header onto another to move the group.
- **Text sizes** (2026-11-13): machine names, agent names and the space beside them at 14px.
- **Font** (2026-11-13): `font` and `ui_font` = `JetBrainsMono NF`, the same as Omarchy and Ghostty.
- **Font size from the system** (2026-11-17) and **per-machine theme** (install keeps the local `theme`
  and `appearance`): see `settings.json` above.
- **+ opens on the clicked machine** (2026-11-23): the + next to a machine name and "New space there"
  left the machine out for "This computer", so Herdr used the focused space's machine instead (a new
  terminal on the Mac opened on a remote server). They now pass `machine: ""` for this computer.

## Troubleshooting

- **A new terminal opens on the wrong machine, or doesn't open:** keys and buttons that don't name a
  machine use the focused space's machine, so with a space on an offline machine focused, new
  terminals fail. Click a space on the machine you want first. `herdr-app status` shows the focused
  space and any errors.
- **"<machine> needs login":** run `hc machine login <machine>`.
- **A change didn't show up:** Herdr reloads changed mods on its own; if not, restart the app.
- **Undo an install:** copy the files back from `~/.config/herdr-app/.backup-<time>/`.

## Install / update

```bash
git clone https://github.com/jtcarrasco/uncle-meat.git ~/Documents/dev/github/uncle-meat
cd ~/Documents/dev/github/uncle-meat
./install.sh --dry-run
./install.sh
```

Update: `git pull && ./install.sh`. The script copies into `~/.config/herdr-app` and
`~/.config/herdr`, backs up anything it would overwrite that differs (to
`~/.config/herdr-app/.backup-<time>/`), leaves Herdr's built-in mods alone, then runs
`herdr-app check` on each of our mods. Herdr reloads changed mods on its own.

Edit here, not in `~/.config/herdr-app`: a local edit there is backed up and replaced on the
next install.

## Tests

`./test.sh` runs the installer against a throwaway home folder. `node --test herdr-app/tests/*.test.cjs` runs Better Sidebar's tests (munza's plus ours).
