# Keyboard Shortcuts and kitten Tools

## Shortcuts

| Shortcut | Action |
|----------|--------|
| Cmd+T | New tab |
| Cmd+W | Close tab (saves state for undo) |
| Cmd+Shift+T | Reopen last closed tab |
| Cmd+D | Vertical split |
| Cmd+Shift+D | Horizontal split |
| Cmd+Shift+S | Smart split (auto-pick vertical or horizontal) |
| Cmd+Shift+W | Close pane |
| Cmd+Shift+Enter | Toggle stack/splits layout |
| Ctrl+Shift+H/J/K/L | Navigate between panes |
| Ctrl+Shift+. | Toggle broadcast mode (type in all panes live) |
| F10 | Command Center Dashboard TUI |
| F12 | Launch AFK Command Center |
| Cmd+Q | Save workspace and quit (intercepted) |
| Cmd+Shift+U | Open URL with hint letters |
| Cmd+Shift+F | Open file path with hint letters |

## Built-in kitten CLI tools

Besides the `kitten @` remote control, kitty ships several standalone
tools:

### Diff viewer
Side-by-side diff with syntax highlighting right in the terminal.

```bash
kitten diff file1 file2
kitten diff HEAD~1 HEAD
```

### SSH with config sync
Transfers shell config and themes to remote hosts. Per-host theme
overrides can go in `~/.config/kitty/ssh.conf`.

```bash
kitten ssh user@hostname
```

```conf
# ~/.config/kitty/ssh.conf
hostname production-*
    color_scheme coral
hostname staging-*
    color_scheme mint
```

Great for visual safety cues — red for prod, green for staging.

### Hyperlinked grep
Clickable results that open in the user's editor at the matched line.

```bash
kitten hyperlinked_grep "pattern" /path/to/search
```

### Display images inline

```bash
kitten icat /path/to/image.png
kitten icat --align center /path/to/image.png
kitten icat --scale-up /path/to/image.png
```

### File transfer over SSH

```bash
kitten transfer /local/file remote:/path/
kitten transfer remote:/path/file /local/path/
```

### Clipboard access (works over SSH)

```bash
echo "text" | kitten clipboard
kitten clipboard --get-clipboard
```

### Visual window picker / swap
Numbered overlay; press a number to focus or swap.

```bash
kitten @ action focus_visible_window
kitten @ action swap_with_window
```

### Unicode input
Opens a character picker.

```bash
kitten @ action input_unicode_character
# or: kitten unicode_input
```
