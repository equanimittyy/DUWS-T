# Garrison strength and reserves

A held zone or town fields a garrison whose strength is a ledger of destroyed composition tokens,
and whose live footprint is capped and topped up from a reserve pool. This doc is the reference for
that model; where it and the source (`src/duws/server`) disagree, the source wins.

## One model, two site kinds

A garrison is a **site**: the shared `fnc_site_*` store (key, pos, radius, roster) that zones and
towns both register in. A site raises a composition, gets ground down by the same player, and
comes back at what was left, not what it started with — one model, whichever kind of ground holds
it. The only differences are which tier table it draws from (`DUWS_zoneSpawnTiers`,
`src/duws/server/init_zones/fnc_zone_spawn_sizes.sqf:24`, vs `DUWS_townSpawnTiers`,
`src/duws/server/civilian/fnc_civ_state_init.sqf:59`) and what happens once it's beaten: a zone flips
to BLUFOR, a town is cleared back toward neutral and bought up again by the commander.

## Whose garrison it is

The model is one side's or the other's, never both. `DUWS_fnc_garrisonSideOf {key}`
(`src/duws/server/garrison/fnc_garrison_strength_init.sqf:11`) is the single derivation, read by every
ledger call, composition filter and raise below: a zone answers to `WARCOM_zones_controled_by_BLUFOR`,
a town to the reputation bands (`fnc_civ_townOwner`), and anything else answers `"OPF"`.

A garrison crews whatever the ground carries, so a zone the player holds mans its prefab's guns with their
own men; only a raise reaches that pass, which is why it happens exactly when they have a garrison and not
before. OPCOM reads a BLUFOR garrison at its **true force**, not a nominal — the commander is omniscient
about what the player has built, and the territorial figure it used to read is now only the floor for
BLUFOR ground carrying no garrison. A sighted group on a live BLUFOR garrison's roster keeps its belief row but
adds nothing to the force grid, because the site's deposit already counts it
(`src/duws/server/warcom/opcom/belief/fnc_opcom_grid_sources.sqf`).

Both sides field the **same tier rows**. A token resolves through the asking side's vehicle table
(`DUWS_spawnVehicles` / `DUWS_spawnVehiclesBlu`) and its own earned Army Power, so one row raises either
army out of its own hulls. Both tables are fenced, and the composition lint fails a vehicle token only
one of them answers — the other side would otherwise resolve the token to its own bare name and hand
`createVehicle` a class that does not exist.

What differs is how a garrison comes to exist, and it is the one asymmetry in the model:

| | OPFOR | BLUFOR |
|---|---|---|
| First tier | handed over: a retaken zone resets to I, a town crossing the band is written I | bought, like every tier above it |
| Inherited on a flip | nothing — the ledger is forgotten and the tier zeroed | nothing, same rule |
| Beaten town garrison | files back to tier I, unrefunded | files back to tier 0 |
| Mobilising hold | held, because OPFOR arrive on ground they already own | none: a BLUFOR garrison never arrives, it is built |
| Who wakes the site | any BLUFOR, players and AI alike | players, and the attacker — a friendly garrison is AI inside its own ring, and counting it would pin the site awake for good |

A flip in either direction zeroes the tier and forgets the ledger, so neither side is ever handed the
other's attrition or their spending. Survivors of the beaten garrison fight on where they stand
(`DUWS_fnc_garrisonRelease`) and are swept once no player is near, whichever side they belong to.

Buying is `fnc_zone_garrison_fortify` / `_reinforce` and `fnc_town_garrison_fortify` / `_reinforce`.
Neither charges: the price is the caller's, which is what keeps OPCOM spending only on its own ground
(its candidate lists skip BLUFOR-held sites) and leaves the player's price to whatever surface spends
their currency. The zone pair is reachable today only from the Debug menu's map-click rows; the town
pair from the economy debug window.

## The ledger

Strength is not a scalar fraction. It is a multiset of composition tokens the garrison could ever
field (`full`), minus the tokens it has actually lost (`lost`):

```
full      = mult copies of the filtered x1 tier list, stamped at raise
              (filtered = what the side can field, given settings and faction)
locked    = the tokens in full behind an Army Power rung the side has not earned
lost      = flat token list, persists across a stow
surviving = full minus lost, by value                    (DUWS_fnc_garrisonSurviving)
pool      = surviving beyond the standing template        (the reserve)
garrison  = surviving capped to the standing template     (what deploys)
strength  = count surviving / count full                 (DUWS_fnc_garrisonStrength)
```

