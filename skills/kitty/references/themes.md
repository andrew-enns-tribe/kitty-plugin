# Themes and Backgrounds

All themes live in `~/.config/kitty/themes/`. Apply themes with the
helper script — it handles all panes in the OS window, clears existing
background images before applying, and reads `## bg_image:` metadata
from the theme file.

```bash
# Focused OS window
~/.config/kitty/scripts/apply-theme.sh ~/.config/kitty/themes/NAME.conf PADDING OPACITY FONT_SIZE

# Specific OS window (pick any pane ID inside it)
~/.config/kitty/scripts/apply-theme.sh ~/.config/kitty/themes/NAME.conf PADDING OPACITY FONT_SIZE --match id:PANE_ID
```

Every theme's `## settings:` comment at the top lists its preferred
padding, opacity, and font size — pass those through.

**Never change tab bar colors.** They are global in kitty. Theme files
must not set `active_tab_*` or `inactive_tab_*` colors.

## Vivid (user preference — saturated, medium-tone)

| Theme | Color | Padding | Opacity | Font |
|-------|-------|---------|---------|------|
| blush | Pink | 12 | 0.95 | 14.0 |
| sky | Blue | 12 | 0.95 | 14.0 |
| peach | Orange | 12 | 0.95 | 14.0 |
| lemon | Yellow | 12 | 0.95 | 14.0 |
| mint | Green | 12 | 0.95 | 14.0 |
| lavender | Purple | 12 | 0.95 | 14.0 |
| coral | Red | 12 | 0.95 | 14.0 |
| ink | Black | 10 | 1.0 | 14.0 |
| snow | White | 14 | 0.97 | 14.0 |
| colored-paper | Kraft | 14 | 0.97 | 14.0 |

## Dark / Moody

| Theme | Vibe | Padding | Opacity | Font |
|-------|------|---------|---------|------|
| ocean-deep | Navy/cyan | 12 | 0.90 | 14.0 |
| forest-night | Woodland/green | 14 | 0.95 | 14.5 |
| sunset-warm | Amber/orange | 16 | 0.93 | 14.0 |
| midnight-purple | Violet | 10 | 0.88 | 14.0 |
| arctic-blue | Ice blue | 12 | 0.95 | 14.0 |
| rose-gold | Copper/blush | 14 | 0.92 | 14.0 |
| neon-nights | Cyberpunk | 8 | 0.95 | 13.5 |
| coffee-dark | Espresso | 16 | 0.90 | 14.5 |

## Calvin & Hobbes (all 15 — always reference the complete list)

Each ch-* theme has a matching background image at
`~/.config/kitty/images/ch-NAME.jpg`. All use padding=12, opacity=1.0
(noir uses 0.95), font_size=14.0 unless noted.

| Theme | Scene |
|-------|-------|
| ch-autumn-tree | Calvin & Hobbes napping in autumn tree — warm golden |
| ch-calvin-alone | Calvin alone in grass — teal/seafoam, contemplative |
| ch-calvin-yellow | Calvin portrait on bold yellow — bright and playful |
| ch-creek | Hobbes by a creek — watercolor nature scene |
| ch-dance-party | Calvin & Hobbes dancing on orange — energetic |
| ch-flying | Calvin & Hobbes flying with birds — light blue sky |
| ch-goofing | Calvin flexing, Hobbes goofing — light blue close-up |
| ch-log-crossing | Crossing a log over a creek — warm orange adventure |
| ch-minimal-peek | Calvin peeking, minimalist sketch on khaki |
| ch-noir | Detective Calvin noir on black (opacity 0.95) |
| ch-peeking | Calvin & Hobbes peeking from bottom — minimal beige |
| ch-sledding | Sledding in winter — white snowy scene |
| ch-stargazer | Gazing at stars — deep space navy, cosmic |
| ch-tree-nap | Napping on tree branch — green forest |
| ch-winter-walk | Winter walk — soft snowy watercolor |

**Never hardcode a subset of CH themes.** When the user says "switch to
a different Calvin and Hobbes one," pick from the table above (or run
`ls ~/.config/kitty/themes/ch-*.conf` to verify the current set).

## Auto-Rotation on New Windows

Every new kitty window gets a Calvin & Hobbes theme applied
automatically, preferring themes not already in use and falling back to
random when all 15 are taken.

- **Mechanism**: kitty watcher at `~/.config/kitty/watchers/ch_bg.py`
- **Wired in**: `~/.config/kitty/kitty.conf` with
  `watcher watchers/ch_bg.py`
- **Fires on**: `on_load` for every new window (new OS window, new tab,
  new split)
- **Override**: any subsequent `set-colors` / `apply-theme.sh` /
  `set-background-image` call overrides the auto-applied theme — so
  workspace-open commands like "open 4 panes mint in Tribe Hub" still
  end up mint, because apply-theme.sh runs after the watcher.

## Custom Themes

User prefers VIVID, saturated, medium-tone themes — not pastel. Theme
file format:

```conf
## name: my-theme
## blurb: Short description
## settings: padding=12 opacity=0.95 font_size=14.0
## bg_image: ~/.config/kitty/images/optional-bg.jpg

foreground       #...
background       #...
cursor           #...
# color0..color15 as usual
```

The `## settings:` and `## bg_image:` comments are read by
apply-theme.sh — do not omit them.

## Background Images vs Window Logos

Two ways to place images in panes, with different behavior.

**`set-background-image`** — edge to edge, goes under padding.

```bash
kitten @ set-background-image --match id:PANE_ID --layout configured /path/to/image.jpg
kitten @ set-background-image --match id:PANE_ID none     # remove
```

**`set-window-logo`** — sits inside padding, doesn't reach edges. Good
for subtle watermarks.

```bash
kitten @ set-window-logo --match id:PANE_ID --alpha 0.3 --position center /path/to/image.png
kitten @ set-window-logo --match id:PANE_ID none
```

**Never use `--all` with `set-background-image`.** It affects every
window globally and is hard to undo. Always use `--match id:PANE_ID`.

### Tagging Panes

Always pair `set-background-image` with `set-user-vars` so save/load
and the auto-rotator can see what image is on the pane:

```bash
kitten @ set-background-image --match id:PANE_ID --layout configured /path/to/image.jpg
kitten @ set-user-vars --match id:PANE_ID bg_image=/path/to/image.jpg
```

### Changing Themes with Existing BG Image

Always clear the existing background image before applying a new theme
— otherwise the old image covers the new colors. `apply-theme.sh`
does this automatically. If applying colors directly:

```bash
kitten @ set-background-image --match id:PANE_ID none
kitten @ set-user-vars --match id:PANE_ID bg_image=
kitten @ set-colors --match id:PANE_ID ~/.config/kitty/themes/THEME.conf
```

Skip the clear only if the new theme also has a `## bg_image:` —
apply-theme.sh will read that metadata and re-apply.

### Readable Text Over Images

For images with busy regions, create the canvas cream/beige/off-white,
place the subject smaller and centered on it, and fade image opacity
via PIL's `ImageEnhance` on the alpha channel. Then set a darker
foreground with `kitten @ set-colors --match id:PANE_ID foreground=#2a2520`.

### Image Format and Directory

Store permanent images at `~/.config/kitty/images/` (never `/tmp/`).

- **Dimensions**: 845×1080 (~0.78:1), matching the user's typical pane shape
- **Format**: JPEG — PNG can be flaky with kitty, JPEG is reliable
- **Layout**: `cscaled` is set globally in kitty.conf; always use
  `--layout configured` with `set-background-image` to pick that up
- Use `sips` for format conversions (more reliable than PIL with kitty)
