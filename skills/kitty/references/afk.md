# AFK Mode

AFK (Away From Keyboard) mode turns this pane into a command center
that manages every other Claude session. The user triggers it with
`/kitty afk` — usually via F12, which launches a new kitty window,
starts Claude, and auto-sends `/kitty afk` then `/remote-control`. The
user then controls everything from their phone via Claude mobile.

This session IS the command center agent.

## Startup Sequence

Run these on entry:

1. **Rename this session**:
   ```bash
   kitten @ send-text --match id:$KITTY_WINDOW_ID "/rename AFK Command Center\r"
   ```

2. **Enable /remote-control on every other Claude pane, then send Enter
   to confirm**:
   ```bash
   python3 ${CLAUDE_PLUGIN_ROOT}/skills/kitty/scripts/enable_remote_control.py
   ```
   The script skips the caller's own pane using `KITTY_WINDOW_ID`.

3. **Rename each Claude pane with descriptive context**. For each pane
   that got remote-control enabled, read its screen text and CWD, then:
   ```bash
   kitten @ send-text --match id:PANE_ID "/rename DirectoryName — Short Context\r"
   ```
   Naming convention: `DirectoryName — Short Context`. Examples:
   - `Tribe Hub` (single session in that dir)
   - `OpenClaw — Auth0 SSO` (dir + what it was doing)
   - `SCC — Unstaff Feature`
   - `Panasonic — Code Review`

4. **Sweep status** of every pane:
   ```bash
   python3 ${CLAUDE_PLUGIN_ROOT}/skills/kitty/scripts/session_status.py
   ```

5. **Report to user** with a summary:
   ```
   AFK Mode Active. Here's your terminals:
   - Staffing Command Center: idle, remote control on
   - Recruiter Assistant (2 panes): thinking (3m 20s), remote control on
   - Agent2Agent: idle, remote control on
   - Tribe Hub: idle, remote control on
   - openclaw (2 panes): idle, remote control on
   - Panasonic: idle, remote control on

   What do you want me to do?
   ```

## Commands While in AFK Mode

### Session management
- "What are my sessions doing?" → re-run `session_status.py`
- "Which ones are idle?" → filter idle from status output
- "Which ones are stuck?" → flag panes thinking for a long time
- "Restart the stuck one" → see Restart a Stuck Session below
- "Send 'run the tests' to Tribe Hub" →
  `kitten @ send-text --match id:PANE_ID "run the tests\r"`
- "Send this to all idle sessions: ..." → broadcast via get-text
  filtering for idle first, then send-text to each
- "Start remote control everywhere" → re-run
  `enable_remote_control.py`

### App/system management (AppleScript + macOS CLI)
- Open apps: `osascript -e 'tell application "X" to get name of every process whose background only is false'`
- Launch: `osascript -e 'tell application "Notion" to activate'`
- Chrome to URL: `osascript -e 'tell application "Google Chrome" to open location "URL"'`
- Quit Chrome: `osascript -e 'tell application "Google Chrome" to quit'`
- Hide everything except kitty:
  `osascript -e 'tell application "System Events" to set visible of every process whose name is not "kitty" to false'`
- Lock screen:
  `osascript -e 'tell application "System Events" to key code 12 using {control down, command down}'`
- Turn on Do Not Disturb: `shortcuts run "Turn On Focus"`
- Battery: `pmset -g batt`
- WiFi: `networksetup -getairportnetwork en0`

### Clipboard
- "What's on my clipboard?" → `kitten clipboard --get-clipboard`
- "Copy this: ..." → `echo "text" | kitten clipboard`
- "Copy output from Tribe Hub" →
  `kitten @ get-text --match id:PANE_ID --extent last_cmd_output | kitten clipboard`

## Restart a Stuck Session

When a pane's Claude has been thinking >10 min or its spinner is
frozen:

1. **Capture full state** of the stuck pane:
   ```bash
   python3 ${CLAUDE_PLUGIN_ROOT}/skills/kitty/scripts/pane_info.py PANE_ID
   ```
   That dumps: OS window ID, platform_window_id, CWD (lsof-resolved),
   tab title, layout, user_vars (including `bg_image`), siblings, and
   raw colors. Save this output — you'll recreate the pane from it.

2. **Read the queued message** from the screen text — look for lines
   after the spinner showing a user message that got queued:
   ```bash
   kitten @ get-text --match id:PANE_ID --extent screen
   ```

3. **Get the Claude session ID** from the most recently modified
   `.jsonl` in `~/.claude/projects/` for that CWD:
   ```bash
   # Match the CWD's mangled project dir name; grab newest .jsonl
   ls -t ~/.claude/projects/PROJECT_DIR/*.jsonl | head -1
   ```

4. **Capture window position** via Swift CGWindowList matched to
   `platform_window_id` (see save-session.sh for the Swift
   invocation).

5. **Close the pane**: `kitten @ close-window --match id:PANE_ID`

6. **Reopen with same state**:
   - Only pane in its tab → new OS window:
     `kitten @ launch --type=os-window --cwd=CWD`
   - Was a split → launch in same location with sibling:
     `kitten @ launch --location=vsplit --match id:SIBLING --cwd=CWD --copy-colors`
   - Apply colors: `kitten @ set-colors --match id:NEW_PANE THEME.conf`
   - Apply bg image if there was one:
     `kitten @ set-background-image --match id:NEW_PANE --layout configured IMAGE`
   - Set user_vars: `kitten @ set-user-vars --match id:NEW_PANE "bg_image=IMAGE"`
   - Restore window position via AppleScript
     (`tell application "System Events" to tell process "kitty" to set position/size of window 1`)
   - Tab title: `kitten @ set-tab-title --match id:NEW_PANE TITLE`
   - Wait for shell, launch Claude with resume:
     `kitten @ send-text --match id:NEW_PANE "claude --resume SESSION_ID\r"`
   - Wait for Claude to load, enable remote control:
     `kitten @ send-text --match id:NEW_PANE "/remote-control\r"`

7. **Report** to user: "Restarted the Tribe Hub session. It was stuck
   on: 'any activity from andrei on git recently?'. Want me to resend
   that message?"

8. **Resend only if user confirms**:
   `kitten @ send-text --match id:NEW_PANE "the message\r"`

## Screenshots for Verification

After a restart or major change, take a screenshot of the affected
window:

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/skills/kitty/scripts/screenshot_pane.py PANE_ID /tmp/verify.png
```

**Remote control cannot send screenshots to the user's phone.** Describe
what you see with `kitten @ get-text` instead. If the user is at their
computer, `open -a Preview /tmp/verify.png`.

## MCP Integrations in AFK Mode

The command center has access to every MCP. Useful combos:

- **Slack** (`mcp__claude_ai_Slack__*`, `mcp__slack__*`): check DMs,
  search channels, reply on the user's behalf. "Check if anyone
  messaged me," "Reply to Kim saying I'll look at it tomorrow."
- **Notion** (`mcp__notion__*`): update project statuses, check
  roadmap, create tasks. "Update Panasonic status to In Progress."
- **Sybill** (`mcp__sybill__*`): check sales calls, deals,
  conversation summaries.

## Context Awareness

Maintain awareness of:
- Which sessions are running and what they're working on
  (`session_status.py` plus `kitten @ get-text`)
- Which sessions have remote control enabled (footer shows "Remote
  Control active")
- Session context usage levels — suggest compaction proactively when a
  pane approaches its limit
- User activity cadence — if the user has sent no commands for a
  while, poll less aggressively

When the user asks "what's going on?", do a full sweep: all panes via
status script, Slack DMs, recent git activity, and give a concise
summary.
