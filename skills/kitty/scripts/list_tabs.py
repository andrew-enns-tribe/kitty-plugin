#!/usr/bin/env python3
"""List all kitty tabs with global sequential numbering, CWDs, and pane IDs.

Matches the tab numbering convention used by the user's shell prompt
(1-based, global across all OS windows). CWDs are resolved via lsof on
the shell process (parent of the foreground Claude PID) because kitty's
cached CWD is unreliable.

Usage: python3 list_tabs.py
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
        ppid_out = subprocess.run(
            ["ps", "-o", "ppid=", "-p", str(claude_pid)],
            capture_output=True, text=True, timeout=5,
        ).stdout.strip()
        if not ppid_out:
            return fallback
        lsof_out = subprocess.run(
            ["lsof", "-a", "-p", ppid_out, "-d", "cwd", "-Fn"],
            capture_output=True, text=True, timeout=5,
        ).stdout
        for line in lsof_out.split("\n"):
            if line.startswith("n/"):
                return line[1:]
    except Exception:
        pass
    return fallback


def main() -> int:
    try:
        result = subprocess.run(
            ["kitten", "@", "ls"], capture_output=True, text=True, timeout=5
        )
    except Exception as e:
        print(f"Error running kitten @ ls: {e}", file=sys.stderr)
        return 1
    if result.returncode != 0 or not result.stdout.strip():
        print("kitten @ ls failed (is remote control enabled?)", file=sys.stderr)
        return 1

    data = json.loads(result.stdout)
    n = 0
    for os_window in data:
        focused = " (FOCUSED)" if os_window.get("is_focused") else ""
        print(f"OS Window {os_window['id']}{focused}:")
        for tab in os_window.get("tabs", []):
            n += 1
            for window in tab.get("windows", []):
                cwd = resolve_cwd(window.get("foreground_processes"), window.get("cwd", "?"))
                short = cwd.rstrip("/").split("/")[-1] or cwd
                title = tab.get("title", "")
                print(f"  T{n}: {short} (pane {window['id']}, title={title!r})")
                break  # one representative window per tab
    return 0


if __name__ == "__main__":
    sys.exit(main())
