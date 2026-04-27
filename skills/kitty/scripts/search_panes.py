#!/usr/bin/env python3
"""Search scrollback text across all kitty panes.

Usage: python3 search_panes.py PATTERN
"""
import json
import re
import subprocess
import sys


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: search_panes.py PATTERN", file=sys.stderr)
        return 2
    pattern = sys.argv[1]

    ls = subprocess.run(["kitten", "@", "ls"], capture_output=True, text=True, timeout=5)
    if ls.returncode != 0:
        print("kitten @ ls failed", file=sys.stderr)
        return 1
    data = json.loads(ls.stdout)

    n = 0
    for os_window in data:
        for tab in os_window.get("tabs", []):
            n += 1
            for window in tab.get("windows", []):
                try:
                    text = subprocess.check_output(
                        ["kitten", "@", "get-text", "--match", f"id:{window['id']}", "--extent", "all"],
                        timeout=10,
                    ).decode(errors="replace")
                except Exception:
                    continue
                matches = re.findall(f".*{pattern}.*", text, re.IGNORECASE)
                if matches:
                    print(f"T{n} (pane {window['id']}): {len(matches)} matches")
                    for m in matches[-3:]:
                        print(f"  {m.strip()[:100]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
