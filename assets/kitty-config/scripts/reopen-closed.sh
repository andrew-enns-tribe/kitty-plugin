#!/bin/bash
# Browser-style Cmd+Shift+T: reopen most recently closed tab
# If the original window still exists, reopens tab in that window
# If window was closed, creates a new window at the saved position

python3 - << 'PYEOF'
import json, subprocess, sys, os, time

STACK_FILE = os.path.expanduser("~/.config/kitty/sessions/recently-closed.json")

# Load stack
if not os.path.isfile(STACK_FILE):
    sys.exit(0)

try:
    with open(STACK_FILE) as f:
        stack = json.load(f)
except:
    sys.exit(1)

if not stack:
    sys.exit(0)

# Pop most recent
entry = stack.pop()

# Save updated stack
with open(STACK_FILE, "w") as f:
    json.dump(stack, f, indent=2)

panes = entry.get("panes", [])
if not panes:
    sys.exit(0)

is_last_tab = entry.get("is_last_tab", True)
saved_pwid = entry.get("platform_window_id")
position = entry.get("position")

# Check if the original window still exists (or was already reopened)
original_window_pane = None

# First check if a previous Cmd+Shift+T already reopened this window
reopen_pane_id = entry.get("_reopen_pane_id")
if reopen_pane_id:
    try:
        kitty_data = json.loads(subprocess.check_output(["kitten", "@", "ls"]).decode())
        for o in kitty_data:
            for t in o.get("tabs", []):
                for w in t.get("windows", []):
                    if w["id"] == reopen_pane_id:
                        original_window_pane = reopen_pane_id
                        break
                if original_window_pane:
                    break
            if original_window_pane:
                break
    except:
        pass

# Then check by platform_window_id
if not original_window_pane and not is_last_tab and saved_pwid:
    try:
        kitty_data = json.loads(subprocess.check_output(["kitten", "@", "ls"]).decode())
        for o in kitty_data:
            if o.get("platform_window_id") == saved_pwid:
                for t in o.get("tabs", []):
                    for w in t.get("windows", []):
                        original_window_pane = w["id"]
                        break
                    if original_window_pane:
                        break
                break
    except:
        pass

# Collect panes that need Claude launched
claude_launches = []

first_win = panes[0]
cwd = first_win.get("cwd", os.path.expanduser("~"))
if not os.path.isdir(cwd):
    cwd = os.path.expanduser("~")

if original_window_pane:
    # Original window exists — create a new tab in it
    result = subprocess.run(
        ["kitten", "@", "launch", "--type=tab",
         "--match", f"id:{original_window_pane}",
         "--cwd=" + cwd],
        capture_output=True, text=True
    )
    first_pane_id = result.stdout.strip()
    time.sleep(0.5)
else:
    # Window is gone — create a new OS window
    result = subprocess.run(
        ["kitten", "@", "launch", "--type=os-window", "--cwd=" + cwd],
        capture_output=True, text=True
    )
    first_pane_id = result.stdout.strip()
    time.sleep(0.8)

    # Update remaining stack entries that reference the same original window
    # so the next Cmd+Shift+T creates a tab in THIS new window instead of another new one
    if saved_pwid and first_pane_id and stack:
        updated = False
        for remaining_entry in stack:
            if remaining_entry.get("platform_window_id") == saved_pwid:
                remaining_entry["_reopen_pane_id"] = int(first_pane_id)
                updated = True
        if updated:
            with open(STACK_FILE, "w") as f:
                json.dump(stack, f, indent=2)

pane_ids = [first_pane_id] if first_pane_id else []

# Create additional panes (splits) for this tab
for wi, win in enumerate(panes):
    if wi == 0:
        pane_id = first_pane_id
    else:
        win_cwd = win.get("cwd", os.path.expanduser("~"))
        if not os.path.isdir(win_cwd):
            win_cwd = os.path.expanduser("~")

        split_type = "vsplit" if wi % 2 == 1 else "hsplit"
        result = subprocess.run(
            ["kitten", "@", "launch",
             f"--location={split_type}",
             "--match", f"id:{first_pane_id}",
             "--cwd=" + win_cwd,
             "--copy-colors"],
            capture_output=True, text=True
        )
        pane_id = result.stdout.strip()
        pane_ids.append(pane_id)
        time.sleep(0.3)

    if not pane_id:
        continue

    # Apply colors
    colors = win.get("colors", {})
    if colors:
        theme_lines = [f"{k} {v}" for k, v in colors.items() if v and v.startswith("#")]
        if theme_lines:
            theme_path = f"/tmp/kitty-reopen-{pane_id}.conf"
            with open(theme_path, "w") as tf:
                tf.write("\n".join(theme_lines) + "\n")
            subprocess.run(
                ["kitten", "@", "set-colors", "--match", f"id:{pane_id}", theme_path],
                capture_output=True
            )
            os.unlink(theme_path)

    # Restore background image if saved
    user_vars = win.get("user_vars", {})
    bg_image = user_vars.get("bg_image")
    if bg_image and os.path.isfile(bg_image):
        subprocess.run(
            ["kitten", "@", "set-background-image", "--match", f"id:{pane_id}",
             "--layout", "scaled", bg_image],
            capture_output=True
        )
        subprocess.run(
            ["kitten", "@", "set-user-vars", "--match", f"id:{pane_id}",
             f"bg_image={bg_image}"],
            capture_output=True
        )

    # Queue Claude launch
    if win.get("has_claude"):
        claude_launches.append({
            "pane_id": pane_id,
            "session": win.get("claude_session")
        })

# Set tab title
if entry.get("tab_title") and pane_ids:
    subprocess.run(
        ["kitten", "@", "set-tab-title", "--match", f"id:{pane_ids[0]}", entry["tab_title"]],
        capture_output=True
    )

# Position the window (only if we created a new OS window)
if not original_window_pane and position and len(position) == 4 and first_pane_id:
    try:
        x, y, w, h = position
        subprocess.run(
            ["kitten", "@", "focus-window", "--match", f"id:{first_pane_id}"],
            capture_output=True
        )
        time.sleep(0.3)
        script = f'''
        tell application "System Events"
            tell process "kitty"
                set position of window 1 to {{{x}, {y}}}
                set size of window 1 to {{{w}, {h}}}
            end tell
        end tell
        '''
        subprocess.run(["osascript", "-e", script], capture_output=True)
    except:
        pass

# Launch Claude in all panes
if claude_launches:
    time.sleep(2.0)
    for cl in claude_launches:
        pane_id = cl["pane_id"]
        if cl["session"]:
            subprocess.run(
                ["kitten", "@", "send-text", "--match", f"id:{pane_id}",
                 f"claude --resume {cl['session']}\r"],
                capture_output=True
            )
        else:
            subprocess.run(
                ["kitten", "@", "send-text", "--match", f"id:{pane_id}",
                 "claude\r"],
                capture_output=True
            )
        time.sleep(0.2)
PYEOF
