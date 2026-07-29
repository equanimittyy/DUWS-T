# Known issues and untested surface

What is broken, what is merely unverified, and what the previous developer worked around
rather than fixed. Everything here is reproducible from the source; nothing is speculation.

## Untested since the client/server split

The move to `server/` / `client/` / `shared/` rewrote every script path in the mission.
`tests/run.sh` proves each one resolves and that no function compiled empty, but path
resolution is not execution — only a live run proves the campaign still plays. Zone
generation has been exercised; the rest has not.

- [ ] Capture a zone and confirm the marker flips **on a second machine**, not just the host
- [ ] Run a side mission to completion and confirm the CP/AP reward lands
- [ ] Save and reload mid-campaign — but settle whether a save happens at all first (see below)
- [ ] Call heli-lift **as a non-host player** (see below)
- [ ] Request one support of each family: drop, artillery, UAV, FOB

Zone capture and side missions are server-owned — 16 of 16 zone files and 11 of 12 mission
files run server-side, pushing notifications outward to clients. The client-owned/
server-commanded inversion that made heli-lift unusable cannot occur there, so the residual
risk is narrower: a `publicVariable` that never lands. That is only visible with a second
player connected, which is why the first item above says so explicitly.

## Composition streaming: the record fields are unexercised

Zone props are deleted when no player is near and rebuilt from a record on return
(`server/server_fnc_init.sqf`, `fnc_duws_stow` and `fnc_duws_deploy`). Stow and deploy have been
seen to run, but the six fields a record carries have not been checked against what comes back.

`tests/run.sh` cannot reach this: it proves brackets balance and paths resolve, not that a command
takes the arguments given. Each field below fails silently and differently, so the symptom is the
quickest way to tell which one is wrong.

- [ ] Deploy a stowed zone and compare it against a screenshot taken before — props in the same places, facing the same way. Wrong headings or objects sunk into a slope means `getPosWorld` / `setVectorDirAndUp`
- [ ] Watch server FPS after a deploy. A drop with no other cause means `simulationEnabled` did not round-trip and the whole composition came back simulated
- [ ] Shoot a prop that was invulnerable before the cycle. Damage taken means `isDamageAllowed` did not survive
- [ ] Empty an ammo crate, stow, deploy, reopen it. A refilled crate means the four `get*Cargo` / `add*CargoGlobal` pairs are wrong, and is an infinite ammo source until fixed
- [ ] Destroy a bunker, stow, deploy. Its return means the alive test at stow time is not filtering

## Per-town reputation: shipped, not yet exercised

- [ ] Destroy a house as a **client** on a dedicated server and watch the escalation counter. No movement means `BuildingChanged` is local-only and escalation has never worked in dedicated MP — neither did the war-crimes script it replaced. Record it rather than working around it
- [ ] Clear a garrison in a populated town. If the `WEST SEIZED` trigger never fires, CIVILIAN-side units are blocking it and the fallback is a condition trigger counting hostile units in `thisList`
- [ ] Check the census line in the RPT on a new map, and confirm a single fire mission cannot advance an escalation level. Both numbers are logged on the first run
- [ ] Look at a neutral town's ellipse. Opaque rather than translucent means the inline colour string's fourth channel does nothing and `setMarkerAlpha` is carrying the translucency alone
- [ ] Confirm the campaign-wide reputation still gates partisan hiring and pays its CP tick exactly as before the per-town split
- [ ] Start a RAVAGE or WBK campaign. Towns should carry a `Pop:`-only marker and a permanently neutral ellipse, spawn no garrison, never scale prices, and log no census line

## Hardcore intel: shipped, not yet exercised

- [ ] Search a corpse and confirm the action appears at all. `side group cursorObject == east` is the last clause of its condition, and a dead unit leaves its group's unit list — a group set to `deleteGroupWhenEmpty` can be gone before the body is, which would hide the action on exactly the bodies it exists for. Fallback is stamping the side on the unit at spawn
- [ ] Confirm `cursorObject` returns a corpse reliably at 3 m. Ragdolled bodies and ones settled half-inside geometry are the doubt; `cursorTarget` or a short `nearestObjects` sweep is the swap, but a scripted sweep must stay behind the cheap clauses
- [ ] On a **dedicated** server, as a non-host player: confirm the search action vanishes the moment the attempt is spent and returns on the next economy tick. The flag is broadcast on the player object precisely so a client-side condition can see it, so a host-only test proves nothing
- [ ] Complete a rescue-pilot and a rescue-squad mission on a dedicated server and confirm each reveals a zone. These are the two sites that never paid out at all
- [ ] Die with a search attempt spent, respawn, and check whether the action is available again. It will be — the flag lives on the body — and the open question is whether that refund is acceptable rather than whether it happens

