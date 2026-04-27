"""kitty watcher: auto-apply a Calvin & Hobbes theme to every new window.

Picks an unused CH image (based on other windows' `user_vars.bg_image`),
falls back to random when every CH image is taken. Applies the matching
`ch-NAME.conf` colors and tags the pane via `user_vars.bg_image` so
save/load roundtrips and future rotations can see the image.

Uses kitty's internal API directly (parse_colors/patch_colors,
boss.set_background_image, window.set_user_var). Calling `kitten @` via
subprocess from inside kitty's own Python deadlocks, so we don't.

Uses `on_resize` with `old_geometry.xnum == 0` to detect window creation
(kitty has no dedicated on-create hook). Each window is themed at most
once per kitty session, tracked in a module-level set.

Diagnostics written to /tmp/ch_bg_rotator.log.
"""
from __future__ import annotations

import glob
import os
import random
import time
from pathlib import Path

IMAGES_DIR = os.path.expanduser("~/.config/kitty/images")
THEMES_DIR = os.path.expanduser("~/.config/kitty/themes")
LOG_PATH = "/tmp/ch_bg_rotator.log"

_applied: set[int] = set()


def _log(msg: str) -> None:
    try:
        with open(LOG_PATH, "a") as f:
            f.write(f"[{time.strftime('%H:%M:%S')}] {msg}\n")
    except Exception:
        pass


try:
    _log(f"MODULE IMPORT pid={os.getpid()}")
except Exception:
    pass


def _ch_stems() -> list[str]:
    return sorted(Path(p).stem for p in glob.glob(os.path.join(IMAGES_DIR, "ch-*.jpg")))


def _iter_other_windows(boss, self_id: int):
    seen: set[int] = set()
    wmap = getattr(boss, "window_id_map", None)
    if wmap:
        for wid, w in wmap.items():
            if wid == self_id or wid in seen:
                continue
            seen.add(wid)
            yield w
        return
    for tm in getattr(boss, "all_tab_managers", []) or []:
        for tab in tm:
            for w in tab:
                wid = getattr(w, "id", None)
                if wid is None or wid == self_id or wid in seen:
                    continue
                seen.add(wid)
                yield w


def _used_stems(boss, self_id: int) -> set[str]:
    used: set[str] = set()
    for w in _iter_other_windows(boss, self_id):
        uv = getattr(w, "user_vars", None) or {}
        bg = uv.get("bg_image", "")
        if bg and Path(bg).stem.startswith("ch-"):
            used.add(Path(bg).stem)
    return used


def _apply_colors(window, theme_path: str) -> None:
    if not os.path.exists(theme_path):
        _log(f"  theme missing: {theme_path}")
        return
    from kitty.colors import parse_colors, patch_colors
    spec, transparent_bg = parse_colors([theme_path])
    patch_colors(spec, transparent_bg, configured=False, windows=[window])


def _apply_background(boss, window, img_path: str) -> None:
    if not os.path.exists(img_path):
        _log(f"  image missing: {img_path}")
        return
    os_window_id = getattr(window, "os_window_id", None)
    if os_window_id is None:
        _log("  window has no os_window_id")
        return
    boss.set_background_image(
        path=img_path,
        os_windows=(os_window_id,),
        configured=False,
        layout="configured",
    )


def _set_user_var(window, key: str, value: str) -> None:
    fn = getattr(window, "set_user_var", None)
    if callable(fn):
        fn(key, value)
        return
    uv = getattr(window, "user_vars", None)
    if isinstance(uv, dict):
        uv[key] = value


def on_resize(boss, window, data) -> None:
    """Fires on every resize. We only act on the first one (creation)."""
    try:
        old = data.get("old_geometry") if isinstance(data, dict) else getattr(data, "old_geometry", None)
        xnum = getattr(old, "xnum", None) if old is not None else None
        if xnum != 0:
            return
        wid = getattr(window, "id", None)
        if wid is None or wid in _applied:
            return
        _applied.add(wid)

        uv = getattr(window, "user_vars", None) or {}
        if uv.get("bg_image"):
            _log(f"create window={wid} already has bg_image, skipping")
            return

        stems = _ch_stems()
        if not stems:
            _log("  no ch-*.jpg images found in " + IMAGES_DIR)
            return
        used = _used_stems(boss, wid)
        unused = [s for s in stems if s not in used]
        pool = unused if unused else stems
        pick = random.choice(pool)
        img = os.path.join(IMAGES_DIR, f"{pick}.jpg")
        theme = os.path.join(THEMES_DIR, f"{pick}.conf")
        _log(f"create window={wid} picked={pick} used={len(used)} unused={len(unused)}")

        try:
            _apply_colors(window, theme)
            _log(f"  OK colors")
        except Exception as e:
            _log(f"  FAIL colors: {e!r}")
        try:
            _apply_background(boss, window, img)
            _log(f"  OK background")
        except Exception as e:
            _log(f"  FAIL background: {e!r}")
        try:
            _set_user_var(window, "bg_image", img)
            _log(f"  OK user_var")
        except Exception as e:
            _log(f"  FAIL user_var: {e!r}")

    except Exception as e:
        _log(f"on_resize exception: {e!r}")


def on_load(boss, data) -> None:
    """Module-level hook, fires once when kitty loads this watcher file."""
    _log("on_load called")
