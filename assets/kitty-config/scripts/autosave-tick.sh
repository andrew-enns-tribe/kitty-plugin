#!/bin/bash
# Periodic autosave hook, invoked by ~/Library/LaunchAgents/com.andrew.kitty-autosave.plist.
# Saves the full kitty workspace to sessions/autosave.json every 2 minutes.
# Silent no-op if kitty isn't running or RPC socket isn't present.

# launchd's PATH is minimal; ensure kitten and swift are reachable
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

SESSION_DIR="$HOME/.config/kitty/sessions"
LOG="$SESSION_DIR/autosave.log"
mkdir -p "$SESSION_DIR"

SOCKET=$(ls -t /tmp/kitty-* 2>/dev/null | head -1)
if [[ -z "$SOCKET" || ! -S "$SOCKET" ]]; then
  exit 0
fi

export KITTY_LISTEN_ON="unix:$SOCKET"

# Rotate log if it gets too big (>1MB)
if [[ -f "$LOG" ]] && [[ $(stat -f%z "$LOG" 2>/dev/null || echo 0) -gt 1048576 ]]; then
  mv "$LOG" "$LOG.old"
fi

STAMP=$(date '+%Y-%m-%d %H:%M:%S')
if out=$("$HOME/.config/kitty/scripts/save-session.sh" autosave 2>&1); then
  echo "[$STAMP] OK $out" >> "$LOG"
else
  echo "[$STAMP] FAIL $out" >> "$LOG"
fi
