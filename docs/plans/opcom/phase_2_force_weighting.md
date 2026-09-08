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

Our own units never need classifying — a unit carries its composition token and the token names its
category (`tokenPower` maps token → category with no config read). The enemy layer is the problem: it
prices a **sighted** class at runtime, and a human can field a class outside any detected roster (a mod
unit, a captured or civilian vehicle, a DLC type), so the grid must resolve an *arbitrary* class name to a
category **in isolation**, with no faction to parse.

`fn_factionAutoDetect` cannot serve that. It classifies only in **bulk** — `fnc_parseFaction` takes a
faction and sorts its whole class list into ~28 named buckets — and that machinery cannot be turned into a
one-class resolver, for three structural reasons:

- **Bucketing is faction-contextual.** `fnc_factionGetFilteredByEditorSubcat` filters by
  `editorSubcategory` first and only falls to `isKindOf` / config heuristics when the *whole faction* has
  no class in that subcategory. Which bucket a class lands in depends on the classes beside it; a lone
  class has no such context.
- **Buckets overlap and break ties by list.** The static splits each scan the whole turret list and pick a
  strict-kind list *or* a loose weapon / threat list (`selectNonEmpty`); a class can sit in several. One
  category per class cannot represent that.
- **The accurate path needs the faction.** `editorSubcategory` is the preferred signal and `isKindOf` the
  explicitly "less accurate" fallback. A one-class resolver has only the fallback tier, so routing the
  detector through it would downgrade detection for every faction — a regression on the mod-compat heart.

So the classifier is a **new, standalone** function, `fnc_classifyVehicle [_class] → category`, in
`fn_factionAutoDetect.sqf` beside the leaf predicates it reuses (`fnc_isThreatTo`, `fnc_vehicleWeaponType`,
and the raw `armor` / `artilleryScanner` / `transportSoldier` reads). Sharing those per-class leaves keeps
it in step with the detector, but it does **not** call `fnc_parseFaction`, and `fnc_parseFaction` is left
untouched. Its categories are the coarse force buckets — one per power value — not the detector's finer
ones; the IFV/MBT split and the static sub-splits live here, once. Contained to `MODERN` (the only detect
family; `CIV_FACTIONS` is civilians).

Cost is bounded without a bucket cache: an enemy sighting is classified once and its category held in
belief, so `classifyVehicle` runs once per sighting, never per grid rebuild. Only once it stands do the
power table and the grid rewiring below make sense; they consume it.

## Files

Flat under `src/duws/server/opcom/`. The force model is *executed* at load (`[] call compile` in
`server_fnc_init.sqf`) to define its several functions, unlike the Phase 1 files that each compile to one
name; the garrison changes extend the existing garrison-strength module.

| File | Change |
|---|---|
| `fnc_opcom_force` *(new)* | The one home of the power model: the `OPCOM_FORCE` category → power table and the resolvers reading it. `DUWS_fnc_tokenPower` (our token → category → power, category from the token name); `DUWS_fnc_classPower` (a class → category → power via the standalone `fnc_classifyVehicle`, for enemy sightings including classes outside the detected roster); `DUWS_fnc_tokenListForce` (Σ `tokenPower` over a token list); `DUWS_fnc_hpForce` (a hardpoint type → its composed static + garrison force) |
| `fnc_garrison_strength_init` *(modify)* | Add `DUWS_fnc_garrisonForce` = `garrisonMen` (its infantry men, unchanged, live roster or stowed ledger) + Σ `tokenPower` over the surviving *vehicle/static* tokens. `garrisonMen` stays as the men component; the grid and readout now deposit `garrisonForce` |
| `fnc_opcom_grid_rebuild` *(modify)* | Deposit `garrisonForce` for zones/towns, a hardpoint's composed `hpForce` instead of the flat nominal, and the renamed force nominal for a BLU-held zone. No structural change to the deposit lambda |
| `fnc_opcom_sense` *(modify)* | Stamp a sighted group's **firepower** into `belief_str`: Σ `classPower(typeOf)` over its sighted members and their vehicles, plus the additive player bonus (below). No condition scaling — belief is fogged, age decay is the fog |
| `fnc_debug_force_emission` *(modify)* | Report **force**, not "men"; keep the (live)/(ledger)/(nominal) tag |

## The power model

