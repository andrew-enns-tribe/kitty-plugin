---
name: kitty
description: "Control kitty terminal: themes, layouts, workspaces, window management, detach/merge, get text, AFK mode. Usage: /kitty theme blue, /kitty open 4 panes mint in tribe hub, /kitty save workday, /kitty afk, /kitty snap left, /kitty status"
user_invocable: true
---

# Kitty Terminal Controller

Full control of kitty terminal via `kitten @` remote control and
AppleScript. The user describes what they want in plain English. Parse
the intent and use the appropriate commands below.

Examples of intent:
- "restore everything" → load from autosave.json
- "open a workspace in Tribe Hub" → new OS window, cd, launch Claude
- "open 4 panes mint in agent2agent" → new OS window, 2×2 grid, apply mint, claude per pane
- "detach this pane" → `kitten @ detach-window --target-tab new`
- "move window 3 to the right half" → find W3, snap right
- "get the text from window 2" → extract screen text from W2

## Companion Resources

- `scripts/` — reusable helpers (run directly; don't re-inline)
- `references/themes.md` — full theme list (Vivid, Dark/Moody, **all 15 Calvin & Hobbes**), custom themes, bg images
- `references/afk.md` — AFK command center mode, stuck-session restart runbook
- `references/flags.md` — `--match` vs `-m` cheat sheet (critical — wrong one fails)
- `references/shortcuts.md` — keyboard shortcuts, built-in kitten tools (diff, ssh, icat, transfer, grep)
- `references/advanced.md` — markers, signals, combine, prompt nav, clear modes, broadcast

## Tab Numbering Convention

Tabs show **`{N}: {directory}`** — global sequential across all OS
windows (1-based). When the user says "tab 3," they mean the tab
currently showing number 3. Enumerate:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/skills/kitty/scripts/list_tabs.py"
```

CWDs in that output are resolved via `lsof` on the shell process
(parent of the Claude PID) — kitty's cached CWD is unreliable.

The user can refer to windows by:
- Number ("tab 3", "W5")
- Project name ("the Tribe Hub one")
- Theme color ("the green one")
- Position ("the big one on the left", "the one on my MacBook")

## Creating Workspaces

```bash
# New OS window in a directory
PANE1=$(kitten @ launch --type=os-window --cwd=/path/to/dir)
sleep 0.8

# 2 panes (side by side)
PANE2=$(kitten @ launch --location=vsplit --match id:$PANE1 --cwd=/path --copy-colors)

# 4 panes — ALWAYS 2×2 grid (vsplit first, then hsplit each side)
PANE2=$(kitten @ launch --location=vsplit --match id:$PANE1 --cwd=/path --copy-colors)
sleep 0.3
PANE3=$(kitten @ launch --location=hsplit --match id:$PANE1 --cwd=/path --copy-colors)
sleep 0.3
PANE4=$(kitten @ launch --location=hsplit --match id:$PANE2 --cwd=/path --copy-colors)

# 3 panes — one left, two stacked right
PANE2=$(kitten @ launch --location=vsplit --match id:$PANE1 --cwd=/path --copy-colors)
PANE3=$(kitten @ launch --location=hsplit --match id:$PANE2 --cwd=/path --copy-colors)

# Apply theme to the whole OS window
~/.config/kitty/scripts/apply-theme.sh ~/.config/kitty/themes/THEME.conf PADDING OPACITY FONT_SIZE

# Launch Claude in each pane after shells are ready
sleep 2
kitten @ send-text --match id:$PANE1 "claude\r"
kitten @ send-text --match id:$PANE2 "claude\r"
```

**For 4 panes, always 2×2. Never stack 3 panes on one side.**

New windows auto-get a Calvin & Hobbes theme via the kitty watcher
(`~/.config/kitty/watchers/ch_bg.py`). Any later
`apply-theme.sh` overrides it — so "4 panes mint" still ends mint.

## Apply a Theme

Use the helper so all panes in the OS window change together and bg
images get cleared/re-applied correctly:

```bash
# Focused OS window
~/.config/kitty/scripts/apply-theme.sh ~/.config/kitty/themes/NAME.conf PADDING OPACITY FONT_SIZE

# Specific OS window
~/.config/kitty/scripts/apply-theme.sh ~/.config/kitty/themes/NAME.conf PADDING OPACITY FONT_SIZE --match id:PANE_ID
```

Read the `## settings:` comment in each `.conf` file for its
padding/opacity/font_size. **Never change tab bar colors** — they are
global in kitty.

Full theme catalog (including all 15 Calvin & Hobbes) and background
image rules live in `references/themes.md`.

## Restore After Cmd+Q

On Cmd+Q, kitty auto-saves to `autosave.json`. If the user says they
accidentally quit:

```bash
~/.config/kitty/scripts/load-session.sh autosave
```

Restores all windows, tabs, panes, themes, positions, and resumes
Claude sessions.

## Save / Load Sessions

```bash
~/.config/kitty/scripts/save-session.sh NAME
~/.config/kitty/scripts/load-session.sh NAME
ls ~/.config/kitty/sessions/*.json 2>/dev/null | while read f; do basename "$f" .json; done
```

Captures OS window positions/sizes, tabs, panes, split layouts, CWDs,
per-pane colors, and Claude session IDs. Load resumes Claude with
`claude --resume`. Positions captured via Swift CGWindowList matched to
`platform_window_id`; CWDs via `lsof` on the shell parent of the
Claude PID.

## Detach / Merge

```bash
kitten @ detach-window --target-tab new                          # current pane → new OS window
kitten @ detach-window --target-tab new-tab                       # current pane → new tab, same window
kitten @ detach-window --match id:PANE_ID --target-tab new        # specific pane → new OS window
kitten @ detach-tab --target-tab new                              # entire tab → new OS window
kitten @ detach-tab --match id:SRC_PANE --target-tab id:TGT_PANE  # merge tab into another window
```

## Get Text from a Pane

```bash
kitten @ get-text                                      # current pane, visible screen
kitten @ get-text --match id:PANE_ID                    # specific pane
kitten @ get-text --extent all                          # scrollback + screen
kitten @ get-text --extent screen                       # just visible
kitten @ get-text --extent last_cmd_output              # last command's output
```

## Search Across Panes

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/skills/kitty/scripts/search_panes.py" "PATTERN"
```

Use when the user asks "which pane mentioned X?" or "find errors in
all my terminals."

## Snap / Position via AppleScript

Always get screen dimensions first (the external monitor is above the
MacBook, so monitor coords have negative Y):

```bash
osascript -e 'tell application "Finder" to get bounds of window of desktop'
```

```bash
kitten @ focus-window --match id:PANE_ID
sleep 0.3
osascript -e 'tell application "System Events" to tell process "kitty" to set position of window 1 to {X, Y}'
osascript -e 'tell application "System Events" to tell process "kitty" to set size of window 1 to {W, H}'
```

**Save original position before moving** so you can restore.

## Focus / Zen Modes

```bash
# Focus
kitten @ set-font-size 18.0
kitten @ set-spacing padding=20
kitten @ goto-layout stack

# Zen
kitten @ set-font-size 16.0
kitten @ set-spacing padding=24
kitten @ set-background-opacity 0.88
kitten @ goto-layout stack

# Exit either
kitten @ set-font-size 14.0
kitten @ set-spacing padding=8
kitten @ set-background-opacity 0.92
kitten @ goto-layout splits
```

## Natural Language Window Control

To find a specific pane:
1. `python3 "${CLAUDE_PLUGIN_ROOT}/skills/kitty/scripts/list_tabs.py"` for
   numbering + CWDs
2. `kitten @ get-colors --match id:PANE_ID` to match by theme color
3. `python3 "${CLAUDE_PLUGIN_ROOT}/skills/kitty/scripts/pane_info.py" PANE_ID`
   for full state (platform_window_id, colors, bg, siblings)

Once targeted, anything is possible:
- Snap/resize/move — focus first with `kitten @ focus-window`, then
  AppleScript
- Change theme, opacity, padding, font — see `references/flags.md` for
  which commands take `--match` vs `-m`
- Splits: `kitten @ launch --location=vsplit --match id:PANE_ID --cwd=current --copy-colors`
- Send anything: `kitten @ send-text --match id:PANE_ID "any text\r"` (\r = Enter)
- Launch Claude: `kitten @ send-text --match id:PANE_ID "claude\r"`
- Close: `kitten @ close-window --match id:PANE_ID`
- Detach: `kitten @ detach-window --match id:PANE_ID --target-tab new`

When applying a theme directly (not via apply-theme.sh), target the
current pane with `$KITTY_WINDOW_ID`. See `references/flags.md`.

## Enable Remote Control Everywhere

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/skills/kitty/scripts/enable_remote_control.py"
```

Skips the caller's pane via `KITTY_WINDOW_ID`.

## Broadcast

Toggle live broadcast: **Ctrl+Shift+.**  (built-in).

Send to all panes once: `kitten @ send-text --match 'state:parent_active' "cmd\r"`.

## Screenshots

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/skills/kitty/scripts/screenshot_pane.py" PANE_ID [OUTPUT.png]
```

Looks up the OS window's `platform_window_id` and runs
`screencapture -l`.

## Status

```bash
kitten @ ls
kitten @ get-colors
```

Parse into a clean summary: window numbers, themes, CWDs, pane counts.

## AFK Mode

When the user says "afk" or `/kitty afk`, read `references/afk.md` and
run the startup sequence there. AFK turns this pane into a command
center that manages every other agent session — Claude or Codex CLI.
Usually controlled from the user's phone via Claude mobile.

## Quick Adjustments

```bash
kitten @ set-font-size SIZE
kitten @ set-background-opacity N
kitten @ set-spacing padding=N
kitten @ set-tab-title "TITLE"
```

## Restart Warning

Font family, tab bar style, cursor shape, and window decorations
require a kitty restart. Everything else is instant. **Warn the user
before changing any of them.**

## Response Style

Keep it short. Confirm what changed. No lengthy explanations.
