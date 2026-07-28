# Hardcore mode and the intel system: implementation plan

Hardcore hides every enemy zone at campaign start and makes finding them the game. Intel is the
mechanism that unhides them, and it is broken in three separate ways — a lost-update race that
can switch it off for a whole campaign, two award sites that never fire on a dedicated server,
and a reveal decision made on the client against a broadcast snapshot. This rewrites the intel
system, fixes the locality, and gives hardcore a persistence shape it currently has none of.

## What hardcore changes today

| Behaviour | Where |
|---|---|
| Zone icon and ellipse created at alpha 0, `zone_namePOS_pairs` entry flagged unrevealed | `fnc_createzone.sqf:16,51,64` |
| Walking into a zone reveals it | `fnc_enterlocation.sqf:18-20` |
| Intel reveals one random unrevealed zone | `fnc_found_intel.sqf`, `fnc_zone_reveal.sqf` |
| "Search for Intel" actions appear on enemy leaders | `fnc_createopteam2.sqf:36-39`, `fnc_createopwpteam.sqf:37-40`, `fnc_createopfortified.sqf:36-39,204-206` |
| Side missions award intel on success | clearthearea_cqb `:189`, rescue_pilot `:606`, rescue_squad `:116`, sabotage_laptop `:194`, target_armor `:171`, target_sniper `:178` |
| Task forces refuse to launch until a revealed OPFOR zone exists | `hardcore_visibleZone_found`, read at `fnc_request_squad.sqf:82`, `fnc_request_squad_fob.sqf:68`, `fnc_WARCOM_blu_assault.sqf:54`, `fnc_WARCOM_opf_air.sqf:25` |
| Task-force waypoints only target revealed zones | `fnc_WARCOM_gps_marker.sqf:9-19` |
| Manual zone placement is disabled, since hand-placing defeats the mode | `fnc_callsign_menu.sqf:13-15` |

## The defects

### Two overlapping reveals disable intel permanently

`fnc_zone_reveal.sqf:44-50` throttles intel by saving `master_Intel_chance`, zeroing it,
sleeping 1200 s and restoring what it saved. With no lock and a 20-minute window, a second
reveal starting inside that window saves `0` as its original and restores `0` when it wakes.

It is reachable without trying: `fnc_enterlocation.sqf:18-20` reveals a zone on entry and is
**not** gated on `master_Intel_chance`, so it fires freely during another reveal's cooldown. In
hardcore, walking into zones is the game. Find intel, enter any zone within twenty minutes, and
every intel source is dead for the rest of the campaign.

