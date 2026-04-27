#!/usr/bin/env python3
"""Summarize the state of every kitty pane: which agent is running and a status hint.

Detection:
- Agent type comes from foreground_processes cmdlines (claude vs codex).
- Status comes from screen text heuristics specific to each agent.

Claude heuristics:
- "idle (at prompt)": screen shows Claude's `Context: ... used` footer
- "thinking": screen shows Claude's cute thinking-state words
  (Calvinball, Susie Derkins, Cogitated, Brewed, Playing)
- " + remote-control" appended when Claude reports "Remote Control active"

Codex heuristics:
- "active": screen shows a working/streaming indicator
  (Working, Thinking, Generating, ▌ at bottom indicating streaming)
- "idle (at prompt)": screen shows Codex's input box prompt with no streaming
- otherwise "unknown" — orchestrator should read screen text directly

Usage: python3 session_status.py
"""
import json
import subprocess
import sys

CLAUDE_THINKING_MARKERS = (
    "Calvinball", "Susie Derkins", "Cogitated", "Brewed", "Playing",
)

CODEX_ACTIVE_MARKERS = (
    "Working", "Generating", "Thinking…", "Thinking...",
    "Reasoning", "Esc to interrupt",
)

CODEX_IDLE_MARKERS = (
    "Send a message",
    "Ask for follow-up",
    "▌",
)


def detect_agent(window: dict) -> str | None:
    fg = window.get("foreground_processes", [])
    for p in fg:
        joined = " ".join(p.get("cmdline", []))
        if "/bin/claude" in joined:
            return "claude"
        if "/bin/codex" in joined or joined.endswith(" codex") or joined == "codex":
            return "codex"
    return None


def classify_claude(text: str) -> tuple[str, list[str]]:
    status = "unknown"
    tail = text.strip().split("\n")[-8:]
    for line in tail:
        if "Context:" in line and "used" in line:
            status = "idle (at prompt)"
        if any(m in line for m in CLAUDE_THINKING_MARKERS):
            status = "thinking"
        if "Remote Control active" in line:
            status += " + remote-control"
    return status, tail[-2:]


def classify_codex(text: str) -> tuple[str, list[str]]:
    tail = text.strip().split("\n")[-12:]
    joined_tail = "\n".join(tail)
    status = "unknown"
    if any(m in joined_tail for m in CODEX_ACTIVE_MARKERS):
        status = "active"
    elif any(m in joined_tail for m in CODEX_IDLE_MARKERS):
        status = "idle (at prompt)"
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
                agent = detect_agent(window)
                if agent is None:
                    continue
                try:
                    text = subprocess.check_output(
                        ["kitten", "@", "get-text", "--match", f"id:{window['id']}", "--extent", "screen"],
                        timeout=10,
                    ).decode(errors="replace")
                except Exception:
                    continue
                if agent == "claude":
                    status, last = classify_claude(text)
                else:
                    status, last = classify_codex(text)
                print(f"Pane {window['id']} [{agent}]: {status}")
                print(f"  Last lines: {last}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
