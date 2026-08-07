# OPFOR area of influence: territory as a field

Zones, towns and hardpoints are points on a map today; ownership is a list membership
(`WARCOM_zones_controled_by_*`) or a per-town number (`civ_town_rep`). Neither says anything about
the *ground between* them. This plan adds that: a signed influence field over the whole map, from
which two behaviours read.

- **Passive rep drift.** A town sitting in ground the enemy dominates loses reputation over time,
  and one in ground the player dominates gains it, with no event firing. The field is the writer.
- **Where OPFOR fortifies.** Standalone hardpoints — the ones the streaming layer already supports
  but nothing places (`server/init_zones/fnc_hardpoint_stream.sqf`, `_zoneKey == ""`) — are sited
  in the band the enemy holds *outside* its zones, which is the area of influence.

This is the first thing the OPFOR commander actually *does*. There is no OPCOM in the tree yet —
`fnc_WARCOM_init.sqf:52-56` runs BLUFOR threads only and states plainly that nothing spawns OPFOR
"until an OPFOR commander decides it." The field, the drift and the fortification pass are that
commander's first decisions, and they are the readers the existing scaffolding was built waiting for
(`DUWS_hpCap_<zoneKey>`, written once and read by nobody — `server/init_zones/fnc_hardpoint_place.sqf:178`).

