#!/bin/bash
# Save the entire kitty workspace — windows, tabs, panes, themes, positions, Claude sessions
# Usage: save-session.sh <session-name>

SESSION_NAME="${1:-default}"
SESSION_DIR="$HOME/.config/kitty/sessions"
SESSION_FILE="$SESSION_DIR/$SESSION_NAME.json"

mkdir -p "$SESSION_DIR"

python3 - "$SESSION_FILE" << 'PYEOF'
import json, subprocess, sys, os, time
from pathlib import Path

session_file = sys.argv[1]
THEMES_DIR = os.path.expanduser("~/.config/kitty/themes")


def is_claude_process(cmdline):
    """Path-anchored claude check: matches /bin/claude but not claude-dev, Claude.app, etc."""
    if not cmdline:
        return False
    exe = cmdline[0]
    return exe == "claude" or exe.endswith("/claude")


def theme_name_from_bg(bg_image):
    """Given a bg_image path like ~/.config/kitty/images/ch-creek.jpg, return 'ch-creek'
    only if a matching theme .conf exists."""
    if not bg_image:
        return None
    stem = Path(bg_image).stem
    if (Path(THEMES_DIR) / f"{stem}.conf").is_file():
        return stem
    return None

# 1. Get kitty window tree
kitty_data = json.loads(subprocess.check_output(["kitten", "@", "ls"]).decode())

# 2. Get window positions via CGWindowList (Swift) matched to platform_window_id
positions = {}
try:
    # Use Swift to get CGWindowID -> position mapping for all kitty windows
    swift_code = '''
    import CoreGraphics
    let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
    for w in windowList {
        guard let owner = w["kCGWindowOwnerName"] as? String,
              owner == "kitty",
              let layer = w["kCGWindowLayer"] as? Int,
              layer == 0,
              let wid = w["kCGWindowNumber"] as? Int,
              let bounds = w["kCGWindowBounds"] as? [String: Any],
              let x = bounds["X"] as? Double,
              let y = bounds["Y"] as? Double,
              let width = bounds["Width"] as? Double,
              let height = bounds["Height"] as? Double
        else { continue }
        print("\\(wid)|\\(Int(x)),\\(Int(y)),\\(Int(width)),\\(Int(height))")
    }
    '''
    result = subprocess.run(["swift", "-e", swift_code], capture_output=True, text=True, timeout=10)
    cg_positions = {}
    for line in result.stdout.strip().split("\n"):
        if "|" not in line:
            continue
        wid_str, coords = line.strip().split("|", 1)
        parts = coords.split(",")
        if len(parts) == 4:
            cg_positions[int(wid_str)] = [int(p) for p in parts]

    # Match kitty platform_window_id to CGWindowID
    for os_win in kitty_data:
        pwid = os_win.get("platform_window_id")
        if pwid and pwid in cg_positions:
            positions[os_win["id"]] = cg_positions[pwid]

except Exception as e:
    print(f"Warning: Could not get window positions: {e}", file=sys.stderr)

# 3. Build session data
session = {
    "name": os.path.basename(session_file).replace(".json", ""),
    "os_windows": []
}

