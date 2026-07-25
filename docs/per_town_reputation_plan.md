# Per-town reputation: implementation plan

Reputation becomes a per-town number. Killing a civilian in one town stops costing the player
standing in a town on the other side of the map. `Player_Reputation` survives as the global
readout so the campaign-wide consumers keep working unchanged; the consumers that are already
local — hostile civilian conversion, suicide bombers, informants, aid, fast travel — read the
town they are acting in.

This plan lands **after** [`civilian_town_generation_plan.md`](civilian_town_generation_plan.md).
That rewrite re-keys the town registry, and per-town reputation keys on the same index.

## Why the current system is replaced

| Problem | Where |
|---|---|
| One global scalar carries all reputation. Every civilian death anywhere moves the same number | `server/server_var_init.sqf:155`, sole writer `server/server_fnc_init.sqf:126-134` |
| The consumer that matters most is *already* per-town and reads a global — hostile conversion computes `(abs Player_Reputation * 3) min _totalGroups` per town | `server/misc/fnc_civ_handler.sqf:532-536` |
| Suicide bombers, the same | `:565-568` |
| Two reputation gates run on clients, so they cannot read server-local town state | `shared/functions/fnc_addAskEnemyAction.sqf:36`, `shared/functions/fnc_civ_recruitAction.sqf:18` |
| The recovery loop ratchets upward without bound: its stop condition is exact equality with 1, which fractional deltas (`-0.3`, `+0.5`, `-0.4`) make unreachable | `server/misc/fnc_civ_init_Tomata.sqf:196-221` |
| That ratchet feeds an uncapped CP faucet at `ceil(rep/2)` every 15 minutes | `:234-237` |

The last two are not per-town problems, but per-town reputation multiplies the ratchet by the
town count. Fix it in this change.

## Design

### State

One index-parallel array beside `civ_locations`, not N separate globals. `publicVariable`
broadcasts an absolute with no lock, and one variable per town multiplies both the traffic and
the lost-update surface described in
[`info/arma_engine_gotchas.md`](info/arma_engine_gotchas.md).

| Variable | Shape | Broadcast |
|---|---|---|
| `civ_town_rep` | numbers, index-parallel to `civ_locations` | yes, on every write |

Initial value 1 per town, matching the current global default (`server/server_var_init.sqf:155`).
The index is the position in `civ_locations`, assigned by `forEachIndex` after the overlap cull
(`server/misc/fnc_civ_init_Tomata.sqf:127-147`) — the same town ID every civilian consumer
already uses.

### The writer

`fnc_town_rep_adjust [_townIndex, _delta, _reason]`, built to the same contract as
`fnc_rep_adjust` (`server/server_fnc_init.sqf:126-134`): server-only, signed delta, the writer
owns the rounding, callers never assign. [`info/server_client_authority.md`](info/server_client_authority.md)
names the delta writers as the mission's authority template, and
[`info/cp_economy.md`](info/cp_economy.md) explains why rounding cannot move to callers —
`abs Player_Reputation` is multiplied into an AI spawn count, so drift reaches AI behaviour.

It writes `civ_town_rep`, broadcasts the whole array, and then calls `fnc_rep_adjust` with the
same delta so the global tracks as it does today.

### Resolving the town

Two cases, both already solved somewhere in the tree:

**The event has a unit.** Civilian deaths and looting act on a civilian who already carries its
town: `civ_locIndex`, set at `server/misc/fnc_civ_handler.sqf:492` and read at `:340,:567,:571`.
This is exact — no distance test.

**The event has only a position.** Iterate `civ_locations` / `civ_radii` in parallel and take
the first town whose radius contains the point. `server/misc/fnc_disguiseAsCivilian.sqf:256-266`
already does exactly this and can be lifted verbatim into a helper.

If neither resolves a town — the player is in open country, or civilians are off — the delta
goes to the global only. That is the degradation path and it must be the default, not an error.

Do **not** try to read the presence triggers: `server/misc/fnc_civ_init_Tomata.sqf:159-172`
discards the handle at creation, so there is no `list _trg` to query.

### Which consumers move

| Consumer | Where | Reads |
|---|---|---|
| Hostile civilian conversion | `server/misc/fnc_civ_handler.sqf:532-536` | **town** |
| Suicide bombers | `:565-568` | **town** |
| Hostile replacement spawn | `:381-382` | **town** |
| Informant spawn chance | `server/misc/fnc_civ_informant_system.sqf:16-20` | **town** |
| Develop informant | `server/misc/fnc_civ_developInformantServer.sqf:15-22` | **town** |
| Ask for aid | `server/misc/fnc_civ_askForAid_server.sqf:15-20` | **town** |
| Ask for toolkit | `server/misc/fnc_civ_askForToolkit_server.sqf:15-20` | **town** |
| Recruit civilian | `shared/functions/fnc_civ_recruitAction.sqf:18,32` | **town** — must move server-side first |
| Ask enemy location | `shared/functions/fnc_addAskEnemyAction.sqf:36-39` | **town** — must move server-side first |
| Disguise break inside a town | `server/misc/fnc_disguiseAsCivilian.sqf:256-266` | **town** |
| Fast travel | `server/misc/fnc_civ_fast_travel_server.sqf:13-20` | **town** (destination) |
| Hire partisans | `server/misc/fnc_hirePartisans.sqf:22-26,43` | global |
| CP income tick | `server/misc/fnc_civ_init_Tomata.sqf:234-237` | global |
| SITREP display | `client/misc/fnc_sitrep_display.sqf:28,40` | global |

