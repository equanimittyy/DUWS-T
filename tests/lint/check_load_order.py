#!/usr/bin/env python3
"""Registry load-order check.

server_fnc_init.sqf runs top to bottom on the server before the mission starts, and it
holds two kinds of line that behave very differently:

  fnc_x = compile preprocessFileLineNumbers "..."   binds a code value under a name.
      The file is NOT executed, so nothing inside it resolves yet. These lines carry no
      order constraint at all -- the great majority of the registry.

  [] call compile preprocessFileLineNumbers "..."   executes the file right there. Its
      top-level statements run immediately, so anything it reads outside a function body
      must already exist, or it reads nil.

Only the second kind can break on order, and the break is silent: a nil read builds a
half-empty table or a dead handler, and the mission starts anyway. Nothing else catches
it -- the sqf-vm suite predates the registry and cannot execute it, and a wrong order
surfaces as an undefined-function error deep into a campaign, in one code path.

So this walks the registry in order, tracks which names exist by each line, and for every
executed file checks the names it reads at load. Function bodies are stripped first: a
reference inside `{ }` resolves when the function is called, long after the registry has
finished, and treating those as load-time would flag nearly every file.

A name this cannot resolve from the registry is reported only when the tree defines it
somewhere -- an engine command or a typo is not this check's business. Where a name is
defined outside the registry on purpose (server_var_init.sqf and friends), record it in
load_order_baseline.txt rather than teaching the parser about every other init path.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.normpath(os.path.join(ROOT, "..", "..", "src"))
REGISTRY = os.path.join(SRC, "duws", "server", "server_fnc_init.sqf")
EXTS = (".sqf", ".hpp", ".h", ".ext", ".inc", ".sqs")

BIND = re.compile(r'\b((?:DUWS_)?fnc_\w+)\s*=\s*compile\s+preprocessFileLineNumbers\s*"([^"]+)"')
EXEC = re.compile(r'\[\]\s*call\s+compile\s+preprocessFileLineNumbers\s*"([^"]+)"')
PUBLIC = re.compile(r'\bpublicVariable\s*"((?:DUWS_)?fnc_\w+)"')
# \b before the optional DUWS_ keeps BIS_fnc_* and other TAG_fnc_* names out: there is no
# word boundary in the middle of BIS_fnc_nearestRoad.
NAME = re.compile(r'\b(?:DUWS_)?fnc_\w+')
ASSIGN = re.compile(r'^\s*((?:DUWS_)?fnc_\w+)\s*=', re.M)


def strip_bodies(text):
    """Comments out, then everything inside balanced braces: what is left runs at load."""
    text = re.sub(r"//[^\n]*", "", text)
    out = []
    depth = 0
    for ch in text:
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth = max(0, depth - 1)
            continue
        if depth == 0:
            out.append(ch)
    return "".join(out)


def read(path):
    return open(path, encoding="utf-8", errors="surrogateescape").read()


def defined_anywhere():
    """Every fnc_ name the tree assigns, so an unresolved read can be told from a typo."""
    out = set()
    for dp, _, files in os.walk(SRC):
        if os.sep + ".git" in dp:
            continue
        for name in files:
            if os.path.splitext(name)[1].lower() in EXTS:
                out.update(ASSIGN.findall(read(os.path.join(dp, name))))
    return out


def load_baseline():
    bl = os.path.join(ROOT, "load_order_baseline.txt")
    out = set()
    if os.path.exists(bl):
        for line in open(bl, encoding="utf-8"):
            line = line.strip()
            if line and not line.startswith("#"):
                out.add(line)
    return out


def main():
    baseline = load_baseline()
    known = set(baseline)
    everywhere = defined_anywhere()
    failures = []
    executed = 0

    for lineno, line in enumerate(read(REGISTRY).split("\n"), 1):
        if line.lstrip().startswith("//"):
            continue

        for name, _ in BIND.findall(line):
            known.add(name)

        for rel in EXEC.findall(line):
            executed += 1
            path = os.path.join(SRC, rel.replace("\\", os.sep))
            if not os.path.isfile(path):
                failures.append((lineno, rel, "file not found", ""))
                continue
            text = read(path)
            own = set(ASSIGN.findall(text))
            reads = set(NAME.findall(strip_bodies(text))) - own
            for ref in sorted(reads):
                if ref in known:
                    continue
                if ref not in everywhere:
                    continue
                failures.append((lineno, rel.split("\\")[-1], "reads at load", ref))
            known |= own

        # A broadcast of a name that does not exist yet ships nil to every client.
        for name in PUBLIC.findall(line):
            if name not in known and name in everywhere:
                failures.append((lineno, "publicVariable", "broadcasts before define", name))

    print(f"[loadorder] checked {executed} executed entries in server_fnc_init.sqf")
    if failures:
        print(f"[loadorder] FAIL: {len(failures)} entry(ies) resolve too late:")
        for lineno, what, kind, ref in failures:
            print(f"  line {lineno}: {what} {kind} {ref}".rstrip())
        print("  Fix: move the defining entry above this line, or record the name in "
              "load_order_baseline.txt if another init path defines it.")
        return 1
    print("[loadorder] OK: every load-time read resolves to an earlier entry")
    return 0


if __name__ == "__main__":
    sys.exit(main())
