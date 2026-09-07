# OPCOM belief: fidelity fixes

Two independent corrections to the belief store, both extensions to Phase 1
([`phase_1_belief_and_grid.md`](phase_1_belief_and_grid.md)) and both landing behind the same debug
verification harness. Each closes a way the shipped store diverges from what belief is meant to be — a
**decaying last-seen estimate** of BLUFOR, planned against instead of live truth
([`opcom_plan.md#perception-the-commander-plans-against-belief-never-against-truth`](opcom_plan.md#perception-the-commander-plans-against-belief-never-against-truth)):

1. **The absence write** — a wiped BLUFOR group's row is never removed, so a dead force lingers as a
   phantom until decay ages it out.
2. **Position freshness** — a stamp's position is re-sampled from the target's *live* position on the
   strength of a lagging knowledge scalar, so belief follows a target nothing is observing, and a
   teleport jumps the stamp.

## Shared decisions

These hold for both fixes:

- **Force stays group-granular on both sides.** Per-man attrition was considered and rejected: it fights
  the whole-token garrison ledger ([`garrison_and_reserves.md`](../../info/gameplay/garrison_and_reserves.md))
  and buys fidelity the grid does not need. OPFOR force already steps on a whole-group wipe (the loss
  ledger, `fnc_garrison_reserve.sqf:205`); belief steps on a whole-group event too. Neither fix changes
  the force *quantity* — the deposited weight stays the men count of §Grid sources
  ([`phase_1_belief_and_grid.md#grid-sources-this-phase`](phase_1_belief_and_grid.md#grid-sources-this-phase)).
- **The one legitimate asymmetry is kept.** OPFOR knows its own holdings for free; BLUFOR force is
  fog-gated behind sighting and decay
  ([`opcom_plan.md#what-the-enemy-knows-for-free`](opcom_plan.md#what-the-enemy-knows-for-free)). What
  these unify is the *event model* — a whole-group death, and a genuine observation, are the only things
  that move believed BLUFOR force.
- **Both edit the sighting branch of `fnc_opcom_sense`** and compose there: fix 1 adds a kill watcher when
  a group is first stamped, fix 2 tightens when the stamp is written. No new tuning constant for either.

---

## Fix 1: the absence write (confirmed-kill feedback)

### Problem

Belief is fed only by sightings ([`opcom_plan.md#sensors`](opcom_plan.md#sensors)), keyed by group
`netId` (`fnc_opcom_sense.sqf:14`). When a sighted group is wiped, its row is not removed — it ages out
through decay over `OPCOM_BELIEF_EXPIRE` (16 min, `fnc_opcom_decay.sqf:8`), depositing a shrinking phantom
into the enemy grid layer (`fnc_opcom_grid_rebuild.sqf:66-70`) the whole time. The commander plans against
force that no longer exists.

Decay is being asked to model two states with one mechanism, and conflates them:

| Epistemic state | Meaning | Correct treatment |
|---|---|---|
| Confirmed dead | OPFOR destroyed the group | drop the belief row now — certainty |
| Lost track | the group is alive but unseen | decay the stamp — falling confidence |

Decay owns *lost track* correctly. It should never have owned *confirmed dead*. This splits them: a kill
drops the row immediately; decay is left to model only unseen-and-uncertain.

### Mechanism

Mirror the OPFOR side's own group-wipe recorder, `DUWS_fnc_garrisonReserveWatch`
(`fnc_garrison_reserve.sqf:192-211`) — the same `Killed` handler, the same last-man-down test, pointed at
BLUFOR and writing absence instead of a loss ledger.

- **Watch, in `fnc_opcom_sense`.** In the sighting branch, for the group just stamped, tag each of its
  units once (a unit flag guards re-tagging, so a group re-sighted across ticks and a reinforcement that
  joins later are each tagged exactly once) with a `Killed` handler. The handler fires the forget only on
  the whole-group wipe — `({alive _x} count units (group _unit)) == 0`.
- **Forget the group read live at death, not a tag-time netId.** The handler forgets `netId (group _unit)`
  — the group the last-dying unit belongs to *now* — never a netId captured when the unit was tagged. This
  is the one place belief deliberately differs from the OPFOR watcher it mirrors: that one captures the
  composition *token* because a dead man outlives its composition identity (`fnc_garrison_reserve.sqf:190`);
  belief needs only the group's netId, which is still resolvable in the handler (the dead unit is still a
  member of its group when `Killed` runs). A tag-time capture would break under a group merge — a unit
  tagged in group B then merged into A, dying last in A, would forget row B and leave row A as a phantom
  ([§Group mutation](#group-mutation-merge-and-split)).
- **Forget, `DUWS_fnc_opcom_beliefForget` (new file `fnc_opcom_belief_forget.sqf`).** Given a `netId`,
  `findIf` it in `DUWS_opcom_belief_key` and `deleteAt` that index from all four parallel arrays
  (`fnc_opcom_belief_init.sqf:6-9`). Absent key is a no-op — the row may already have decayed out, or the
  group may have been wiped after its stamp expired.

A partial kill leaves the row: the wipe test is false while any unit lives, so belief holds the
last-sighted force until the group is re-sighted or finished off — consistent with OPFOR's own whole-token
stepping.

### A group is watched for life once sighted

OPCOM learns of a kill only for a group it had already sighted — you cannot confirm the death of something
you never knew existed, which keeps the fog honest at first contact. After that first sighting the watch
persists until the group dies, even if the group slips away unseen and dies off-map later. This slightly
over-attributes kill knowledge, and that is accepted: the absence write only ever *removes* a phantom,
never adds live knowledge of position or strength, so it cannot leak truth into belief.

### Required safeguard: prune orphaned rows

A group that empties without a death leaves an orphan row the `Killed` handler never clears — no unit
died, so nothing fired. The `Killed` handler alone is not enough, so the prune ships with the mechanism,
not as an optional extra. Each tick, for every row whose key is a group `netId`, resolve it with
`groupFromNetId` and drop the row when the group is null or empty. **It must guard the subject type** —
belief keys will later include zone and FOB indices and `"HQ"` (`fnc_opcom_belief_init.sqf:6`), which are
not groups; only `netId`-keyed rows may be resolved this way.

The case that forces it is a group merge ([§Group mutation](#group-mutation-merge-and-split)), not a rare
despawn: merging drains one group to empty, and its row would otherwise double-count its force against the
surviving group's row until decay expires it 16 minutes later. The prune bounds that to one tick.

### Group mutation (merge and split)

Zeus (and any script) can merge or split BLUFOR groups mid-fight. The accounting holds because force is
keyed per group and re-read from the live group each sweep:

- **Merge B into A.** grpA keeps its netId, and `count units grpA` grows to the combined headcount, so the
  edge gate ([Fix 2](#fix-2-position-freshness-acquisition-not-knowledge)) rewrites row A's strength to the
  combined force on the next sweep — `knowsAbout` is pinned high in a firefight, so the write is not gated
  out. grpB empties to zero, no death fires, and the prune above drops its orphan row within a tick. Total
  believed force settles at the combined count with at most one tick of transient double-count.
- **Split A into A + C.** grpC is a new netId OPCOM has not sighted, so it carries no row until re-sighted
  — fog-correct, a newly-formed group is a fresh subject. Row A shrinks to its reduced count via the edge
  gate. No double-count.
- **Leader swap on merge** is the one soft spot: if the merge promotes a leader OPCOM knew less well,
  `knowsAbout` on the new leader may sit below the gate and row A freezes at its pre-merge strength until
  the new leader is sighted. This is the documented leader-only approximation (`fnc_opcom_sense.sqf:5`),
  amplified by the swap, and self-heals on the next sighting.

---

## Fix 2: position freshness (acquisition, not knowledge)

### Problem

`east knowsAbout _ldr` is a **lagging knowledge scalar** (0–4): it rises while a target is sensed and
decays over time after line-of-sight breaks — it is not "can see right now"
([`arma_engine_gotchas.md#knowsabout-is-a-decaying-knowledge-scalar-not-a-current-visibility-flag`](../../info/architecture/arma_engine_gotchas.md#knowsabout-is-a-decaying-knowledge-scalar-not-a-current-visibility-flag)).
The sighting sweep stamps `getPosATL _ldr` — the target's **live true position** (`fnc_opcom_sense.sqf:15`)
— gated only on `knowsAbout > 1.5` (:13). So through the decay tail (contact lost, scalar still above
threshold) the sweep keeps re-reading and stamping the live position:

- A target that walks behind cover is tracked while it is unobserved.
- A player who fast-travels to HQ moves the stamp to HQ, blooming enemy force there though nothing saw the
  move — the reported symptom.

Two write paths do it: the new-row stamp (`:15,23`) and the stale-refresh path, which re-writes the live
position once a stamp ages past `OPCOM_BELIEF_FRESH` (`:27-29`) with no new observation at all. Both
violate the store's own stated invariant that a position is *"as last observed, never a live lookup"*
(`fnc_opcom_belief_init.sqf:7`). Storing a position rather than a handle (`opcom_plan.md:49-51`) only stops
the follow *after* the sensor quits — but the sensor keeps firing on stale knowledge, so it re-samples
live position anyway.

### Fix: gate the write on the acquisition edge

Turn the gate from a *level* (`knowsAbout > 1.5`) into an *edge* — write only when the target is being
acquired *now*, detected as knowledge that is not falling:

- Keep a per-group previous-knowsAbout value in a small transient store (a `netId`→number map, server-local
  and handle-free). It need not persist — belief-store persistence is open
  ([`opcom_plan.md#open-questions`](opcom_plan.md#open-questions)) and one tick of missed gating after a
  load is harmless.
- Stamp position, time and strength only when `knowsAbout > 1.5 && knowsAbout >= prev`. A genuine
  observation supersedes: overwrite the row with the current reading.
- When knowsAbout is falling (memory fading, no live contact) do **not** write — the stamp freezes at its
  last-seen position and the existing decay carries its confidence down. This is the decaying last-seen the
  store is meant to be.
- **Remove the stale-refresh path** (`:27-29`): a stale stamp must decay, never silently jump to the live
  position. The edge gate now decides freshness, so keep-strongest and the `_stale` clause are dropped —
  one row per group already holds one observation-independent headcount, so there is nothing to keep
  "strongest" against.

Edge behaviour:

| Situation | knowsAbout | Result |
|---|---|---|
| Sustained contact (mover or static) | pinned high / rising | keeps stamping — accurate track |
| Breaks line-of-sight | starts falling next tick | freeze last-seen, decay |
| Teleports away unseen | keeps falling (no new observation) | new position rejected, old stamp decays — **fixed** |
| Teleports into an OPFOR's view | rises (genuinely seen there) | stamp the new position — correct |

### Engine-native alternative (rejected)

`unit targetKnowledge target` returns the engine's own last-known position plus a current-visible flag — a
real decaying last-seen that never teleports. But it is **per-observer**, not side-wide, so it breaks the
plan's one-`knowsAbout`-call-per-group budget (`opcom_plan.md:63-65`). The acquisition-edge gate keeps the
cheap side-wide call and reconstructs the freshness signal from its derivative.

---

## Spec updates to fold into `opcom_plan.md` when this ships

- **[§Sensors](opcom_plan.md#sensors)** — add a row for the confirmed-kill absence write (removes a row,
  sighted-group-only); and correct the direct-sighting row to say it stamps on acquisition (knowsAbout not
  falling), not on `knowsAbout > 1.5` alone.
- **[§Shape](opcom_plan.md#shape)** — the "never a live lookup" note (belief_init:7 mirrors it) now holds
  in fact, once fix 2 lands; no wording change, but it stops being aspirational.
- **[§Decay](opcom_plan.md#decay)** — state that decay models *lost track* only; a confirmed kill drops the
  row immediately, so an unseen stamp aging to expiry now means only "not seen since", never "may already
  be dead".

## Persistence

Nothing new to persist. Fix 1's `Killed` handlers live on live BLUFOR units, never saved (they regenerate
on approach, [`opcom_plan.md#persistence`](opcom_plan.md#persistence)); the watch re-establishes on the
next sighting after a load. Fix 2's previous-knowsAbout store is transient and rebuilds. Belief-store
persistence stays open and unaffected.

## Verification

All checkable from the debug console against a live player, in the Phase 1 style
([`phase_1_belief_and_grid.md#verification`](phase_1_belief_and_grid.md#verification)):

- **Absence:** sight a BLUFOR group → one belief row appears; wipe the whole group → the row disappears
  **immediately**, not after the decay horizon, and the enemy grid bloom clears on the next rebuild. Kill
  part of the group → the row persists at its last-sighted force. Wipe a group whose stamp had already
  expired → no error (forget no-ops on the absent key).
- **Freshness:** sight a group, then break contact → the stamp holds position and decays in place. Break
  contact and fast-travel across the map → the stamp stays at the last-seen position and does **not** jump
  to the new one. Fast-travel into an OPFOR unit's view → a fresh stamp appears at the new position.
- **Group mutation:** with two sighted groups (two rows), Zeus-merge one into the other under fire →
  within a tick the store holds one row at the combined force, not two summing to a double-count; wiping
  the merged group then removes that row. Zeus-split a sighted group → the parent row shrinks and the new
  group gets no row until it is sighted.
