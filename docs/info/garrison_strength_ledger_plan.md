# Garrison strength ledger + site parity — design plan

Status: implemented. Records the settled design; the source is the authority. Replaces the "Deferred: attrition by lost tokens" note in
[`zone_reserve_reinforcement_plan.md`](zone_reserve_reinforcement_plan.md#deferred-attrition-by-lost-tokens-not-a-random-thin).

Two changes that land together, because the second only makes sense on the first:

1. **Strength becomes a ledger of lost tokens**, replacing the scalar men-thin — for every garrison.
2. **Towns get the exact same treatment as zones**: the multiplier is reserve depth, the garrison is the
   x1 tier with a refilling pool, and losses are tracked per token. The *only* difference between a zone
   garrison and a town garrison becomes the composition table it draws from (`DUWS_zoneSpawnTiers` vs
   `DUWS_townSpawnTiers`). No divergence in how a tier or the multiplier is calculated.

This is a large refactor: it turns the zone-only reserve/strength code into one **garrison-site model**
keyed by the shared site store, with thin zone and town adapters. The task breakdown phases it so each
step lands green.

## Problem

A garrison's attrition is a single scalar fraction (`DUWS_garrisonStrength_<key>`), shared by zones
(`fnc_zone_strength*`) and towns (`fnc_town_garrison_strengthAt/…`). Below one it thins each team's *men*
at random (`fnc_zone_thin`) and drops vehicles whole below half (`DUWS_fnc_tokenStrength`). So killing
anything wears the whole garrison's manpower down uniformly and remembers nothing about *what* died.

Separately, towns and zones already diverge in how the multiplier applies: a zone treats it as reserve
depth (`fnc_zone_spawn` — x1 garrison plus a pool), a town treats it as `scaleComposition` and puts
every copy on the ground at once (`fnc_civ_garrison.sqf:67`). The intent is one model for both.

## The garrison-site model

A garrison is a **site** (the shared `fnc_site_*` store — key, pos, radius, roster — that zones and
towns already both register in). One model governs every site; the site type supplies only its tier
table and its ownership rules.

```
full      = scaleComposition(filtered <site tier row>, mult)   // mult = reserve depth
lost      = DUWS_garrisonLost_<key>       // flat token list, persists across a stow
surviving = spawnDiff(lost, full)         // full minus lost
garrison  = surviving, capped to the x1 shape    // what stands on the ground
pool      = surviving beyond the x1 shape         // the reserve, refilled in as garrison groups die
strength  = (fullMen − lostMen) / fullMen         // the map bar, a live projection
```

A token is recorded lost when its **group is wiped** (last man dead) — "destroy one tank = lose one
tank." Garrisons deploy `surviving` as whole tokens; nothing is men-thinned. Chip damage does not
persist (a squad not wiped comes back whole); confirmed as intended.

### What is shared vs. per-site-type

| Concern | Shared (garrison-site model) | Zone only | Town only |
|---|---|---|---|
| Tier → composition | `scaleComposition(filtered tier, mult)` | `DUWS_zoneSpawnTiers`, tier rolled once | `DUWS_townSpawnTiers`, tier from reputation / commander |
| Strength ledger | lost / surviving / projection / seed / unlose / recordLoss | — | — |
| Reserve pool + refill waves | pool split, hunt-wave delivery, killed-dip, the pass/loop | — | — |
| Loss recording | `garrisonWatchLosses` on raised groups | — | — |
| Beaten condition | `garrisonBeaten`: remaining ≤ 0.1 × peak, remaining = garrison + owed reserves | — | — |
| Removal outcome | — | WARCOM capture (flip to BLUFOR) | reputation clear (credit, REGROUPING, tier → I) |

Only the *outcome* of being beaten stays divergent: a zone flips to BLUFOR, a town is cleared back toward
neutral and bought up again by the commander. The *condition* — garrison plus owed reserves worn to a
tenth of full potential — is now one shared test for both, so a town, like a zone, is not finished until
its reserve waves are drawn out and beaten. Everything about how much force a tier fields, how it wears
down, and when it counts as beaten is unified; only who ends up owning the ground differs.

## The shared strength API (`fnc_garrison_strength_init.sqf`)

Already the shared attrition store, keyed by string, loaded ahead of both `fnc_zone_state_init` and
`fnc_civ_state_init`. It stops storing a scalar and stores the ledger:

| Variable | Meaning |
|---|---|
| `DUWS_garrisonLost_<key>` | flat list of destroyed tokens (a multiset by value) |
| `DUWS_garrisonFullMen_<key>` | men in `full`, stamped at raise — the projection's denominator |

Functions, replacing `garrisonStrengthSet` / `garrisonStrengthRecord`:

- `DUWS_fnc_garrisonSetFull {key, fullList}` — stamp `fullMen`. Called at raise (and on a town tier buy,
  which re-derives `full`).
- `DUWS_fnc_garrisonLost {key}` → the lost list.
- `DUWS_fnc_garrisonSurviving {key, fullList}` → `spawnDiff(lost, full)`.
- `DUWS_fnc_garrisonRecordLoss {key, token, fullList}` → push `token`, bounded so its count never exceeds
  its count in `full`. The bound makes a double-fire of the killed handler a no-op.
- `DUWS_fnc_garrisonStrength {key}` → `fullMen > 0 ? (fullMen − lostMen)/fullMen : 1`, clamped `[0,1]`.
- `DUWS_fnc_garrisonSeed {key, fullList, frac}` → mark tokens lost until `survivingMen <= frac × fullMen`,
  spending pool copies before garrison copies. Recapture and town-clear call it with `0.3`.
- `DUWS_fnc_garrisonUnlose {key, fullList, targetFrac}` → remove lost entries until survival ≥ target.
  The town reinforce purchase calls it.
- `DUWS_fnc_garrisonWatchLosses {key, grps}` → tag + killed handler that records a wiped group's token.

`tokenMenCount` / `tokenListMen` move from `fnc_zone_state_init.sqf` to the shared vocabulary
(`fnc_spawn_vocab.sqf`, beside `teamRow`). They simplify — no `_strength` argument, tokens are whole:
`menCount = count roles + (leader ? 1 : 0)`.

## Recording losses — one shared watcher

`DUWS_fnc_garrisonWatchLosses {key, grps}`:

- Tag the source token on the group at raise. `DUWS_fnc_zoneSpawnOne` (`fnc_zone_spawn_sizes.sqf:268`)
  already receives the token and returns the group — tag it there, `_grp setVariable ["DUWS_srcToken",
  _token]`. That spawner is shared by the zone band and the town garrison (both via
  `DUWS_fnc_raiseGarrison`), so one line covers both.
- Hang a `Killed` handler per unit that, when the group has no one left alive
  (`{alive _x} count units _grp == 0`), calls `garrisonRecordLoss`. Fired once per group, at the last
  death; covers a wiped garrison group and a delivered reserve that then dies.

A group that streams out with survivors, or a reserve still pooled at stow, is **not** in the ledger — it
is `surviving` and comes back next raise. That is chip-damage-refunded, by construction.

## Generalizing the reserve machinery from zone to site

Today's `fnc_zone_reserve.sqf` is zone-keyed. Under parity it becomes site-keyed — the functions already
take a key and read pos/radius from the site store, so the generalization is mostly renaming and widening
the site list the pass iterates. `DUWS_fnc_zoneReserve*` is renamed to `DUWS_fnc_garrisonReserve*`
throughout (mechanical, ~20 call sites) — the zone name misleads once towns use it.

- **The pool, ceiling, and killed-dip** (`DUWS_zoneReserve_<key>`, `DUWS_zoneCeiling_<key>`,
  `DUWS_fnc_zoneReserveMen`, `zoneGroupCount`, `OnKill`) are already per-key and carry over unchanged
  except in name.
- **The refill pass** (`DUWS_fnc_zoneReservePass`) iterates `WARCOM_zones_controled_by_OPFOR` today. It
  must iterate **all awake OPFOR garrison sites** — zones and towns. Add a shared registry
  `DUWS_garrisonSites` (a list of keys) that a site pushes on raise and drops on stow, and iterate that.
  The pass's per-site work (pool non-empty, players near, sort by crowd, spawn `RefillOne`) is unchanged.
- **The "site is live and held" gate** the pass and killed-dip use is `peak > 0` today. Generalize to a
  site-agnostic predicate: a zone publishes a peak; a town is `awake && tier > 0`. One small helper,
  `DUWS_fnc_garrisonHeld {key}`.
- **Placement and hunt posture** are geometry over site pos/radius — unchanged; they work for a town.

## The break test — shared

The core of `fnc_zone_capture_ready.sqf` (`remaining = garrison_count + reserveMen`; beaten when
`remaining <= 0.1 × peak`) extracts to `DUWS_fnc_garrisonBeaten {key}`, with **peak = the ledger's
`fullMen`** — the full fighting potential, which the ledger already stamps at raise. This retires the
separate `DUWS_zonePeak_<key>` denominator; peak's other role (a published peak meant "garrison is real")
moves to `garrisonHeld`, so the two duties peak carried split cleanly.

- **Zone capture** = `garrisonBeaten && WEST outnumbers OPFOR present` — the second half of the current
  capture test, unchanged.
- **Town clear** fires on `garrisonBeaten` alone, replacing the `WEST SEIZED` `EmptyDetector` trigger.
  The town's clear economy (reputation credit, `REGROUPING`, tier → I, `garrisonSeed 0.3`) is unchanged;
  only its trigger moves from "empty of OPFOR" to "garrison plus owed reserves beaten to a tenth." A town
  is no longer cleared by OPFOR merely withdrawing — it has to be beaten, like a zone.

## Zones (adapter)

Largely the current reserve model, now calling the shared ledger:

- **Raise** (`fnc_zone_spawn`): `full = scaleComposition(x1, mult)`; stamp it; `surviving`; split garrison
  / pool by the x1 shape (two `spawnDiff`); raise the garrison whole; register the site; ceiling
  `count _x1`; peak/baseline unchanged (already full-potential men).
- **Recapture** (`fnc_opfor_cap.sqf:31`): `garrisonSeed {key, full, 0.3}`, pool copies first.
- **Stow** (`fnc_zone_stream_init.sqf`): drop `fnc_zone_strength_record` (losses are live); deregister the
  site; pool-clear order otherwise unchanged.
- **Capture** (`fnc_zone_capture_ready.sqf`): the break core moves to `garrisonBeaten` (peak = `fullMen`);
  the trigger becomes `garrisonBeaten && WEST outnumbers OPFOR present`.

## Towns (adapter) — full parity

The town raise, reinforcement and clear rework to the garrison-site model. The reputation band and the
commander's tier/reinforce purchases stay — those are the town's ownership economy — but the clear's
*trigger* moves to the shared `garrisonBeaten` test; only its payout stays town-specific.

- **Raise** (`fnc_civ_garrison.sqf` `_fnc_raise`): instead of `thinComposition(scaleComposition(tier,
  mult))` deployed whole, derive `full` / `surviving` / garrison / pool exactly as a zone does, deploy the
  x1 garrison, seed the pool, register the site, set the ceiling. The async worker's timing (5-s confirm,
  wait for men) is town-specific and stays; only the composition logic inside it changes.
