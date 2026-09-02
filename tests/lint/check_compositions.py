#!/usr/bin/env python3
"""Composition-fence referential check.

The DUWS spawn tables live behind `// --DUWS-UNITCOMP` fences and are edited two
ways: the PowerShell TUI (duws_eden.ps1), which refuses a write whose role names
do not resolve, and by hand -- which gets no such check. A hand edit that renames
a team but misses a tier token, or names a role the faction schema never declares,
compiles clean and then spawns nothing at runtime. This catches that class before
it ships, on any platform (python only, no PowerShell, no Eden).

Two invariants, mirroring what the TUI enforces at write time:

  Role tokens -- every `*_X` role a team/fallback/vehicle row names must be a key
  in fnc_faction_schema (both sides for a table both armies raise out of). A
  required=false schema key counts: it is a DUWS_roleFallbacks target that
  fnc_faction_backfill fills at load, so the schema IS the "resolves or backfills"
  set. A name the schema does not carry would spawn nothing.

  Composition tokens -- every `posture:name` cell in a tier/squad must name a team
  (DUWS_teamRosters) or a vehicle (DUWS_spawnVehicles). A dangling name is a rename
  that did not propagate.

Column meaning is read from each fence's own `fields=`/`kind=` header, not a table
whitelist, so a new fenced table is checked without editing this script -- but a
role column under an unrecognised field name is passed through, so the summary
prints what was checked to keep silent under-checking visible.
"""
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SRC = os.path.join(ROOT, "src")
SCHEMA_FILE = os.path.join(SRC, "duws", "shared", "faction_lib", "fnc_faction_schema.sqf")

# Field names whose value is a role slot (or list of them). A value that is not a
# `*_X` slot and carries no faction prefix -- a team key, a vanilla class, "HMG" --
# is passed through by role_ok, exactly as the TUI passes it through.
ROLE_FIELDS = {"roles", "role", "leader", "borrows from", "faction role"}

FENCE = re.compile(
    r'//\s*--DUWS-UNITCOMP BEGIN\s+(?P<attrs>.*?)--.*?\n(?P<body>.*?)//\s*--DUWS-UNITCOMP END--',
    re.S,
)
# A schema row: ["<side>_<KEY>", "<GROUP>", ...]. Group-tagged so a stray comment or
# the params line cannot masquerade as a key.
SCHEMA_ROW = re.compile(
    r'\[\s*"((?:blufor|opfor)_[A-Za-z0-9_]+)"\s*,\s*"(?:INFANTRY|OPERATORS|VEHICLES|STATIC|SPECIAL)"'
)


def strip_comments(s):
    s = re.sub(r'/\*.*?\*/', '', s, flags=re.S)
    return re.sub(r'//[^\n]*', '', s)


def split_top(s):
    """Top-level comma split of a list's interior, honouring nesting and "" '' quotes."""
    out, buf, depth, q, i = [], [], 0, None, 0
    while i < len(s):
        c = s[i]
        if q:
            buf.append(c)
            if c == q:
                if i + 1 < len(s) and s[i + 1] == q:  # doubled quote = escaped
                    buf.append(s[i + 1]); i += 2; continue
                q = None
            i += 1; continue
        if c in '"\'':
            q = c; buf.append(c)
        elif c in '([{':
            depth += 1; buf.append(c)
        elif c in ')]}':
            depth -= 1; buf.append(c)
        elif c == ',' and depth == 0:
            out.append(''.join(buf).strip()); buf = []
        else:
            buf.append(c)
        i += 1
    tail = ''.join(buf).strip()
    if tail:
        out.append(tail)
    return out


def array_inner(body):
    """Interior of the first top-level [...] in a fenced body, or None."""
    i = body.find('[')
    if i < 0:
        return None
    depth, q, j = 0, None, i
    while j < len(body):
        c = body[j]
        if q:
            if c == q:
                if j + 1 < len(body) and body[j + 1] == q:
                    j += 2; continue
                q = None
        elif c in '"\'':
            q = c
        elif c == '[':
            depth += 1
        elif c == ']':
            depth -= 1
            if depth == 0:
                return body[i + 1:j]
        j += 1
    return None


def unquote(s):
    s = s.strip()
    if len(s) >= 2 and s[0] in '"\'' and s[-1] == s[0]:
        return s[1:-1]
    return s


