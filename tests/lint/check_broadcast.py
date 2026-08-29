#!/usr/bin/env python3
"""Missing-broadcast check.

server_fnc_init.sqf is a hand-maintained registry: each `fnc_x = compile
preprocessFileLineNumbers "..."` line defines a function global on the server, and a
`publicVariable "fnc_x"` line ships its compiled value to every client. A registry
entry added without that broadcast is nil on remote clients, and nothing catches it —
a client `call fnc_x` silently does nothing, a `remoteExec ["fnc_x", client]` resolves
the name to nil on arrival. It is the most common silent-failure class in the codebase
and the one a compiler-less language can still buy back statically.

The naive check (registry entry with no publicVariable) is noise: a server-only helper
is *correctly* unbroadcast, and most of the registry is server-only. The signal is a
client caller. This flags an entry only when its name is also, somewhere in the tree,

  - a remoteExec / remoteExecCall target whose destination is not literally the server
    (target 2 resolves the name on the server, where it exists, so it needs no broadcast); or
  - `call`ed / `spawn`ed inside a client/ file, where it runs locally on the client.

Registry entry + client caller + no broadcast = the bug. A purely server-side entry is
not flagged. Where an entry looks client-called but is deliberately server-only and the
target cannot be read statically (a variable that only ever holds the server), record it
in broadcast_baseline.txt -- the explicit server-only marker the design calls for, which
is cheaper than a heuristic that tries to prove intent. The tree is clean today, so the
baseline starts empty and this gates regressions from here.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.normpath(os.path.join(ROOT, "..", "..", "src"))
REGISTRY = os.path.join(SRC, "duws", "server", "server_fnc_init.sqf")
EXTS = (".sqf", ".hpp", ".h", ".ext", ".inc", ".sqs")

# A registry entry: the compiled-and-named form. The `[] call compile ...` init files
# that define their functions internally are a different pattern and broadcast their own
# names right there; the named-assignment line is what "the registry" means here.
ENTRY = re.compile(r'(fnc_\w+)\s*=\s*compile\s+preprocessFileLineNumbers')
# publicVariableServer is client->server and cannot reach a client, so it is not a
# broadcast; the \s*(?:"|') after the word excludes the longer verb by construction.
PUBLIC = re.compile(r'\bpublicVariable\s*(?:"|\')(fnc_\w+)(?:"|\')')
# remoteExec ["fnc_x", <target>, ...] -- capture the name and the target token up to the
# next comma or the closing bracket, to spot the literal server-only target.
REMOTE = re.compile(
    r'remoteExec(?:Call)?\s*\[\s*(?:"|\')(fnc_\w+)(?:"|\')\s*(?:,\s*([^,\]\n]+))?'
)
LOCAL = re.compile(r'\b(?:call|spawn)\s+(fnc_\w+)')


def iter_files():
    for dp, _, files in os.walk(SRC):
        if os.sep + ".git" in dp:
            continue
        for name in files:
            if os.path.splitext(name)[1].lower() in EXTS:
                yield os.path.join(dp, name)


def load_baseline():
    """Registry names deliberately server-only despite a client-looking caller."""
    bl = os.path.join(ROOT, "broadcast_baseline.txt")
    out = set()
    if os.path.exists(bl):
        for line in open(bl, encoding="utf-8"):
            line = line.strip()
            if line and not line.startswith("#"):
                out.add(line)
    return out


def main():
    text_registry = open(REGISTRY, encoding="utf-8", errors="surrogateescape").read()
    entries = {m.group(1) for m in ENTRY.finditer(text_registry)}

    broadcast = set()
    callers = {}  # name -> list of "kind@rel" evidence, for entries a client reaches
    for fp in iter_files():
        rel = os.path.relpath(fp, SRC).replace(os.sep, "/")
        text = open(fp, encoding="utf-8", errors="surrogateescape").read()
        for m in PUBLIC.finditer(text):
            broadcast.add(m.group(1))
        for m in REMOTE.finditer(text):
            if (m.group(2) or "").strip() == "2":
                continue  # server-only target: resolves where the function is defined
            callers.setdefault(m.group(1), []).append(f"remoteExec @ {rel}")
        if "/client/" in "/" + rel:
            for m in LOCAL.finditer(text):
                callers.setdefault(m.group(1), []).append(f"client call @ {rel}")

    baseline = load_baseline()
    client_called = entries & set(callers)
    failures = sorted(
        n for n in client_called if n not in broadcast and n not in baseline
    )
    baselined = sorted(
        n for n in client_called if n not in broadcast and n in baseline
    )

    print(f"[broadcast] checked {len(entries)} registry entries "
          f"({len(client_called)} client-called, {len(baselined)} baselined server-only)")
    if failures:
        print(f"[broadcast] FAIL: {len(failures)} registry entry(ies) a client calls but "
              f"nothing publicVariable's:")
        for n in failures:
            ev = "; ".join(sorted(set(callers[n]))[:3])
            print(f"  {n}  <- {ev}")
        print('  Fix: add `publicVariable "<fnc>";` in server_fnc_init.sqf, or list the '
              "name in broadcast_baseline.txt if it is genuinely server-only.")
        return 1
    print("[broadcast] OK: every client-called registry entry is broadcast")
    return 0


if __name__ == "__main__":
    sys.exit(main())
