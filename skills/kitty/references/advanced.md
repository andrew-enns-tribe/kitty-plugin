# Advanced / Niche Operations

## Markers (highlight patterns)

Highlight text in any pane. Useful for watching logs.

```bash
kitten @ create-marker --match id:PANE_ID text 1 ERROR
kitten @ create-marker --match id:PANE_ID text 2 WARNING
kitten @ remove-marker --match id:PANE_ID
```

Colors 1–3 correspond to kitty's `mark1_*` config values.

## Send Unix signals

Send signals to the foreground process in any pane.

```bash
kitten @ signal-child --match id:PANE_ID SIGINT    # Ctrl+C
kitten @ signal-child --match id:PANE_ID SIGTERM   # graceful stop
kitten @ signal-child --match id:PANE_ID SIGSTOP   # pause
kitten @ signal-child --match id:PANE_ID SIGCONT   # resume
```

## Combine actions

Chain multiple kitty actions into one invocation.

```bash
kitten @ action combine : new_window : next_layout
```

Useful when a single user trigger should fire multiple UI actions.

## Prompt navigation in scrollback

Requires shell integration (enabled in kitty.conf). These are keyboard
actions that jump between previous prompts in scrollback.

```bash
kitten @ action --match id:PANE_ID scroll_to_prompt -1   # previous prompt
kitten @ action --match id:PANE_ID scroll_to_prompt 1    # next prompt
kitten @ action --match id:PANE_ID copy_last_command_output
```

## Clear terminal modes

```bash
kitten @ action --match id:PANE_ID clear_terminal reset       # full reset
kitten @ action --match id:PANE_ID clear_terminal clear        # clear screen
kitten @ action --match id:PANE_ID clear_terminal scrollback   # scrollback only
kitten @ action --match id:PANE_ID clear_terminal scroll       # push screen into scrollback
```

## Broadcast to specific panes

True broadcast mode (type live into all panes): **Ctrl+Shift+.** —
built into kitty.

To send a single command to all panes without toggling broadcast:

```bash
kitten @ send-text --match 'state:parent_active' "command\r"
```

## Restart-required settings

These require a full kitty restart. **Warn the user before changing
them:**

- `font_family`
- `tab_bar_style`
- `cursor_shape` (sometimes)
- `hide_window_decorations`

Everything else is instant.
