#!/bin/bash
# Intercepts Cmd+Q: saves full workspace to autosave.json, then quits kitty

echo "Saving workspace..."

# Run the save script to autosave
~/.config/kitty/scripts/save-session.sh autosave 2>/dev/null

echo "Quitting kitty..."

# Now actually quit kitty
osascript -e 'tell application "kitty" to quit'

# Fallback: if AppleScript didn't work, try SIGTERM
sleep 1
killall kitty 2>/dev/null
