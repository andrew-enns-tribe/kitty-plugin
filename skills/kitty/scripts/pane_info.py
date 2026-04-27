#!/usr/bin/env python3
"""Dump the full state of a single kitty pane.

Captures: pane id, OS window id, platform_window_id, tab title, cwd
(resolved via lsof when Claude is running), colors (from get-colors),
user_vars (including bg_image), and split layout neighbors so a caller
can recreate the pane elsewhere.

Usage: python3 pane_info.py PANE_ID
"""
import json
import subprocess
import sys


def resolve_cwd(fg_processes, fallback):
    claude_pid = None
    for p in fg_processes or []:
        if "/bin/claude" in " ".join(p.get("cmdline", [])):
            claude_pid = p.get("pid")
            break
    if not claude_pid:
        return fallback
    try:
        ppid = subprocess.run(
            ["ps", "-o", "ppid=", "-p", str(claude_pid)],
            capture_output=True, text=True, timeout=5,
        ).stdout.strip()
        if not ppid:
            return fallback
        lsof = subprocess.run(
            ["lsof", "-a", "-p", ppid, "-d", "cwd", "-Fn"],
            capture_output=True, text=True, timeout=5,
        ).stdout
        for line in lsof.split("\n"):
            if line.startswith("n/"):
                return line[1:]
    except Exception:
        pass
    return fallback


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: pane_info.py PANE_ID", file=sys.stderr)
        return 2
    try:
        target = int(sys.argv[1])
    except ValueError:
        print("PANE_ID must be an integer", file=sys.stderr)
        return 2

    ls = subprocess.run(["kitten", "@", "ls"], capture_output=True, text=True, timeout=5)
    if ls.returncode != 0:
        print("kitten @ ls failed", file=sys.stderr)
        return 1
    data = json.loads(ls.stdout)

    info = None
    for os_window in data:
        for tab in os_window.get("tabs", []):
            for window in tab.get("windows", []):
                if window["id"] == target:
                    info = {
                        "pane_id": target,
                        "os_window_id": os_window["id"],
                        "platform_window_id": os_window.get("platform_window_id"),
                        "tab_title": tab.get("title"),
                        "tab_layout": tab.get("layout"),
                        "cwd": resolve_cwd(window.get("foreground_processes"), window.get("cwd")),
                        "user_vars": window.get("user_vars", {}),
                        "env": {k: v for k, v in (window.get("env") or {}).items()
                                if k in {"CLAUDE_SESSION_ID", "TERM", "ITERM_PROFILE"}},
                        "sibling_pane_ids": [w["id"] for w in tab.get("windows", []) if w["id"] != target],
                    }
                    break
    if info is None:
        print(f"No pane found with id {target}", file=sys.stderr)
        return 1

    colors = subprocess.run(
        ["kitten", "@", "get-colors", "--match", f"id:{target}"],
        capture_output=True, text=True, timeout=5,
    )
    if colors.returncode == 0:
        info["colors_raw"] = colors.stdout.strip()

    print(json.dumps(info, indent=2, default=str))
    return 0


if __name__ == "__main__":
    sys.exit(main())