def role_tokens(val):
    """The role names a role-column value carries: a [...] list, or a lone scalar."""
    val = val.strip()
    if val.startswith('['):
        return [unquote(e) for e in split_top(val[1:-1])]
    return [unquote(val)]


class Fence:
    def __init__(self, rel, attrs, body):
        self.rel = rel
        self.name = (re.search(r'name="([^"]*)"', attrs) or [None, "?"])[1]
        self.kind = (re.search(r'kind=(\w+)', attrs) or [None, "team"])[1]
        fields = re.search(r'fields="([^"]*)"', attrs)
        self.fields = [f.strip() for f in fields.group(1).split(",")] if fields else None
        pref = re.search(r'prefix=(\S+)', attrs)
        self.sides = [p.rstrip("_") for p in pref.group(1).split(",")] if pref else []
        self.rows = split_top(array_inner(strip_comments(body)) or "")


def collect_fences():
    fences = []
    for dp, _, files in os.walk(SRC):
        if os.sep + ".git" in dp:
            continue
        for name in files:
            if not name.endswith(".sqf"):
                continue
            fp = os.path.join(dp, name)
            rel = os.path.relpath(fp, SRC).replace(os.sep, "/")
            text = open(fp, encoding="utf-8", errors="surrogateescape").read()
            for m in FENCE.finditer(text):
                fences.append(Fence(rel, m.group("attrs"), m.group("body")))
    return fences


def main():
    schema = set(SCHEMA_ROW.findall(open(SCHEMA_FILE, encoding="utf-8").read()))
    fences = collect_fences()

    # Vocab first: a fence keyed "team"/"token" in its first column defines the
    # names every composition token later resolves against.
    teams, vehicles = set(), set()
    for f in fences:
        if f.kind == "team" and f.fields and f.rows:
            head = f.fields[0]
            if head in ("team", "token"):
                target = teams if head == "team" else vehicles
                for row in f.rows:
                    cols = split_top(row.strip()[1:-1])
                    if cols:
                        target.add(unquote(cols[0]))

    role_fail, comp_fail = [], []
    roles_checked = comp_checked = 0

    def check_role(tok, sides, f):
        nonlocal roles_checked
        if not tok or not (tok.endswith("_X") or tok.startswith(("blufor_", "opfor_"))):
            return  # not a role slot -- team key, vanilla class, enum: passed through
        roles_checked += 1
        keys = [tok] if tok.startswith(("blufor_", "opfor_")) else [f"{s}_{tok}" for s in (sides or [])]
        for k in keys:
            if k not in schema:
                role_fail.append((f.rel, f.name, k))

    def check_comp(tok, f):
        nonlocal comp_checked
        name = unquote(tok).split(":")[-1]
        if not name:
            return
        comp_checked += 1
        if name not in teams and name not in vehicles:
            comp_fail.append((f.rel, f.name, name))

    for f in fences:
        if f.fields:
            for row in f.rows:
                cols = split_top(row.strip()[1:-1])
                for idx, fname in enumerate(f.fields):
                    if idx >= len(cols):
                        continue
                    if fname in ROLE_FIELDS:
                        for tok in role_tokens(cols[idx]):
                            check_role(tok, f.sides, f)
                    elif fname == "team" and f.kind == "composition":
                        check_comp(cols[idx], f)
        elif f.kind == "composition":
            for row in f.rows:  # free-list: each row is a tier, every cell a token
                for cell in split_top(row.strip()[1:-1]):
                    check_comp(cell, f)

    print(f"[compositions] {len(fences)} fences; {roles_checked} role tokens, "
          f"{comp_checked} composition tokens ({len(teams)} teams, {len(vehicles)} vehicles)")
    if role_fail or comp_fail:
        for rel, fn, key in role_fail:
            print(f"  {rel}  [{fn}]  role '{key}' not in fnc_faction_schema -- would spawn nothing")
        for rel, fn, name in comp_fail:
            print(f"  {rel}  [{fn}]  token '{name}' names no team or vehicle")
        print(f"[compositions] FAIL: {len(role_fail)} role, {len(comp_fail)} composition")
        return 1
    print("[compositions] OK: every role and composition token resolves")
    return 0


if __name__ == "__main__":
    sys.exit(main())
