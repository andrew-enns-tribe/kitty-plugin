#!/bin/bash
# AFK Command Center — launched by F12
# 1. Prevents sleep (caffeinate)
# 2. Activates screensaver after brief delay
# 3. Launches Claude with /kitty afk + /remote-control

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

# 1. Prevent system sleep
caffeinate -i -t 28800 &
CAFFEINATE_PID=$!
echo $CAFFEINATE_PID > /tmp/afk-caffeinate.pid

# 2. Activate screensaver after Claude has time to start
(
    sleep 12
    open -a ScreenSaverEngine
) &

# 3. Send AFK + remote-control commands after Claude loads
(
    sleep 8
    PANE=$(kitten @ ls 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
newest_id = 0
for o in data:
    for t in o.get('tabs', []):
        for w in t.get('windows', []):
            for p in w.get('foreground_processes', []):
                if '/bin/claude' in ' '.join(p.get('cmdline', [])):
                    if w['id'] > newest_id:
                        newest_id = w['id']
if newest_id:
    print(newest_id)
" 2>/dev/null)

    if [ -n "$PANE" ]; then
        kitten @ send-text --match "id:$PANE" "/kitty afk\r"
        sleep 20
        kitten @ send-text --match "id:$PANE" "/remote-control\r"
    fi
) &

# 4. Cleanup on exit
cleanup() {
    if [[ -f /tmp/afk-caffeinate.pid ]]; then
        kill $(cat /tmp/afk-caffeinate.pid) 2>/dev/null
        rm -f /tmp/afk-caffeinate.pid
    fi
}
trap cleanup EXIT

# 5. Start Claude
exec claude