Per-category power (the plan's starter table
([§The quantity](opcom_plan.md#the-quantity-force-not-coverage)) with statics added). Values are tune
starters, held in the `OPCOM_FORCE` hashmap in `fnc_opcom_force` — the coarse force buckets, one power
each, that both resolvers land on:

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

Classification runs once per sighting, not per grid rebuild (the
[prerequisite](#prerequisite-a-single-class-classifier-build-this-first) above). Each force category hangs
one power value, so:

- **our units** carry their token; `tokenPower` maps token → category → power, no config read;
- **a sighted enemy** class resolves through `fnc_classifyVehicle`, then category → power, the result held
  in belief.

The IFV/MBT and static sub-splits live in `fnc_classifyVehicle`, off per-class config: any `artilleryScanner`
piece is `static_arty` (1) whatever its hull — a towed mortar or a self-propelled gun, since indirect fire
holds no ground — checked ahead of the hull-kind tests; a tracked hull that carries dismounts and mounts an
autocannon is an IFV (9), one with no dismounts an MBT (12), one with only an MG a tracked APC (4); a static
splits MG (2) from AT / AA / GMG (4, by `threat[]` / `GMG_F`). The detector is untouched.

**OPFOR holdings** are priced whole-token, not per-object: `garrisonForce` is the site's infantry men
(`garrisonMen`, live roster or stowed ledger) plus the power of its **surviving vehicle and static
tokens**. Attrition rides the existing whole-token loss ledger — a destroyed vehicle leaves the surviving
set, so a mauled holding weighs less — and there is deliberately **no** per-object `× (1 − damage)`: a
damaged-but-alive vehicle counts full until it is killed. This keeps the metric consistent with the
codebase's whole-token model (a placed token is placed full) and needs no live-object walk; crew are not
counted, the vehicle carries them ([§Unit strength](opcom_plan.md#unit-strength)).

**Belief** is likewise not condition-scaled: an enemy sighting deposits full `classPower`, and age decay
is the only fog — the commander does not track a sighted vehicle's damage.

The single table is the point: our holdings resolve through `tokenPower`, enemy sightings through
`classPower`, but both land on the one `OPCOM_FORCE` table — so the grid rebuild, the sense sweep and the
debug readout cannot drift into different metrics.

## Sources

- **OPFOR zone / town garrison** — `DUWS_fnc_garrisonForce` (infantry men + surviving vehicle/static token
  power), replacing `garrisonMen` at both `fnc_opcom_grid_rebuild` call sites.
- **OPFOR hardpoint** — `DUWS_fnc_hpForce`, summed off the type's composition layout
  (`DUWS_hardpointComp_<type>`): every emplaced weapon in it, each `classPower`-priced and added (a prop —
  sandbag, gate, mast — classifies to nothing and adds 0), plus its loose garrison
  (`DUWS_hardpointGarrison[type]` token(s) through `tokenListForce`). Counting the layout means a two-gun
  roadblock counts both guns and a fortified radio base its whole nest, not one nominal; reading the layout
  data (not live objects) means it holds deployed or stowed. Replaces the flat `OPCOM_GRID_HP_MEN`.
- **BLU-held zone** — a fixed nominal, `OPCOM_GRID_ZONE_ENEMY_FORCE` (starter 8, renamed from
  `_ENEMY_MEN`). The player's garrison is not modelled, so the commander only knows the ground is held,
  not how strongly. A later OPCOM step is intended to read the actual BLUFOR garrison strength here
  instead of a nominal; see [§Forward note](#forward-note).
- **Belief (sighted BLUFOR)** — `fnc_opcom_sense` sums firepower over the sighted group: each dismounted
  man 1, each crewed vehicle its `classPower` (counted once), then **adds** the player bonus per human
  aboard — `OPCOM_PLAYER_WORTH` is an *additive* premium (starter 3), not the old men multiplier. So a
  player on foot deposits `1 + 3`, a player in an APC `4 + 3` (the APC's power plus the bump). Age decay in
  the grid ([§Decay](opcom_plan.md#decay)) is the only fog thereafter.

## Constants

The category → power table is the `OPCOM_FORCE` hashmap in `fnc_opcom_force`, beside the token → category
map the resolvers use (`DUWS_forceTokenCat`). In `server_var_init.sqf`, the two scalar grid/sense knobs:

- `OPCOM_GRID_ZONE_ENEMY_FORCE` — was `OPCOM_GRID_ZONE_ENEMY_MEN` (8).
- `OPCOM_PLAYER_WORTH` (3) — same constant, now read as an additive power premium per human, not a
  headcount multiplier. Its comment changes to match.
- `OPCOM_GRID_HP_MEN` is dropped with no replacement — a hardpoint's force composes through `DUWS_fnc_hpForce`.

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
