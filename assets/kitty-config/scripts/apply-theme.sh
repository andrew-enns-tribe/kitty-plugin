#!/bin/bash
# Apply a theme to ALL panes in a target OS window
# Usage: apply-theme.sh <theme.conf> [padding] [opacity] [font_size] [--match id:PANE_ID]
#
# If --match is provided, applies to all panes in that pane's OS window.
# If not provided, uses KITTY_WINDOW_ID to find current OS window.
# Reads ## bg_image: from theme metadata and applies it too.

THEME_FILE="$1"
PADDING="${2:-12}"
OPACITY="${3:-0.95}"
FONT_SIZE="${4:-14.0}"
TARGET_PANE=""

# Parse --match from any position
shift 4 2>/dev/null
while [[ $# -gt 0 ]]; do
    case "$1" in
        --match) TARGET_PANE="$2"; shift 2 ;;
        *) shift ;;
    esac
done

if [[ -z "$THEME_FILE" ]]; then
    echo "Usage: apply-theme.sh <theme.conf> [padding] [opacity] [font_size] [--match id:PANE_ID]"
    exit 1
fi

if [[ ! -f "$THEME_FILE" ]]; then
    echo "Theme not found: $THEME_FILE"
    exit 1
fi

# Read bg_image from theme metadata
BG_IMAGE=$(grep '## bg_image:' "$THEME_FILE" | sed 's/## bg_image: //' | sed "s|~|$HOME|g")

# Find all pane IDs in the target OS window
MY_WIN_ID="${KITTY_WINDOW_ID:-0}"
PANE_IDS=$(kitten @ ls 2>/dev/null | python3 -c "
import json, sys, os
data = json.load(sys.stdin)
target = '${TARGET_PANE}'
my_id = int('${MY_WIN_ID}')

target_os = None

# Method 1: explicit --match id:X
if target and target.startswith('id:'):
    tid = int(target.replace('id:', ''))
    for o in data:
        for t in o.get('tabs', []):
            for w in t.get('windows', []):
                if w['id'] == tid:
                    target_os = o
                    break
            if target_os: break
        if target_os: break

# Method 2: use KITTY_WINDOW_ID to find our OS window
if not target_os and my_id:
    for o in data:
        for t in o.get('tabs', []):
            for w in t.get('windows', []):
                if w['id'] == my_id:
                    target_os = o
                    break
            if target_os: break
        if target_os: break

# Method 3: fallback to is_focused
if not target_os:
    for o in data:
        if o.get('is_focused'):
            target_os = o
            break

if not target_os:
    print('ERROR: could not find target OS window', file=sys.stderr)
    sys.exit(1)

for t in target_os.get('tabs', []):
    for w in t.get('windows', []):
        if not w.get('is_self'):
            print(w['id'])
")

if [[ -z "$PANE_IDS" ]]; then
    echo "No panes found"
    exit 1
fi

# Apply theme to each pane
COUNT=0
while IFS= read -r pane_id; do
    # Clear existing background image first
    kitten @ set-background-image --match "id:$pane_id" none 2>/dev/null
    kitten @ set-user-vars --match "id:$pane_id" bg_image= 2>/dev/null

    # Apply colors (uses --match)
    kitten @ set-colors --match "id:$pane_id" "$THEME_FILE" 2>/dev/null

    # These commands use -m not --match
    kitten @ set-spacing -m "id:$pane_id" "padding=$PADDING" 2>/dev/null
    kitten @ set-background-opacity -m "id:$pane_id" "$OPACITY" 2>/dev/null
    kitten @ set-font-size -m "id:$pane_id" "$FONT_SIZE" 2>/dev/null

    # Apply background image if theme has one
    if [[ -n "$BG_IMAGE" && -f "$BG_IMAGE" ]]; then
        kitten @ set-background-image --match "id:$pane_id" --layout configured "$BG_IMAGE" 2>/dev/null
        kitten @ set-user-vars --match "id:$pane_id" "bg_image=$BG_IMAGE" 2>/dev/null
    fi

    COUNT=$((COUNT + 1))
done <<< "$PANE_IDS"

echo "Applied to $COUNT pane(s)"