A locked token is kept, not dropped. `DUWS_fnc_garrisonFull` leaves it out, so it counts toward no
strength, force, break test or standing template until OPFOR's earned Army Power reaches its rung
(`DUWS_fnc_tokenLocked`). The site then gains it with no restamp, so a zone stamped at campaign start
fields its armour once the rung is earned. A seed and a tier buy file locked tokens as lost, so earning a
rung never refills ground that a clear, a retake or a purchase left owed.

Every strength measure counts tokens, not men: a tank, a 2-man patrol and a 6-man team each weigh one
token. The one exception is `DUWS_fnc_garrisonForce`, the OPCOM force grid's firepower figure, which
still counts men and vehicle power.

A token is lost when its **group is wiped** — destroy one tank, lose one tank. A squad that takes
casualties but keeps a survivor is not recorded: it streams out and comes back whole next raise.
Chip damage does not persist; only a wipe does.

Every raise, and every buy on a standing garrison, re-stands through `DUWS_fnc_garrisonRestand {key,
x1}`. It calls the shared derivation `DUWS_fnc_garrisonDerive {key, x1, mult, stand}`
(`src/duws/server/garrison/fnc_garrison_strength_init.sqf:77`), which stamps `full`, computes
`surviving`, and splits it against `_stand` (the density-thinned standing template) into
`[garrison, pool]`. Losses come out of the pool before they ever thin the standing garrison. The
derive rebuilds only the base pool, so Restand carries OPCOM's pooled tokens across it. It then sets
the refill ceiling to the standing template's count plus the OPCOM units already accounted to the
site, and re-syncs OPCOM's homed units.

The sync, `DUWS_fnc_opcom_zoneReserveSync {key}`
(`src/duws/server/warcom/opcom/taskings/orders/fnc_opcom_garrison.sqf:11`), compares the homed units with the
tokens it added this awake session (`DUWS_zoneReserveOpcom_<key>`), not with the pool. A unit already
drawn onto the ground is out of the pool but still homed, and adding its token again would field it
twice. The sync adds a token for each newly homed unit, removes the token of a unit that left, and
moves the ceiling by the difference. A stow clears this record with the pool.

A raise then fills to the ceiling through `DUWS_fnc_garrisonStandFill {key, garrison}`
(`src/duws/server/garrison/fnc_garrison_strength_init.sqf:106`). It draws random fieldable base tokens
from the pool first, and OPCOM's homed units take only the room that is left. The drawn tokens leave
the pool and stand with the garrison, so the players meet the whole force on arrival, not a short or
empty site that waits up to five minutes for its first refill wave. The draw stops at the global
group wall. A re-stand on a standing garrison (a reinforce or a fortify) does not fill, because its
men are already on the ground and the refill tops it up.

The ledger API, all in `src/duws/server/garrison/fnc_garrison_strength_init.sqf`:

| Function | Does |
|---|---|
| `DUWS_fnc_garrisonSetFull {key, full}` | Stamp `full`. Called by the derivation, a tier buy, an OPFOR cap and a town clear. |
| `DUWS_fnc_garrisonLocked {key}` | The stamped tokens that `DUWS_fnc_garrisonFull` leaves out because their rung is not earned yet. |
| `DUWS_fnc_garrisonLost {key}` | The lost token list. |
| `DUWS_fnc_garrisonSurviving {key}` | `full` minus `lost`, by value. |
| `DUWS_fnc_garrisonRecordLoss {key, token}` | Push one lost token, bounded at its count in `full` — a double-fire of the killed handler is a no-op. |
| `DUWS_fnc_garrisonStrength {key}` | The live `[0,1]` projection the map bar reads. |
| `DUWS_fnc_garrisonSeed {key, keep}` | Keep `keep` random tokens of `full` and file the rest lost, locked tokens included, which spends the pool before the garrison. Called by `DUWS_fnc_garrisonSeedOpforCap`, and with `keep` 0 by a town clear. |
| `DUWS_fnc_garrisonSeedOpforCap {key, x1}` | Stamp `full` at the tier I list `x1`, then keep `ceil(0.1 × full)` tokens. Rounded up, so a tier I site at multiplier 1 still stands one token. Called when OPFOR take ground: a zone retake (`fnc_opfor_cap`) and a town crossing into the OPFOR band (`fnc_civ_garrison`). |
| `DUWS_fnc_garrisonUnlose {key, n}` | Remove `n` random unlocked lost entries, or all of them if fewer are lost — a paid replacement, not a heal. |
| `DUWS_fnc_garrisonReinforce {key, x1}` | Unlose `floor(REINFORCE_STEP × full)` tokens (`REINFORCE_STEP` is `0.3`), then re-stand a standing garrison at `x1`. The town and zone reinforce purchases both call it. |
| `DUWS_fnc_garrisonBuyTier {key, oldX1, newX1}` | Stamp `full` at `newX1` and file all but a tenth (rounded up, drawn from unlocked tokens) of the tokens it adds over `oldX1` as lost, bounded at each token's count in the new `full`. The zone and town fortify both call it, so a bought tier must be reinforced to field whole. The caller re-stands a standing garrison. |
| `DUWS_fnc_garrisonForget {key}` | Clear `full`/`lost` entirely. Called only when a town leaves the OPFOR band, whether or not a garrison stands, so a garrison re-earned later starts fresh instead of redeploying the remains of ground that stopped being contested. |
| `DUWS_fnc_garrisonHeld {key}` | Liveness: true from the moment a raise finishes placing men to the stow or capture that tears it down. Gates the capture test and the refill pass. |