This is the lost-update shape
[`info/arma_engine_gotchas.md`](info/arma_engine_gotchas.md#a-shared-global-mutated-as-x--x---c-publicvariable-x-loses-concurrent-writes)
already documents, disguised as a save/restore rather than an increment.

### Two award sites never fire on a dedicated server

`fnc_found_intel.sqf:2` is `if (!hasInterface) exitWith {}`, because it draws markers and hints.
Most callers respect that: they attach `{[] spawn fnc_found_intel}` as an `addAction` through
`fnc_actionRotary`, so it runs on the player who used the action.

Two do not. `fnc_rescue_pilot_mission.sqf:606` and `fnc_rescue_squad_success.sqf:116` call
`[] spawn fnc_found_intel` directly from a server thread. On a dedicated server `hasInterface`
is false and the reward silently evaporates; on a hosted server the host has an interface, so it
works for exactly one player. That is the failure signature
[`info/server_client_authority.md`](info/server_client_authority.md) exists to catch.

### The reveal decides itself on the client

Both intel rolls read `master_Intel_chance` wherever the caller happens to run, which for the
`addAction` path is the player's machine reading a `publicVariable`d snapshot. The client then
tells the server what to reveal (`fnc_found_intel.sqf:13`). So the cooldown is advisory: a
client whose copy has not caught up still passes the gate, and nothing server-side re-checks.

### Three near-identical recomputations of one flag

`fnc_captured.sqf:28-40`, `fnc_blufor_cap.sqf:27-38` and `fnc_opfor_cap.sqf:28-39` each rebuild
`hardcore_visibleZone_found` with the same nested loop over `WARCOM_zones_controled_by_OPFOR`
against `zone_namePOS_pairs`, comparing positions by `str`. One helper, called from three places.

### Informants ignore hardcore

`fnc_civ_informant_system.sqf:12` reads `if (!hardcore_mode_enable) then { continue; }` — but
that line sits *above* the `while` loop it means to skip, so `continue` has no loop to act on.
Informants spawn in every campaign regardless of the setting.

## Design

### Reveal state is the system, not a side effect

`zone_namePOS_pairs` entries are `[name, pos, revealed]` (`fnc_createzone.sqf:28`) and every
consumer compares positions by `str` because there is no index to key on. Reveal becomes an
explicit operation on that array with one writer, on the server, and the marker repaint follows
from the state rather than being done alongside it.

### The throttle becomes one attempt per player per economy tick

The campaign-wide `master_Intel_chance` mutation goes entirely. In its place each player gets a
single search attempt per 30-minute economy tick, at a **10 %** chance of a reveal.

Per player rather than campaign-wide is what makes it work in co-op: the old throttle was a
single global, so the first player to find intel switched it off for everyone, and a four-player
squad searched at the same rate as a lone operator. Here a squad genuinely searches four times
as fast, which is one of the few things co-op should be better at.

One roll, not two. The shape it replaces gated the action on `random 10 < 7.5` and then rolled
the same gate again inside `fnc_found_intel`, so the real chance was 56 % and neither number
said so.

`econ_tick` (`server/misc/fnc_zonesundercontrol.sqf`) is the clock, the same one the civilian
heal cap keys off. Nothing new is timed.

**State lives on the player object, broadcast.** `DUWS_intel_searched`, set true on the server
when a player spends their attempt, cleared on every player by the economy tick. It goes on the
unit with the public flag because the action's own condition reads it — see below — and that
condition runs on the client. Broadcasting one boolean per player is far cheaper than
broadcasting `econ_tick` so clients can compare numbers, and it means the tick clears state
rather than clients inferring it.

### The action hides itself while spent

An action that refuses is worse than no action. The search entry's `condition` tests
`!(_this getVariable ["DUWS_intel_searched", false])`, so it vanishes the moment the attempt is
used and returns when the tick clears it. The player never clicks something that answers no.

This is why the flag is per-player rather than a server-side table keyed by UID: a condition
string is evaluated on the client, several times a second, against whatever that machine can
see.

### The server owns the roll

`fnc_found_intel` splits. The decision — attempt check, chance roll, pick an unrevealed zone —
moves server-side. What stays client-side is presentation: the marker, the hint, the dialogue.
Server-side callers then call it directly and correctly, and the two dedicated-server holes
close because there is no `hasInterface` guard on the half that matters.

The attempt is spent on the *attempt*, not on success, and the server is what spends it. A
client cannot be trusted to report having already searched, and a 10 % roll the client makes is
a 10 % roll the client can retry.

### Which sources answer to the cap

| Source | Capped |
|---|---|
| Search-for-intel on an enemy | yes — one attempt per player per tick, 10 % |
| Side-mission award | no — the mission is its own gate, and a player cannot repeat it |
| Walking into a zone | not applicable; it reveals the zone the player is standing in and rolls nothing |
| Civilian interaction menu | no — see [`civilian_interaction_plan.md`](civilian_interaction_plan.md); the player paid a bribe, and that path is limited by per-civilian consumption |

Side missions leave the cap alone deliberately. The old design rolled the same throttle for them,
which meant a mission completed during another source's cooldown paid nothing and told the
player nothing about why.

## Persistence

A hardcore campaign's entire progress is *which zones it has revealed*, and today none of it
survives a restore. [`campaign_persistence_plan.md`](campaign_persistence_plan.md) treats
`zone_namePOS_pairs` as builder output rather than state — restoring it and replaying
`fnc_createZone` would double-count every zone — so the array is rebuilt from scratch and every
entry comes back with `_visible` set from `hardcore_mode_enable`. A restored hardcore campaign
therefore re-hides every zone the player had found.

The fix is small and fits the plan's existing input/outcome split: revealed state is an
**outcome**, applied after the builders have run, exactly like the Ownership group. Store the
positions of revealed zones and nothing else, and re-flag matching entries and repaint their
markers after build-out — the same shape as restoring which zones BLUFOR hold.

Storing the *state* rather than how it was reached is what makes this cheap, and it means every
source persists for free: a zone the player walked into, bought from a local, or won off a dead
officer all restore identically, because by then they are one flag.

`DUWS_intel_searched` is deliberately **not** stored. It is at most one attempt per player
against a campaign measured in hours, and a restored session where everyone's search is
available again is the forgiving failure.

`hardcore_visibleZone_found` is not stored either: it is derived from revealed state and OPFOR
ownership, both of which the restore already has, so the helper above recomputes it.

## Three reveal sources, kept deliberately

Proximity, the search-for-intel action on enemy leaders, and the civilian menu all stay. They
are not redundant with each other: proximity costs the walk in, the enemy action costs a
firefight, and the menu costs coins and a town's patience. Three prices for the same commodity
is the point, because a hardcore player who is out of one currency still has a route.

They do draw from one finite pool. A campaign has as many unrevealed zones as it was generated
with, so the sources compete rather than stack, and the hidden-map phase ends when the last one
is found however that happened. That is the intended arc rather than a leak — but it does mean
adding a fourth source later shortens hardcore rather than enriching it.

Only the two *rolled* sources answer to the cooldown; proximity reveals the zone the player is
standing in and rolls nothing, so there is nothing to throttle.

## Open questions

- Which enemies carry the search action. "Not only team leaders" admits two readings: every live
  OPFOR unit, or every OPFOR corpse. The corpse route reuses `fnc_add_intel_on_death`, which
  already reaches every body and adds no new `addAction` traffic, and searching a body reads
  better than searching a living soldier — but it is a different moment in the fight from the
  action on a live leader that exists today.
- Whether 10 % per player per tick is generous enough for solo hardcore. One attempt every
  thirty minutes at 10 % is an expected reveal every five hours alone, against roughly every
  seventy-five minutes for a four-player squad. Zones are hidden, so intel is the primary way to
  find the first one at all — the other two sources need a zone you already know about, or a
  town you have standing with. To be judged in play rather than argued.
