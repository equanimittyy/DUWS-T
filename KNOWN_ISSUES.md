# Known issues and untested surface

What is broken, what is merely unverified, and what the previous developer worked around
rather than fixed. Everything outside the dump is reproducible from the source; nothing there
is speculation.

**How this doc is used.** This doc carries what is still wrong or still unproven — not a record
of work done, which is what git is for. Checkboxes are ticked as each check is actually run, so
an unticked box means untested rather than merely unfixed.

## User dump

Raw play-test notes land between the markers below, written as observed and before anyone knows
whether they name something further down.

**Triaging the dump empties it.** Every note ends in one of two states, and neither leaves
anything behind in this section:

- **Fully addressed** — deleted outright. No section is opened for it, no verification checklist
  is filed, and no note of the fix is kept anywhere in this doc; git carries what was done.
- **Not fully addressed** — written into the section below that owns it, as the problem that
  remains rather than as the note that was made. Partly fixed counts as not fully addressed, and
  what gets recorded is only the part still wrong.

The markers stay so the next round has somewhere to land. An empty block means the last round is
fully triaged.

_BEGIN-USER_
- Killa Tomata message lasts a little bit too long now, cut down by 3 seconds
- Note in the docs/code that the building change/destruction logic for escalation actually means building state has changed (so 1 house can contribute more than once)
> This is fine, non-issue.
> We need to make escalation easier to trigger though, I think it's currently set to 10%? I want the current ratio divided by 3 so level 1 escalation costs 159 buildings, should be about 50 buildings, and so on.
- Straight up killing civilians did nothing; need to make it cost -1 REP and -2 REP for building destruction (same constraints; player within 200m)
> Ensure same notification plays when rep is changed, ensrue it's consistent
- There is a zone generation mechanic that hides buildings/deletes them
> Maybe needs to be fed through to server/clients but an explosion nearby that changes building state, re-pops the building
- Despawning of enemy zones should match civilians, or 2x of civilians, 5min is too long
- Left over dynamic side-missions should be deleted where OPFOR does something
> e.g. Hunt Mortar Observer; not killing the observer spawns mortars ontop of you - to be replaced with OPFOR commander system later
- Garrisons spawn all their units all in one spot instead of spreading them out across buildings and patrols; if it does, it does so very slowly (efficiency gain here likely)

_END-USER_

## The refactor branch: twenty-four code commits, none of them run

A structural pass over `src/duws/` fixed eight defects on the way through. All of it passes
`bash tests/run.sh`, which reads brackets, resolves paths and runs the pure-function unit layer —
none of which can see a running mission. Eight of the commits change what the game does.

Eleven checks cover the risk. Each names the commits it clears, so a failure points somewhere
narrower than the whole branch.

- [ ] **Run one side mission end to end.** Covers the mission prologue and exit helpers, the shared
      garrison, and corpse intel. Watch for: a mission that fails to find ground is immediately
      re-requestable rather than locked for an hour; markers are deleted on completion; the reward
      pays once. A sniper hunt's garrison should now drop searchable intel, which it never did
- [ ] **Open the HQ and FOB request menus, buy a unit and a vehicle from each — on a vanilla, a
      modded and an auto-detected faction.** Covers the `getVariable` conversion, the guards added
      beneath it, and the move to one array per faction. Rows must populate identically, and a row
      with no faction entry behind it must refuse *before* charging rather than after. The three
      faction kinds are three different writers: literal arrays, a third-party file that may still
      use the old numbered names, and the detection loop that builds its list at runtime. All three
      populating **both** menus is what allows the numbered fallback in `fnc_faction_rqst_list` to
      be deleted; nothing static can confirm it, because these globals only exist at runtime
