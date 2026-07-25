# Subzone system: implementation plan

Add a third objective tier between side missions and zone capture. A subzone is a small
garrisoned position attached to an enemy zone: more numerous than zones, faster to clear,
and worth less. It exists to give a player who is short on CP something to do that moves
the campaign forward.

Subzones run on their own state and their own capture handler. They must not pass through
`fnc_createZone` or `fnc_zone_control_set`, for reasons set out under
[§Why subzones cannot be small zones](#why-subzones-cannot-be-small-zones).

Background on how zones are placed, captured and consumed:
[`info/zone_and_town_generation.md`](info/zone_and_town_generation.md).

## Why subzones cannot be small zones

`fnc_createZone` writes five campaign registries in its first fourteen lines
(`server/init_zones/fnc_createzone.sqf:19-32`) and `fnc_zone_control_set` moves four globals
as one atomic transition (`server/server_fnc_init.sqf:81-120`). Both are all-or-nothing.
Routing a subzone through either puts it into every consumer of zone state at once:

| Global | Written by | What breaks if a subzone increments it |
|---|---|---|
| `amount_zones_created` | `server/init_zones/fnc_createzone.sqf:19-20` | The campaign never ends. The win condition is `zoneundercontrolblu >= amount_zones_created` (`server/misc/fnc_capture_zones_task.sqf:33`). FOB cap inflates too (`client/supports/fnc_request_fob.sqf:16`) |
| `zoneundercontrolblu` | `server/server_fnc_init.sqf:97,110` | Passive income becomes `(zones + subzones) * 6` per 30 min (`server/misc/fnc_zonesundercontrol.sqf:11`) — the largest balance blow-up available |
| `WARCOM_zones_controled_by_OPFOR` | `server/server_fnc_init.sqf:95,107-108` | Index 0 is the OPFOR primary assault target. A lost subzone redirects the entire enemy war effort. 25+ read sites |
| `zone_namePOS_pairs` | `server/init_zones/fnc_createzone.sqf:28-29` | Intel reveals pick a random entry (`client/misc/fnc_found_intel.sqf:5`), so subzones dilute what intel is worth |
| `zone_spawn_array` | `:32` | Lookup is positional — `find [_zone_num,false,false]` (`:221`) — so a duplicate number matches the wrong entry |

The subzone tier therefore gets parallel state built to the same template, and touches none
of the above.

## Design

### Siting

Subzones are placed off the zone list, after it is published. Two per enemy zone, in the
annulus between 600 m and 1,500 m from the zone centre, so a subzone is always outside its
parent's capture trigger area (zone radius maxes at 1,000 m, `server/server_var_init.sqf:211`)
and always close enough to read as belonging to it.

```sqf
private _parents = serv_zones_array;   // flat [x,y] pairs, 2D
```

`serv_zones_array` entries are two-element `[x,y]` (`server/init_zones/fnc_locatorzones_random.sqf:180`),
so normalise to `[x,y,0]` and compare with `distance2D`. Under manual placement the array is
published from the game-master **client** (`server/warcom/fnc_init_OPFOR_WARCOM.sqf:14`,
`server/init_zones/fnc_locatorzones_manual.sqf:121-122`), so the siting pass must wait on the
array rather than on a server-side generation flag.

Rejection rules, cheapest first: at least 300 m from another subzone, at least 400 m from
`PosOfBLUHQ`, not on water. No keep-out against civilian towns — a subzone on a town edge is
a good fight, and the town registry is server-local anyway.

### State

Three broadcast parallel arrays, indexed together. All entries are numbers or strings, which
keeps them serialisable — the mission namespace is the save file
([`info/arma_engine_gotchas.md`](info/arma_engine_gotchas.md), §mission namespace).

| Variable | Shape | Broadcast |
|---|---|---|
| `subzone_pos_array` | `[[x,y,0], …]` | yes, once at generation |
| `subzone_owner_array` | `[0\|1, …]` — 0 OPFOR, 1 BLUFOR | yes, on every transition |
| `subzone_parent_array` | index into `serv_zones_array` | yes, once at generation |
| `subzone_count_blu` | number, derived | yes, on every transition |

No Location objects, no object handles, no `createLocation`. Trigger handles go in
`subzone_trg_<i>` as the zone code does (`server/init_zones/fnc_createzone.sqf:266-267`), which
is a local script variable pattern, not campaign state.

### Capture

One trigger per subzone, same shape as a zone's (`:259-264`) but firing a subzone handler:

```sqf
_trg setTriggerArea [150, 150, 0, false];
_trg setTriggerActivation ["WEST SEIZED", "PRESENT", true];
```

`fnc_subzone_captured` opens with `if (!isServer) exitWith {}` — the three zone handlers all
do (`server/init_zones/fnc_captured.sqf:12-14`) because trigger evaluation locality is
unproven. It calls one transition writer, `fnc_subzone_control_set`, which owns
`subzone_owner_array` and `subzone_count_blu` together and broadcasts both. That mirrors
`fnc_zone_control_set` (`server/server_fnc_init.sqf:81-120`) and satisfies the one-writer rule
in [`info/server_client_authority.md`](info/server_client_authority.md).

### Garrison

Four to eight units and one static weapon, built from the `opfor_*_X` faction globals exactly
as `server/init_zones/fnc_createopfortified.sqf:14,23,43` does. Hardcoding unit classnames is
the single change that would break mod-free operation and faction auto-detection; hardcoding
vanilla `Land_*` structures is fine, and the zone code already does it (`fnc_createzone.sqf:145-151`).

No spawn/despawn loop. A subzone garrison is small enough to leave alive for the campaign,
which avoids adding to the 39 `while {true}` loops the server already runs.

### Reward

This is the part that needs care, because the existing tiers already overlap: zone capture
pays 10–50 CP (`server/init_zones/fnc_captured.sqf:41`, worth = radius/10 halved) and side
missions pay 5–45 CP (`server/missions/fnc_mission_reward.sqf`). There is no room to price a
third tier below both — CP is integer with a floor of 1 (`server/server_fnc_init.sqf:18-24`).

So the tier separates by *shape*, not size:

| Tier | One-off | Ongoing |
|---|---|---|
| Zone capture | 10–50 CP, AP swing | `zones_held * 6` CP / 30 min |
| Side mission | 5–45 CP, AP | none |
| **Subzone** | **5 CP, 10 BLUFOR AP** | **`subzones_held * 3` CP / 30 min** |

The ongoing half is what makes a subzone worth taking when the player is short on resources,
which is the stated purpose. It is one added term in `server/misc/fnc_zonesundercontrol.sqf:11`
and reads `subzone_count_blu`, never `zoneundercontrolblu`.

CP and AP go through the existing delta writers, `fnc_cp_adjust` and `fnc_ap_adjust`
(`server/server_fnc_init.sqf:12,41`). Never `x = x + n; publicVariable "x"` from a trigger body.

### Markers

Markers are named `subzone_<i>` and `subzone_<i>_ellipse`. They must not use the
coordinate-derived scheme: zones use `<round x><round y>` (`fnc_createzone.sqf:38,52`) and side
missions use `<markerText><round x><round y>` (`server/missions/fnc_missionMarkerData.sqf:7,17`),
and `createMarker` on a taken name returns `""` with no error. A subzone sited within a metre
of either would fail silently.

Icon `o_installation`, `ColorRed` while OPFOR and `ColorBlue` once taken, ellipse alpha 0.2.
Hardcore mode hides subzone markers on the same rule zones use, but subzones stay out of
`zone_namePOS_pairs`, so `server/init_zones/fnc_zone_reveal.sqf` needs no change.

### Ordering

The siting pass runs inside `server/warcom/fnc_init_OPFOR_WARCOM.sqf`, after the existing gate
on `serv_zones_array` at `:22` and before `fnc_WARCOM_init` at `:34`. Wait with
`fnc_waitLogged`, which returns false on timeout and lets the caller continue
(`shared/functions/fnc_log_init.sqf`); on timeout, generate no subzones and log it. A campaign
whose zones never appeared has already failed elsewhere.

## Files touched

| File | Change |
|---|---|
| `server/init_zones/fnc_subzone_place.sqf` | New. Siting, state arrays, markers, triggers, garrison dispatch. |
| `server/init_zones/fnc_subzone_captured.sqf` | New. Server-guarded capture handler; marker recolour; reward. |
| `server/server_fnc_init.sqf` | New `fnc_subzone_control_set` transition writer beside `fnc_zone_control_set:81-120`; three registry lines. |
| `server/warcom/fnc_init_OPFOR_WARCOM.sqf:26` | Call the siting pass after the zone-array gate. |
| `server/server_var_init.sqf` | Declare and broadcast the four subzone globals. |
| `server/misc/fnc_zonesundercontrol.sqf:11` | Add the `subzone_count_blu * 3` term. |
| `client/missions/fnc_stratmap.sqf:147-155` | Add a 250 m subzone keep-out to mission siting. Missions already keep out of zones; without this they can spawn on top of a subzone. |
| `shared/includes/notifications.hpp` | One notification class for subzone capture, beside `CPadded:87`. |
| `stringtable.xml` | Subzone name, capture notification, marker label. |
| `info/zone_and_town_generation.md` | Document the tier and its state contract. |

## Task list

- [ ] Write `fnc_subzone_place.sqf` with siting and state only — no garrison, no trigger. Verify: `bash tests/run.sh` passes the path lint; markers appear in the right annulus around every zone.
- [ ] Add the garrison spawn, built from `opfor_*_X` globals. Verify: start a campaign with a faction mod loaded and confirm no `Land_`/vanilla classnames leak in.
- [ ] Add the capture trigger and `fnc_subzone_captured`; write `fnc_subzone_control_set`. Verify: clearing a subzone flips its marker and increments `subzone_count_blu` exactly once.
- [ ] Wire the reward: 5 CP / 10 AP one-off, plus the passive term in `fnc_zonesundercontrol.sqf`. Verify: `zoneundercontrolblu` and `amount_zones_created` are unchanged after a subzone capture.
- [ ] Add the mission-siting keep-out in `fnc_stratmap.sqf`.
- [ ] In-game: capture every zone with subzones still held and confirm the campaign still ends. This is the regression the whole design exists to prevent.
- [ ] In-game: repeat with manual zone placement, where `serv_zones_array` is published from a client.
- [ ] Update `info/zone_and_town_generation.md`.

## Decided trade-offs

**Subzones cannot be lost.** Capture is one-way; there is no `EAST SEIZED` re-arm as zones
have (`server/init_zones/fnc_captured.sqf:66-71`). Making them retakeable means teaching the
OPFOR director to target them, and WARCOM's assault, QRF and patrol logic all read
`WARCOM_zones_controled_by_*` — the lists subzones deliberately stay out of. If subzones
should be contestable later, the addition is a subzone assault thread, not a change to this
design.

**Subzones are invisible to WARCOM.** The enemy director does not defend or retake them, does
not route patrols through them, and does not count them when sizing an assault. A player can
therefore clear every subzone unopposed by anything but the local garrison. That is the price
of not touching the zone registries, and it is the right price.

**Two per zone is a constant, not a setting.** `zones_number` already ranges widely and the
subzone count multiplies it; a separate knob invites 6 zones x 8 subzones and 48 extra
garrisons. Raise the constant if play says so.

**No dependency on the civilian town rewrite.** Attaching subzones to towns was considered —
towns already carry position, radius, trigger and markers per index
([`civilian_town_generation_plan.md`](civilian_town_generation_plan.md)) — and rejected. The
town registry is not broadcast (`server/misc/fnc_civ_init_Tomata.sqf:141-142`), indices are
re-keyed by that pending rewrite, and towns are absent entirely when civilians are off.
Siting off `serv_zones_array` gets the same "near the fighting" property with no shared
schedule.
