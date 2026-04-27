#!/bin/bash
# Apply a kitty theme to all panes in the current OS window
# Usage: apply-theme.sh <theme-file.conf> [padding] [opacity] [font_size]
# Usage: apply-theme.sh --reset

THEME_FILE="$1"
PADDING="${2:-12}"
OPACITY="${3:-0.95}"
FONT_SIZE="${4:-14.0}"

if [[ "$1" == "--reset" ]]; then
  kitten @ ls 2>/dev/null | python3 -c "
import sys,json
data=json.load(sys.stdin)
my_id=None
for o in data:
 for t in o.get('tabs',[]):
  for w in t.get('windows',[]):
   if w.get('is_self'): my_id=o['id']
if my_id:
 for o in data:
  if o['id']==my_id:
   for t in o.get('tabs',[]):
    for w in t.get('windows',[]):
     print(w['id'])
" | while read wid; do kitten @ set-colors --match "id:$wid" --reset; done
  kitten @ set-spacing padding=8
  kitten @ set-background-opacity 0.92
  kitten @ set-font-size 14.0
  exit 0
fi

if [[ ! -f "$THEME_FILE" ]]; then
  echo "Theme file not found: $THEME_FILE"
  exit 1
fi

# Apply colors to all panes in current OS window
kitten @ ls 2>/dev/null | python3 -c "
import sys,json
data=json.load(sys.stdin)
my_id=None
for o in data:
 for t in o.get('tabs',[]):
  for w in t.get('windows',[]):
   if w.get('is_self'): my_id=o['id']
if my_id:
 for o in data:
  if o['id']==my_id:
   for t in o.get('tabs',[]):
    for w in t.get('windows',[]):
     print(w['id'])
" | while read wid; do kitten @ set-colors --match "id:$wid" "$THEME_FILE"; done

# Apply spacing, opacity, font size
kitten @ set-spacing padding="$PADDING"
kitten @ set-background-opacity "$OPACITY"
kitten @ set-font-size "$FONT_SIZE"
