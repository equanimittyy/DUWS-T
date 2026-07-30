# Refactor backlog

What is left of the structural pass over `src/duws/`, in the order it should be taken. Each item is
independent; none blocks another. The two large ones are last because they are where the automated
checks stop being able to see anything.

Two other pieces of the same pass have plans of their own:
[`spawn_helpers_plan.md`](spawn_helpers_plan.md) and
[`registry_split_plan.md`](registry_split_plan.md).

## HQ unit placement is implemented twice

`server/init_hq/fnc_BluHQinit.sqf` (762 lines) places the HQ's units at build time and
`server/misc/fnc_redeployHQUnits.sqf` (261) places them again on a rebuild. The clone detector puts
110 duplicated lines in each — they are the same placement routine, written twice, and a change to
one is a change the other silently does not get.

`fnc_redeployFOBUnits.sqf` shows the shape the fix should take: it is 34 lines that check, charge
once, and delegate to `fnc_fortifyFOB` and `fnc_guardsFOB` rather than re-implementing either.

- [ ] Extract the placement routine, call it from both. Verify: HQ units stand in the same spots on
      a fresh campaign and after a redeploy, and the redeploy still charges once.

## The RAVAGE and WBK civilian handlers share 51 lines

`fnc_civ_handler_ravage.sqf` (407) and `fnc_civ_handler_wbk.sqf` (554) share 51 lines across seven
blocks, the largest nine lines. The plain handler, `fnc_civ_handler.sqf` (185), shares **nothing**
with either and must stay that way — it is what runs mod-free, and a mode strategy threaded through
it puts RAVAGE and WBK branches on the path every stock game takes.

The shape is a helper the two mode handlers call, never a third entry point all three enter.

- [ ] Extract the shared blocks. Verify: both modes spawn, clean up, and respect the spawn mutex;
      the plain path is untouched.

## Adding a side mission still touches seven places

Four of the seven are type-indexed tables kept in step by hand: the config switch and the
cooldown-ready notification switch in `client/missions/fnc_stratmap.sqf`, `_threads` in
`server/misc/fnc_debug_force_mission.sqf`, and `_types` in
`client/dialog/fnc_debug_mission_menu.sqf`. They agree today because somebody checked.

The file also carries 34 numbered globals (`mission0_pos` … `mission16_name`) that exist nowhere
else. Those are **not** carelessness: `array_of_missions` is handed to `BIS_fnc_strategicMapOpen`,
whose per-mission block runs with no arguments, so the block reaches its position and name through
globals because SQF blocks do not capture locals. Any fix has to preserve that, and has to preserve
the shuffle-and-draw that offers seven of seventeen types per opening.

Two smaller things live in the same file and should go with it: three `switch (VERSION_X)` blocks
inside the notification switch return the same string from case and default, and the comment above
the type array still reads `CURRENTLY 15 MISSIONS AVAILABLE` over seventeen entries.

- [ ] One definition table feeding all four consumers, with `[pos, name]` in a shared slot array and
      the deferred block built per index. Verify: seven missions drawn per opening, each launches
      the thread it names, the cooldown notification names the right mission, and every debug-menu
      row forces the type its label claims.

## Faction request tables: 2,389 padding entries and a 50-slot ceiling

`shared/factions/` is 27,758 lines across 256 files. The bulk is not the role globals, it is the
request menus: every BLUFOR file declares `blufor_RQST_VEHICLE_01_X` through `_50_X` and an
equivalent unit block, padded to full length with `["empty",0,0]` — **2,389 such entries**, existing
only because the consumer walks a fixed numbered range.

The consumers rebuild each name as a string with a zero-pad special case, and the two readers use
different thresholds for the same boundary (`> 9` on the raw counter in the menu builders, `> 10` on
the offset index in the request handlers). They agree only because the indices are off by one.

**This is the highest-risk item left, and the automated checks cannot help.** The globals are built
at runtime, so `check_paths.py` and the syntax pass see nothing; a subtly wrong conversion shows up
as empty request menus in-game and nowhere earlier.

Sequence matters more here than anywhere else:

- [ ] Change the consumer to read one array global (`blufor_RQST_VEHICLES = [[class, label, cost], …]`)
      **with the numbered globals as a fallback**, so nothing breaks while both shapes exist.
- [ ] Convert the 256 files by script, and `shared/factions/MODERN/fn_factionAutoDetect.sqf` in the
      same change — it generates the same names at runtime, so a conversion that skips it leaves
      auto-detected factions reading globals nobody writes any more.
- [ ] Delete the fallback only once a vanilla faction, a modded faction and an auto-detected faction
      have each been seen populating both menus.

## Composition schemas: three formats for one concept

The `--DUWS-COMPOSITION` fence carries three row schemas across fifteen compositions — eight on A,
two on B, five on C — and `scripts/duws_eden.ps1` already normalises all three to
`[class, offX, offY, offZ, dir°]`. The schemas exist because three authors wrote three formats, not
because they encode anything.

- [ ] Convert all fifteen to schema A and drop the B and C adapters from the tool.

**This one cannot be verified from the devcontainer.** Its check is "import each composition through
`duws_eden.ps1` before and after and diff the normalised rows", and that tool is Windows PowerShell.
Whoever takes it needs a Windows checkout, or the conversion ships unverified.

## Decide: does the killhouse composition stay inline

`server/misc/fnc_createKillhouse.sqf` is 1,334 lines, of which **821 are two composition arrays**
(`:18-727` and `:730-842`). They already sit behind the `--DUWS-COMPOSITION` fence that
`scripts/duws_eden.ps1` round-trips through Eden
([`info/hq_layout_editing.md`](info/hq_layout_editing.md)), so the tooling to treat them as data
exists and is in use.

The only question left is whether they move out. `preprocessFile` on a separate data file costs one
more path reference and buys a 513-line file in place of a 1,334-line one. That is the whole trade.

- [ ] Decide. If they move, the Eden tool has to keep finding them, so the fence markers travel with
      the arrays rather than staying behind.

## Decide: two broadcast globals nothing reads

`OvercastVar` and `FogArray` are declared and `publicVariable`'d in `server/server_var_init.sqf:174,220`
and written by `server/dialog/fnc_weather.sqf` on every cycle. **Nothing in `src/` reads either.**

They were left in place deliberately rather than swept with the rest of the dead code: a broadcast
global has an unknowable consumer — any client, any joining player — and unlike a local that is
provably overwritten before use, absence of a reader in this tree is not proof of absence of a
reader. The plan's own standing rule is not to touch `publicVariable` keys, because a missed one
fails silently at runtime with no compiler to catch it.

- [ ] Decide whether they go. If they stay, they cost two assignments per weather cycle and nothing
      else; if they go, it is a three-line deletion and a `publicVariable` key retired.