`DUWS_fnc_garrisonSetLive {key, live}` (same file) is the only writer of `DUWS_fnc_garrisonHeld`,
and it doubles as the registry maintainer: it pushes or drops `key` on `DUWS_garrisonSites`, the
list the refill pass iterates. A site is on that list exactly while it's live, kept in lockstep
because both are written in the one place.

Hardpoints are not on this ledger. An emplacement's liveness is its own broadcast `DUWS_hardpoints`
row — present means alive, the streamer deletes it on clear — read client-side by the strat-map
pickers and latched (a cleared hardpoint never returns). That broadcast, one-shot model doesn't fit
this server-only, graded, recapturable one, so the two are kept deliberately separate. The streamer's
`DUWS_hpPeak_<key>` is its server-side deployed-gate, the analogue of `garrisonLive`.

An old save's strength is not migrated: nothing has stamped `full` yet, so the first raise after
an upgrade starts every garrison fresh.

## Recording a loss

`DUWS_fnc_garrisonReserveWatch {key, grps}`
(`src/duws/server/init_zones/fnc_garrison_reserve.sqf:222`) tags each unit with its group's source
token — stamped on the group at raise by `DUWS_fnc_zoneSpawnOne`
(`src/duws/server/init_zones/fnc_zone_spawn_sizes.sqf:259`) — and hangs a `Killed` handler on it.
The handler checks that the whole group is down (`{alive _x} count units (group _unit) == 0`)
before calling `DUWS_fnc_garrisonRecordLoss`; a unit dying with squadmates still up records
nothing. The tag rides the *unit*, not the group, since a dead man can outlive it. The same
handler also fires the event-refill trigger (below).

A zone or town raise hangs the watch only after it places every group, so a group that dies during
the raise has no handler to record it. `DUWS_fnc_garrisonRefundUnplaced {key, tokens, grps}`
(`src/duws/server/init_zones/fnc_garrison_reserve.sqf:254`) runs between the raise and the watch. It
returns the token of each group with no living man, and of each token that raised no group, to the
pool, and the refill pass fields it again. Such a death comes from the placement (for example, a
vehicle that spawns on a slope), not from a fight, so it does not cost the garrison a token. Without
the refund, the token stays in `surviving` but nothing stands for it, and the ledger shows one more
token available than groups on the ground.

An OPCOM unit's token is not in `full`, so `DUWS_fnc_garrisonRecordLoss` ignores its wipe. The handler
passes that wipe to `DUWS_fnc_opcom_defenderLost {key, token}` instead, which marks the unit dead and
re-syncs. A homed unit exists on the ground only as its reserve-spawned group, so the wipe is its death,
and without the mark the next raise would stand it again.

## Reserve depth and the group ceiling

`enemyunitMultiplier` is reserve depth, not a live-force multiplier. A site always stands up its
**x1** tier composition; the surplus `(mult - 1)` copies wait as a pool that refills the garrison
as casualties are taken. This exists because a composition token is a group, and the engine
silently drops any `createGroup`/`BIS_fnc_spawnGroup` call once a side passes **144 groups**
(`docs/info/architecture/arma_engine_gotchas.md`) — scaling the live composition wholesale at x3 could ask for
triple a tier's groups on one site alone, and two hot sites at once would blow the wall.

Per-site, the live *composition* group count is capped at the standing template's count plus the
OPCOM combatants homed there, stored as `DUWS_zoneCeiling_<key>`. `DUWS_fnc_garrisonGroupCount {key}`
(`src/duws/server/init_zones/fnc_zone_state_init.sqf:205`) counts distinct alive groups the
streaming garrison raised; a prefab's manned static weapons sit on the same roster but are
excluded, so a site with guns doesn't read as already at its ceiling. Globally,
`DUWS_zoneGroupCeiling` (130, `src/duws/server/server_var_init.sqf:457`) pauses a garrison's spawns
and refills once its own side's group count (`DUWS_fnc_sideGroupCount {side}`) reaches it — slack for
hardpoints and town garrisons, which raise their own groups outside any per-site cap but still count
against this wall. The engine's limit is per side, so a BLUFOR garrison is throttled by BLUFOR groups,
the player's own squads and recruits included.