It also settles two deferrals. [`opfor_commander_loop_plan.md`](opfor_commander_loop_plan.md#why-not-goap)
put an influence map down as an upgrade path and nothing more; [`hardpoint_system_plan.md`](hardpoint_system_plan.md)
sited its normal hardpoints "35-65% along the segment between an OPFOR zone and the nearest BLUFOR
anchor" as a hand-drawn stand-in for a front line. A field produces the front line as a by-product,
so both of those become reads of one thing rather than two approximations of it.

## Why a field and not a grid

[`opfor_commander_loop_plan.md`](opfor_commander_loop_plan.md#why-not-goap) describes the upgrade as
"a coarse grid holding decayed per-side influence." A grid is the wrong first build for what this
plan needs, for three reasons:

- **Every read is at a known point.** Rep drift asks the field at each town centre; siting asks it
  at a candidate position. Neither iterates the whole plane, so neither needs the plane precomputed.
  The field is a function `fnc_aoi_field_at [_pos]`, evaluated where a caller stands.
- **The emitters already persist.** OPFOR and BLUFOR zones, FOBs, the HQ, banded towns and the
  standing OPFOR radio towers are all live campaign state; the BLUFOR support level is one scalar
  read beside them ([§Rep drift](#rep-drift)). The field is derived from them each time it is asked;
  there is no second store to keep in step, and nothing new to serialise
  ([`info/arma_engine_gotchas.md`](info/arma_engine_gotchas.md#non-serializable-handles-must-not-live-in-the-mission-namespace)).
- **A grid buys gradients this plan does not spend.** Its value is smooth interpolation and decay
  over time; siting and a per-town drift tick want neither. The grid stays the documented upgrade
  for when the commander's *scoring* wants a cheap "how contested is this whole region" read, which
  is a different consumer than these two.

The cost is that a whole-map read (a debug overlay, or a future scoring pass that samples many
points) recomputes per sample. That is a real ceiling, and the point at which it bites is the point
the grid earns its keep — recorded in [§Open questions](#open-questions), not pre-solved here.

## The field

The field is not a magnitude — it is **coverage**. Two primitives answer whether a point sits inside
any OPFOR emitter's reach (`fnc_aoi_opfor_covers`) and inside any BLUFOR one (`fnc_aoi_blufor_covers`);
an emitter covers every point within its reach and nothing beyond it, with no falloff and no
per-emitter strength, because the drift it drives is a flat step rather than a weighted one
([§Rep drift](#rep-drift)). `fnc_aoi_field_at [_pos]` composes the two into an OPFOR-positive
dominance — `+1` OPFOR-only, `-1` BLUFOR-only, `0` contested or empty — which is what siting reads;
the drift reads the primitives directly, so it can add the radio-tower amplifiers.

| Emitter | Side | Reach beyond its edge |
|---|---|---|
| OPFOR radio tower | OPFOR | `AOI_TOWER_REACH` = **5 km** — longest on the map |
| Zone | its controller | `_size +` `AOI_ZONE_REACH` = **2 km** |
| Player HQ | BLUFOR | `AOI_HQ_REACH` = **2 km** |
| FOB | BLUFOR | `AOI_FOB_REACH` = **2 km** |
| Banded town | its band's side | `civ_radius +` `AOI_TOWN_REACH` = **2 km** |

Reach is measured from each source's outer edge, not its centre, so a naturally large zone claims
proportionally more ground (`_size + 2 km`) than a small one. The radio tower is the one source with
no footprint — its 5 km runs from the mast.

The **BLUFOR** radio supports are **not** in this table: with no structure on the map they have no
reach, and they amplify BLUFOR's drift globally wherever the emitters above already cover
([§Radio towers](#radio-towers)). The OPFOR tower appears in two roles — a 5 km coverage emitter
here, and the global `-1` amplifier in [§Rep drift](#rep-drift) — because it does both.

**A zone's reach exceeds its own radius, and that gap is the whole mechanic.** The influence extends
`AOI_ZONE_REACH` past `_size`, so the band an emitter owns *outside* its footprint is the annulus
`(_size, _size + AOI_ZONE_REACH)`. Set reach equal to the radius and there is no band and nothing to
site in.

**Only banded towns emit, and that gate is what makes spreading safe.** A town emits nothing until
its reputation crosses `±10` — the same `OPFOR_BAND` threshold that already flips it to a side for
garrison and income (`server/misc/fnc_civ_garrison.sqf:33`, `fnc_civ_state_init.sqf:296-301`). A
neutral town is inert. So influence spreads only after a town has *fully* fallen, never from a town
merely leaning, and the threshold is a brake on the cascade rather than a smooth ramp into it.

**Coverage spreads from both sides, but the push does not.** A banded town extends its side's
coverage to its neighbours either way — that much is symmetric. What the coverage then *does* is not:
an OPFOR-banded town drags its neighbours down for free on the base push alone, while a BLUFOR-banded
town lifts nobody until the player has bought a radio tower for the coverage to carry
([§Rep drift](#rep-drift)). The enemy's tide flows on its own; the player's flows only once paid for.

### The exclusion

The area of influence is the field's OPFOR-positive region **minus the interior of every zone**. A
point inside any zone's `_size` is not in the band, whoever holds the zone: inside a zone is the
zone hardpoint system's ground ([`hardpoint_system_plan.md`](hardpoint_system_plan.md#zone-hardpoints)),
gated by the capture trigger, and the band is the countryside between. The field still *covers* zone
interiors — a town under a zone still drifts — but siting reads `net > 0 && not inside any zone`.

Town interiors are excluded from *combat hardpoint siting* for a softer reason: an MG nest in a
market square is the town garrison's job, not a standalone emplacement's. The field covers them; the
siting mask steps around them. Whether that exclusion should be the town's full `civ_radius` or a
tighter core is a tuning question, not a structural one.

## Rep drift

Every drift tick, each town reads the coverage at its centre and steps its reputation by the
difference of the two sides' pushes — and the pushes are asymmetric, deliberately:

```
_opfor = 0; _blufor = 0;
if (_townPos call fnc_aoi_opfor_covers)  then { _opfor  = 1 + DUWS_opforRadioLevel };
if (_townPos call fnc_aoi_blufor_covers) then { _blufor = DUWS_bluforRadioLevel };  // no base — see below
[_townIndex, _blufor - _opfor] call fnc_town_rep_adjust;
```

**OPFOR pushes by holding ground; BLUFOR pushes only once it has paid to.** OPFOR's push is a base
`1` for the coverage plus its towers; BLUFOR's is its bought tier alone, with no base. So a town in
undisputed OPFOR ground drifts `-1` a tick, `-2` with one enemy tower and as low as `-6` against the
cap of five; a BLUFOR-covered town drifts `0` until the player buys a radio tower, then `+1` to `+3`
by tier; and a contested town nets the difference.

That `0` is the whole of "start with nothing to invest in". **BLUFOR coverage does nothing to a
town's drift on its own** — a FOB or a held zone establishes *where* a bought tier will apply, but
until one is bought it neither pulls rep up nor slows a fall. So the player's first rep lever is
capturing zones, which removes OPFOR's coverage and its base push; the second is buying towers, which
turns all that hard-won BLUFOR coverage into a pull at last.

The two amplifiers are global scalars, not per-town ([§Radio towers](#radio-towers)):
`DUWS_opforRadioLevel` is the number of the enemy's radio-tower hardpoints still standing, capped at
`5`, and `DUWS_bluforRadioLevel` is the tier the player has bought, `0` to `3`. The base step is flat
— the *speed* of the war is the amplifiers and the reaches on a fixed tick, never a weighted distance.

The writer is the existing one — `fnc_town_rep_adjust` (`server/misc/fnc_economy_init.sqf:132-153`),
already clamped to `[-20, 20]`. The field adds a passive caller beside its event callers (civilian
harmed −1, garrison cleared +5, and the rest); it invents no new reputation rule and touches no
consumer. Everything rep already drives — the OPFOR/BLUFOR band, town income
(`fnc_civ_state_init.sqf:296-301`), the reaction weights, the map marker colour
(`fnc_civ_townBand:285-290`) — follows for free.

**The drift rides the 30-minute economy tick — it is not a loop of its own.**
`server/misc/fnc_zonesundercontrol.sqf` already wakes every 1800 s and loops every town to tally
`fnc_civ_townIncome` (`:11-12,26-29`); the drift pass slots into the top of that same iteration, so
it costs no new `while {true}` in a tree that already carries too many, and a town that crosses a band
this tick pays income on its new side the same tick. The interval is therefore fixed at 30 minutes,
not a tuning knob — the balance levers are the amplifier caps and the reaches. At `-1` a tick that is
ten ticks, five hours, to band a neutral town from neglect alone; under the enemy's towers it is far
faster — an hour at the `-6` cap, which is the pace the seeded towers exist to set. Between ticks a
heal (`+1`) or a cleared garrison (`+5`) still lands at once, so player action stays legible against a
drift that only moves twice an hour.

**No separate anti-runaway clamp is needed, because the counter-play is the clamp.** OPFOR starts
holding every zone with towers already up, so the map opens OPFOR-positive and towns fall — that
pressure is the point. The player answers on two axes. *Coverage*: capturing a zone removes OPFOR's
coverage and its base push where it hurts most, while FOBs and banded towns extend the ground
BLUFOR's own push can reach. *Push*: buying tiers turns that BLUFOR coverage from inert into a pull,
and knocking down an enemy tower cuts its global amplifier by a point everywhere at once. Neither
axis works without the other — coverage with no tier pushes nothing, a tier with no coverage has
nothing to push — which is what keeps the player spending on both. The front settles where the
pushes cancel, and a capped-amplifier field cannot run to all-red unless the player never contests
it, the same condition under which any campaign is already lost.

## Radio towers

A radio tower does two things for its side, and the OPFOR and BLUFOR versions differ in which. The
**amplifier** is common to both: each tower a side has raises how hard its drift pushes in every town
that side covers, tracked by the scalars `DUWS_opforRadioLevel` and `DUWS_bluforRadioLevel`
([§Rep drift](#rep-drift)). The **coverage** is OPFOR's alone: its tower is a real structure with a
5 km reach that also *extends* where OPFOR influences, the longest-reaching source on the map
([§The field](#the-field)). BLUFOR's supports have no structure, so they add the amplifier and never
coverage.

The one fact that makes the mechanic is that the enemy's towers are objects on the map and the
player's are not.

### OPFOR towers are hardpoints the player can destroy

OPFOR's amplifier is physical. Each level of `DUWS_opforRadioLevel` is a radio-tower hardpoint
standing somewhere in OPFOR ground, and the level is simply how many are still up — capped at `5`,
so the enemy's drift bottoms out at `-6` a tick in ground it fully holds. A few are seeded at
campaign start and the commander builds toward the cap over the campaign
([§The OPCOM tick](#the-opcom-tick)); every one is a hardpoint the player can find, garrisoned and
clearable like any other, and clearing one drops the enemy's global amplifier by a whole point
everywhere at once — and removes that tower's 5 km of coverage with it, so far towns no zone reaches
fall out of OPFOR ground entirely. A tower is never sited inside another tower's AoI — the seeder
rejects any draw within `AOI_TOWER_REACH` of a standing tower — so their coverage circles never nest
and each new tower reaches into fresh ground rather than thickening cover the field already has. The
seeder also prefers high ground: it samples a pool of band draws and stands the mast on the
best-scoring hilltop — raised above its surroundings with the ground falling away on every bearing (a
symmetric crest, not a hillside) — through the `"RADIO"` case in `fnc_hardpoint_score`, so a tower
crowns a peak that sees far rather than sitting in a hollow.

That is the counterplay a purchased buff could never give. The enemy's rep pressure across the *whole
map* has a physical cause the player can go and remove, so a player losing the reputation war has
somewhere to point the fight — and destroying a tower is felt in towns nowhere near it, which is what
makes an amplifier read as strategic rather than as a bigger number.

It is a hardpoint type: a `"RADIO"` entry in `DUWS_hardpointName`, `DUWS_hardpointGarrison`,
`DUWS_hardpointStreaming` and a `DUWS_hardpointComp_RADIO` composition
(`server/init_zones/hardpoint_compositions.sqf`), the core a destructible tower prop dressed with the
comms-hub the OP composition already carries (`RuggedTerminal_01_communications_hub_F`,
`hardpoint_compositions.sqf:26`). It is **not** in `DUWS_hardpointBaseWeight` (`server_var_init.sqf:392`)
— that table is the init-rollable combat types, and a tower is placed deliberately, never rolled into
a zone. The amplifier reads the registry: `DUWS_opforRadioLevel` is the count of uncleared `"RADIO"`
rows in `DUWS_hardpoints` (`server_var_init.sqf:423`), recomputed when one is built or cleared, so
the tower contributes whether or not a player is near enough for it to stream in.

### BLUFOR towers are permanent supports

The player has no radio-tower hardpoint. BLUFOR's amplifier is bought: three **permanent
purchasable supports** — **Radio Tower**, **Radio Tower II**, **Radio Tower III** — that mimic the
enemy's effect without a structure on the map. Each raises `DUWS_bluforRadioLevel` one tier, and
because BLUFOR has no base push, that level *is* the player's whole drift: `+1`, `+2`, `+3` by tier,
so a fully-invested BLUFOR town drifts up to `+3` a tick and an uninvested one drifts `0`. They are
three `PERM` rows in the support catalogue (`client/supports/fnc_supports_init.sqf`) rather than a
bespoke request handler: a tier places nothing and is owned once bought, so it needs only the unlock
the existing permanent-support machinery already provides — the buy, the team-wide flag, the campaign
save, and the gate that hides a tier until the one below it is owned. They carry no comm-menu item,
because there is nothing to activate; the purchase itself is the whole effect, applied server-side
where `fnc_support_perm_grant` recomputes the level from the permanent record.

**BLUFOR starts at level 0, and level 0 pushes nothing.** The enemy opens the campaign with towers
already up and a base push besides; the player starts with neither, so the reputation war begins
entirely one-sided and every point of BLUFOR pull has to be paid for — that asymmetry is the reason
the support exists. There is no BLUFOR structure to destroy because there is no structure; the enemy
answers a rising BLUFOR amplifier the only way it can, by taking back the ground that amplifier
multiplies.

Nothing is placed and nothing streams, so a BLUFOR support is a single global write behind a
menu entry — the lightest half of the feature, and the reason the tiers are three separate purchases
rather than an upgrade dialog.

## The campaign-start hardpoint pass

At generation, place `x` standalone combat hardpoints in the OPFOR-positive band, where `x` is the
zone count — `count serv_zones_array`, the authoritative post-generation count, not the requested
`zones_number` (the two differ; `fnc_init_OPFOR_WARCOM.sqf:28-30`).

A new siting caller — call it `fnc_hardpoint_site_aoi` — beside the zone one
(`fnc_hardpoint_site_zone`, `server/init_zones/fnc_hardpoint_place.sqf:174`). It differs from the
zone pass in exactly one respect: where the candidate position comes from. The zone pass samples
`BIS_fnc_findSafePos` around a zone centre inside `_size` (`fnc_hardpoint_place.sqf:196`); the AoI
pass samples the band — a candidate is kept only if `fnc_aoi_field_at` is positive there and it is
outside every zone. Everything downstream is shared: the terrain survey and per-type score
(`server/init_zones/fnc_hardpoint_siting.sqf:24,89`), the facing derivation (`:160`), the spacing
and water rejection, and registration as a standalone site (`_zoneKey == ""`,
`fnc_hardpoint_stream.sqf:249`).

**Uniform across the band at init, biased later.** The start batch spreads evenly through the
OPFOR-positive region — the war has not started, so there is no front to weight toward and no intel
to act on. Everything the enemy learns about where the player operates belongs to the commander's
later builds, not to hour zero.

This pass touches none of the zone hardpoint machinery. It writes no `zone_hp_left_<n>`, sits in no
capture gate, and increments no zone counter — standalone hardpoints are cleared for CP and remove a
threat, and that is all, exactly as [`hardpoint_system_plan.md`](hardpoint_system_plan.md#why-hardpoints-cannot-be-small-zones)
requires.

## The OPCOM tick

The start batch is static; the commander is what makes the field move after hour zero. The tick is
where `DUWS_hpCap_<zoneKey>` (`fnc_hardpoint_place.sqf:178`) finally gets a reader and
`WARCOM_opfor_ap` (`server_var_init.sqf:326`) finally gets a spender beyond the garrison tier-gate it
feeds today (`fnc_zone_spawn_sizes.sqf:127`).

Two behaviours on the tick, both AP-priced so they compete with the commander's other sinks:

- **Top up toward the cap.** A zone below `DUWS_hpCap_<zoneKey>` can have a hardpoint added, which is
  the "OPCOM tops the zone back up" the scaffolding comment promised. This is inside-zone work, so it
  reuses `fnc_hardpoint_site_zone`.
- **Fortify the band.** Build a new standalone hardpoint, or raise a radio tower toward the cap of
  five — the latter lifts the enemy's global drift amplifier, replacing what the player has knocked
  down.

**Where a band build lands is the commander's personality and its intel, not a uniform roll.** This
is the point the start batch defers to. An aggressive commander pushes hardpoints toward ground the
player holds; a defensive one thickens its own rear. Both read where they *believe* the player is
from the belief store, never from a live `getPos`
([`opfor_commander_loop_plan.md`](opfor_commander_loop_plan.md#perception-the-commander-plans-against-belief-never-against-truth)),
so a fortification going up where the player was an hour ago is a decision the player can reconstruct.

That coupling sets the phase order: the belief store and the archetype weights are
[`opfor_commander_loop_plan.md`](opfor_commander_loop_plan.md#build-order)'s to build, and
intel-biased siting cannot precede them. Until they exist, the tick can still run the top-up and a
*uniform* band build — the field is enough to place, and the personality is the refinement that lands
with belief. The scoring pass runs unscheduled inside `isNil { ... }` for the reason the loop plan
sets out, with `time` for anything that must survive a savegame
([`info/arma_engine_gotchas.md`](info/arma_engine_gotchas.md#diag_ticktime-counts-from-process-start-and-is-not-restored-by-a-savegame)).

## What is built, and what is deferred

The field, the passive rep drift, the campaign-start band pass, both radio-tower amplifiers and the
OPCOM tick are built — `server/misc/fnc_aoi_init.sqf` and the files in [§Files](#files-touched). The
build followed the order the readers force: the field first, then the drift and the siting that read
it, then the amplifiers the drift reads, then the OPCOM tick that spends against all of them.

Two pieces are deferred, each on something that does not exist yet:

- **Intel-biased placement.** OPCOM sites uniformly across the band; personality- and belief-weighted
  placement waits on [`opfor_commander_loop_plan.md`](opfor_commander_loop_plan.md#build-order)'s
  belief store and archetype weights, which it cannot precede.
- **A debug coverage overlay.** The field is read at points, never drawn. Whether the player should
  see an influence overlay at all is an open question below, not a missing tool.

## Open questions

- **The reaches are set but unvalidated in play.** `AOI_TOWER_REACH` = 5 km, `AOI_ZONE_REACH` = 2 km,
  and the town, FOB and HQ reaches at 2 km are large against Altis by intent — OPFOR AoI blankets most
  of the map at start and the player opens with 2 km around HQ. That is deliberate back-foot pressure,
  but it leaves little truly neutral ground, so whether the front reads as a line or as a slow
  reconquest of near-total coverage is the first thing to watch.
- **Whether the ceilings are the right ones.** They are asymmetric by design — BLUFOR tops out at
  `+3` a tick and only with investment, OPFOR at `-6` and for free — so at full tilt the enemy
  out-pushes the player by two even before coverage is counted. That is deliberate pressure, but
  whether a maxed player should be able to *hold* a town the enemy has five towers on, or only slow
  its fall, is a balance call that needs the reaches settled first — the tick interval is already
  fixed at the 30-minute economy tick.
- **How many OPFOR towers to seed, and how fast the commander builds toward five.** Too many at start
  and the reputation war is lost before the player can contest it; too slow a build and the cap never
  bites. This is the enemy's whole rep-pressure curve and it is pure tuning.
- **Whether a cascade needs a per-tick rate cap.** Symmetric spreading with a banded-town gate should
  settle at a front, but a region tipping several towns across `±10` in quick succession could
  accelerate before the counter-side reacts. Whether the flat `±1` step and the banding threshold are
  brake enough, or a global cap on how many towns may change band per tick is needed, is answerable
  only by watching a campaign run unattended.
- **Whether the field should be visible to the player at all.** The enemy's territory is currently
  read off town colours and zone markers. An explicit influence overlay would make the front legible
  and the drift's cause obvious, which is either the mechanic finally being appreciated or the map
  answering a question the intel system exists to ask — the same tension
  [`opfor_commander_loop_plan.md`](opfor_commander_loop_plan.md#open-questions) raises about stale
  belief.
- **Whether the amplifiers persist across a save.** Both serialise trivially — the enemy's towers are
  registry rows and the player's level is one number — so the question is not *can* they but
  *should* they: a campaign resumed with the enemy's towers standing and the player's bought tiers
  intact is a different difficulty from one resumed with either reset, the same question the loop plan
  leaves open for the belief store.

## Files touched

| File | Change |
|---|---|
| `server/misc/fnc_aoi_init.sqf` | New. Defines `fnc_aoi_field_at`, the two coverage primitives, `fnc_aoi_in_any_zone` and the shared band sampler `DUWS_fnc_aoi_bandPos`; compiled and registered ahead of the hardpoint placer that reads it. |
| `server/server_var_init.sqf` | The `AOI_*` reach constants (`AOI_TOWER_REACH` 5 km, `AOI_ZONE_REACH` 2 km, town/FOB/HQ 2 km) and `AOI_OPFOR_TOWER_CAP` = 5; `DUWS_bluforRadioLevel` and `DUWS_opforRadioLevel` (both init `0`); the OPCOM tick period and AP costs; a `"RADIO"` row in `DUWS_hardpointName`, `DUWS_hardpointGarrison`, `DUWS_hardpointStreaming`. |
| `server/misc/fnc_zonesundercontrol.sqf` | The drift pass added to the top of the 30-min economy tick's town loop, before the income tally; reads the two coverage tests and two amplifier scalars, writes through `fnc_town_rep_adjust`, then pays income on the post-drift band. |
| `server/misc/fnc_economy_init.sqf` | `fnc_town_rep_adjust` gains a `_silent` flag so the drift writes rep and repaints the town marker without posting a per-town notification card. |
| `server/init_zones/hardpoint_compositions.sqf` | New `DUWS_hardpointComp_RADIO`, comms mast plus hub and an MG nest. |
| `server/init_zones/fnc_hardpoint_place.sqf` | Extract the shared placement loop `fnc_hardpoint_lay` from the zone pass (candidate source is the one thing that varies); new `fnc_hardpoint_site_aoi` and `fnc_hardpoint_seed_radio`, both sampling the band through `DUWS_fnc_aoi_bandPos`. |
| `server/init_zones/fnc_hardpoint_stream.sqf` | Recompute `DUWS_opforRadioLevel` (uncleared `"RADIO"` rows, capped at `AOI_OPFOR_TOWER_CAP`) when one is registered or cleared. |
| `client/supports/fnc_supports_init.sqf` | Three `PERM` catalogue rows — `radio1`/`radio2`/`radio3` — CP-priced, no comm item, gated so a tier is hidden until the one below it is owned. Reuses the existing permanent purchase/gate/save machinery, not a bespoke request handler. |
| `server/supports/fnc_support_perm_grant.sqf` | Recompute `DUWS_bluforRadioLevel` from the permanent record on each grant, so the level survives a save and cannot drift from the flags. |
| `client/includes/supports_init.hpp` | The three `support_radioN_available` flags, defaulted behind `isNil` like every team-state permanent. |
| `shared/includes/notifications.hpp` | The three `unlock_radioN` cards. |
| `server/warcom/fnc_init_OPFOR_WARCOM.sqf` | Call the tower seed then the AoI start pass after zone build-out, beside the zone hardpoint loop, before civilians. |
| `server/warcom/fnc_WARCOM_opf_hardpoints.sqf` | New. The OPCOM tick's tower raise, zone top-up and band build, one AP-priced build a pass; spawned once by `fnc_WARCOM_init`. |
| `server/warcom/fnc_WARCOM_init.sqf` | Spawn the OPCOM director beside the BLU threads; the stale "until an OPFOR commander decides it" note updated. |
| `server/server_fnc_init.sqf` | Registry lines for `fnc_aoi_init` and `fnc_WARCOM_opf_hardpoints`. |
| `stringtable.xml` | The three BLUFOR support labels and their unlock cards. (The `"RADIO"` type name is an inline English label in `DUWS_hardpointName`, not a stringtable key, like the other hardpoint names.) |
| `info/zones_and_civilians.md` | Document the field, the drift and the band exclusion as decided behaviour once built. |
| `info/economy.md` | Note passive rep drift as a new input to town income, and the radio-tower supports as a CP sink. |