- **Commander tier buy**: raising the tier re-derives `full` at the new row (same
  `scaleComposition(filtered tier, mult)` formula), re-stamps `full`, raises the ceiling, and reseeds the
  pool from `surviving`. The refill pass then delivers the difference as hunt waves — the town's
  reinforcement stops being a bespoke `spawnDiff`-raise and becomes the shared refill. Lost tokens carry
  across the tier change (a destroyed unit stays destroyed); the new tier's added token types are
  surviving.
- **Commander reinforce buy** (`fnc_town_garrison_reinforce`, `fnc_civ_state_init.sqf:189`): today +0.3 on
  the scalar. Under the ledger it **un-loses**: `garrisonUnlose {key, full, min(1, current + 0.3)}` — a
  paid replacement of destroyed tokens that refills the pool, which the refill pass then delivers. This is
  the one place a garrison's strength rises, and it is a purchase, not a heal — orthogonal to the tier.
- **Clear** now fires on `garrisonBeaten` (the shared 10%-of-peak break, owed reserves included), not
  `WEST SEIZED`. The `EmptyDetector` trigger and its arm/activate/delete dance
  (`fnc_civ_garrison.sqf:105-109`, `:343`) go; the poller tick evaluates `garrisonBeaten` instead. The
  clear's payout (reputation credit, `REGROUPING`, tier → I, `garrisonSeed {key, full, 0.3}`) is unchanged.
