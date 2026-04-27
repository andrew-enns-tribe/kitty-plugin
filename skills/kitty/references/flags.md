# `--match` vs `-m` Flag Reference

Some `kitten @` commands use `--match`, others use `-m`. Using the
wrong one causes "Unknown option" errors. This cheat sheet is the
definitive list — check here before running a targeted command.

## Uses `--match`

- `set-colors`
- `set-background-image`
- `set-user-vars`
- `set-tab-title`
- `set-window-logo`
- `send-text`
- `get-text`
- `get-colors`
- `close-window`
- `close-tab`
- `focus-window`
- `detach-window`
- `detach-tab`
- `launch`
- `signal-child`
- `create-marker`
- `remove-marker`

## Uses `-m`

- `set-spacing`
- `set-background-opacity`
- `set-font-size`

## No Match Flag

These all work without any match flag — they apply to the focused or
active window.

## Targeting the Current Pane

Always use `$KITTY_WINDOW_ID` when applying changes directly (not via
`apply-theme.sh`):

```bash
kitten @ set-colors --match "id:$KITTY_WINDOW_ID" theme.conf
kitten @ set-spacing -m "id:$KITTY_WINDOW_ID" padding=12
kitten @ set-background-opacity -m "id:$KITTY_WINDOW_ID" 1.0
kitten @ set-background-image --match "id:$KITTY_WINDOW_ID" --layout configured /path/to/image.jpg
```
