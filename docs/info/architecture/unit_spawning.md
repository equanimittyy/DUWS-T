# Unit spawning: token API vs direct spawn

Two ways to raise OPFOR groups coexist in `duws/`. The newer one is the intended default; the older
one survives in most mission threads. This records the split, why the two are not interchangeable, and
the open decision blocking consolidation.

## The two paths

**Token API — the intended default.** `server/init_zones/fnc_spawn_team.sqf` and
`fnc_spawn_vehicle.sqf` raise a group from a composition *token* (`posture:name`), resolving the roster
through `DUWS_teamRosters` (`shared/functions/fnc_spawn_vocab.sqf:50`) and the faction pools. One call
does side, AI skill, loot, position banding and patrol orders. The rosters are data — a team added to
the table is spawnable without touching code, which is what lets the composition TUI add one
(see [`composition_tooling.md`](composition_tooling.md)).

**Direct spawn — legacy.** A raw `[_pos, EAST, [class, class, ...], [], [], opfor_ai_skill] call
BIS_fnc_spawnGroup`. The class list is hand-written inline and every downstream concern (skill, loot,
waypoints) is the caller's to repeat or forget.

What the token path centralises, and the direct path scatters or drops:

| Concern | Token path | Direct path |
|---|---|---|
| Side | `EAST` in one file | `EAST` at every call site |
| AI skill | `opfor_ai_skill` always applied | per-site; some sites pass none (`server/missions/mission_threads/protect_civ/fnc_protect_civ.sqf:243`) |
| Loot / body-search identity | `fnc_addRandomLoot` on every man | only where the caller remembers |
| Waypoints | `fnc_apply_posture`; `"none"` is a verified no-op for exact placement | hand-written or absent |

## Two constraints that shape any fix

- **`fnc_spawn_team` is OPFOR-only by design.** It hardcodes `EAST` and asks the shared roster for the
  OPFOR side; its header states this is "the OPFOR zone spawner". WEST and CIVILIAN groups therefore
  *cannot* route through it without adding a side parameter, which fights the file's whole design.
- **It takes a token, not a raw class list.** `DUWS_fnc_teamRoster` looks the name up in
  `DUWS_teamRosters` and returns nothing for an unknown token. A one-off or dynamically built class list
  has no row to name, so it cannot use the API as written.

## The gap: direct-spawn call sites in mission threads

The direct spawn sites that remain, and why each stays direct — most are not a simple migration:

| Sites | What they raise | Why still direct |
|---|---|---|
| `protect_civ:243` | 8-man OPFOR wave | convertible — one-off composition, no row; also the site that passes no skill |
| `deny_armor:133` | tank repair crew `[CREW, CREW, ENG]` | convertible — one-off composition |
| `destroy_cache:152/154`, `destroy_radar:100/102` | 1-man bunker gunner | frozen static gunner: wants no posture and no loot; belongs in a shared bunker-gun helper, not the team API |
| `protect_civ:70`, `rescue_pilot:442`, `rescue_squad:72` | WEST group | side param could route these, but they are a civilian VIP and follow-player rescue squads — they want no posture and no loot |
| `transport_idap:121` | CIVILIAN group | not OPFOR |
| `target_sniper:87` | OPFOR perch pair | deliberate exception, documented at the call site |
| `deny_armor:155/165/181` | convoy vehicles | scripted self-routing convoy; posture bands would fight the convoy logic |

Line numbers are anchors into `server/missions/mission_threads/<name>/`; they drift with edits.

Already migrated (reference examples): `target_armor`, `target_sniper`, `rescue_squad` and
`sabotage_laptop` call `fnc_spawn_team`/`fnc_spawn_vehicle`. `rescue_squad:118` shows the
exact-placement pattern — a token with `"none"` posture and a supplied position. The `steal_builder`,
`steal_supply` and `transport_idap` vehicle guards share that pattern through the existing `team` row.

## Decision: side parameter

`fnc_spawn_team` and `fnc_spawn_vehicle` take a trailing `_side` (`"opfor"`/`"blufor"`, default
`"opfor"`). One string drives the engine side, the skill globals and the roster prefix; the shared
roster already held bare role names and asked for a side (`DUWS_fnc_teamRoster`), so the primitives were
the only OPFOR-hardcoded layer. Defaulting to `"opfor"` keeps every existing caller spawning as before —
the argument is appended past `_spawnPos`, and no caller passed one there.

CIVILIAN is deliberately *not* a value: only the two armies have a role vocabulary and skill globals
(`format ["%1_%2", _side, role]` has no `civilian_` pool). A civilian group stays a direct
`BIS_fnc_spawnGroup`.

Not chosen: the raw-list escape hatch (let the API take a class array, not just a token). Dynamic and
one-off class lists — the `protect_civ:243` / `deny_armor:133` one-offs — still
cannot name a roster row, so they stay direct until a row is added for the recurring ones. The side
parameter does not address them.

## Call-site conversions still owed

The primitive is done; routing sites through it is separate, per-site work. `steal_builder`,
`steal_supply` and `transport_idap` now raise their vehicle guard through `fnc_spawn_team` with `"none"`
posture at the vehicle point, reusing the existing `team` row rather than earning a new one. That trades
the old hand-written three-man `[SL, LAT, SOLDIER]` guard for the six-man `team`, a deliberate difficulty
bump; loot is unchanged in kind, since all three already looted their guards.

The side parameter *enables* the WEST conversions but does not settle them: a converted site gains
`fnc_apply_posture` and `fnc_addRandomLoot` whether it wants them or not. `rescue_squad:72` and
`rescue_pilot:442` raise a WEST group that should follow the player, not garrison under a posture, and
wants no loot — those stay direct by choice, not by limitation. Any conversion that adds loot to a group
that had none changes body-search identity (searchable bodies feed faction detection), so each converted
thread needs an in-game check of head-count, position, AI behaviour and body-search identity.

The deliberate-exception sites (`target_sniper:87`, the `deny_armor` convoy hulls) remain correct as
direct spawns: the convoy hulls need bespoke column seating that the posture band would fight, and route
through raw `BIS_fnc_spawnVehicle` — the side parameter never reaches them.