- [ ] **Check the five factions whose vehicle lists were truncated.** `SFP_DES`, `SFP_WDL`,
      `TIOW_CADIAN_776`, `CFP_O_HEZBOLLAH` and `TFC_TEMP` each hid everything past a gap in their
      numbering — `SFP_DES` offered 14 of 36. All 70 recovered entries must spawn the vehicle their
      label names. `CFP_O_HEZBOLLAH` lists one classname under three different labels and prices and
      `TIOW_CADIAN_776` lists two vehicles twice; both pre-date the recovery and were already
      visible, so they are faction-data errors to correct rather than regressions
- [ ] **Buy a support, then try to buy it again.** Covers the table-and-driver rewrite. Every
      support unlocks once, refuses a second purchase, respects the eight-slot radio cap, and
      colours **its own** listbox row — HALO previously coloured the laser strike's
- [ ] **Build a FOB, let OPFOR approach it, then remove it.** Covers the trigger conversion: the
      enemy warning still fires, and removal deletes the trigger rather than orphaning it
- [ ] **Capture a zone, leave, and let OPFOR return to it.** Covers the spawn-band table and the new
      contact warning. Garrison sizes per radius band should be unchanged; a zone you hold now
      reports enemy contact, and one you do not must stay silent
- [ ] **Rebuild the base from the HQ redeploy action.** Covers the extraction of `fnc_placeHQUnits`,
      which now runs for both the first build and the rebuild. Tower, door, tent and guard-box
      sentries stand where a fresh campaign puts them, the patrol walks its towers, 2 CP is charged
      once, and the replacement MG and AA gun survive a cleanup sweep — the rebuild never registered
      them with the composition stream, so they were not persistent and could be deleted
- [ ] **Open the strategic map twice, then force a mission from the debug menu.** Covers the one
      definition table replacing four hand-synced ones. Seven of seventeen types are offered each
      opening, each row launches the mission it names rather than a neighbour's, the cooldown-ready
      notification names the right type, and every debug row forces the type its label claims
- [ ] **Enter and leave a RAVAGE town and a WBK town.** Covers the shared spawn gate. Both fill,
      both clean up after their grace period, and a duplicate entry does not double-spawn. A WBK
      town still holds the mutex until it empties, which is the open defect above, not a regression.
      Then start a **plain** civilian campaign: it shares nothing with either and must be unchanged
- [ ] **Board the killhouse and run it.** Covers moving 821 lines of composition into a data file
      `#include`d by the builder. The range and its targets build at altitude as before. Re-import
      one of the two compositions through `duws_eden.ps1` on Windows if convenient: the tool
      resolves `zbase=` against the file holding the fence, which is why `_centerSpawnZ` moved too
- [ ] **Watch the weather change once.** Covers two retired broadcast globals. The sky and fog still
      move on their cycle; on a dedicated server a client must see the same sky as the host

