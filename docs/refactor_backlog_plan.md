# Refactor backlog

What is left of the structural pass over `src/duws/`. Two other pieces of the same pass have plans
of their own: [`spawn_helpers_plan.md`](spawn_helpers_plan.md) and
[`registry_split_plan.md`](registry_split_plan.md).

## Composition schemas: three formats for one concept

The `--DUWS-COMPOSITION` fence carries three row schemas across fifteen compositions — eight on A,
two on B, five on C — and `scripts/duws_eden.ps1` already normalises all three to
`[class, offX, offY, offZ, dir°]`. The schemas exist because three authors wrote three formats, not
because they encode anything.

- [ ] Convert all fifteen to schema A and drop the B and C adapters from the tool.

**This one cannot be verified from the devcontainer.** Its check is "import each composition through
`duws_eden.ps1` before and after and diff the normalised rows", and that tool is Windows PowerShell.
Whoever takes it needs a Windows checkout, or the conversion ships unverified.

Two constraints the tool imposes on any such move. It enumerates `*.sqf` only, so a composition
parked in an `.hpp` becomes invisible to it; and it resolves a `zbase=` attribute by regex against
the file holding the fence, so the constant named there has to live in that same file. The
killhouse split is the worked example — its `_centerSpawnZ` travelled with its arrays.

## Retire the numbered faction-request fallback

`shared/functions/fnc_faction_rqst_list.sqf` prefers `blufor_RQST_UNITS` / `blufor_RQST_VEHICLES`
and falls back to walking the old `blufor_RQST_UNIT_01_X … _99_X` names. Nothing in this tree writes
the numbered shape any more; the fallback carries a faction file shipped by somebody else against
the old one, which is a real case for a mission that supports faction mods and auto-detection.

Deleting it early fails silently — two empty listboxes, no error and no log line, because these
globals are built at runtime and no linter sees them.

- [ ] Delete the fallback once a vanilla, a modded and an auto-detected faction have each been seen
      filling **both** menus in game. Those are the three distinct writers: literal arrays, a
      third-party file, and the detection loop in `factions/MODERN/AUTODETECT_blufor.sqf` that seeds
      the vehicle array and appends to it. The check itself is the request-menu row in the refactor
      branch's list in [`../KNOWN_ISSUES.md`](../KNOWN_ISSUES.md) — unanchored because that heading
      carries a commit count that moves.

Keeping it indefinitely is defensible: the loop is never reached when the array exists.