## Hardcore civilian towns: shipped, not yet exercised

- [ ] Open the map on a fresh hardcore campaign. Up to three towns near the HQ should be drawn and every other one dark. None at all means the HQ was not the first anchor when selection ran — the `Town selection:` log line reports the anchor count, and `PosOfBLUHQ` being unset at that moment is the way it happens
- [ ] Walk into a hidden town and confirm the ellipse and the population icon appear together. One without the other means only half the pair is being repainted, and the two alphas are set in different places (`fnc_civ_town_reveal` on reveal, `fnc_civ_townRender` on every reputation change)
- [ ] Shoot a civilian in a hidden town, then check the map. The town appearing means the band repaint is overriding the reveal flag rather than reading it
- [ ] From well away from the HQ, roll the debug payout until it lands on a town rather than a zone — the kind is a coin flip while both buckets hold stock. The town it reveals should be the nearest hidden one to *you*; one near base means the origin never arrived and the HQ fallback is carrying every call
- [ ] Enter a town as a **client** on a dedicated server and watch that client's RPT. `fnc_civ_town_reveal` is named by the town's presence trigger, which is global, so an undefined-variable error there means the broadcast is not landing before the first player arrives

## JIP queue: keyed, not yet exercised

The `remoteExec` JIP queue was keyed throughout; the five bare `true` flags left are the
compiled-code payloads in [Open defects](#open-defects). None of it has been exercised. A second
player joining a LAN host is a real JIP client and covers the first group below; testing alone, or
covering the dedicated-server path a host masks, needs the setup in
[`docs/info/testing.md`](docs/info/testing.md#testing-join-in-progress).

Every check is: build the state, then have a joiner arrive — a second player connecting, or
yourself rejoining a dedicated server. "Rejoin" below means either.

**Entries a joiner receives.** Each tests one keying form, so a failure names its own cause.

- [ ] Hack a sabotage laptop, rejoin. The action is gone and the mission cannot be completed twice — this was the one behavioural bug, a joiner re-hacking finished work
- [ ] In a **hardcore** campaign, approach an un-hacked sabotage laptop and rejoin. It must offer *both* the sabotage action and the intel search: they key to the same object, and the search used to evict the sabotage action so the mission could not be finished at all
- [ ] Deploy and undeploy the MHQ several times, rejoin. Exactly one action, matching its current state — not the toggle history
- [ ] Run several side missions to different outcomes, rejoin. Each task appears once at its latest state, with no replay of superseded transitions
- [ ] Kill a mission patrol, let a mission-slot release fire (it clears `allDeadMen`), rejoin. Corpse search actions track the corpses actually on the map, not the campaign's total kill count
- [ ] Rejoin with the HQ built. All six HQ actions are present — quick change, map board, HQ building, medical tent, black market, redeploy — plus AI rearm on the tent. Three of these hang off one object and two off another, so a missing one is an id collision
- [ ] Activate the repair and recycle stations, rejoin. Both actions are present: they resolve the same depot object from `HQ_repairDepot_netId`
- [ ] Build a FOB, rejoin. Its action menu, fortify and guards entries are all present
- [ ] Spawn a RAVAGE/WBK recruitable, rejoin. Exactly one recruit action on it, not several
- [ ] Rest-heal and let a mission slot release a few times, then rejoin. No burst of stacked date/time OSDs

**Boot path.** These gate everything above, so run them first.

- [ ] Rejoin and confirm the client reaches play: no stall on `serverinit_complete`, and the server's `true` is not overwritten by the joiner
- [ ] Confirm a rejoining player ends up at base, visible, and takes damage — `allowDamage` is set `false` at `initPlayerLocal` and only restored after the intro wait
- [ ] Grep the client `.rpt` for `\[DUWS\]\[WARN\]\[BOOT\]`. Any bounded wait that timed out names itself there; before this change it would have hung silently

**Unverified engine behaviour.** Both are safe either way today; the answers decide future shape.

- [ ] Settle whether `BIS_fnc_taskCreate` already delivers task state to joiners by itself. Every call runs server-side under a plain `call` and is never broadcast, yet clients see the tasks — which would make the 27 `BIS_fnc_taskSetState` broadcasts redundant rather than merely keyed
- [ ] Settle whether `remoteExec ["", _id]` removes a queue entry when issued from a client. The one removal in the tree hands the call to the server rather than rely on it

## Heli-lift for non-host players

`client/supports/fnc_helolift.sqf` used to create the transport helicopter on the calling
client and then ask the server to give it waypoints. Waypoint and flight commands are only
honoured where the group is local, so this worked for a hosting player — whose client *is*
the server — and silently did nothing for anyone else. `fnc_request_support.sqf` carried an
`if (!isServer) exitWith` that disabled the whole support for non-host players rather than
fix it.

The helicopter is now created and owned by `server/supports/fnc_helolift_spawnHeli.sqf`, and
that gate is gone. **The host case is confirmed working; the non-host case is not, and cannot
be tested solo** — it needs a second player or a dedicated server. If it misbehaves in co-op,
restoring the `!isServer` gate re-hides the feature without reverting the rewrite.

Background on the locality rule: [`docs/info/arma_engine_gotchas.md`](docs/info/arma_engine_gotchas.md).

## Does a multiplayer save happen at all?

Unverified in **either** direction, and worth settling before anyone builds on top of it.

`server/misc/fnc_autoSave.sqf` is the only save in the mission: it re-enables saving if
`savingEnabled` is false, then calls `saveGame`. Its one caller is the SITREP support. The
common understanding is that `saveGame` does nothing in multiplayer, which would make the
whole path dead in co-op — but nothing in this tree demonstrates that. No RPT in `temp/`
contains a single save-related line, and the mission disables saving itself at
`server/server_init.sqf:113` (`enableSaving [false, false]`), which is a mission decision and
says nothing about what the engine would do. Treating "saveGame is a no-op in MP" as
established fact is how an assumption gets promoted to a premise.

Two failure modes are being conflated and need separating, because `fnc_autoSave.sqf:5-8`
actively tries to undo the second one:

- the engine refuses to save in a multiplayer session at all
- saving was switched off at boot and the re-enable does not take

**The test.** Host the mission in multiplayer — hosted counts, `isMultiplayer` is true — call
SITREP, then check whether a resumable save appears. That distinguishes "no save" from "save
works and reload is the untested half". For the diagnosis rather than the symptom, log
`isMultiplayer` and `savingEnabled` either side of the `enableSaving` call, plus a line after
`saveGame` proving it was reached.

Until that runs, the SITREP notification is unsound in one direction or the other: it
broadcasts *"The game has been saved"* to every player unconditionally
(`server/supports/fnc_sitrep_support.sqf`). If MP saves do not work, that message is a lie to
everyone; if they do, it is correct as written. Do not gate it on `isMultiplayer` before
knowing which — the gate would suppress a true message in the case where saving works.

This matters beyond the save button: [`docs/campaign_persistence_plan.md`](docs/campaign_persistence_plan.md)
opens by asserting the current save cannot work, and that assertion rests on the same
unverified premise.

## Open defects

| Defect | Where | Effect |
|---|---|---|
| `localize "STR_DUWS_T_jjztkt04"` names a key that has never existed in `stringtable.xml` | `client/supports/fnc_siva_drop.sqf:88` | The player sees the raw key name on screen instead of a message |
| `random_placement` is set on the client and never `publicVariable`'d | `client/dialog/fnc_HQ_random_place.sqf`, `fnc_HQ_faction_dialog.sqf`, `fnc_startup_faction_flow.sqf` | Harmless today — its only reader is client-side on the same machine — but it fails silently the moment anything server-side reads it |
| Two registered functions are never called from anywhere | `server/missions/fnc_missionPatrolsSmall.sqf`, `server/misc/fnc_findSafeMissionPos.sqf` | Dead weight; both carry a `Locality: unreferenced` header saying so |
| Two script paths in `paths_baseline.txt` point at files that do not exist | `client/misc/fnc_player_markers.sqf`, `server/misc/fnc_repetitive_cleanup.sqf` | Pre-dates the test suite; baselined so the linter gates regressions without being blocked by it |
| Six `format[...]` calls wrap a single literal with no placeholders | `client/supports/fnc_helolift.sqf` | Cosmetic — a wasted call per invocation |
| `fnc_log` calls itself instead of writing the line | `shared/functions/fnc_log_init.sqf:25` | Unbounded recursion on every line at or below the active level: nothing reaches the RPT and the first logged milestone kills the boot. The `diag_log` -> `fnc_log` sweep has to skip this one file — it is where `diag_log` lives |
| Two functions named by zone triggers are never broadcast | `fnc_captured`, `fnc_enterlocation`, registered in `server/server_fnc_init.sqf` without `publicVariable` | A `createTrigger` statement is global, which is why the civilian town trigger's `fnc_civ_handler_ravage` / `fnc_civ_handler_wbk` *are* broadcast. One of the two treatments is wrong: if the zone side is, every client spawns a nil on each zone entry and capture. The campaign is unaffected — the server runs its own copy — but a client RPT fills with undefined-variable errors |
| `duws_all_helmets` and `duws_all_vests` are read but assigned nowhere in the mission | `server/misc/fnc_civ_handler_ravage.sqf:260,270` | RAVAGE only, and only on the zombies that draw no uniform — roughly 30%, since the uniform roll is `_isZombie && random 1 < 0.7`. Those two branches are the fallback for a unit with no uniform side to match, so they are the only readers, and `count` on an undefined variable throws where the assigned lists would have been used. Both were carried over untouched when RAVAGE was split out of `fnc_civ_handler` |
| Five `remoteExec ["call", 0, true]` sites ship a whole `addAction` body as compiled code | `destroy_cache:123,158`, `rescue_pilot:336,407`, `steal_supply:87` | Queued under an engine-generated id nothing can address or remove, and the largest entries a joiner receives. Cannot be keyed until each body becomes a named function taking arguments |
| `removeAction` takes index `0` rather than a captured `addAction` return | `client/missions/mission_threads/sabotage_laptop/fnc_sabotage_laptop_success.sqf:24` | Works today because insertion order puts the sabotage add before the hardcore intel rotary, but the laptop carries two actions, which is exactly when index-`0` removal stops being safe |
| An unbounded `waitUntil` sits on the joiner's branch of the client boot | `client/client_init.sqf:140` | Blocks on `HQ_pos_found_generated && chosen_settings` with no timeout, reached only when `WARCOM_init_done` is false. It hints the player every five seconds, so the stall is visible; proceeding on a timeout would boot a client into a campaign whose settings never arrived. What it lacks is a log line |
| `staminaEnabled` is read but never assigned anywhere in the mission | `server/warcom/fnc_init_OPFOR_WARCOM.sqf:67` | The whole `format` throws on `Undefined variable in expression: staminaenabled`, so the campaign settings summary hint never displays for any player. Confirmed in an RPT at the moment generation completes. `client/misc/fnc_sitrep_display.sqf:33` reads the same variable behind an `isNil` guard, which is why only this site fails — either assign it at setup or drop it from the hint |

## Zone generation is slow at large radii

`server/misc/fnc_moreUrban_locations.sqf` filters candidate zone sites by asking the engine
how many buildings sit within 100 m of each — one `nearestTerrainObjects` sweep per
candidate. Logged runs at `zones_max_dist_from_hq = 15000` took 20 s, 70 s and 114 s for
1144, 3392 and 5909 candidates: a flat ~50 candidates/second, so the spread is candidate
count and not lookup speed. What moves the count is the arc filter, whose yield depends on
where HQ landed relative to the map — the same radius left 1144 of 6145 candidates in one
run and 5909 of 6064 in another.

A flat rate that tracks frame rate rather than workload was the scheduler rationing the pass,
so the sweeps are batched unscheduled
([§scheduled scripts](docs/info/arma_engine_gotchas.md#scheduled-scripts-share-3-ms-per-frame-so-a-long-loop-runs-at-frame-rate)),
which measured 2589 candidates in 10 s — ~259/second against the ~50 before it.

That is as far as batching goes: the same run reports 10 s wall against 10.2 s sweeping, so
the pass now spends all of its time inside the engine lookups at roughly 4 ms each and none
of it waiting for frames. Cost is `candidates x 4 ms`, and the only remaining lever is
sweeping fewer candidates. The `ZONES` line keeps reporting both figures because a future
boot script that starves the pass again would show up as the two diverging.

Reading those logs: [`docs/info/testing.md`](docs/info/testing.md#runtime-logging-reading-the-rpt).

## Zone and civilian siting defects

Thirteen defects in the zone-siting and Dynamic Town subsystems are catalogued with their
failure modes alongside the explanation of how those systems work, rather than restated
here: [`docs/info/zone_and_town_generation.md`](docs/info/zone_and_town_generation.md#defects-subsystem-a).

The two worth knowing before a long campaign: the origin keep-out uses `exitWith` inside a
loop, so a rejected candidate silently costs a zone slot and you get fewer zones than
requested; and dynamic towns can spawn on top of enemy zones because the exclusion wait
never actually blocks.

## Worked around, not fixed

Carried from the previous developer and left alone deliberately.

- **`Land_GuardTower_02_F` reports one building position with a wrong Z**, and `modelToWorld`'s
  Z is unusable on it too. `server/init_hq/fnc_BluHQinit.sqf:348` combines model-space XY with
  world-space Z to place the tower garrison. The comment there records the reasoning.
- **Zone selection can pick a centre that surprises BLUFOR.** Three WARCOM spawners
  (`fnc_WARCOM_opf_patrol.sqf`, `fnc_WARCOM_opf_qrf.sqf`, `fnc_random_veh_opf_patrol.sqf`)
  each place their units deliberately far from the zone centre to compensate. The underlying
  selection is untouched.
