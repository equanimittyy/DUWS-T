# OPCOM Phase 2 — force weighting

The second build phase of [`opcom_plan.md`](opcom_plan.md), in that plan's
[§Build order](opcom_plan.md#build-order). Phase 1 deposits a **men-count** into the influence grid — the
interim metric both layers shared. Phase 2 replaces it with **firepower**, so each cell carries combat
power, not bodies: the metric the force ratio and the muster check need
([§The quantity](opcom_plan.md#the-quantity-force-not-coverage)). This is the swap point the grid rebuild
and the belief store were built around; no new grid geometry, no new tick.

One power table serves **both** layers — OPFOR holdings (known) and believed BLUFOR (read off a sighting)
— keyed on the **category the faction detector already assigns** to each class at build time, not
re-derived per rebuild. A modded faction is bucketed by the same detector, so the metric keeps no mod
dependency.

## Prerequisite: a single-class classifier (build this first)

Friendly classification is free — our units carry their token, and the token names its category. The
enemy layer is the problem: it classifies a **sighted** class at runtime, and a human can field a class
outside the detected BLUFOR roster (a mod unit, a captured or civilian vehicle, a DLC type), so the grid
must resolve an *arbitrary* class name to a category on the fly.

`fn_factionAutoDetect` today classifies only in **bulk**: it filters a faction's whole class list into
named bucket-lists (`_turretHMG` / `_turretGMG` / `_turretMortar` / `_turretAA` / `_turretAT`,
`_apcWheeled` / `_apcTracked`, `_tank`, `_arty`, `_antiAir`, `_carArmed` / `_carTransport`, `_heliArmed`
…) through list-filters (`fnc_factionGetFilteredByEditorSubcat`, `fnc_filterBySeats` / `ByWeapons` /
`ByPylons` / `ByUtility`, plus `armor` / `radarType` / `artilleryScanner` reads). The per-class rules are
buried inside those `select {}` passes; there is no `class → category` resolver to call for one class.

So the first P2 task is a **behaviour-preserving extraction**: lift those per-class predicates into a
reusable `DUWS_fnc_classifyVehicle [_class] → category`. The detector then maps it over the roster (same
buckets, no change to what it detects); runtime `classPower` calls it per sighting; and the IFV/MBT split
and the static sub-splits live in it once, not in two places. Contained to the one `MODERN` faction family
(the only detect family; `CIV_FACTIONS` is civilians).

Two cautions: `fn_factionAutoDetect` is the mod-compatibility heart, and detection is already known
unreliable — the extraction must not change the buckets it produces, only where the rules live. If
profiling later shows live classification is hot, the detector's existing bucket-lists seed an inverse
`class → category` cache for the detected faction cheaply; treat that as an optimisation, not a
first-cut requirement — a sighting is classified once and then held in belief.

Only once the classifier stands does the power table and the grid rewiring below make sense; they consume
it.

## Files

Flat under `src/duws/server/opcom/`, registered by compile-path in `server_fnc_init.sqf` like the Phase 1
functions; the garrison changes extend the existing garrison-strength module.

| File | Change |
|---|---|
| `fnc_opcom_force` *(new)* | The one home of the power model and the single category → power table. Two resolvers feed it: `DUWS_fnc_tokenPower` (our token → category → power, category known from the token name) and `DUWS_fnc_classPower` (a class → category → power via the extracted `DUWS_fnc_classifyVehicle` — for enemy sightings, including classes outside the detected roster). `DUWS_fnc_effForce` sums `power × condition` over a list of live objects |
| `fnc_garrison_strength_init` *(modify)* | Replace `DUWS_fnc_garrisonMen` with `DUWS_fnc_garrisonForce` — live roster → `effForce`, else stowed → Σ `tokenPower` over the ledger's surviving tokens — and add `DUWS_fnc_tokenListForce` beside `tokenListMen`. The ledger already *is* tokens, so the stowed path needs no class lookup |
| `fnc_opcom_grid_rebuild` *(modify)* | Deposit `garrisonForce` for zones/towns, a hardpoint's composed force (its stowed static + patrol(s), below) instead of the flat nominal, and the renamed force nominal for a BLU-held zone. No structural change to the deposit lambda |
| `fnc_opcom_sense` *(modify)* | Stamp a sighted group's **firepower** into `belief_str`: Σ `classPower(typeOf)` over its sighted members and their vehicles, plus the additive player bonus (below). No condition scaling — belief is fogged, age decay is the fog |
| `fnc_debug_force_emission` *(modify)* | Report **force**, not "men"; keep the (live)/(ledger)/(nominal) tag |

## The power model

Per-category power (the plan's starter table
([§The quantity](opcom_plan.md#the-quantity-force-not-coverage)) with statics added), the categories being
the faction detector's own buckets. Values are tune starters, held as plain server globals (`OPCOM_`
prefix, out of a preprocessor macro's reach like the other OPCOM constants):

| Category | Power |
|---|---|
| Man | 1 |
| Static — MG | 2 |
| Static — AT / AA / GMG | 4 |
| Static — mortar / artillery | 1 |
| Car — unarmed / logistics | 2 |
| Car — armed | 3 |
| APC | 4 |
| IFV | 9 |
| Tank (MBT) | 12 |
| Helicopter / Plane | 15 |

Mortar / artillery weighs almost nothing: indirect fire holds no ground and must itself be protected, so
it barely moves the force grid even though it is a real threat elsewhere (it earns its keep through the
`arty` action, not by garrisoning).

Classification is a build-time job, not a grid-time one (the
[prerequisite](#prerequisite-a-single-class-classifier-build-this-first) above). P2 hangs a power off each
detector bucket, so:

- **our units** carry their token; `tokenPower` maps token → category → power, no `isKindOf`;
- **a sighted enemy** class resolves through `DUWS_fnc_classifyVehicle` (the [prerequisite](#prerequisite-a-single-class-classifier-build-this-first)) —
  the same rules the detector buckets BLUFOR with, now callable per class, so a class outside the detected
  roster still classifies.

The IFV/MBT split needs a **detector** change: today `tank` is `isKindOf "Tank"` and swallows tracked
IFVs, so telling IFV (9) from MBT (12) is a rule added at detect time (e.g. a tracked class with
`transportSoldier > 0` is an IFV), never a grid-time test. Static MG vs AT / AA / GMG splits the same way,
off `turrets` vs `turretCannon` / `antiAir`.

**OPFOR** force is condition-scaled, so `effForce = Σ power × condition` and the grid deposits `effForce`
— a shot-up holding weighs less with no extra logic ([§Unit strength](opcom_plan.md#unit-strength)):

- **Live** (a raised OPFOR site): iterate the roster, valuing each element by its token (`tokenPower`). A
  team contributes its alive men (each 1); a vehicle contributes `tokenPower × (1 − damage)`, a static the
  same. A man **inside** a vehicle is not counted — the vehicle already carries him (crew is never counted,
  mirroring `garrisonMen` today and the plan's crew rule).
- **Stowed** (a site streamed out): no live objects, so `garrisonForce` falls to `tokenListForce` over the
  ledger's **surviving** tokens at full condition — the ledger has already dropped the lost ones, exactly
  as the men-count path works now.

**Belief** does not condition-scale: an enemy sighting deposits full `classPower`, and age decay is the
only fog — the commander does not track a sighted vehicle's damage.

The single table is the point: our holdings resolve through `tokenPower`, enemy sightings through
`classPower`, but both land on the one category → power table — so the grid rebuild, the sense sweep and
the debug readout cannot drift into different metrics.

## Sources

- **OPFOR zone / town garrison** — `DUWS_fnc_garrisonForce` (live `effForce`, else stowed token power),
  replacing `garrisonMen` at both `fnc_opcom_grid_rebuild` call sites.
- **OPFOR hardpoint** — no power of its own; its force **composes** from its constituent assets (our
  tokens, so `tokenPower`): the emplaced static weapon plus any patrol group(s) that belong to it. So a mortar
  pit reads ~1 (indirect fire barely holds ground), while an AT emplacement with a covering patrol reads
  the AT static plus the patrol's men and vehicles. Replaces the flat `OPCOM_GRID_HP_MEN`. *Implementation
  to confirm:* source the static class and patrol roster from the hardpoint record/ledger, and check that
  composition is tracked for a **stowed** hardpoint (it survives stow) — else the stowed value falls back
  to the static alone.
- **BLU-held zone** — a fixed nominal, `OPCOM_GRID_ZONE_ENEMY_FORCE` (starter 8, renamed from
  `_ENEMY_MEN`). The player's garrison is not modelled, so the commander only knows the ground is held,
  not how strongly. A later OPCOM step is intended to read the actual BLUFOR garrison strength here
  instead of a nominal; see [§Forward note](#forward-note).
- **Belief (sighted BLUFOR)** — `fnc_opcom_sense` sums `classPower(typeOf)` over the sighted group and its
  vehicles (full power, no condition), then **adds** the player bonus per human aboard: `OPCOM_PLAYER_WORTH`
  becomes an *additive* premium (starter 3), not the old men multiplier. So a player on foot deposits
  `1 + 3`, a player in an APC deposits `6 + 3` — the hardware plus a fixed "a human is more dangerous"
  bump. Age decay in the grid ([§Decay](opcom_plan.md#decay)) is the only fog thereafter.

## Constants

In `server_var_init.sqf`, replacing the two Phase 1 placeholders:

- The power table above (a category → power map).
- `OPCOM_GRID_ZONE_ENEMY_FORCE` — was `OPCOM_GRID_ZONE_ENEMY_MEN` (8).
- `OPCOM_PLAYER_WORTH` (3) — same constant, now read as an additive power premium per human, not a
  headcount multiplier. Its comment changes to match.
- `OPCOM_GRID_HP_MEN` is dropped with no replacement — a hardpoint's force composes from its static and
  patrol(s) through `tokenPower`, not from a constant.

## Forward note

The BLU-held-zone nominal is a deliberate placeholder. The intent is a later OPCOM step that knows the
actual BLUFOR garrison strength for a held zone rather than assuming a fixed value. That trades against
the belief/truth firewall the plan otherwise holds for enemy force
([§Perception](opcom_plan.md#perception-the-commander-plans-against-belief-never-against-truth)) — knowing
*which* zones are held is a free territorial fact, but knowing their *strength* unsighted is not — so
whether it arrives as omniscience or as a scouting/recon result is left open for that step to decide.

## Verification

The debug force-emission readout (Phase 1) now reports firepower: a tank-heavy garrison outweighs an
equal-headcount infantry one, and a hardpoint reads its static plus its patrols, not a flat 3. On the grid overlay,
the friendly and enemy layers are finally in the same unit, so the force balance and the front line mean
what they say — a sighted player in armour blooms a heavier `ene` cell than the same player on foot.
Checkable against a live player with no scoring in play, the same way Phase 1 was.