## The refill pass

`DUWS_fnc_garrisonReservePass` (`src/duws/server/init_zones/fnc_garrison_reserve.sqf:551`) walks
every site on `DUWS_garrisonSites` that is held and has a non-empty pool — with no BLUFOR-presence
gate, the same as the event trigger below, so a site refills whether or not it is being fought;
sorts the candidates by player count present, most-crowded first; and spawns
`DUWS_fnc_garrisonReserveRefillOne` per site. That worker pops random fieldable tokens from the
pool and delivers them until the site's group count reaches its ceiling, the pool empties, or the
global throttle is hit. Infantry tokens now ride in trucks, batched — consecutive squads share one
until it's at least half full, then it's dispatched — rather than walking in on foot; a vehicle
token drives itself in, unbatched. The truck is drawn from the site's own side; BLUFOR's pair of transport
keys is vanilla-defaulted, since no faction file names one, so a friendly wave still rides.

Two triggers fire the pass: a 5-minute heartbeat (`DUWS_fnc_garrisonReserveLoop`,
`DUWS_zoneReservePollPeriod = 300`) for the steady grind, and a debounced
(`DUWS_zoneReserveEventDebounce = 20`s) event on a deep dip — a held site whose live groups fall below
`DUWS_zoneReinforceFrac` (0.5) of its ceiling pulls an immediate wave rather than waiting for the
beat, so reinforcement reads as waves, not one-in-one-out whack-a-mole.

A reserve counts as still-owed force until it either arrives-and-dies or the site stows: the break
test adds the tokens still in the pool to the groups standing. Delivering a wave moves a token from
the pool to the ground without changing that total; only a wipe does.

## Placement: keeping a wave off the player's back

`DUWS_fnc_garrisonReservePos {center, radius, side}`
(`src/duws/server/init_zones/fnc_garrison_reserve.sqf:89`) chooses where a wave stands up, in
priority order over a flat distance floor, so a player never watches a squad appear and never gets
flanked from their own approach direction:

1. **Opposite the player approach (non-negotiable).** The spawn bearing is `-bluDir`, where
   `bluDir` is the site-centre-to-player-centroid direction — reserves come from the far side and
   meet the advance head-on, never from behind it.
2. **Nudged toward the nearest other zone the side holds (soft).** The bearing bends up to 50 degrees
   toward a neighbouring zone so a wave reads as coming from friendly ground, clamped so it can
   never fight the anti-flank rule.
3. **Preferably out of sight (best-effort).** A handful of candidate points along the bearing are
   tried with `BIS_fnc_findSafePos`; the one fewest players have line of sight to wins. Not a hard
   gate — a widened fallback runs if every candidate on the preferred arc is bad ground (most often
   a far side facing open water).

Distance is a flat floor, `DUWS_zoneReserveSpawnDist` (400 m,
`src/duws/server/server_var_init.sqf:467`), measured from the nearest player rather than scaled to
the site radius — a radius-relative distance would drop a wave a kilometre off a small island and
on top of the player at a large base.

A candidate is rejected when it is in the water or within the floor of a player. Candidates come
from `fnc_safe_pos`, so a failed search is rejected rather than taken as a point
([`arma_engine_gotchas.md`](../architecture/arma_engine_gotchas.md)). The search runs on a ring at `radius + 400` m first. When no bearing passes
(for example, players ring the site), it runs again on a ring at `radius + 800` m. When that ring
also fails, the wave spawns at `radius + 800` m on the spawn bearing, with no player or sight test,
walked in toward the site centre until it is on land.

**Line-of-sight cost.** `lineIntersectsSurfaces` is a raycast, expensive only when run per-frame
across many units. Here it runs at spawn time only — a handful of candidates times the players
present, once per wave every few minutes — so it's dozens of casts spread over time, not a
frame-budget item. Bounding the candidate count and accepting the best-seen point rather than
demanding a fully-hidden one keeps the cost constant and never blocks a spawn.

## Hunt posture

Reserves are ordered with a dedicated `"hunt"` case in
`src/duws/server/placement/fnc_apply_posture.sqf:188`: `AWARE` behaviour, `YELLOW` combat mode,
`FULL` speed, a `SAD` waypoint, then a cycle. Speed is deliberate — a reinforcement runs, it does
not patrol; the wave has to arrive as pressure, not a slow trickle. It applies unchanged to a
mounted group or aircraft, each hunting at its own pace.

