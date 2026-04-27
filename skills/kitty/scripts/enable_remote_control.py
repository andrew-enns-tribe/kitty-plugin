#!/usr/bin/env python3
"""Discover every agent pane (Claude or Codex) and enable /remote-control on the Claude ones.

Reads KITTY_WINDOW_ID from the environment to skip the calling pane.
For each Claude pane: sends `/remote-control\r`, waits, sends a confirming Enter.
For each Codex pane: just reports it. Codex CLI has no /remote-control command,
but the AFK orchestrator can still drive it via `kitten @ send-text` and read it
via `kitten @ get-text`.

Output format (one line per discovered pane):
    [claude rc-enabled] pane=PANE_ID os_window=OS_WINDOW_ID
    [codex driveable] pane=PANE_ID os_window=OS_WINDOW_ID

Usage: python3 enable_remote_control.py
"""
import json
import os
import subprocess
import sys
import time


def detect_agent(window: dict) -> str | None:
    """Return 'claude', 'codex', or None based on foreground processes."""
    fg = window.get("foreground_processes", [])
    for p in fg:
        joined = " ".join(p.get("cmdline", []))
        if "/bin/claude" in joined:
            return "claude"
        if "/bin/codex" in joined or joined.endswith(" codex") or joined == "codex":
            return "codex"
    return None


def main() -> int:
    my_id = int(os.environ.get("KITTY_WINDOW_ID", 0))
    ls = subprocess.run(["kitten", "@", "ls"], capture_output=True, text=True, timeout=5)
    if ls.returncode != 0:
        print("kitten @ ls failed", file=sys.stderr)
        return 1
    data = json.loads(ls.stdout)

    claude_panes: list[tuple[int, int]] = []
    codex_panes: list[tuple[int, int]] = []

    for os_window in data:
        os_id = os_window.get("id", 0)
        for tab in os_window.get("tabs", []):
            for window in tab.get("windows", []):
                if window.get("is_self") or window["id"] == my_id:
                    continue
                agent = detect_agent(window)
                if agent == "claude":
                    claude_panes.append((window["id"], os_id))
                elif agent == "codex":
                    codex_panes.append((window["id"], os_id))

    for pid, os_id in claude_panes:
        subprocess.run(
            ["kitten", "@", "send-text", "--match", f"id:{pid}", "/remote-control\r"]
        )
        print(f"[claude rc-enabling] pane={pid} os_window={os_id}")

    if claude_panes:
        time.sleep(1)
        for pid, _ in claude_panes:
            subprocess.run(["kitten", "@", "send-text", "--match", f"id:{pid}", "\r"])

    for pid, os_id in claude_panes:
        print(f"[claude rc-enabled] pane={pid} os_window={os_id}")
    for pid, os_id in codex_panes:
        print(f"[codex driveable] pane={pid} os_window={os_id}")

    if not claude_panes and not codex_panes:
        print("No agent panes found.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
