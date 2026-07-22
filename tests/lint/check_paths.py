#!/usr/bin/env python3
"""Path-resolution check.

Every static script/include path in the mission is a string literal the engine
resolves at runtime with no compiler to catch a typo. This verifies each one points
at a file that actually exists, case-insensitively (Arma resolves paths
case-insensitively, and the module layout has intentional casing skews such as
modules\\vcom -> modules/VCOM).

Checked: execVM / execFSM / preprocessFile / preprocessFileLineNumbers / loadFile
paths (mission-root-relative) and #include directives (relative to the including
file). Skipped by design: engine/addon paths (leading '\\' or an 'a3\\' root) and
dynamically built paths (format[...] / variables), which cannot be resolved statically.

Known pre-existing dead references live in paths_baseline.txt; this fails only on NEW
unresolved paths, so it gates regressions without being blocked by legacy debt.
"""
import os
import re
import sys

SRC = os.path.normpath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "src")
)
EXTS = (".sqf", ".hpp", ".h", ".ext", ".inc", ".sqs")

LOAD = re.compile(
    r'\b(?:execVM|execFSM|preprocessFileLineNumbers|preprocessFile|loadFile)\b\s*'
    r'(?:"([^"\n]+)"|\'([^\'\n]+)\')'
)
INCLUDE = re.compile(r'#\s*include\s*"([^"\n]+)"')


def resolve_ci(base, relpath):
    """Case-insensitively resolve relpath (\\ or /) from directory `base`."""
    parts = re.split(r"[\\/]+", relpath)
    cur = base
    for p in parts:
        if p in ("", "."):
            continue
        if p == "..":
            cur = os.path.dirname(cur)
            continue
        try:
            entries = os.listdir(cur)
        except (NotADirectoryError, FileNotFoundError):
            return None
        hit = next((e for e in entries if e.lower() == p.lower()), None)
        if hit is None:
            return None
        cur = os.path.join(cur, hit)
    return cur if os.path.exists(cur) else None


def line_commented(text, start):
    """True if the match at `start` is preceded by // on its own line."""
    ls = text.rfind("\n", 0, start) + 1
    return "//" in text[ls:start]


def load_baseline():
    """Known-unresolved paths to tolerate (pre-existing dead code), as rel|path."""
    bl = os.path.join(os.path.dirname(os.path.abspath(__file__)), "paths_baseline.txt")
    out = set()
    if os.path.exists(bl):
        for line in open(bl, encoding="utf-8"):
            line = line.strip()
            if line and not line.startswith("#"):
                out.add(line)
    return out


def is_external_or_dynamic(path):
    if path.startswith("\\") or path.startswith("/"):
        return True  # engine/addon absolute root
    first = re.split(r"[\\/]+", path, 1)[0].lower()
    if first.startswith("a3") or first == "userconfig":
        return True
    if "%" in path or "+" in path:
        return True  # format placeholder / concatenation fragment
    return False


def main():
    baseline = load_baseline()
    failures = []     # new, unexpected -> fail
    baselined = []    # known pre-existing -> tolerated
    checked = 0
    for dp, _, files in os.walk(SRC):
        if os.sep + ".git" in dp:
            continue
        for name in files:
            if os.path.splitext(name)[1].lower() not in EXTS:
                continue
            fp = os.path.join(dp, name)
            rel = os.path.relpath(fp, SRC).replace(os.sep, "/")
            try:
                text = open(fp, encoding="utf-8", errors="surrogateescape").read()
            except Exception:
                continue

            def handle(path, kind, start):
                nonlocal checked
                if is_external_or_dynamic(path) or line_commented(text, start):
                    return
                checked += 1
                if kind == "load":            # mission-root-relative
                    ok = resolve_ci(SRC, path) is not None
                else:                         # include: relative to file, root as fallback
                    ok = resolve_ci(dp, path) is not None or resolve_ci(SRC, path) is not None
                if ok:
                    return
                ln = text[:start].count("\n") + 1
                key = f"{rel}|{path.replace(chr(92), '/')}"
                (baselined if key in baseline else failures).append((rel, ln, kind, path))

            for m in LOAD.finditer(text):
                handle(m.group(1) or m.group(2), "load", m.start())
            for m in INCLUDE.finditer(text):
                handle(m.group(1), "include", m.start())

    print(f"[paths] checked {checked} static path references "
          f"({len(baselined)} known-dead baselined)")
    if failures:
        print(f"[paths] FAIL: {len(failures)} NEW unresolved:")
        for rel, ln, kind, path in failures:
            print(f"  {rel}:{ln}  ({kind})  \"{path}\"")
        return 1
    print("[paths] OK: no new unresolved paths")
    return 0


if __name__ == "__main__":
    sys.exit(main())