- **Stream-out record** (`fnc_civ_garrison.sqf:254`): drops — losses are live. Baseline handling stays
  (it anchors the men figure the log reports).
- **Loss recording**: town groups go through the shared `garrisonWatchLosses` — the per-unit attrition a
  town never had.

## Code the ledger deletes

The random-thin apparatus has no caller once both sites field whole survivors. Removed in the same change
(resolve, do not flag):

| Symbol | Why it dies |
|---|---|
| `fnc_zone_thin` | only `teamRoster`'s `_strength < 1` branch called it |
| `DUWS_fnc_tokenStrength` | only `thinComposition` and `raiseGarrison`'s per-token thin called it |
| `DUWS_fnc_thinComposition` | both sites stop thinning |
| `DUWS_fnc_garrisonStrengthSet`, `…StrengthRecord` | replaced by seed / unlose / recordLoss |
| `fnc_zone_strength_set/_record/_refresh` | zones record live; the map bar reads the live projection |
| `fnc_town_garrison_setStrength` | its writes (clear, reinforce) become seed / unlose |
| `_strength` params on `teamRoster` / `raiseGarrison` / `spawn_team` / `zoneSpawnOne` | nothing thins; whole tokens raise at full |

`DUWS_fnc_scaleComposition` is **kept** — promoted to the shared full-potential builder for both sites.

