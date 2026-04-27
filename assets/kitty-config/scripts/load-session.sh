#!/bin/bash
# Restore a saved kitty workspace — windows, tabs, panes, themes, positions, Claude sessions
# Usage: load-session.sh <session-name>
# Creates ALL new windows — does NOT touch the current window.

SESSION_NAME="${1:-default}"
SESSION_DIR="$HOME/.config/kitty/sessions"
SESSION_FILE="$SESSION_DIR/$SESSION_NAME.json"

if [[ ! -f "$SESSION_FILE" ]]; then
    echo "Session not found: $SESSION_FILE"
    echo "Available sessions:"
    ls "$SESSION_DIR"/*.json 2>/dev/null | while read f; do basename "$f" .json; done
    exit 1
fi

python3 - "$SESSION_FILE" << 'PYEOF'
import json, subprocess, sys, time, os

session_file = sys.argv[1]
THEMES_DIR = os.path.expanduser("~/.config/kitty/themes")


def is_claude_process(cmdline):
    if not cmdline:
        return False
    exe = cmdline[0]
    return exe == "claude" or exe.endswith("/claude")

with open(session_file) as f:
    session = json.load(f)

print(f"Loading session '{session['name']}'...")

def wait_for_shell(pane_id, timeout=3.0):
    """Wait until the shell is ready in a pane before sending text."""
    start = time.time()
    while time.time() - start < timeout:
        time.sleep(0.3)
        try:
            ls_data = json.loads(subprocess.check_output(["kitten", "@", "ls"]).decode())
            for o in ls_data:
                for t in o.get("tabs", []):
                    for w in t.get("windows", []):
                        if str(w.get("id")) == str(pane_id):
                            fg = w.get("foreground_processes", [])
                            for p in fg:
                                cmd = " ".join(p.get("cmdline", []))
                                if "zsh" in cmd or "bash" in cmd or "fish" in cmd:
                                    return True
        except:
            pass
    return False

def get_os_window_for_pane(pane_id):
    """Get the OS window ID that contains a given pane."""
    try:
        ls_data = json.loads(subprocess.check_output(["kitten", "@", "ls"]).decode())
        for o in ls_data:
            for t in o.get("tabs", []):
                for w in t.get("windows", []):
                    if str(w.get("id")) == str(pane_id):
                        return o["id"]
    except:
        pass
    return None

# Collect all panes that need Claude launched (do these last with delays)
claude_launches = []

for oi, os_win in enumerate(session["os_windows"]):
    tabs = os_win.get("tabs", [])
    if not tabs:
        continue

    # Track the first pane of this OS window so we can target it for additional tabs
    os_win_first_pane = None

    for ti, tab in enumerate(tabs):
        windows = tab.get("windows", [])
        if not windows:
            continue

        first_win = windows[0]
        cwd = first_win.get("cwd", os.path.expanduser("~"))
        if not os.path.isdir(cwd):
            cwd = os.path.expanduser("~")

        if ti == 0:
            # First tab — create a new OS window
            result = subprocess.run(
                ["kitten", "@", "launch", "--type=os-window", "--cwd=" + cwd],
                capture_output=True, text=True
            )
            first_pane_id = result.stdout.strip()
            os_win_first_pane = first_pane_id
            time.sleep(0.8)
        else:
            # Additional tabs — target the correct OS window using --match
            result = subprocess.run(
                ["kitten", "@", "launch", "--type=tab",
                 "--match", f"id:{os_win_first_pane}",
                 "--cwd=" + cwd],
                capture_output=True, text=True
            )
            first_pane_id = result.stdout.strip()
            time.sleep(0.5)

        # Track pane IDs for this tab
        pane_ids = [first_pane_id] if first_pane_id else []

        # Create additional panes (splits) for this tab
        for wi, win in enumerate(windows):
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
                time.sleep(0.5)

            if not pane_id:
                continue

            # Apply colors to this pane.
            # Prefer theme_name (points at a .conf file) since it's exact and cheap.
            # Fall back to saved color dict for older sessions or panes without a theme tag.
            theme_name = win.get("theme_name")
            theme_path = None
            if theme_name:
                cand = os.path.join(THEMES_DIR, f"{theme_name}.conf")
                if os.path.isfile(cand):
                    theme_path = cand

            if theme_path:
                subprocess.run(
                    ["kitten", "@", "set-colors", "--match", f"id:{pane_id}", theme_path],
                    capture_output=True
                )
            else:
                colors = win.get("colors", {})
                if colors:
                    theme_lines = []
                    for key, value in colors.items():
                        if value and value.startswith("#"):
                            theme_lines.append(f"{key} {value}")
                    if theme_lines:
                        tmp_theme = f"/tmp/kitty-restore-{pane_id}.conf"
                        with open(tmp_theme, "w") as tf:
                            tf.write("\n".join(theme_lines) + "\n")
                        subprocess.run(
                            ["kitten", "@", "set-colors", "--match", f"id:{pane_id}", tmp_theme],
                            capture_output=True
                        )
                        os.unlink(tmp_theme)

            # Restore background image if one was saved.
            # Use layout=configured to match the watcher/apply-theme.sh (global cscaled).
            user_vars = win.get("user_vars", {})
            bg_image = user_vars.get("bg_image")
            if bg_image and os.path.isfile(bg_image):
                subprocess.run(
                    ["kitten", "@", "set-background-image", "--match", f"id:{pane_id}",
                     "--layout", "configured", bg_image],
                    capture_output=True
                )
                # Re-tag the pane with the bg_image user var
                subprocess.run(
                    ["kitten", "@", "set-user-vars", "--match", f"id:{pane_id}",
                     f"bg_image={bg_image}"],
                    capture_output=True
                )

            # Restore any other user vars
            for var_name, var_value in user_vars.items():
                if var_name != "bg_image":
                    subprocess.run(
                        ["kitten", "@", "set-user-vars", "--match", f"id:{pane_id}",
                         f"{var_name}={var_value}"],
                        capture_output=True
                    )

            # Queue Claude launches for later (needs shell to be ready)
            fg_procs = win.get("foreground_processes", [])
            has_claude = any(is_claude_process(p.get("cmdline", [])) for p in fg_procs)
            claude_session = win.get("claude_session")

            if has_claude:
                claude_launches.append({
                    "pane_id": pane_id,
                    "session": claude_session,
                    "cwd": win.get("cwd", "")
                })

        # Set tab title
        if tab.get("title") and pane_ids:
            subprocess.run(
                ["kitten", "@", "set-tab-title", "--match", f"id:{pane_ids[0]}", tab["title"]],
                capture_output=True
            )

    # Position this OS window BEFORE creating the next one
    pos = os_win.get("position") or os_win.get("bounds")  # support both formats
    if pos and len(pos) == 4 and os_win_first_pane:
        try:
            # New format: [x, y, width, height]
            # Old format: [x, y, x2, y2] — detect by checking if values look like bounds
            x, y = pos[0], pos[1]
            if pos[2] > 3000 or pos[3] > 3000:
                # Likely old bounds format
                w = pos[2] - pos[0]
                h = pos[3] - pos[1]
            else:
                w, h = pos[2], pos[3]

            # Focus the OS window first, then position window 1 (frontmost)
            subprocess.run(
                ["kitten", "@", "focus-window", "--match", f"id:{os_win_first_pane}"],
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
            time.sleep(0.3)
        except:
            pass

# Now launch Claude in all panes simultaneously
if claude_launches:
    print(f"Launching Claude in {len(claude_launches)} panes...")
    time.sleep(2.0)  # Let all shells fully initialize

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
        time.sleep(0.2)  # Tiny gap between sends, but they all launch ~simultaneously

total_panes = sum(len(w.get("windows", [])) for o in session["os_windows"] for w in o.get("tabs", []))
print(f"Restored session '{session['name']}' — {len(session['os_windows'])} windows, "
      f"{sum(len(o['tabs']) for o in session['os_windows'])} tabs, {total_panes} panes")
PYEOF
