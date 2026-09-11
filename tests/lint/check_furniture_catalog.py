#!/usr/bin/env python3
"""Furniture-catalog structural check.

furniture_catalog.hpp is the one place class-specific furniture knowledge lives; it is
`#include`d as the body of an SQF array literal and read into a class->entry map at load
(fnc_furnish_catalog). A malformed row -- wrong column count, an unknown role, family or
slot, a non-numeric frontYaw -- compiles into the array clean and then misplaces or drops
a piece at runtime with no error. This catches the class before it ships, python-only.

Per row [class, role, frontYaw, family, seats, slot, maxPerRoom?] it checks:
  - 6 or 7 columns; class a non-empty string, unique across the file;
  - role a known role; frontYaw numeric; seats an integer; the optional maxPerRoom a
    non-negative integer;
  - family a known family, slot a known slot, and the three agree: an anchor carries a
    family and a center|wall slot; a seat or clutter carries a family and no slot; a wall
    or freestand piece carries neither (family "", slot "").

It does NOT check that a class resolves in CfgVehicles/CfgMagazines/CfgWeapons -- python
cannot read the engine config, so the runtime loader logs and skips an unresolved class --
nor that frontYaw is correct (that is hand-calibrated in playtest, not machine-checkable).
"""
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
CATALOG = os.path.join(ROOT, "src", "duws", "shared", "includes", "furniture_catalog.hpp")

ROLES = {"anchor", "seat", "wall", "clutter", "freestand"}
FAMILIES = {"", "dining", "office"}
SLOTS = {"", "center", "wall"}


def strip_comments(s):
    s = re.sub(r'/\*.*?\*/', '', s, flags=re.S)
    return re.sub(r'//[^\n]*', '', s)


def split_top(s):
    """Top-level comma split, honouring [] nesting and "" quotes."""
    out, buf, depth, q, i = [], [], 0, None, 0
    while i < len(s):
        c = s[i]
        if q:
            buf.append(c)
            if c == q:
                q = None
            i += 1
            continue
        if c in '"\'':
            q = c
            buf.append(c)
        elif c in '([{':
            depth += 1
            buf.append(c)
        elif c in ')]}':
            depth -= 1
            buf.append(c)
        elif c == ',' and depth == 0:
            out.append(''.join(buf).strip())
            buf = []
        else:
            buf.append(c)
        i += 1
    tail = ''.join(buf).strip()
    if tail:
        out.append(tail)
    return out


def unquote(s):
    s = s.strip()
    if len(s) >= 2 and s[0] in '"\'' and s[-1] == s[0]:
        return s[1:-1]
    return None  # not a quoted string


def is_int(s):
    return re.fullmatch(r'-?\d+', s.strip()) is not None


def is_num(s):
    return re.fullmatch(r'-?\d+(\.\d+)?', s.strip()) is not None


def main():
    rows = split_top(strip_comments(open(CATALOG, encoding="utf-8").read()))
    fails = []
    seen = {}
    for r in rows:
        r = r.strip()
        if not (r.startswith('[') and r.endswith(']')):
            fails.append((r[:40], "row is not a [...] literal"))
            continue
        cols = split_top(r[1:-1])
        if len(cols) not in (6, 7):
            fails.append((r[:40], f"{len(cols)} columns, expected 6 or 7"))
            continue
        cls = unquote(cols[0])
        role = unquote(cols[1])
        family = unquote(cols[3])
        slot = unquote(cols[5])
        tag = cls or r[:40]
        if not cls:
            fails.append((tag, "class is not a quoted string"))
        elif cls in seen:
            fails.append((tag, "duplicate class"))
        else:
            seen[cls] = True
        if role not in ROLES:
            fails.append((tag, f"role '{role}' unknown"))
        if not is_num(cols[2]):
            fails.append((tag, f"frontYaw '{cols[2]}' not numeric"))
        if family not in FAMILIES:
            fails.append((tag, f"family '{cols[3]}' unknown"))
        if not is_int(cols[4]):
            fails.append((tag, f"seats '{cols[4]}' not an integer"))
        if slot not in SLOTS:
            fails.append((tag, f"slot '{cols[5]}' unknown"))
        if len(cols) == 7 and not (is_int(cols[6]) and int(cols[6]) >= 0):
            fails.append((tag, f"maxPerRoom '{cols[6]}' not a non-negative integer"))
        if role == "anchor":
            if not family:
                fails.append((tag, "anchor needs a family"))
            if slot not in ("center", "wall"):
                fails.append((tag, "anchor needs slot 'center' or 'wall'"))
        elif role in ("seat", "clutter"):
            if not family:
                fails.append((tag, f"{role} needs a family"))
            if slot:
                fails.append((tag, f"{role} must not carry a slot"))
        elif role in ("wall", "freestand"):
            if family:
                fails.append((tag, f'{role} piece must have family ""'))
            if slot:
                fails.append((tag, f'{role} piece must have slot ""'))

    print(f"[furniture] checked {len(rows)} catalog row(s), {len(seen)} class(es)")
    if fails:
        for tag, msg in fails:
            print(f"  {tag}: {msg}")
        print(f"[furniture] FAIL: {len(fails)} problem(s)")
        return 1
    print("[furniture] OK: every catalog row is well-formed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
