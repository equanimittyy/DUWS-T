# Composition schemas: three formats for one concept

The `--DUWS-COMPOSITION` fence carries three row schemas across fifteen compositions — eight on A,
two on B, five on C — and `scripts/duws_eden.ps1` already normalises all three to
`[class, offX, offY, offZ, dir°]` before it does anything with them. The schemas exist because
three authors wrote three formats, not because any of them encodes something the others cannot.

- [ ] Convert the seven B and C compositions to schema A, then drop the B and C adapters from
      `duws_eden.ps1`.

## Why this is not a devcontainer job

The only check that means anything is "import each composition through `duws_eden.ps1` before and
after the conversion and diff the normalised rows". That tool is Windows PowerShell, so it needs a
Windows checkout. Nothing in `bash tests/run.sh` can see a wrong offset — a mis-transcribed row is
still balanced SQF holding a valid classname, so the syntax and path checks pass and the fault
surfaces as a prop in the wrong place, in game, later.

Whoever takes this either has a Windows checkout or ships it unverified. There is no third option,
and unverified is a real choice here: the conversion is mechanical and the diff is what proves it.

## Where the compositions are

Eight on schema A across `server/init_zones/prefabs/modern/` and `server/init_hq/`, five on C
across the same prefab tree and `server/missions/mission_threads/`, and the two B blocks in
`server/misc/killhouse_composition.sqf`. Grep for `DUWS-COMPOSITION BEGIN` to enumerate them; the
attribute on each fence names its schema.

Two constraints the tool imposes on any move — it enumerates `*.sqf` only, and it resolves a
`zbase=` attribute against the file holding the fence — are in
[`info/hq_layout_editing.md`](info/hq_layout_editing.md#eden-round-trip). They matter here because
the killhouse pair is exactly the case that trips both.
