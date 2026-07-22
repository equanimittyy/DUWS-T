#!/usr/bin/env python3
"""Extract a `NAME = { ... }` (or `= compileFinal { ... }`) definition from a source
file, brace-matched with string/comment awareness, and print it. This lets the Tier 2
unit tests run the CURRENT real source of a pure function — no copy, so no drift.

`compileFinal` is stripped so the pinned sqf-vm (which predates it) can run the body;
that only affects rebind-protection, not the logic under test.

Usage: extract_fn.py <source-file> <FunctionName>
"""
import re
import sys


def extract(text, name):
    m = re.search(re.escape(name) + r"\s*=\s*(?:compileFinal\s*)?\{", text)
    if not m:
        raise SystemExit(f"extract_fn: '{name}' not found")
    i = text.index("{", m.start())
    depth = 0
    j = i
    n = len(text)
    while j < n:
        c = text[j]
        nxt = text[j + 1] if j + 1 < n else ""
        if c == "/" and nxt == "/":
            k = text.find("\n", j)
            j = n if k == -1 else k
            continue
        if c == "/" and nxt == "*":
            k = text.find("*/", j + 2)
            j = n if k == -1 else k + 2
            continue
        if c in "\"'":
            q = c
            j += 1
            while j < n:
                if text[j] == q:
                    if j + 1 < n and text[j + 1] == q:
                        j += 2
                        continue
                    j += 1
                    break
                j += 1
            continue
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                body = text[m.start():j + 1]
                return re.sub(r"=\s*compileFinal\s*\{", "= {", body, count=1) + ";\n"
        j += 1
    raise SystemExit(f"extract_fn: unbalanced braces extracting '{name}'")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: extract_fn.py <source-file> <FunctionName>")
    src = open(sys.argv[1], encoding="utf-8", errors="surrogateescape").read()
    sys.stdout.write(extract(src, sys.argv[2]))
