#!/usr/bin/env python3
"""Enable /remote-control on every Claude pane except the caller's own.

Reads KITTY_WINDOW_ID from the environment to skip the calling pane.
Sends `/remote-control\r` to each matched pane, waits briefly, then sends
a confirming Enter to each.

Usage: python3 enable_remote_control.py
"""
import json
import os
import subprocess
import sys
import time


def main() -> int:
    my_id = int(os.environ.get("KITTY_WINDOW_ID", 0))
    ls = subprocess.run(["kitten", "@", "ls"], capture_output=True, text=True, timeout=5)
    if ls.returncode != 0:
        print("kitten @ ls failed", file=sys.stderr)
        return 1
    data = json.loads(ls.stdout)

    pane_ids = []
    for os_window in data:
        for tab in os_window.get("tabs", []):
            for window in tab.get("windows", []):
                if window.get("is_self") or window["id"] == my_id:
                    continue
                fg = window.get("foreground_processes", [])
                is_claude = any("/bin/claude" in " ".join(p.get("cmdline", [])) for p in fg)
                if not is_claude:
                    continue
                subprocess.run(
                    ["kitten", "@", "send-text", "--match", f"id:{window['id']}", "/remote-control\r"]
                )
                pane_ids.append(window["id"])
                print(f"Sent /remote-control to pane {window['id']}")

    time.sleep(1)
    for pid in pane_ids:
        subprocess.run(["kitten", "@", "send-text", "--match", f"id:{pid}", "\r"])
        print(f"Sent Enter to pane {pid}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