## The display projection

`fnc_zone_strength` and `fnc_town_garrison_strengthAt` both keep returning a `[0,1]` fraction, now the
live projection. Never-rising is automatic for zones (the ledger only grows); the map readouts
(`fnc_map_readout_query.sqf:69` zone, `:136` town) call the same names and get a current figure, so
`fnc_zone_strength_refresh` retires. The 0.3 redeploy floor and tenth-quantisation go for natural
attrition — scalar-model crutches; the peak is the full potential, decoupled from what survives, so an
empty redeploy is still capturable and a garrison worn to two survivors honestly returns at two. The
explicit `0.3` seeds on clear/recapture stay, as ledger seeds.

## No save migration

Accept a reset on upgrade: an old save's scalar is ignored, and the first raise after the upgrade stamps
`full`, finds no ledger, and starts every garrison at full.

## Files touched

| File | Change |
|---|---|
| `fnc_garrison_strength_init.sqf` | the ledger API + projection + `garrisonWatchLosses`; delete `StrengthSet` / `StrengthRecord` |
| `fnc_spawn_vocab.sqf` | receive `tokenMenCount` / `tokenListMen` (whole-token); drop `fnc_zone_thin` and `teamRoster`'s thin branch |
| `fnc_zone_reserve.sqf` | generalize zone→site (rename to `garrisonReserve*`); pass iterates `DUWS_garrisonSites`; `garrisonHeld` and `garrisonBeaten` helpers; delegate loss-recording to the shared watcher; fieldable filter without the vehicle-strength clause |
| `fnc_zone_capture_ready.sqf` | break core → `garrisonBeaten` (peak = `fullMen`); trigger = `garrisonBeaten && WEST outnumbers` |
| `fnc_zone_spawn_sizes.sqf` | garrison/pool from `full − lost`; raise whole; tag `DUWS_srcToken`; register the site; delete `thinComposition` / `tokenStrength`; strip `_strength` plumbing |
| `fnc_zone_state_init.sqf` | `fnc_zone_strength` → projection; reserve-men whole; delete `_strength_set/_record/_refresh` |
| `fnc_opfor_cap.sqf` | recapture → `garrisonSeed 0.3` |
| `fnc_zone_stream_init.sqf` | stow drops the strength record; deregister the site |
| `fnc_civ_garrison.sqf` | raise = x1 garrison + pool (shared derivation); register the site; tier buy re-derives full/ceiling/pool; groups through `garrisonWatchLosses`; clear fires on `garrisonBeaten` (remove the SEIZED `EmptyDetector` trigger) → `garrisonSeed 0.3`; drop the stream-out record, `thinComposition`, and the bespoke reinforcement `spawnDiff`-raise |
| `fnc_civ_state_init.sqf` | `reinforce` → `garrisonUnlose`; delete `setStrength`; `strengthAt` reads the projection |
| `fnc_spawn_team.sqf`, `fnc_spawn_vehicle.sqf` | drop the `_strength` thin argument |
| new `DUWS_garrisonSites` registry | pushed on raise, dropped on stow, iterated by the refill pass |