Parts of these need a dedicated server rather than a hosted session: one search per corpse *for the
whole team* cannot be observed with one machine, neither can the once-by-anyone claim behind it, and
weather reaching a machine that is not the one setting it is the same kind of claim
([`docs/info/testing.md`](docs/info/testing.md#testing-join-in-progress)).

## Composition streaming: the prop-position fix is unverified

Every field a stowed composition's record carries has now been exercised, and only the positions
came back wrong. `fnc_duws_deploy` disabled simulation *after* placing each prop rather than before
— and the loop is scheduled code, so a prop that stayed simulated over a frame boundary settled off
the position just written to it — and it never re-applied the position after rotating. The prefabs
that place these props do both, which is why the drift appeared only across a stow/deploy cycle.

- [ ] Stow a zone, deploy it, compare against a screenshot taken before. Props still off by a little
      means the residue is `createVehicle`'s own placement rather than those two ordering faults

## Per-town reputation: shipped, not yet exercised

- [ ] Destroy a house as a **client** on a dedicated server and watch the escalation counter. No movement means `BuildingChanged` is local-only and escalation has never worked in dedicated MP — neither did the war-crimes script it replaced. Record it rather than working around it
- [ ] Clear a garrison in a populated town. If the `WEST SEIZED` trigger never fires, CIVILIAN-side units are blocking it and the fallback is a condition trigger counting hostile units in `thisList`
- [ ] Check the census line in the RPT on a new map, and confirm a single fire mission cannot advance an escalation level. Both numbers are logged on the first run
- [ ] Start a RAVAGE or WBK campaign. Towns should carry a `Pop:`-only marker and a permanently neutral ellipse, spawn no garrison, never scale prices, and log no census line

## Hardcore intel: shipped, not yet exercised

- [ ] Complete a rescue-pilot and a rescue-squad mission on a dedicated server and confirm each reveals a zone. These are the two sites that never paid out at all
- [ ] Die with a search attempt spent and respawn. The action must still be hidden, and must come back on the next economy tick and not before. Available again on respawn means `fnc_intel_search_restore` is not reaching the new body; never coming back means the UID entry is outliving the window it was stamped in
- [ ] Die a few times in one window, then walk back over your own bodies. No second search action may appear on any of them — the strip in `onPlayerKilled.sqf` is what keeps this one action per player rather than one per death

## Hardcore civilian towns: shipped, not yet exercised

Only one check is left, and it is a **RAVAGE or WBK** one. Those two modes are the only ones that
give a town a presence trigger; a plain civilian campaign reveals towns from a polling thread on the
server instead, which no client ever runs.

A trigger made by `createTrigger` is global by default, and a global trigger runs its activation
statement on *every* machine — server and each client — not only on the machine that made it. That
statement names `fnc_civ_town_reveal`. The function is broadcast, and it returns immediately on a
client (`if (!isServer) exitWith {false}`), so a client running it is meant to be a harmless no-op.
The doubt is timing: if a client's copy of the function has not arrived by the time that client's
trigger fires, the statement names something that does not exist yet and the engine throws. Nothing
breaks — the server reveals the town regardless — but the client's log fills up, and a broadcast
arriving later than the first trigger it feeds is worth knowing about for its own sake.

- [ ] In a RAVAGE or WBK campaign on a dedicated server, walk a **client** into a town and grep that
      client's `.rpt` for `Undefined variable in expression: fnc_civ_town_reveal`

## JIP queue: keyed, not yet exercised

The `remoteExec` JIP queue was keyed throughout; the five bare `true` flags left are the
compiled-code payloads in [Open defects](#open-defects). None of it has been exercised. A second
player joining a LAN host is a real JIP client and covers the first group below; testing alone, or
covering the dedicated-server path a host masks, needs the setup in
[`docs/info/testing.md`](docs/info/testing.md#testing-join-in-progress).

Every check is: build the state, then have a joiner arrive — a second player connecting, or
yourself rejoining a dedicated server. "Rejoin" below means either.

**Entries a joiner receives.** Each tests one keying form, so a failure names its own cause.

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

**Unverified engine behaviour.**

- [ ] Settle whether `remoteExec ["", _id]` removes a queue entry when issued from a client. Both removals in the tree hand the call to the server rather than rely on it
- [ ] Buy the Mobile HQ, then rejoin. It must still read as claimed. A joiner offered it a second time means `publicVariable` values are **not** delivered to joining clients, in which case the `isNil` defaults in `client/includes/supports_init.hpp` have nothing to preserve and the team can still be charged twice — the fix would then have to be a server-side record of what the team owns rather than a client-side default. Recycle and repair are the same test the other way round: both must still read as unlocked. This also settles the claim the gotchas entry rests on ([gotchas](docs/info/arma_engine_gotchas.md#a-joining-client-is-sent-every-publicvariabled-global-then-its-own-init-overwrites-them))

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

- [ ] Call SITREP in a hosted multiplayer session and confirm whether a resumable save appears
- [ ] If one does, reload it mid-campaign and confirm the campaign comes back playable. This is the
      half that stays untested even when the save itself works, and it is the only check the
      client/server split left outstanding

Until that runs, the SITREP notification is unsound in one direction or the other: it
broadcasts *"The game has been saved"* to every player unconditionally
(`server/supports/fnc_sitrep_support.sqf`). If MP saves do not work, that message is a lie to
everyone; if they do, it is correct as written. Do not gate it on `isMultiplayer` before
knowing which — the gate would suppress a true message in the case where saving works.

This matters beyond the save button: [`docs/campaign_persistence_plan.md`](docs/campaign_persistence_plan.md)
opens by asserting the current save cannot work, and that assertion rests on the same
unverified premise.

## Does a dedicated server read its profile namespace back?

Unverified here, and [`docs/campaign_persistence_plan.md`](docs/campaign_persistence_plan.md)
rests on the answer being yes. If it is no, the store changes and much of that plan changes with
it, so this runs before any of it is built.

The concern is specific rather than general: dedicated servers have historically written
profile-namespace variables to their `.vars.Arma3Profile` file correctly and then failed to load
them back at the next mission start. That is reported fixed upstream, which is not the same as
observed working on the box this mission runs on.

**It has to be a dedicated server.** A hosted session and a singleplayer game use the player's own
profile and were never subject to the failure, so passing there proves the call shape and the file
name and nothing about the thing at risk. Run it hosted first if you like — it is thirty seconds
and rules out a typo — but it does not substitute.

**Restart the server process, not the mission.** `#restart` and a mission change both leave the
server process alive, and the namespace is still in memory across either, so the probe reads back
from RAM and passes whether or not the file is ever loaded. Only a full process stop and start
exercises the load path.

Setup, including the `#login` the debug console needs on a dedicated server, is in
[`docs/info/dedicated_server_setup.md`](docs/info/dedicated_server_setup.md).

- [ ] With the debug console targeting **Server**, run
      `missionProfileNamespace setVariable ["DUWST_probe", [1,"alive",true]]; saveMissionProfileNamespace;`
- [ ] Confirm a `.vars.Arma3Profile` appears under the server's `-profiles` directory
- [ ] Stop the server process fully, start it again, rejoin
- [ ] With the console targeting **Server**, run
      `missionProfileNamespace getVariable ["DUWST_probe", "MISSING"]`

`[1,"alive",true]` means the plan's store works as designed. `"MISSING"` means it does not, and the
question becomes whether `profileNamespace` behaves any differently — it is the same subsystem, so
expect not — with the clipboard export left as the only route, which would make persistence on a
dedicated server a manual act rather than an automatic one.

## Open defects

| Defect | Where | Effect |
|---|---|---|
| `localize "STR_DUWS_T_jjztkt04"` names a key that has never existed in `stringtable.xml` | `client/supports/fnc_siva_drop.sqf:88` | The player sees the raw key name on screen instead of a message |
| `random_placement` is set on the client and never `publicVariable`'d | `client/dialog/fnc_HQ_random_place.sqf`, `fnc_HQ_faction_dialog.sqf`, `fnc_startup_faction_flow.sqf` | Harmless today — its only reader is client-side on the same machine — but it fails silently the moment anything server-side reads it |
| Two script paths in `paths_baseline.txt` point at files that do not exist | `client/misc/fnc_player_markers.sqf`, `server/misc/fnc_repetitive_cleanup.sqf` | Pre-dates the test suite; baselined so the linter gates regressions without being blocked by it |
| Six `format[...]` calls wrap a single literal with no placeholders | `client/supports/fnc_helolift.sqf` | Cosmetic — a wasted call per invocation |
| `fnc_log` calls itself instead of writing the line | `shared/functions/fnc_log_init.sqf:25` | Unbounded recursion on every line at or below the active level: nothing reaches the RPT and the first logged milestone kills the boot. The `diag_log` -> `fnc_log` sweep has to skip this one file — it is where `diag_log` lives |
| Two functions named by zone triggers are never broadcast | `fnc_captured`, `fnc_enterlocation`, registered in `server/server_fnc_init.sqf` without `publicVariable` | A `createTrigger` statement is global, which is why the civilian town trigger's `fnc_civ_handler_ravage` / `fnc_civ_handler_wbk` *are* broadcast. One of the two treatments is wrong: if the zone side is, every client spawns a nil on each zone entry and capture. The campaign is unaffected — the server runs its own copy — but a client RPT fills with undefined-variable errors |
| `duws_all_helmets` and `duws_all_vests` are read but assigned nowhere in the mission | `server/misc/fnc_civ_handler_ravage.sqf:260,270` | RAVAGE only, and only on the zombies that draw no uniform — roughly 30%, since the uniform roll is `_isZombie && random 1 < 0.7`. Those two branches are the fallback for a unit with no uniform side to match, so they are the only readers, and `count` on an undefined variable throws where the assigned lists would have been used. Both were carried over untouched when RAVAGE was split out of `fnc_civ_handler` |
| Five `remoteExec ["call", 0, true]` sites ship a whole `addAction` body as compiled code | `destroy_cache:123,158`, `rescue_pilot:336,407`, `steal_supply:87` | Queued under an engine-generated id nothing can address or remove, and the largest entries a joiner receives. Cannot be keyed until each body becomes a named function taking arguments |
| `removeAction` takes index `0` rather than a captured `addAction` return | `server/missions/mission_threads/sabotage_laptop/fnc_sabotage_laptop_success.sqf:18` | Works today because insertion order puts the sabotage add before the hardcore intel rotary, but the laptop carries two actions, which is exactly when index-`0` removal stops being safe |
| An unbounded `waitUntil` sits on the joiner's branch of the client boot | `client/client_init.sqf:140` | Blocks on `HQ_pos_found_generated && chosen_settings` with no timeout, reached only when `WARCOM_init_done` is false. It hints the player every five seconds, so the stall is visible; proceeding on a timeout would boot a client into a campaign whose settings never arrived. What it lacks is a log line |
| `staminaEnabled` is read but never assigned anywhere in the mission | `server/warcom/fnc_init_OPFOR_WARCOM.sqf:67` | The whole `format` throws on `Undefined variable in expression: staminaenabled`, so the campaign settings summary hint never displays for any player. Confirmed in an RPT at the moment generation completes. `client/misc/fnc_sitrep_display.sqf:33` reads the same variable behind an `isNil` guard, which is why only this site fails — either assign it at setup or drop it from the hint |
| Buying the Mobile HQ and never designating one locks the team out of it permanently | `client/dialog/fnc_request_support.sqf:477`, `shared/functions/fnc_MHQ_destroyed.sqf:23` | The purchase clears `support_mobile_HQ_available` for everyone and hands the buyer a one-shot comm-menu token; the only path that sets the flag back waits on an MHQ that exists being destroyed. If the token is lost before it is spent — the buyer disconnecting being the certain case — no second purchase is possible and no MHQ exists to die, so the campaign has no Mobile HQ and 10 CP bought nothing. The three guards in `fnc_MHQ_select.sqf` hand the token back rather than consume it, so a bad target or an MHQ already being active cost nothing; losing the player is the case none of them can cover. Whether respawn also drops the token is unverified |
| WBK holds the campaign-wide town mutex for a town's whole occupancy | `server/misc/fnc_civ_handler_wbk.sqf` | The lock is taken in `fnc_civ_mode_spawnGate` and released only on the cleanup path, so a second WBK town cannot fill until the first empties or the gate's ten-minute timeout expires — a co-op pair splitting between two towns leaves one of them dead. RAVAGE releases immediately after its spawn burst and carries a comment recording that exact symptom as the reason. The two handlers were written separately and only the RAVAGE side was ever changed, so this is the same defect surviving in the copy nobody revisited. Left alone because making WBK match is a behaviour change, not a refactor, and WBK's one-shot fill may depend on the serialisation in ways only a play-test shows |

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
- **Zone selection can pick a centre that surprises BLUFOR.** Two WARCOM spawners
  (`fnc_WARCOM_opf_patrol.sqf`, `fnc_random_veh_opf_patrol.sqf`) each place their units
  deliberately far from the zone centre to compensate. The underlying selection is untouched.
