---
description: Install or repair the kitty terminal setup shipped with this plugin (themes, scripts, watcher, zsh integration).
argument-hint: [--repair | --check]
allowed-tools: [Bash, Read, Edit, Write]
---

# /install-kitty

You are the install agent for the **kitty-plugin**. Your job is to walk
the user through getting a fully working kitty terminal that the plugin's
`kitty` skill can drive. Be friendly, narrate each step in one short
sentence, and **always ask before doing anything destructive** (overwriting
existing config, editing `.zshrc`, restarting kitty, etc).

The plugin payload lives at `${CLAUDE_PLUGIN_ROOT}/assets/kitty-config/`.
The user's target is `~/.config/kitty/` and `~/.zshrc`.

## Arguments

`$ARGUMENTS` may contain:
- `--check` — only report status, don't change anything
- `--repair` — re-copy the payload over an existing install (after confirmation), don't touch zsh

If empty, do a full guided install.

## Step 0 — Sanity check

Run these in parallel:

```bash
uname -s                                              # must be Darwin (macOS)
which kitty 2>/dev/null
which brew 2>/dev/null
test -d ~/.config/kitty && echo EXISTS || echo MISSING
test -f ~/.zshrc && echo HAS_ZSHRC || echo NO_ZSHRC
fc-list 2>/dev/null | grep -i "JetBrainsMono Nerd Font" | head -1
test -f ~/.p10k.zsh && echo P10K_OK || echo P10K_MISSING
echo "$SHELL"
```

If `uname` is not Darwin, stop and tell the user this plugin is macOS-only
right now. Otherwise summarize what's installed and what's missing in 4–6
short bullets, then propose what needs to happen. **If `--check`, stop here.**

## Step 1 — Prerequisites

For each missing piece, ask the user before installing.

**kitty:** if missing → `brew install --cask kitty` (requires brew; if brew
is also missing, point them at https://brew.sh and stop).

**JetBrainsMono Nerd Font:** if missing → `brew install --cask
font-jetbrains-mono-nerd-font`. Without this font the powerline tab bar
and prompt icons render as boxes. The user can opt to skip it but warn
about the cosmetic fallout.

**Powerlevel10k:** the kitty config assumes a p10k prompt. If the user
doesn't have it, that's fine — kitty.conf doesn't require it — but the
tab-title-update zsh hook is still useful. Mention it as optional and link
https://github.com/romkatv/powerlevel10k.

## Step 2 — Back up an existing kitty config

If `~/.config/kitty/` already exists with files in it, **do not overwrite
silently**. Offer to move it aside:

```bash
ts=$(date +%Y%m%d-%H%M%S)
mv ~/.config/kitty ~/.config/kitty.backup-$ts
```

Confirm the path you backed up to. If the user wants to keep their existing
config and only add what's missing, do `--repair` mode (Step 3 with merge,
not replace).

## Step 3 — Lay down the config tree

```bash
mkdir -p ~/.config/kitty
cp -R "${CLAUDE_PLUGIN_ROOT}/assets/kitty-config/kitty.conf" ~/.config/kitty/
cp -R "${CLAUDE_PLUGIN_ROOT}/assets/kitty-config/apply-theme.sh" ~/.config/kitty/
cp -R "${CLAUDE_PLUGIN_ROOT}/assets/kitty-config/themes" ~/.config/kitty/
cp -R "${CLAUDE_PLUGIN_ROOT}/assets/kitty-config/images" ~/.config/kitty/
cp -R "${CLAUDE_PLUGIN_ROOT}/assets/kitty-config/scripts" ~/.config/kitty/
cp -R "${CLAUDE_PLUGIN_ROOT}/assets/kitty-config/watchers" ~/.config/kitty/
chmod +x ~/.config/kitty/apply-theme.sh ~/.config/kitty/scripts/*.sh
mkdir -p ~/.config/kitty/sessions
```

For `--repair`, only overwrite files in `themes/`, `images/`, `scripts/`,
`watchers/`, and `apply-theme.sh`. Diff `kitty.conf` and ask the user
which to keep before overwriting it.

## Step 4 — Inject the zsh integration block

Read `${CLAUDE_PLUGIN_ROOT}/assets/kitty-config/zshrc-snippet.zsh` and
check whether `~/.zshrc` already contains the line
`# >>> kitty-plugin integration >>>`.

- If yes → already installed. Skip.
- If no → **show the user the snippet, then ask** whether to append it to
  `~/.zshrc`. On approval, append with a leading newline so it doesn't
  smash into existing content. If the user declines, tell them the
  per-tab title rename won't work but everything else will.

If `$SHELL` isn't zsh, skip this step and tell the user how to translate
the snippet to their shell (the `kitten @ set-tab-title` line is the
only essential part).

## Step 5 — Restart kitty

Kitty has to restart for `allow_remote_control` and the watcher to take
effect.

- If kitty isn't running: tell the user to launch it.
- If kitty IS running: ask before quitting it. They might have unsaved
  work. Offer: "I can quit kitty now and you can reopen it, or you can
  Cmd+Q yourself when ready."

After restart, verify:

```bash
kitten @ ls 2>&1 | head -5
```

If that returns JSON, remote control is on and the skill will work. If it
errors, walk through troubleshooting (likely `allow_remote_control` not
honored — check that `~/.config/kitty/kitty.conf` is what got loaded, not
a leftover symlink).

## Step 6 — Smoke test

Run the skill's own status command:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/skills/kitty/scripts/list_tabs.py"
```

Should print every kitty tab with its number and CWD. If it does, you're
done — tell the user they can now invoke `/kitty <anything>` (e.g.
`/kitty open 4 panes mint in ~/code`, `/kitty save workday`,
`/kitty afk`).

## Final report

Give a short recap (4–6 bullets max):
- what was installed
- what was skipped and why
- where the backup (if any) lives
- the next thing to try (e.g. `/kitty status`)
