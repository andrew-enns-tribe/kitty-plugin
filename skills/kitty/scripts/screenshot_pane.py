#!/usr/bin/env python3
"""Screenshot the OS window containing a given kitty pane.

Looks up the pane's containing OS window, finds its macOS
`platform_window_id`, and runs `screencapture -l` to capture just that
window.

Usage: python3 screenshot_pane.py PANE_ID [OUTPUT_PATH]
Default OUTPUT_PATH: /tmp/kitty-pane-<PANE_ID>.png
"""
import json
import subprocess
import sys


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: screenshot_pane.py PANE_ID [OUTPUT_PATH]", file=sys.stderr)
        return 2
    try:
        target = int(sys.argv[1])
    except ValueError:
        print("PANE_ID must be an integer", file=sys.stderr)
        return 2
    out = sys.argv[2] if len(sys.argv) > 2 else f"/tmp/kitty-pane-{target}.png"

    ls = subprocess.run(["kitten", "@", "ls"], capture_output=True, text=True, timeout=5)
    if ls.returncode != 0:
        print("kitten @ ls failed", file=sys.stderr)
        return 1
    data = json.loads(ls.stdout)

    platform_window_id = None
    for os_window in data:
        for tab in os_window.get("tabs", []):
            for window in tab.get("windows", []):
                if window["id"] == target:
                    platform_window_id = os_window.get("platform_window_id")
                    break
    if not platform_window_id:
        print(f"No OS window found containing pane {target}", file=sys.stderr)
        return 1

    result = subprocess.run(["screencapture", "-l", str(platform_window_id), out])
    if result.returncode != 0:
        print("screencapture failed", file=sys.stderr)
        return 1
    print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
