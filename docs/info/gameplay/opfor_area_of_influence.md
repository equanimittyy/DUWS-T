# OPFOR area of influence

Zone ownership is list membership (`WARCOM_zones_controled_by_BLUFOR`) and town ownership is a
number (`civ_town_rep`); neither says anything about the ground *between* them. The area of
influence is a signed coverage field over the whole map that fills that gap. Three things read it:
BLUFOR's passive town-reputation drift, the towns OPCOM may send Rapport to, and where OPFOR's
standalone hardpoints get sited.

## The field

`server/warcom/fnc_aoi_init.sqf` defines the field as coverage, not a magnitude: a point is either
within reach of a side's ground or it isn't, with no falloff and no per-emitter strength, because
the drift it drives is a flat step rather than a weighted one (see [Rep drift](#rep-drift)).
`DUWS_fnc_aoi_covers` (`fnc_aoi_init.sqf:17`) is the shared primitive both sides' coverage tests
wrap (`fnc_aoi_opfor_covers` / `fnc_aoi_blufor_covers`, `:66-67`); `fnc_aoi_field_at [_pos]`
(`:72-77`) composes the two into an OPFOR-positive dominance value: `+1` OPFOR-only, `-1`
BLUFOR-only, `0` contested or empty. Siting reads `fnc_aoi_field_at`; the drift reads
`fnc_aoi_blufor_covers` and the Rapport offer reads `fnc_aoi_opfor_covers` directly.

| Emitter | Side | Reach beyond its edge |
|---|---|---|
| OPFOR radio tower | OPFOR | `AOI_TOWER_REACH` = 5000 m, the longest on the map |
| Zone | its controller | `_size + AOI_ZONE_REACH` (2000 m) |
| Player HQ | BLUFOR | `AOI_HQ_REACH` = 2000 m |
| FOB | BLUFOR | `AOI_FOB_REACH` = 2000 m |
| Banded town | its band's side | `civ_radius + AOI_TOWN_REACH` (2000 m) |

Reach is measured from each source's outer edge, not its centre, so a naturally large zone claims
proportionally more ground than a small one — the constants live at `server_var_init.sqf:584-588`.
BLUFOR's radio supports are not in this table: they have no structure on the map, so they carry no
coverage of their own. Each tier widens every BLUFOR reach above, and tiers II and III set BLUFOR's
drift inside that coverage (see [Radio towers](#radio-towers)).

A town emits only once its reputation has fully crossed `±10` — the same `OPFOR_BAND` threshold
that flips a town's side for income (`fnc_civ_townOwner`, `server/civilian/fnc_civ_state_init.sqf`).
A neutral town is inert, so influence spreads only from a town that has fully fallen, never one
merely leaning.

The reaches are large against Altis by intent: OPFOR starts holding every zone (all zones are
OPFOR until captured) and one radio tower, so the field opens OPFOR-positive around every zone and
across the tower's reach, while the player opens with `AOI_HQ_REACH` — 2 km around the HQ — and
whatever FOBs get built. That asymmetry is the starting pressure the rest of the mechanic answers.

### The exclusion

The area of influence is the field's OPFOR-positive region minus the interior of every zone.
`fnc_aoi_in_any_zone [_pos]` (`fnc_aoi_init.sqf:85-88`) tests a point against each zone's own
`_size`, whoever holds it; inside a zone is the zone hardpoint ring's ground (see
[`hardpoints.md`](hardpoints.md)), not the band's. The field still *covers* zone interiors — a
town under a BLUFOR zone still drifts, and one under an OPFOR zone still takes Rapport — but siting
reads `fnc_aoi_field_at > 0 && !(fnc_aoi_in_any_zone)`, so a candidate outside every zone in
OPFOR-positive ground is the band.

## Rep drift

Every 30-minute economy tick, before that tick's income tally, each town inside BLUFOR's coverage
steps its reputation up by one less than the BLUFOR radio tier
(`server/warcom/fnc_zonesundercontrol.sqf:36-46`, riding the economy clock rather than running a loop
of its own):

```sqf
private _bluPush = DUWS_bluforRadioLevel - 1;
// ...
if (_bluPush > 0 && {[getPos (_locs select _forEachIndex)] call fnc_aoi_blufor_covers}) then {
    [_forEachIndex, _bluPush, "aoi_drift", true] call fnc_town_rep_adjust;
};
```

The drift is asymmetric by design. **BLUFOR pushes only once it has paid to**:
`DUWS_bluforRadioLevel` is the tier bought, `0`-`3`, and tier I buys reach only, so a BLUFOR-covered
town drifts `0` through tier I, `+1` at tier II and `+2` at tier III. Coverage with no tier pushes
nothing; a tier with no coverage has nothing to push. **OPFOR has no passive push**: its coverage
does not cancel BLUFOR's, and it moves a town only by buying Rapport, `-OPCOM_RAPPORT_STEP` (2) a
delivery, offered in each town above `-20` that OPFOR's coverage reaches, a BLUFOR town included
(`DUWS_fnc_opcom_rapportOffer`, `warcom/opcom/appraisal/fnc_opcom_buy_holding.sqf`; the Value is
[`opcom_plan.md`](../../plans/opcom/opcom_plan.md)'s). A delivery to a town the player can see names
the town and its reputation change in an Allseer line.

The writer is the existing `fnc_town_rep_adjust` (`server/warcom/fnc_economy_init.sqf:179`),
already clamped to `[-20, 20]`; the drift and Rapport are silent callers (`_silent` param) beside its
event callers, so they repaint the town marker without posting a reputation card. Every consumer
rep already drove — the OPFOR/BLUFOR band, town income, the map marker colour — follows for free.

## Radio towers

OPFOR's radio tower is a hardpoint with coverage of its own. BLUFOR's radio tier is a support with
no structure: it widens the coverage of every other BLUFOR emitter and, from tier II, sets BLUFOR's
drift push.

### OPFOR: a physical hardpoint

A tower's only effect is its `AOI_TOWER_REACH` coverage, which `DUWS_fnc_aoi_covers` reads live
from the `DUWS_hardpoints` registry, so a destroyed tower's coverage goes when its row does.
Campaign generation always places one tower in the band before the other band passes, so they sample
the band it widens (`fnc_hardpoint_site_radio`, `server/init_zones/fnc_hardpoint_place.sqf:363`). It
takes the best of 24 band draws by OPCOM's own tower Value; civilian init runs before hardpoint
generation so that the towns exist to weigh. OPCOM builds the rest in play, up to
`AOI_OPFOR_TOWER_CAP` (4) standing or on their way, the start tower included (`DUWS_opcom_assetCap`,
`warcom/opcom/appraisal/fnc_opcom_assets.sqf`), on the band cell whose town reach scores best, less
the covered towns it overlaps ([`opcom_plan.md`](../../plans/opcom/opcom_plan.md#asset-siting)). The
mast takes the best-scoring crest within half a grid cell of the chosen site. The cap stops
builds only: a save that already holds more towers keeps them. `"RADIO"` is a hardpoint type like
any other (`DUWS_hardpointName`, `DUWS_hardpointGarrison`, `server_var_init.sqf`). It is
deliberately absent from `DUWS_hardpointWeightZone` and `DUWS_hardpointWeightSolo` — a tower is
placed on purpose, never rolled into the ordinary hardpoint mix.

### BLUFOR: a permanent support, no structure

`DUWS_bluforRadioLevel` is the tier bought, `0`-`3`, recomputed from the permanent-support record
on every grant (`server/supports/fnc_support_perm_grant.sqf:19`). It is three `PERM` catalogue
rows — `radio1`/`radio2`/`radio3` — in `client/supports/fnc_supports_init.sqf:38-40`, gated so a
tier is hidden until the one below it is owned (`:114-115`). Nothing is placed and nothing streams:
the purchase itself is the whole effect, so there is no BLUFOR structure for OPFOR to destroy —
only ground to retake.

Each tier also widens BLUFOR's coverage. `DUWS_fnc_aoi_covers` multiplies the reach of every BLUFOR
emitter by `1 + AOI_BLUFOR_RADIO_STEP × DUWS_bluforRadioLevel`, so tiers I to III reach 10%, 20% and
30% farther: the HQ's 2000 m becomes 2200, 2400 and 2600 m. The step adds; it does not compound. Only
the reach beyond the edge scales, so a zone's or a town's own radius stays the same. Every reader of
the coverage follows, the band siting included, so a higher tier also leaves OPFOR less band to build
in. The scale needs no save key: a restore recounts `DUWS_bluforRadioLevel` from the saved
permanent-support record.

## Band siting

`DUWS_fnc_aoi_bandPos` (`fnc_aoi_init.sqf:97-112`) is the shared candidate sampler: it draws an
annulus around a random OPFOR zone, out to `AOI_ZONE_REACH` past the zone's edge, and keeps the
draw only where `fnc_aoi_field_at` is positive and `fnc_aoi_in_any_zone` is false. Every band
placer except the two flank lines and the observation posts goes through it (directly, or via the per-emplacement
anchor/candidate pair `fnc_hardpoint_band_anchor` / `fnc_hardpoint_band_cand`,
`fnc_hardpoint_place.sqf:243-258`), so all of them sample the same ground the same way. The flank
lines and the observation posts sample the band uniformly over the whole map instead, so a site's odds do
not depend on which zone's band it falls in ([`hardpoints.md`](hardpoints.md#siting)); siting mechanics beyond the
candidate source — terrain survey, per-type score, facing, spacing — are shared with the zone ring and
documented in
[`hardpoints.md`](hardpoints.md).

At campaign generation the band is laid after the zone rings: one radio tower first, then the two
flank lines, an AA net, the observation-post net and the roadblock net
([`hardpoints.md`](hardpoints.md#siting) owns the passes and their counts).

After generation, only OPCOM's standalone, asset and minefield builds add to the band
(`appraisal/fnc_opcom_buy_build.sqf`). They do not draw from `DUWS_fnc_aoi_bandPos`. Each pick,
`DUWS_fnc_opcom_siteAll` (`appraisal/fnc_opcom_siting.sqf`) samples `OPCOM_SITE_SAMPLES` band cells from the
band mask the need field keeps (`appraisal/value/fnc_opcom_need.sqf`), and each build type takes the best of
them by its own Value. A
minefield takes the cell holding the most BLUFOR traffic. The truck drives to that cell's centre, and the
hardpoint is sited within half a grid cell of where it is delivered. Each point that a standalone build stands on
is tested against the band again: the delivered spot, a road snap, and each square of a minefield belt. A belt
drops the squares that fall outside the band. The rules are
[`opcom_plan.md`](../../plans/opcom/opcom_plan.md#asset-siting)'s.

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
| `AOI_OPFOR_TOWER_CAP` | 4 | most OPFOR radio towers OPCOM keeps standing or on their way |
| `AOI_BLUFOR_RADIO_STEP` | 0.1 | share of each BLUFOR reach that each BLUFOR radio tier adds |

All defined at `server/server_var_init.sqf:584-621`, server-only (not `publicVariable`d): every
reader — the drift on the economy tick, the hardpoint band siting — runs on the server.