for oi, os_win in enumerate(kitty_data):
    os_win_data = {
        "id": os_win["id"],
        "is_focused": os_win.get("is_focused", False),
        "position": positions.get(os_win["id"], None),
        "tabs": []
    }

    for tab in os_win.get("tabs", []):
        tab_data = {
            "id": tab["id"],
            "title": tab.get("title", ""),
            "is_focused": tab.get("is_focused", False),
            "layout": tab.get("layout", "splits"),
            "windows": []
        }

        for win in tab.get("windows", []):
            # Get colors for this window
            try:
                colors_raw = subprocess.check_output(
                    ["kitten", "@", "get-colors", "--match", f"id:{win['id']}"]
                ).decode().strip()
                colors = {}
                for line in colors_raw.split("\n"):
                    parts = line.strip().split()
                    if len(parts) >= 2:
                        colors[parts[0]] = parts[1]
            except:
                colors = {}

            # Detect Claude Code session
            claude_session = None
            fg_procs = win.get("foreground_processes", [])
            has_claude = False
            for proc in fg_procs:
                args = proc.get("cmdline", [])
                if is_claude_process(args):
                    has_claude = True
                    for i, arg in enumerate(args):
                        if arg in ("--resume", "-r") and i + 1 < len(args):
                            claude_session = args[i + 1]
                            break
                    break

            # If Claude is running but no --resume flag, record PID for later matching
            claude_pid = None
            if has_claude and not claude_session:
                for proc in fg_procs:
                    if is_claude_process(proc.get("cmdline", [])):
                        claude_pid = proc.get("pid")
                        break

            # Get real CWD from the shell process (lsof), not kitten's cached CWD
            real_cwd = win.get("cwd", "")
            try:
                # Find the Claude process PID, get its parent (shell), get shell's CWD
                for proc in fg_procs:
                    if is_claude_process(proc.get("cmdline", [])):
                        claude_pid = proc.get("pid")
                        if claude_pid:
                            ps_r = subprocess.run(["ps", "-o", "ppid=", "-p", str(claude_pid)],
                                                 capture_output=True, text=True, timeout=5)
                            shell_pid = ps_r.stdout.strip()
                            if shell_pid:
                                lsof_r = subprocess.run(["lsof", "-a", "-p", shell_pid, "-d", "cwd", "-Fn"],
                                                       capture_output=True, text=True, timeout=5)
                                for line in lsof_r.stdout.split("\n"):
                                    if line.startswith("n/"):
                                        real_cwd = line[1:]
                                        break
                        break
                else:
                    # No Claude process - try the first process with a real PID
                    for proc in fg_procs:
                        pid = proc.get("pid")
                        if pid:
                            lsof_r = subprocess.run(["lsof", "-a", "-p", str(pid), "-d", "cwd", "-Fn"],
                                                   capture_output=True, text=True, timeout=5)
                            for line in lsof_r.stdout.split("\n"):
                                if line.startswith("n/"):
                                    real_cwd = line[1:]
                                    break
                            break
            except Exception:
                pass

            # Capture user vars (includes bg_image tracking)
            user_vars = win.get("user_vars", {})
            theme_name = theme_name_from_bg(user_vars.get("bg_image"))

            win_data = {
                "id": win["id"],
                "is_focused": win.get("is_focused", False),
                "is_self": win.get("is_self", False),
                "cwd": real_cwd,
                "title": win.get("title", ""),
                "foreground_processes": [
                    {"cmdline": p.get("cmdline", []), "pid": p.get("pid", 0)}
                    for p in fg_procs
                ],
                "theme_name": theme_name,
                "colors": colors,
                "claude_session": claude_session,
                "user_vars": user_vars,
                "_claude_pid": claude_pid
            }
            tab_data["windows"].append(win_data)

        os_win_data["tabs"].append(tab_data)
    session["os_windows"].append(os_win_data)

# Post-process: match Claude PIDs to session files for panes sharing a CWD
from collections import defaultdict
cwd_panes = defaultdict(list)  # cwd -> list of (pane_ref, pid)

for os_win_data in session["os_windows"]:
    for tab_data in os_win_data["tabs"]:
        for win_data in tab_data["windows"]:
            pid = win_data.pop("_claude_pid", None)
            if pid and not win_data.get("claude_session"):
                cwd_panes[win_data["cwd"]].append((win_data, pid))

for cwd, pane_list in cwd_panes.items():
    try:
        slug = cwd.replace("/", "-").replace(" ", "-")
        proj_dir = os.path.join(os.path.expanduser("~/.claude/projects"), slug)
        if not os.path.isdir(proj_dir):
            continue

        # Collect session IDs already assigned (via --resume) for this CWD
        already_assigned = set()
        for os_win_data in session["os_windows"]:
            for tab_data in os_win_data["tabs"]:
                for w in tab_data["windows"]:
                    if w["cwd"] == cwd and w.get("claude_session"):
                        already_assigned.add(w["claude_session"])

        # Get .jsonl files sorted by modification time (most recent first)
        # Exclude sessions already assigned via --resume
        jsonl_files = [f for f in os.listdir(proj_dir) if f.endswith(".jsonl")]
        jsonl_files.sort(
            key=lambda f: os.path.getmtime(os.path.join(proj_dir, f)),
            reverse=True
        )
        available_sessions = [
            f.replace(".jsonl", "") for f in jsonl_files
            if f.replace(".jsonl", "") not in already_assigned
        ]

        # Sort panes by PID (higher PID = started more recently)
        pane_list.sort(key=lambda x: x[1] or 0, reverse=True)

        # Match: most recent PID -> most recently modified available session
        for i, (win_ref, pid) in enumerate(pane_list):
            if i < len(available_sessions):
                win_ref["claude_session"] = available_sessions[i]
    except Exception:
        pass

# Save atomically: write to .tmp then rename, so a partial write can't corrupt the session file
tmp_file = session_file + ".tmp"
with open(tmp_file, "w") as f:
    json.dump(session, f, indent=2)
os.replace(tmp_file, session_file)

print(f"Saved session '{session['name']}' — {len(session['os_windows'])} windows, "
      f"{sum(len(o['tabs']) for o in session['os_windows'])} tabs, "
      f"{sum(len(w['windows']) for o in session['os_windows'] for w in o['tabs'])} panes")
PYEOF
