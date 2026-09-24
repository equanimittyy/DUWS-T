#!/usr/bin/env python3
"""Eden composition check.

Static layouts are Eden compositions read at runtime by fnc_composition_rows. Three
mistakes compile clean and place nothing, and the mission reports them only when that
site is built -- possibly hours into a campaign:

  a name passed to fnc_composition_rows with no class in compositions.hpp;
  a layer name the composition does not hold;
  a composition.sqe without exactly one DUWS_ORIGIN and one DUWS_FRONT marker, which
  the reader needs to measure every row from.

A missing .sqe file behind an #include is check_paths.py's.
"""
import os
import re
import sys

SRC = os.path.normpath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "src")
)
HPP = os.path.join(SRC, "duws", "shared", "includes", "compositions.hpp")
CALL = re.compile(r'\[\s*"([^"]+)"\s*(?:,\s*"([^"]*)"\s*)?\]\s*call\s+fnc_composition_rows')
ENTRY = re.compile(r'class\s+(\w+)\s*\{\s*#include\s+"([^"]+)"', re.S)


def main():
    failures = []
    comps = {}
    hpp = open(HPP, encoding="utf-8").read()
    for name, inc in ENTRY.findall(hpp):
        path = os.path.normpath(os.path.join(os.path.dirname(HPP), *re.split(r"[\\/]+", inc)))
        text = open(path, encoding="utf-8", errors="replace").read() if os.path.isfile(path) else ""
        comps[name] = text
        for marker in ("DUWS_ORIGIN", "DUWS_FRONT"):
            n = len(re.findall(r'\bname="%s";' % marker, text))
            if text and n != 1:
                failures.append(f"{name}: {n} {marker} markers, needs exactly 1")

    calls = 0
    for dp, _, files in os.walk(SRC):
        for fn in files:
            if not fn.endswith(".sqf"):
                continue
            fp = os.path.join(dp, fn)
            text = open(fp, encoding="utf-8", errors="replace").read()
            for m in CALL.finditer(text):
                calls += 1
                rel = os.path.relpath(fp, SRC).replace(os.sep, "/")
                ln = text[:m.start()].count("\n") + 1
                name, layer = m.group(1), m.group(2) or ""
                if name not in comps:
                    failures.append(f"{rel}:{ln}: \"{name}\" has no class in compositions.hpp")
                elif layer and not re.search(r'dataType="Layer";\s*name="%s";' % re.escape(layer), comps[name]):
                    failures.append(f"{rel}:{ln}: \"{name}\" has no layer \"{layer}\"")

    print(f"[eden] {len(comps)} compositions, {calls} reader calls")
    if failures:
        print(f"[eden] FAIL: {len(failures)} problem(s):")
        for f in failures:
            print("  " + f)
        return 1
    print("[eden] OK: every name, layer and marker resolves")
    return 0


if __name__ == "__main__":
    sys.exit(main())