## Task breakdown

Phased so each lands green:

1. **Shared ledger API + projection** in `fnc_garrison_strength_init.sqf`; move `tokenMenCount` /
   `tokenListMen` to vocab. No behaviour change until callers read them.
2. **Zone whole-token raise**: garrison/pool from `full − lost`; strip the thin plumbing. Zones behave as
   the reserve model does now, minus the men-thin.
3. **Loss recording**: `DUWS_srcToken` + `garrisonWatchLosses` on zone (then town) groups.
4. **Generalize the reserve machinery** zone→site: the `DUWS_garrisonSites` registry, the `garrisonHeld`
   gate, the rename. Zones still the only registered site — no town behaviour yet.
5. **Town parity**: town raise = x1 garrison + pool; register the site; tier buy re-derives; reinforce →
   unlose; clear fires on `garrisonBeaten` (drop the SEIZED trigger) → seed; the pass tops towns up in
   hunt waves.
6. **Delete the dead thin apparatus**; run the lint / manifest.
7. **Tests.**

## Test plan

- **Unit (sqf-vm):** `surviving = spawnDiff(lost, full)`; the garrison/pool split is the x1 shape and its
  surplus, pool absorbing a type's losses first; `recordLoss` bounded at `mult × tier-count`; the
  projection equals `(fullMen − lostMen)/fullMen`, monotonic for zones; `seed` hits its fraction spending
  pool first; `unlose` raises survival by the step; `tokenMenCount` whole-token; the site model is
  table-agnostic (same assertions pass with a town tier row).
- **Manual / integration:** wipe a zone's one tank across visits and it stops fielding a tank while rifle
  sections stay full; a town wiped group-by-group wears down, refills in hunt waves, and a commander
  reinforce visibly refills the pool; a commander tier buy grows the town's garrison via waves; a cleared
  town seeds to 0.3; two hot towns plus zones stay under the global group ceiling.

## Settled decisions

Non-obvious calls a reader of the source will meet, all confirmed:

- **Whole tokens only.** Chip damage does not persist; only a wiped group is recorded lost.
- **Town parity is total.** Reserve depth, refill waves, ledger, and the 10%-of-peak break (owed reserves
  included) all apply to towns; only the removal *outcome* (capture vs reputation-clear) differs. The town
  is beaten on the same condition as a zone and cleared by the same reputation economy as before.
- **No save migration.** An upgrade resets every garrison to full.
- **Reserve functions rename** `DUWS_fnc_zoneReserve*` → `garrisonReserve*` (they serve both sites).
