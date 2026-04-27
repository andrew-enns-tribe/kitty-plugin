# kitty-plugin

A Claude Code plugin that turns kitty into a power-user terminal you
control with plain English. Ships:

- A `kitty` skill — Claude understands prompts like `/kitty open 4 panes
  mint in ~/code`, `/kitty save workday`, `/kitty afk`,
  `/kitty snap left`, `/kitty status`
- 38 themes including all 15 hand-picked Calvin & Hobbes backgrounds
- An auto-rotating watcher that gives every new kitty window its own CH
  scene
- Save/restore sessions across reboots — windows, tabs, splits, themes,
  positions, even Claude session resumes
- An "AFK Command Center" mode (F12) that turns one kitty window into a
  Claude session that controls every other Claude session, useful from
  your phone over Claude mobile
- Helper scripts the skill uses: enumerate panes, snapshot pane text,
  enable remote control everywhere, screenshot a specific kitty window,
  and more

## Install

```text
/plugin install kitty@<your-marketplace>
/install-kitty
```

`/install-kitty` walks you through everything: it checks for kitty,
JetBrainsMono Nerd Font, and an existing config; backs up anything it's
about to overwrite; copies the kitty config tree into place; offers to
add a small zsh integration block to `~/.zshrc`; and restarts kitty.

It asks before doing anything destructive.

For a non-destructive status check: `/install-kitty --check`.
To re-copy the assets onto an existing install: `/install-kitty --repair`.

## What gets installed

| Path | What |
| --- | --- |
| `~/.config/kitty/kitty.conf` | Main config (transparency, splits layout, remote control on, custom keybinds) |
| `~/.config/kitty/themes/*.conf` | 38 themes |
| `~/.config/kitty/images/*.jpg` | 15 Calvin & Hobbes backgrounds |
| `~/.config/kitty/scripts/*.sh` | 8 helper scripts (save/load sessions, AFK launcher, etc.) |
| `~/.config/kitty/watchers/ch_bg.py` | Per-window CH theme rotator |
| `~/.config/kitty/apply-theme.sh` | Theme applier (whole-OS-window) |
| `~/.zshrc` | Adds a small block (with your consent) that auto-renames each tab to its CWD |

The Claude skill itself is loaded from the plugin install path — it does
not touch `~/.claude/skills/`.

## Requirements

- macOS (Apple Silicon or Intel)
- Homebrew (the install command uses `brew install --cask kitty` and
  `brew install --cask font-jetbrains-mono-nerd-font` if either is
  missing)
- zsh — required only for the auto-tab-rename hook. Everything else works
  on any shell.
- Powerlevel10k recommended but optional

## Custom keybinds

| Key | Action |
| --- | --- |
| Cmd+T | New tab in current cwd |
| Cmd+W | Close current pane (auto-saves recently-closed list) |
| Cmd+Shift+T | Reopen last closed tab |
| Cmd+D / Cmd+Shift+D | Vertical / horizontal split |
| Cmd+Shift+S | Smart split (auto-picks based on pane shape) |
| Ctrl+Shift+H/J/K/L | Move focus between panes |
| Cmd+Shift+Enter | Toggle stack layout (zoom current pane) |
| Cmd+Q | Save the whole workspace before quitting |
| F12 | Launch AFK Command Center |

## Skill commands you can ask for

The skill is conversational. Try:

- `/kitty status` — list every window/tab with theme + cwd
- `/kitty theme mint` — apply mint to the focused OS window
- `/kitty open 4 panes ocean-deep in ~/code` — new OS window, 2×2 grid, theme applied
- `/kitty save workday` — snapshot every window's positions, themes, splits, claude sessions
- `/kitty load workday` — restore that snapshot
- `/kitty restore everything` — restore the autosave kitty made on Cmd+Q
- `/kitty afk` — turn this pane into the command center
- `/kitty snap window 3 to the right half`
- `/kitty get the text from window 2`
- `/kitty detach this pane`

The skill knows about `--match` vs `-m` flag quirks and resolves CWDs via
`lsof` (kitty's cached CWD is unreliable).

## Excluded from the package

- The `command-center/` TUI dashboard (custom Andrew tooling, requires
  npm + tsx). The corresponding F10 keybind is omitted from the shipped
  `kitty.conf`.
- User-specific `sessions/` snapshots.

## License

MIT
