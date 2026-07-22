#!/usr/bin/env python3
"""Structural syntax check.

A grammar-agnostic balance check: brackets () [] {} matched, strings and comments
terminated. It does NOT understand SQF semantics, but bracket and string balance is
exactly the class of error a careless edit or a bad rewrite introduces, and this
catches it reliably with no false positives on new language syntax. (A real SQF parser
is a better check, but the headless VM available here predates the mission's syntax and
false-positives; this balancer does not.)

SQF/config string escaping is by doubling the quote ("" or '') — handled below. Known
pre-existing quirks live in syntax_baseline.txt; this fails only on NEW problems.
"""
import os
import sys

SRC = os.path.normpath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "src")
)
EXTS = (".sqf", ".hpp", ".h", ".ext", ".inc", ".sqs")
PAIRS = {")": "(", "]": "[", "}": "{"}
OPENS = set("([{")


def check(text):
    """Return (line, col, message) of first problem, or None if balanced."""
    stack = []          # (open_char, line, col)
    i, n = 0, len(text)
    line, col = 1, 1
    while i < n:
        c = text[i]
        nxt = text[i + 1] if i + 1 < n else ""
        # comments
        if c == "/" and nxt == "/":
            j = text.find("\n", i)
            if j == -1:
                break
            line += 1
            col = 1
            i = j + 1
            continue
        if c == "/" and nxt == "*":
            j = text.find("*/", i + 2)
            if j == -1:
                return (line, col, "unterminated block comment /* ...")
            line += text.count("\n", i, j + 2)
            i = j + 2
            col = 1
            continue
        # strings ("" or '' escapes)
        if c in "\"'":
            q = c
            sl, sc = line, col
            i += 1
            col += 1
            while i < n:
                d = text[i]
                if d == "\n":
                    line += 1
                    col = 1
                    i += 1
                    continue
                if d == q:
                    if i + 1 < n and text[i + 1] == q:  # doubled = escaped quote
                        i += 2
                        col += 2
                        continue
                    i += 1
                    col += 1
                    break
                i += 1
                col += 1
            else:
                return (sl, sc, f"unterminated string {q}...")
            continue
        # brackets
        if c in OPENS:
            stack.append((c, line, col))
        elif c in PAIRS:
            if not stack:
                return (line, col, f"unmatched closing '{c}'")
            op, ol, oc = stack.pop()
            if op != PAIRS[c]:
                return (line, col, f"'{c}' closes '{op}' opened at {ol}:{oc}")
        if c == "\n":
            line += 1
            col = 1
        else:
            col += 1
        i += 1
    if stack:
        op, ol, oc = stack[-1]
        return (ol, oc, f"unclosed '{op}'")
    return None


def load_baseline():
    """Files with known, pre-existing benign structural quirks (vendored code)."""
    bl = os.path.join(os.path.dirname(os.path.abspath(__file__)), "syntax_baseline.txt")
    out = set()
    if os.path.exists(bl):
        for line in open(bl, encoding="utf-8"):
            line = line.strip()
            if line and not line.startswith("#"):
                out.add(line)
    return out


def main():
    baseline = load_baseline()
    failures = []
    baselined = 0
    checked = 0
    for dp, _, files in os.walk(SRC):
        if os.sep + ".git" in dp:
            continue
        for name in files:
            if os.path.splitext(name)[1].lower() not in EXTS:
                continue
            fp = os.path.join(dp, name)
            checked += 1
            text = open(fp, encoding="utf-8", errors="surrogateescape").read()
            res = check(text)
            if res:
                rel = os.path.relpath(fp, SRC).replace(os.sep, "/")
                if rel in baseline:
                    baselined += 1
                else:
                    ln, cn, msg = res
                    failures.append((rel, ln, cn, msg))
    print(f"[syntax] checked {checked} files ({baselined} baselined)")
    if failures:
        print(f"[syntax] FAIL: {len(failures)} file(s) with NEW structural errors:")
        for rel, ln, cn, msg in failures:
            print(f"  {rel}:{ln}:{cn}  {msg}")
        return 1
    print("[syntax] OK: brackets/strings/comments balanced")
    return 0


if __name__ == "__main__":
    sys.exit(main())
