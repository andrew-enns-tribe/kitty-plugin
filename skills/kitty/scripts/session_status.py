#!/usr/bin/env python3
"""Summarize the state of every kitty pane: idle / thinking / unknown.

Heuristics:
- "idle (at prompt)": screen shows Claude's `Context: ... used` footer
- "thinking": screen shows Claude's cute thinking-state words
  (Calvinball, Susie Derkins, Cogitated, Brewed, Playing)
- adds " + remote-control" when Claude reports "Remote Control active"

Usage: python3 session_status.py
"""
import json
import subprocess
import sys

THINKING_MARKERS = (
    "Calvinball", "Susie Derkins", "Cogitated", "Brewed", "Playing",
)


def classify(text: str) -> str:
    status = "unknown"
    tail = text.strip().split("\n")[-8:]
    for line in tail:
        if "Context:" in line and "used" in line:
            status = "idle (at prompt)"
        if any(m in line for m in THINKING_MARKERS):
            status = "thinking"
        if "Remote Control active" in line:
            status += " + remote-control"
    return status, tail[-2:]


def main() -> int:
    ls = subprocess.run(["kitten", "@", "ls"], capture_output=True, text=True, timeout=5)
    if ls.returncode != 0:
        print("kitten @ ls failed", file=sys.stderr)
        return 1
    data = json.loads(ls.stdout)

    for os_window in data:
        for tab in os_window.get("tabs", []):
            for window in tab.get("windows", []):
                if window.get("is_self"):
                    continue
                try:
                    text = subprocess.check_output(
                        ["kitten", "@", "get-text", "--match", f"id:{window['id']}", "--extent", "screen"],
                        timeout=10,
                    ).decode(errors="replace")
                except Exception:
                    continue
                status, last = classify(text)
                print(f"Pane {window['id']}: {status}")
                print(f"  Last lines: {last}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