The two client-side gates have to move server-side before they can read town state, following
`fnc_civ_askForAid_server.sqf` as the pattern — its siblings already work this way. Leaving
them client-side and broadcasting the registry instead is the wrong trade: it exports civilian
internals to every machine to serve two `addAction` conditions.

### Fixing the recovery ratchet

Same change, because per-town multiplies it. Recovery becomes per-town, and the stop condition
becomes a clamp rather than exact equality:

```sqf
if (_townRep >= 1) exitWith {};    // not: if (_townRep == 1)
```

A town at or above its baseline stops recovering. Fractional deltas can no longer walk past the
stop condition, and the CP faucet at `:234-237` stops being unbounded.

## Files touched

| File | Change |
|---|---|
| `server/server_fnc_init.sqf` | New `fnc_town_rep_adjust` beside `fnc_rep_adjust:126-134`; new `fnc_civ_townAt` position→index helper; registry lines. |
| `server/misc/fnc_civ_init_Tomata.sqf` | Initialise and broadcast `civ_town_rep` alongside `civ_locations:141`; rewrite the recovery loop `:196-221` as per-town with a clamped stop. |
| `server/misc/fnc_civ_rep_Tomata.sqf:27` | Route the civilian-death `-0.3` through the town writer, resolving the town from the victim's `civ_locIndex`. |
| `server/misc/fnc_civ_handler.sqf:381,532-536,565-568` | Read town rep instead of the global. |
| `server/misc/fnc_civ_handler_wbk.sqf:135-136` | Same for the WBK path. |
| `server/misc/fnc_civ_informant_system.sqf:16-20` | Town rep. |
| `server/misc/fnc_civ_developInformantServer.sqf:15-22` | Town rep. |
| `server/misc/fnc_civ_askForAid_server.sqf:15-20`, `fnc_civ_askForToolkit_server.sqf:15-20` | Town rep. |
| `server/misc/fnc_civ_fast_travel_server.sqf:13-20` | Destination town's rep. |
| `server/misc/fnc_disguiseAsCivilian.sqf:256-266` | Town rep; the town lookup here becomes the shared helper. |
| `shared/functions/fnc_civ_recruitAction.sqf`, `fnc_addAskEnemyAction.sqf` | Move the gate server-side, then read town rep. |
| `shared/functions/fnc_civ_lootAction.sqf:44`, `fnc_civ_healAction.sqf:69` | Resolve the town from the civilian acted on. |
| `server/missions/mission_threads/protect_civ/fnc_protect_civ.sqf:206,227` | Resolve from the escorted civilian; fall back to global. |
| `server/missions/mission_threads/transport_idap/fnc_transport_IDAP_mission.sqf:236,253` | Resolve from delivery position; fall back to global. |
| `server/misc/fnc_warcrimes_script.sqf:46` | Resolve from the damaged building's position. |
| `info/cp_economy.md` | Document the second reputation writer and the clamped recovery. |

## Task list

- [ ] Add `civ_town_rep` and initialise it per town; broadcast once. Verify: `bash tests/run.sh`; array length matches `count civ_locations` after the overlap cull.
- [ ] Write `fnc_town_rep_adjust` and `fnc_civ_townAt`. Verify: a civilian killed in town A moves only town A's entry.
- [ ] Move the two client-side gates server-side, unchanged in behaviour, before touching what they read. Verify: recruit and ask-enemy still work for a non-host player.
- [ ] Convert the per-town consumers in the table above.
- [ ] Rewrite the recovery loop as per-town with the `>= 1` clamp. Verify: leave a campaign idle after one civilian death and confirm reputation stops at 1 instead of climbing.
- [ ] In-game: drive reputation negative in one town and confirm hostile civilians and suicide bombers appear there and nowhere else.
- [ ] In-game: confirm the global still gates partisan hiring and the CP tick as before.
- [ ] Update `info/cp_economy.md`.

## Decided trade-offs

**The global receives the raw delta, not one derived from nearby towns.** The original
suggestion was to compute the global's plus/minus from the reputation of towns near the
player. Feeding it the same delta the town received is simpler, keeps the global's current
behaviour bit-for-bit, and means every consumer still reading the global is unaffected by this
change. If the global later needs to be a genuine aggregate, that is a separate change with its
own regression risk, and it should not ride along with the per-town split.

**Reputation still has no floor.** Unlike CP and AP, negative reputation is the mechanic
(`info/server_client_authority.md`). Per-town pools are not clamped at zero, only at their
recovery ceiling.

**One hated town can lock one zone.** At negative reputation a share of civilians re-side to
`resistance` (`server/misc/fnc_civ_handler.sqf:532-534`), which `server/server_init.sqf:31` sets
hostile to west, and a zone's capture trigger is `WEST SEIZED`
(`server/init_zones/fnc_createzone.sqf:259`). Hostile civilians standing inside a zone block its
capture. Today that risk is spread across the map by the global; per-town concentrates it. It
is the feature working as intended, but it is now possible to permanently lock one zone by
misbehaving in one town, and that should be a known consequence rather than a surprise.

**Towns are re-keyed by the civilian rewrite.** `civ_town_rep` keys on the array index, and
[`civilian_town_generation_plan.md`](civilian_town_generation_plan.md) replaces the selector and
caps towns at 21. Landing this plan first means re-keying it twice. Keying on town name instead
would survive the rewrite but breaks the moment two map towns share a name, which Altis does
not guarantee.
