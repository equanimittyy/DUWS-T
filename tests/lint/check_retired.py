#!/usr/bin/env python3
"""Retired-name check.

Three dialogue functions were replaced by fnc_duws_dialogue, and the replacement is only
worth anything while it stays the single entry point. Each name below was previously spread
over dozens to hundreds of call sites, so they drift back one line at a time: someone copies
a nearby block, or an old snippet, and nothing complains. Nothing else catches it —
BIS_fnc_showSubtitle is a live engine function, and the other two would simply be nil at
runtime, which is silent.

The registry self-check covers a function whose file went missing; it cannot see a call to a
name that no longer exists anywhere. This is that half.
"""
import os
import re
import sys

SRC = os.path.normpath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "src", "duws")
)
EXTS = (".sqf", ".hpp", ".h", ".ext", ".inc", ".sqs")

RETIRED = {
    "BIS_fnc_showSubtitle": "route the line through fnc_duws_dialogue",
    "fnc_broadcastRadioChatter": "the squelch is decided in fnc_duws_dialogue",
    "fnc_sideChat_filter": "use fnc_duws_dialogue with a real speaker",
}
PAT = re.compile("|".join(re.escape(k) for k in RETIRED))


def main():
    failures = []
    checked = 0
    for dp, _, files in os.walk(SRC):
        if os.sep + ".git" in dp:
            continue
        for name in files:
            if os.path.splitext(name)[1].lower() not in EXTS:
                continue
            fp = os.path.join(dp, name)
            checked += 1
            rel = os.path.relpath(fp, SRC).replace(os.sep, "/")
            with open(fp, encoding="utf-8", errors="surrogateescape") as fh:
                for ln, line in enumerate(fh, 1):
                    for m in PAT.finditer(line):
                        failures.append((rel, ln, m.group(0)))

    print(f"[retired] checked {checked} files for {len(RETIRED)} retired names")
    if failures:
        print(f"[retired] FAIL: {len(failures)} call(s) to a retired dialogue function:")
        for rel, ln, name in failures:
            print(f"  {rel}:{ln}  {name} -> {RETIRED[name]}")
        return 1
    print("[retired] OK: no retired dialogue functions referenced")
    return 0


if __name__ == "__main__":
    sys.exit(main())