The `SAD` target is the **site centre**, not the player's position: aiming at a player's
spawn-time location let a wave walk off the objective if the player withdrew before it arrived,
leaving the ground taken and the counterattack chasing nothing. A centre destination still crosses
the wave through the players on the way in, since it spawns on the far side.

The mobile ground combat vehicle tokens — `car`, `apc`, `ifv`, `tank` — always resolve to a hull that
can fight infantry. `DUWS_fnc_tokenClass` narrows their role pool through `DUWS_fnc_classGroundCapable`
(`src/duws/server/init_zones/fnc_zone_spawn_sizes.sqf`), which fails any class whose turrets carry no
gun — a missile-only or unarmed hull. This is a derivation rule, not a posture one: such a hull drawn
for one of these tokens parks at `SAD` range and duels from spawn rather than close — idling instead of
fighting — whether it is holding a zone or hunting one. Dedicated `aa` and the air roles are exempt;
that weapon is their job. A combat role whose pool holds nothing gun-armed resolves `""`, so
`fnc_zoneSpawnList` drops the token and no site fields it.

The same classifier (`DUWS_fnc_classArms`, one turret walk) reads the gunless hulls `car` drops into two
dedicated tokens — `at_car` (a guided AT missile, no gun) and `aa_car` (an air-locking missile, no gun) —
a clean three-way split of the armed-car pool, since a gun-armed hull is always `car`. Both are defined
but not yet fielded by any composition.

The intended use is OPFOR's tasking, as **static defenders** rather than line units. They are specialist
assets — defenceless outside their niche — so when wired in they belong in `garrison` posture, held at a
firing position, and must be kept out of the reserve/hunt pool and the enemy-multiplier scaling (one per
zone is the threat, not a stack that grows with the setting). The exclusion is the whole point: a
specialist that reinforces by driving into the open forfeits its only advantage and revives the very
faults the gun filter removed — a hunting ATGM parks and duels from spawn, a hunting SAM drives in
defenceless. Held on defense the same standoff is the asset doing its job: an ATGM killing armour at
range, a SAM denying the airspace over the zone.

## The break test

`DUWS_fnc_garrisonBeaten {key}` (`src/duws/server/init_zones/fnc_garrison_reserve.sqf:10`) is the
one capture/clear line for both site kinds: standing groups plus pooled tokens, worn to **15 % of
`full`'s token count**. A group counts as one whole token while any of its men stands, which is why
the line sits above a tenth. A site with an unspent pool cannot fall on an empty perimeter — the pooled
tokens hold it above the line until the waves have spawned and been killed, so a player has to draw out
and beat most of everything the site was ever worth, not just what happened to be standing when they
arrived.

The test counts standing groups, not the ledger's `surviving`, because a reserve token whose spawn
placed nobody is neither lost nor pooled and would hold the site forever. OPCOM's homed defenders sit outside
`full` but count through both halves: standing, they are tagged groups on the roster; pooled, they are
tokens in the pool. A prefab's turret crews carry no reserve tag, so they do not count.

`garrisonBeaten` alone never takes ground. `DUWS_fnc_siteTaken`
(`src/duws/server/init_zones/fnc_garrison_reserve.sqf`) is the one rule for a zone capture, a zone
retake and a town clear. It also needs an attacking ground unit inside the site radius, and the
attacker outnumbering the defender over the streaming ring (radius + 400 m), ground units only, counted
owner-blind. All three must hold unbroken for `DUWS_captureHold` (20 s,
`src/duws/server/server_var_init.sqf`), and the function stamps that hold itself.

- **Zone capture and retake** run it as the zone trigger's condition, twice a second.
- **Town clear** runs it as the condition of the town's own trigger, also twice a second, and only
  at tier I or above (`src/duws/server/civilian/fnc_civ_garrison.sqf`). Clearing pays a reputation
  credit and drops the tier to I —
  not 0; ownership survives, only the purchase was beaten. It stamps `full` at tier I with every
  token lost, so the town stands nothing until the commander resupplies it. A raise with nothing to
  stand never goes live, so the clear cannot fire again on an empty town.

Survivors of a flipped zone or a cleared town are not ordered off. `DUWS_fnc_garrisonRelease` moves
them to the site's `leftover` roster and clears their garrison key, so a later wipe records nothing
against the ledger. They fight on where they stand, and `DUWS_fnc_garrisonLeftoverSweep`
deletes each one once no player is within 500 m.
