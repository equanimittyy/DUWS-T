# OPFOR area of influence

Zone ownership is list membership (`WARCOM_zones_controled_by_BLUFOR`) and town ownership is a
number (`civ_town_rep`); neither says anything about the ground *between* them. The area of
influence is a signed coverage field over the whole map that fills that gap. Two things read it:
passive town-reputation drift, and where OPFOR's standalone hardpoints get sited.

## The field

`server/warcom/fnc_aoi_init.sqf` defines the field as coverage, not a magnitude: a point is either
within reach of a side's ground or it isn't, with no falloff and no per-emitter strength, because
the drift it drives is a flat step rather than a weighted one (see [Rep drift](#rep-drift)).
`DUWS_fnc_aoi_covers` (`fnc_aoi_init.sqf:17`) is the shared primitive both sides' coverage tests
wrap (`fnc_aoi_opfor_covers` / `fnc_aoi_blufor_covers`, `:62-63`); `fnc_aoi_field_at [_pos]`
(`:68-73`) composes the two into an OPFOR-positive dominance value: `+1` OPFOR-only, `-1`
BLUFOR-only, `0` contested or empty. Siting reads `fnc_aoi_field_at`; the drift reads the two
coverage primitives directly so it can layer the radio-tower amplifiers on top.

| Emitter | Side | Reach beyond its edge |
|---|---|---|
| OPFOR radio tower | OPFOR | `AOI_TOWER_REACH` = 5000 m, the longest on the map |
| Zone | its controller | `_size + AOI_ZONE_REACH` (2000 m) |
| Player HQ | BLUFOR | `AOI_HQ_REACH` = 2000 m |
| FOB | BLUFOR | `AOI_FOB_REACH` = 2000 m |
| Banded town | its band's side | `civ_radius + AOI_TOWN_REACH` (2000 m) |

Reach is measured from each source's outer edge, not its centre, so a naturally large zone claims
proportionally more ground than a small one — the constants live at `server_var_init.sqf:451-455`.
BLUFOR's radio supports are not in this table: they have no structure on the map, so they carry no
reach and only amplify BLUFOR's drift wherever the emitters above already cover (see
[Radio towers](#radio-towers)).

A town emits only once its reputation has fully crossed `±10` — the same `OPFOR_BAND` threshold
that already flips a town's side for garrison and income
(`server/civilian/fnc_civ_garrison.sqf:33`, `fnc_civ_state_init.sqf:296-301`). A neutral town is inert,
so influence spreads only from a town that has fully fallen, never one merely leaning.

The reaches are large against Altis by intent: OPFOR starts holding every zone (all zones are
OPFOR until captured) with towers already up, so the field opens OPFOR-positive across most of the
map, while the player opens with `AOI_HQ_REACH` — 2 km around the HQ — and whatever FOBs get
built. That asymmetry is the starting pressure the rest of the mechanic answers.

### The exclusion

The area of influence is the field's OPFOR-positive region minus the interior of every zone.
`fnc_aoi_in_any_zone [_pos]` (`fnc_aoi_init.sqf:79-82`) tests a point against each zone's own
`_size`, whoever holds it; inside a zone is the zone hardpoint ring's ground (see
[`hardpoints.md`](hardpoints.md)), not the band's. The field still *covers* zone interiors — a
town under a zone still drifts — but siting reads `fnc_aoi_field_at > 0 && !(fnc_aoi_in_any_zone)`,
so a candidate outside every zone in OPFOR-positive ground is the band.

## Rep drift

Every 30-minute economy tick, before that tick's income tally, each town reads coverage at its
centre and steps its reputation by the difference of the two sides' pushes
(`server/warcom/fnc_zonesundercontrol.sqf:39-47`, sharing the tick's own `sleep 1800` at `:11-12`
rather than running a loop of its own):

```sqf
private _opforPush = 0;
private _bluforPush = 0;
if (_townPos call fnc_aoi_opfor_covers)  then { _opforPush  = 1 + DUWS_opforRadioLevel };
if (_townPos call fnc_aoi_blufor_covers) then { _bluforPush = DUWS_bluforRadioLevel };
if (_bluforPush != _opforPush) then {
    [_forEachIndex, _bluforPush - _opforPush, "aoi_drift", true] call fnc_town_rep_adjust;
};
```

The pushes are asymmetric by design. **OPFOR pushes by holding ground**: a base `1` for coverage
alone, plus `DUWS_opforRadioLevel` (its standing radio towers, capped at `AOI_OPFOR_TOWER_CAP` =
5) — so a town in undisputed OPFOR ground drifts as low as `-6` a tick. **BLUFOR pushes only once
it has paid to**: `DUWS_bluforRadioLevel` (the tier bought, `0`-`3`) with no base, so a
BLUFOR-covered town drifts `0` until a radio-tower support is bought, then `+1` to `+3` by tier.
Coverage with no tier pushes nothing; a tier with no coverage has nothing to push. A town's first
rep lever is capturing zones (removes OPFOR's coverage and base push where it hurts most); the
second is buying towers (turns BLUFOR coverage into an actual pull).

The writer is the existing `fnc_town_rep_adjust` (`server/warcom/fnc_economy_init.sqf:136-157`),
already clamped to `[-20, 20]`; the drift is a silent caller (`_silent` param, `:138`) beside its
event callers, so it repaints the town marker without posting a notification card. Every consumer
rep already drove — the OPFOR/BLUFOR band, town income, the map marker colour — follows for free.

## Radio towers

A radio tower amplifies its side's drift push; the two sides differ in whether that amplifier also
carries coverage.

### OPFOR: a physical hardpoint

`DUWS_opforRadioLevel` is the live count of uncleared `"RADIO"` rows in the `DUWS_hardpoints`
registry, capped at `AOI_OPFOR_TOWER_CAP` (`server_var_init.sqf:463-465`). It is recomputed, never
incremented in place, by `DUWS_fnc_aoi_opforRecount`
(`server/init_zones/fnc_hardpoint_stream.sqf:21-24`), called whenever a `"RADIO"` hardpoint is
registered (`:328`) or cleared (`:182`) — so a destroyed tower drops the amplifier, and its
`AOI_TOWER_REACH` coverage with it, in the same recount. `"RADIO"` is a hardpoint type like any
other (`DUWS_hardpointName`, `DUWS_hardpointGarrison`, `server_var_init.sqf:417,430`), sited via
`fnc_hardpoint_seed_radio` (`server/init_zones/fnc_hardpoint_place.sqf:355-393`), which samples the
band, rejects any draw inside another tower's `AOI_TOWER_REACH`, and stands the mast on the
best-scoring hilltop of what survives. It is deliberately absent from `DUWS_hardpointWeightZone`
and `DUWS_hardpointWeightSolo` (`server_var_init.sqf:405-410`) — a tower is placed on purpose,
never rolled into the ordinary hardpoint mix.

### BLUFOR: a permanent support, no structure

`DUWS_bluforRadioLevel` is the tier bought, `0`-`3`, recomputed from the permanent-support record
on every grant (`server/supports/fnc_support_perm_grant.sqf:19`). It is three `PERM` catalogue
rows — `radio1`/`radio2`/`radio3` — in `client/supports/fnc_supports_init.sqf:32-34`, gated so a
tier is hidden until the one below it is owned (`:74-75`). Nothing is placed and nothing streams:
the purchase itself is the whole effect, so there is no BLUFOR structure for OPFOR to destroy in
answer to a rising amplifier — only ground to retake.

## Band siting

`DUWS_fnc_aoi_bandPos` (`fnc_aoi_init.sqf:91-106`) is the shared candidate sampler: it draws an
annulus around a random OPFOR zone, out to `AOI_ZONE_REACH` past the zone's edge, and keeps the
draw only where `fnc_aoi_field_at` is positive and `fnc_aoi_in_any_zone` is false. Every band
placer goes through it (directly, or via the per-emplacement anchor/candidate pair
`fnc_hardpoint_band_anchor` / `fnc_hardpoint_band_cand`, `fnc_hardpoint_place.sqf:306-324`), so all
of them sample the same ground the same way; siting mechanics beyond the candidate source —
terrain survey, per-type score, facing, spacing — are shared with the zone ring and documented in
[`hardpoints.md`](hardpoints.md).

At campaign generation, `fnc_hardpoint_site_aoi` (`fnc_hardpoint_place.sqf:335-341`) spreads
`count serv_zones_array` standalone combat hardpoints uniformly across the band — there is no front
yet to weight toward. After generation, a low-frequency director,
`server/warcom/fnc_WARCOM_opf_hardpoints.sqf`, spawned unconditionally from
`server/warcom/fnc_WARCOM_init.sqf:57`, spends OPFOR Army Power once per `OPCOM_HP_TICK` (600 s) on
one of: raising a radio tower toward the cap, topping a depleted zone back toward its stored
`DUWS_hpCap_<zoneKey>` (`fnc_hardpoint_place.sqf:283-285`), or fortifying the band with one more
standalone emplacement — priced `OPCOM_AP_TOWER`/`OPCOM_AP_TOPUP`/`OPCOM_AP_BAND`
(`server_var_init.sqf:472-475`) in that priority order. Its band placement is still uniform, drawn
through the same `DUWS_fnc_aoi_bandPos` sampler as the start pass — it has no belief about where
the player operates to weight toward. That weighting, and the personality behind which action a
commander prefers, is [`../opcom_plan.md`](../../plans/opcom_plan.md)'s to
add; nothing here reads a belief store or an archetype.

A dev-only coverage overlay exists for inspecting the field in play: `fnc_debug_opcom_view` remote
execs `fnc_debug_aoi_circles` (`server/warcom/fnc_debug_aoi_circles.sqf`) to gather every emitter's
`[center, radius, side]`, which `fnc_debug_aoi_draw` (`client/debug/fnc_debug_aoi_draw.sqf`) draws
as translucent local markers, pink for OPFOR and cyan for BLUFOR. It is reached from the dev debug
menu, not shown to the player.

## Tuning

| Constant | Value | Meaning |
|---|---|---|
| `AOI_TOWER_REACH` | 5000 m | OPFOR radio tower coverage radius |
| `AOI_ZONE_REACH` | 2000 m | added to a zone's own radius |
| `AOI_HQ_REACH` | 2000 m | player HQ coverage radius |
| `AOI_FOB_REACH` | 2000 m | each FOB's coverage radius |
| `AOI_TOWN_REACH` | 2000 m | added to a banded town's `civ_radius` |
| `AOI_OPFOR_TOWER_CAP` | 5 | ceiling on `DUWS_opforRadioLevel`; OPFOR's push bottoms out at `-6` |
| `OPCOM_HP_TICK` | 600 s | how often the hardpoint director acts |
| `OPCOM_AP_TOWER` | 30 | AP cost to raise a radio tower |
| `OPCOM_AP_TOPUP` | 8 | AP cost to top up a depleted zone |
| `OPCOM_AP_BAND` | 12 | AP cost to fortify the band |

All defined at `server/server_var_init.sqf:451-475`, server-only (not `publicVariable`d): every
reader — the drift on the economy tick, the hardpoint band siting, the director tick — runs on the
server.
