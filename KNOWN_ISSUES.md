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
Currently testing:
- Grind a garrison to a fifth and let it break: `bounding back from`, then `broke contact` with a card naming the zone rather than a grid, and `opfor_withdrawal` AP
- Read a zone's tier at generation and again at deploy: `is tier N, fielding` then `deployed N men at tier`; a rebuild keeps the tier it had
- Lose a captured zone back to OPFOR: strength floored to 0.3 rather than refreshed, and the readout says Mobilising until the first man stands
- Stand on a zone and step off mid-count: a flat 30 s every time, restarting on the step off
- Clear a town below -10: `cleared at tier N; rep R + 5, garrison broken to 0.3 and regrouping`, and both purchase sinks refused for the 3 h
- Visit several towns on a 40-zone campaign: every town garrisons, not only the first — one poller replaced a thread apiece
- Click zones and towns on the map: a roman tier on both, and on a zone the composition kind beside the callsign over a twenty-segment strength bar, refreshed on opening the map
- Click through the request menu: nothing clipped, only Squad Manager / FOB Manager / Special Operatives close it, costed entries orange
- Start a campaign in each game mode: zombie factions filtered out of the other picks, and Zombies with neither Ravage nor WBK falling back to DUWS
- Run side missions: each briefing opens with its category, English only
- Call JDAM or artillery onto structures: the inner ring stays destroyed rather than being healed back by the outer pass
- Carry a downed pilot and let the auto-drop fire: no stale load action left for the next carry
- Grep the boot for `[DUWS][ERROR]` and `compiled EMPTY`: the dead-code sweep, the fortification ring, the night flare and the multimeter probe all came out
- Ignore the standby task forces for a few hours: at most one stands by
- Watch for `stow <key>: refused`: something unmodelled crewed a static
- Play three hours or more and watch frame time: the waypoint, litter, aim-skill, Zeus and resupply fixes have no other symptom
- Try a disguise: the gear scan runs the whole session again, so the tables keep filling

_END-USER_

## No zone has been seen to fall since the capture rule changed

`fnc_zone_capture_ready` replaced `WEST SEIZED` on the BLUFOR direction, and no session logged since
carries a `captured by BLUFOR` line. The last one that does pre-dates the rule, so the whole
condition — the roster count against the peak, and the centre being clear — is unexercised rather
than merely untuned. Everything downstream of a capture is unexercised with it.

- [ ] Take a zone and watch for `captured by BLUFOR` in the RPT. A zone that will not fall with
      nothing alive within 50 m of the composition and its garrison beaten means something standing
      on the objective is not on the roster, which is the failure the centre test is prone to and
      cannot report on its own — nothing in that condition logs why it refused

## OPFOR retreat: a difficulty lever nobody has played against

A garrison beaten to a fifth withdraws under `fnc_opfor_retreat` rather than being fought to the
last man, and so does whatever survives inside the streaming ring when a zone flips. It cuts both
ways: the player loses the clean sweep of a wiped garrison, and gains ground they no longer have to
clear unit by unit. Whether that wants a campaign toggle is not answerable until a zone has actually
fallen this way ([§No zone has been seen to fall](#no-zone-has-been-seen-to-fall-since-the-capture-rule-changed)),
since the withdrawal is what clears the objective and the two are felt together.

## Per-town reputation: shipped, not yet exercised

- [ ] Take a town below -10. The RPT logs `Town N taken at rep R; first garrison held for 1800 s`
      at once, and no garrison appears for thirty minutes of wall-clock — the capture grace, so a
      tier does not materialise around the player who just spent the reputation. Nothing appearing
      inside that window is the mechanic, not a failure; leave and come back after it
- [ ] Once the grace has run, stand in the town. A garrison must appear and the town must keep its
      debt until that garrison is fought. Reputation returning to 0 on its own means something other
      than the clear trigger's arming order is discharging it; the RPT says which happened, since
      an armed garrison logs `Garrison tier N spawned` and a spawn that put nothing inside the
      trigger area logs `placed no OPFOR`
- [ ] Raise a garrisoned town's tier from the debug menu while standing in it. Nothing must spawn
      while you are there; walk out past the town radius plus 400 m, come back, and the difference
      must be standing — `garrison reinforced to tier N` in the RPT, with the baseline risen rather
      than reset, so casualties already taken are still counted against it
- [ ] Clear that garrison. If the `WEST SEIZED` trigger never fires, CIVILIAN-side units are blocking it and the fallback is a condition trigger counting hostile units in `thisList`
- [ ] Read the `Escalation census:` line in the RPT on a new map and check `tier` against 30.
      Thirty buildings a level across eleven levels is the shipped figure, but it is reached as a
      fraction of a whole-map house count rather than as a constant, so it lands on 30 for Altis's
      17472 houses and proportionally lower on any smaller map. That line is the only place the
      total, the budget and `tier` ever appear

## The search system: shipped whole, barely exercised

Five separate faucets became one two-roll path, and the rewrite deleted seven functions, so a
failure here is more likely to be something missing than something wrong.

- [ ] Clear a garrison and search bodies. Half of them carry the action, the static crews among
      them; a garrison offering none at all is the flag not reaching them rather than a cold run
- [ ] Play far enough to exhaust the intel pool, then search a flagged body. It must speak an
      outcome. Silence means the payout re-draw is not dropping the dry kind
- [ ] On a dedicated server with two clients, have one player search a body and send the other over
      the same one. No prompt for the second, one payout in total. The same test on an objective and
      on a civilian, which are the two that paid once *per player* before
      ([`docs/info/testing.md`](docs/info/testing.md#testing-join-in-progress))
- [ ] Die a few times and walk back over your own bodies. No search action on any of them — the
      strip in `onPlayerKilled.sqf` is what keeps this one action per player
- [ ] Complete a rescue-pilot and a rescue-squad mission on a dedicated server and confirm each
      reveals a zone. These two pay on completion rather than through a search, so the rewrite did
      not touch them; they are the two sites that never paid out at all

**The numbers are only half played.** The 50 % flag rate on a garrison was set from play; 15 % on a
mission group and every payout weight are still the shape's placeholder values. They are one table
in `server/server_var_init.sqf`, with what a document is worth in
`server/misc/fnc_intelAnalysis.sqf`, and are meant to be moved once the arc has been felt end to
end.

## RAVAGE and WBK: parked until base DUWS is whole

Nothing here runs until base DUWS is complete: these are unticked by decision rather than by
oversight. They are collected in one place because a campaign in each mode clears the lot, and
because no plain campaign can stand in — only these two route a town's fill through
`fnc_civ_mode_spawnGate`, and only they give a town a presence trigger.

- [ ] Enter and leave a RAVAGE town and a WBK town. Both fill, both clean up after their grace
      period, and a duplicate entry does not double-spawn. A WBK town holding the mutex until it
      empties is the defect in [Open defects](#open-defects), not a failure of this check
- [ ] Start a campaign in either mode. Towns should carry a `Pop:`-only marker and a permanently
      neutral ellipse, spawn no garrison, never scale prices, and log no census line
- [ ] Spawn a recruitable, then rejoin. Exactly one recruit action on it, not several — the JIP
      queue's per-object keying, which only these two modes produce a subject for

The remaining check is a client-log one, and the reason it exists needs the trigger's locality. A
plain civilian campaign reveals towns from a polling thread on the server, which no client ever
runs; these two use a trigger instead. A trigger made by `createTrigger` is global by default, and
a global trigger runs its activation statement on *every* machine — server and each client — not
only on the machine that made it. That statement names `fnc_civ_town_reveal`. The function is
broadcast, and it returns immediately on a client (`if (!isServer) exitWith {false}`), so a client
running it is meant to be a harmless no-op. The doubt is timing: if a client's copy of the function
has not arrived by the time that client's trigger fires, the statement names something that does
not exist yet and the engine throws. Nothing breaks — the server reveals the town regardless — but
the client's log fills up, and a broadcast arriving later than the first trigger it feeds is worth
knowing about for its own sake.

- [ ] On a dedicated server, walk a **client** into a town and grep that client's `.rpt` for
      `Undefined variable in expression: fnc_civ_town_reveal`

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

**Platform is part of the question.** Antistasi ships both namespaces and defaults
`missionProfileNamespace` off on Linux servers because of an Arma bug it names on the control, so
a pass on Windows says nothing about a Linux box and vice versa. Record which the probe ran on.

**It has to be a dedicated server.** A hosted session and a singleplayer game use the player's own
profile and were never subject to the failure, so passing there proves the call shape and the file
name and nothing about the thing at risk. Run it hosted first if you like — it is thirty seconds
and rules out a typo — but it does not substitute.

**Restart the server process, not the mission.** `#restart` and a mission change both leave the
server process alive, and the namespace is still in memory across either, so the probe reads back
from RAM and passes whether or not the file is ever loaded. Only a full process stop and start
exercises the load path.

Setup, including the `#login` the debug console needs on a dedicated server, is in
[`docs/info/testing.md`](docs/info/testing.md#running-a-dedicated-server).

- [ ] With the debug console targeting **Server**, run
      `missionProfileNamespace setVariable ["DUWST_probe", [1,"alive",true]]; saveMissionProfileNamespace;`
- [ ] Confirm a `.vars.Arma3Profile` appears under the server's `-profiles` directory
- [ ] Stop the server process fully, start it again, rejoin
- [ ] With the console targeting **Server**, run
      `missionProfileNamespace getVariable ["DUWST_probe", "MISSING"]`

`[1,"alive",true]` means the plan's store works as designed. `"MISSING"` means it does not, and the
next step is the same probe against `profileNamespace` — which is what Antistasi falls back to on
the platform where this fails, so it is worth running rather than assuming the same subsystem
behaves the same way. Only if both fail is the clipboard export the sole route, which would make
persistence on a dedicated server a manual act rather than an automatic one.

## Can a dedicated server boot a campaign with nobody connected?

`-autoInit` starts the mission at server boot with no player, and the unattended restart in
[`docs/campaign_persistence_plan.md`](docs/campaign_persistence_plan.md#nobody-at-the-screen)
assumes that path already works. Two boot steps run against an empty server and neither has been
watched doing it. Both are minutes to check, and either one alone makes an unattended restart
useless.

**The slot sweep runs with every slot unoccupied.** `server/server_init.sqf:130-138` deletes
`player2` through `player36` wherever `isPlayer` is false. Hosted, it fires after everyone has
picked a slot, so it only ever removes genuinely spare ones; under `-autoInit` it fires against
every playable slot in the mission, including the ones players are about to join into.
`disabledAI = 1` (`src/description.ext`) may have already left it nothing to delete — that is the
outcome to confirm rather than assume, because if the slots do go, the server comes back up after
every restart with nobody able to join it.

- [ ] Start a server with `-autoInit` and nobody connected, then join. Every slot the mission
      ships is still selectable. A short lobby means the sweep is deleting units the engine still
      needs, and it has to be skipped when no player is connected

**Setup is owned by one slot.** `client/client_init.sqf:82` opens the faction, HQ and environment
screens only for a player whose variable name is in `game_master`, which is `["player1"]`
(`server/server_var_init.sqf`). Nobody else publishes `chosen_hq_placement` or
`createzone_server`, and the server's gates on those (`server/server_init.sqf:46,52`) are retry
loops with no fallback — so a session where that one slot stays empty waits on a screen no
connected player will ever be shown.

- [ ] Join a dedicated server as the only player, taking any slot but `player1`. A campaign that
      never generates means a full server can be held up today by one empty slot, and that the fork
      screen's timeout has to key on no *game master* connected rather than on no player connected

## A hosted session froze hard, and nothing in the log says why

A LAN host stopped responding for the rest of the session and wrote two `FROZEN` minidumps beside
its `.rpt`. It is a stalled main thread rather than a slow one: `No alive in N ms` climbs from 10 s
to 92 s and the log ends there. What makes it hard to place is that **no scripting error is logged
at the freeze at all** — the last line before it is `Setting invalid pitch`, and the nearest error
is forty seconds earlier, in the request-menu fill, which the engine caught and carried on from.

The play-test note names two candidates and cannot separate them: escaping out of the side-mission
map, and clicking one of the command buttons that came up blank. The second is not reachable — a
command slot with nothing written into it exits on its own bounds check — so a repeat answers
whether the side-mission map was ever involved.

That is the path with a mechanism to look at, because `fnc_stratmap.sqf` holds the game under
`startLoadingScreen` while a spawned search runs, and only its own 60 s failsafe takes the screen
down again. That accounts for a stall, but not for one lasting 92 s.

- [ ] Open Side Missions, let the map come up, and press Escape out of it. A repeat means the
      strategic map owns it; no repeat over several attempts means it belonged to the half-built
      request menu and went with it
- [ ] If it repeats, log either side of `startLoadingScreen` and `endLoadingScreen` in
      `client/missions/fnc_stratmap.sqf`. A freeze that spans the `endLoadingScreen` line is not
      the loading screen, and the search below it is not the suspect either

## Open defects

| Defect | Where | Effect |
|---|---|---|
| `localize "STR_DUWS_T_jjztkt04"` names a key that has never existed in `stringtable.xml` | `client/supports/fnc_siva_drop.sqf:88` | The player sees the raw key name on screen instead of a message |
| Manual HQ placement hides terrain objects from a client, and never re-hides them | `client/dialog/fnc_HQ_manual_place.sqf:40` | The same clearing pass zones run, on the machine that clicked the map. Two faults follow from the locality: `hideObjectGlobal` is a server command, so what a client hides may only be hidden there; and the objects are not in the `DUWS_zone_hidden` register, so the `BuildingChanged` handler in `fnc_createzone.sqf` cannot re-hide the replacements the engine swaps in when a blast changes their damage state. A base built on a manually placed HQ therefore grows its cleared buildings back through itself. Fixing it means the clearing moving to the server, which is a locality change to the setup flow rather than a line |
| `random_placement` is set on the client and never `publicVariable`'d | `client/dialog/fnc_HQ_random_place.sqf`, `fnc_HQ_faction_dialog.sqf`, `fnc_startup_faction_flow.sqf` | Harmless today — its only reader is client-side on the same machine — but it fails silently the moment anything server-side reads it |
| Two script paths in `paths_baseline.txt` point at files that do not exist | `client/misc/fnc_player_markers.sqf`, `server/misc/fnc_repetitive_cleanup.sqf` | Pre-dates the test suite; baselined so the linter gates regressions without being blocked by it |
| Six `format[...]` calls wrap a single literal with no placeholders | `client/supports/fnc_helolift.sqf` | Cosmetic — a wasted call per invocation |
| Two functions named by zone triggers are never broadcast | `fnc_captured`, `fnc_enterlocation`, registered in `server/server_fnc_init.sqf` without `publicVariable` | A `createTrigger` statement is global, which is why the civilian town trigger's `fnc_civ_handler_ravage` / `fnc_civ_handler_wbk` *are* broadcast. One of the two treatments is wrong: if the zone side is, every client spawns a nil on each zone entry and capture. The campaign is unaffected — the server runs its own copy — but a client RPT fills with undefined-variable errors |
| `duws_all_helmets` and `duws_all_vests` are read but assigned nowhere in the mission | `server/misc/fnc_civ_handler_ravage.sqf:260,270` | RAVAGE only, and only on the zombies that draw no uniform — roughly 30%, since the uniform roll is `_isZombie && random 1 < 0.7`. Those two branches are the fallback for a unit with no uniform side to match, so they are the only readers, and `count` on an undefined variable throws where the assigned lists would have been used. Both were carried over untouched when RAVAGE was split out of `fnc_civ_handler` |
| Five `remoteExec ["call", 0, true]` sites ship a whole `addAction` body as compiled code | `destroy_cache:123,158`, `rescue_pilot:336,407`, `steal_supply:87` | Queued under an engine-generated id nothing can address or remove, and the largest entries a joiner receives. Cannot be keyed until each body becomes a named function taking arguments |
| `removeAction` takes index `0` rather than a captured `addAction` return | `server/missions/mission_threads/sabotage_laptop/fnc_sabotage_laptop_success.sqf:18` | Safe only while the laptop carries exactly one action. It carried two until the search rewrite gave the objective search back to the player's own action, so the collision this describes is currently not reachable — and returns the moment anything adds a second action to that laptop |
| An unbounded `waitUntil` sits on the joiner's branch of the client boot | `client/client_init.sqf:140` | Blocks on `HQ_pos_found_generated && chosen_settings` with no timeout, reached only when `WARCOM_init_done` is false. It hints the player every five seconds, so the stall is visible; proceeding on a timeout would boot a client into a campaign whose settings never arrived. What it lacks is a log line |
| `staminaEnabled` is read but never assigned anywhere in the mission | `server/warcom/fnc_init_OPFOR_WARCOM.sqf:67` | The whole `format` throws on `Undefined variable in expression: staminaenabled`, so the campaign settings summary hint never displays for any player. Confirmed in an RPT at the moment generation completes. `client/misc/fnc_sitrep_display.sqf:33` reads the same variable behind an `isNil` guard, which is why only this site fails — either assign it at setup or drop it from the hint |
| One classname is sold under three labels and prices | `shared/factions/MODERN/CFP_O_HEZBOLLAH_blufor.sqf:120,122,126` | "BTR-60P APC" at 25 CP, "MTLB-LV APC" at 28 and "BTR 60PB" at 35 all deliver `CFP_O_HEZBOLLAH_BTR_60PB_01`, so two of the three charge for a vehicle they do not hand over. Three rows were meant to be three vehicles and one classname was copied across all of them; the two missing classnames can only come from the mod, so this needs someone with CFP installed rather than a source edit |
| WBK holds the campaign-wide town mutex for a town's whole occupancy | `server/misc/fnc_civ_handler_wbk.sqf` | The lock is taken in `fnc_civ_mode_spawnGate` and released only on the cleanup path, so a second WBK town cannot fill until the first empties or the gate's ten-minute timeout expires — a co-op pair splitting between two towns leaves one of them dead. RAVAGE releases immediately after its spawn burst and carries a comment recording that exact symptom as the reason. The two handlers were written separately and only the RAVAGE side was ever changed, so this is the same defect surviving in the copy nobody revisited. Left alone because making WBK match is a behaviour change, not a refactor, and WBK's one-shot fill may depend on the serialisation in ways only a play-test shows |
| A unit marker is never removed, and its update loop throws every four seconds | `client/misc/fnc_kndr_unit_markers.sqf:81` | The loop *index* is passed where `kndr_removeMarker` (`:183-195`) expects the object, so `kndr_objs find <number>` returns -1 and `kndr_mrks select -1` raises `Index out of range`. The entry is never removed and the local marker never deleted, so the 4 s update loop (`:203-208`) retries that same dead entry for the rest of the mission and throws once per pass. The leaked marker costs nothing; the permanent error rate does, since every throw writes to the RPT. It starts the moment a marked object dies — MHQ1 (`server/dialog/fnc_MHQ_deploy.sqf:63`) or the mission builder BLD1 (`missions/mission_threads/steal_builder/fnc_steal_builder_mission.sqf:239`). The `remoteExec` callers pass the object and are correct; only the internal update path is wrong |
| A marker is assigned with no preceding remove | `shared/functions/fnc_MHQ_addActions.sqf:11` | Re-running it stacks a second marker on the same object |
| Hardcore does not hide zone positions from Zeus | `server/misc/fnc_zeus_objects_init.sqf` | Under the BLUFOR curator option (`ZeusStatus == 1`) it adds every WEST and CIVILIAN unit and vehicle to the curator on a 30 s loop. Arma counts static weapons as vehicles, so a curator can read a hidden zone's defences straight off the map. A branch there once narrowed the civilian half to aircraft for exactly this reason, but it tested `DUWS_MODE == "HARDCORE"` — a value nothing ever assigned — so it never ran once and has been removed rather than left as dead code. Restoring the intent means gating on `hardcore_mode_enable` instead, and applying the same guard to the civilian *unit* loop above it, which never had one |

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

## The enemy gear scan runs for the whole session

`server/misc/fnc_scanEnemyGear.sqf` holds an `EntityCreated` handler for the life of the mission,
reading kit off new EAST units into the eight tables `fnc_disguiseAsEnemy` validates a disguise
against. Two costs come with it, each small per occurrence and neither bounded.

The handler filters to `CAManBase` and then spawns a scheduled script per man, which sleeps 0.5 s
before testing the side — so every civilian a town fill creates and every BLUFOR soldier recruited
gets its own script whose whole job is to wake up and discover it is not an enemy. The civilian
streaming system creates and deletes crowds continuously, so this fires for as long as the campaign
runs. `DUWS_enemyGear_scannedUnits`, the `netId`-keyed hashmap that stops a unit being read twice,
is never pruned either: it holds an entry for every EAST unit ever spawned, including long-dead ones
whose netIds will not be seen again. Entries are small, so the symptom would be a slow server memory
climb with no obvious owner.

**A convergence ceiling is not the fix.** Retiring the handler after N consecutive units add nothing
was tried and reverted, for two independent reasons. Convergence is per unit *role* rather than per
faction — pilot and vehicle crew are a separate class set the spawners only reach at higher tiers,
which is why `AUTODETECT_opfor.sqf` carries `fnc_filterPilotCrew` at all — so a stretch of infantry
fighting satisfies any counter before the campaign has shown its armour, and the tables then never
learn a crew uniform. And the removal has to name the handler by an id indexing an event that two
faction-detection handlers also hook
([gotchas](docs/info/arma_engine_gotchas.md#a-mission-event-handler-id-is-a-per-event-index-not-a-unique-handle)),
where a wrong id disables part of faction detection silently.

Hooking the OPFOR spawners directly, instead of a mission-wide handler, is the direction that
removes the per-man script without either problem.

## Zone and civilian siting defects

Six defects in the enemy zone-siting subsystem. How the siting stages fit together is in
[`docs/info/zones_and_civilians.md`](docs/info/zones_and_civilians.md#enemy-zone-siting-more-urban).

**Origin keep-out drops the zone instead of retrying it.** `fnc_locatorzones_random.sqf:172-177`. When a
candidate lands within 500 m of `[0,0,0]`, the guard runs `exitWith`. In SQF `exitWith` exits the nearest
enclosing **loop** (`if/then` is transparent to it), so it terminates `while {!_found}` with `_found`
still false and the `for` loop advances — the zone slot is silently lost, yielding **fewer than
`zones_number` zones**. The comment ("let the outer loop keep searching") describes what a plain
`if/then` would do. Fix: re-roll inside the loop instead of exiting it. Engine background:
[gotchas](docs/info/arma_engine_gotchas.md).

**The `moreUrban` branch can emit `[0,0,0]`.** `:92-126`. It sets `_Posfound = true` unconditionally with
no validity retry; its no-buildings fallback takes `getPos (nearestBuilding …)` (`:100-102`), which is
`[0,0,0]` when `nearestBuilding` returns `objNull`. That `[0,0,0]` is exactly what the origin guard then
eats, so the two defects compound. The branch needs the reject-and-retry the less-urban path already has.

**Prefab obstacle-clear hides real town buildings permanently.** `:61-87`. For prefab zones it
deletes/hides everything within 35 m of centre except men/pads/flags/HQ/FOBs. `deleteVehicle` cannot
remove terrain buildings, so the `hideObjectGlobal true` fallback is what actually clears them — a global,
unrestored change to the town just selected for being dense. The `_deletedCount`/`_hiddenCount` counters
double-count (both ops per object).

**Unbounded, no-yield retry with a heavy per-iteration cost.** `:62-155`. Rejected positions re-roll with
no `sleep`, and each `moreUrban` pass calls `nearestTerrainObjects` over 400 m plus a centroid pass; on a
cramped map or large `zones_spacing` this can busy-spin until the 90 s failsafe. Needs a yield and/or an
attempt cap.

**Centroid can land in dead space; road nudge not re-checked.** `:103-123`. Averaging two sub-clusters
inside 400 m yields a point between them (possibly an empty field), kept by the 0-10 m `findSafePos`; the
single 5 m `relPos` road nudge is never re-validated. Placement-quality only.

## Economy balance

Open observations from an economy review. Each is a design or correctness property, not a crash; none is
currently scheduled. The writers, faucets and sinks these read against are in
[`docs/info/economy.md`](docs/info/economy.md).

**Territory income snowballs with no upkeep.** Passive hold pays `zones_held × 6` every 30 min
(`fnc_zonesundercontrol.sqf:55`) on top of lump capture rewards, and holding a zone costs nothing
thereafter. That is a positive feedback loop — hold → CP → buy → hold more — with no attrition pulling the
other way, so late-game CP outruns anything to spend it on. This is the central design lever, not a bug:
if a demanding economy is the goal, the levers are per-zone/garrison upkeep, diminishing per-zone passive
scale, or a CP cap. Paying it in AP instead was considered and rejected — a holdings-scaled AP faucet
feeds the escalation ladder, and the enemy starts holding the map
([`docs/economy_plan.md`](docs/economy_plan.md)).

**Enemy-loot → intel-analysis is an unbounded, cooldown-free faucet.** `fnc_addRandomLoot.sqf` puts
`Files` (2 CP) / `Wallet_ID` (1.5 CP) on ~80% of spawned enemies, and terminal analysis
(`fnc_intelAnalysis.sqf`) converts them with no cap and no cooldown; HVT missions add `FileTopSecret` at
8 CP each. Because a zone re-garrisons every time it is left and re-approached, and patrols keep spawning,
this taps ≈1 CP per kill scaling with playtime rather than difficulty. A per-visit cap or a cooldown on the
terminal action bounds it.

**Recycle pays for vehicles the player never bought.** `fnc_activateBaseRecycleStation.sqf:88-101` deletes
every empty, non-excluded vehicle near the HQ pad and credits its computed value with no ownership check —
captured or found vehicles convert to free CP. It is *not* a buy-then-recycle loop: purchase cost
(`fn_factionAutoDetect.sqf:161`, clamped `[5,100]`) always exceeds recycle value
(`DUWS_fnc_calculateVehicleValue`, small and uncapped), so buying to recycle always loses. The two formulas
are simply not on the same scale, and recycle has no floor tying reward to what a vehicle cost.

**AP is a threshold ladder with almost nothing spending it, so town income is inflationary.** The WARCOM
director reads it as gates — BLUFOR wave tiers at 10, 40, 65, 100 and 136
(`fnc_WARCOM_blu_assault.sqf:11-25`) and mission-guard armour above 100 (`fnc_missionPatrols.sqf:20`)
— and the only subtractions are losing a zone and the AP→CP converter. The enemy half of that ladder
is a single rung now; the rest went with the WARCOM OPFOR spawners. Turning it into a currency both sides spend, without breaking the ladder, is
[`docs/economy_plan.md`](docs/economy_plan.md). A 20-town campaign averaging 2 AP pays at most 40 AP per
30 min with every town banded, against 25 for capturing a 500 m zone and 50 for a 1000 m one — worth is
`round(radius/10)` (`fnc_locatorzones_random.sqf:56`), halved by `zone_ap_swing`. So at its ceiling
civilian income substitutes for a capture rather than supplementing one; how far below that ceiling a real
campaign sits is the untested part. The ladder only goes up, so escalation is permanent once earned; the
1–3 scale sets how long it takes.

**The two routes into a reputation band are not symmetric, and the negative one is far shorter.** Both
bands sit ten points from neutral, but the travel costs are nothing alike. Going negative is incidental and
cheap: a civilian death at `-1`, charged three times in ten and only with a player inside 200 m, is about
thirty-three kills; a building at `-2` under the same proximity guard gets there in five, with no rate roll
at all; a failed IDAP at `-5` covers half the distance alone. Going positive is deliberate and slow:
healing is worth `+1` but caps at one credit per town per economy tick (`fnc_civ_healed.sqf`), so the
BLUFOR band is hours of visits away on healing alone, against IDAP success at `+5`.

That gap is the mechanic rather than an oversight. Ordinary fighting drags a town toward the enemy and no
amount of ordinary fighting drags it back, so the routes out of the OPFOR band are the ones built for it:
clearing the garrison, which discharges the debt at once, and the aid missions. The rate roll on deaths can
sit as low as 30 % precisely because reputation is localised — a bad engagement costs the campaign nothing
outside the town it happened in. Deliberate demolition carries no such excuse, which is why it is charged
every time.

**AP→CP merges the two economies.** `fnc_convertAPtoCP.sqf` trades 15 AP → 10 CP, repeatable with no
cooldown. It is one-way (there is no CP→AP path), so it cannot loop, but it means any AP income route —
mission rewards, held territory — ultimately feeds CP.

**The bribe figures are placeholders, and the coin supply they meet is unmeasured.** Intel at 3, recruit /
aid / toolkit at 2 were chosen to make the framework testable. The HQ crate hands out 20 coins once and
never refills, enemy infantry drop **0.267 coins each** (80 % carry loot, `floor random 3` items, one class
in three) — so a thirty-enemy zone assault yields about eight coins — and a civilian search averages
**1.1**, paid only after an arrest that costs the town a point of reputation. Whether that pays for a
campaign of talking to towns is the first thing to watch.

## Worked around, not fixed

Carried from the previous developer and left alone deliberately.

- **`Land_GuardTower_02_F` reports one building position with a wrong Z**, and `modelToWorld`'s
  Z is unusable on it too. `server/init_hq/fnc_BluHQinit.sqf:348` combines model-space XY with
  world-space Z to place the tower garrison. The comment there records the reasoning.
- **Zone selection can pick a centre that surprises BLUFOR.** The two WARCOM spawners that
  compensated by placing their units deliberately far from the zone centre are gone, so nothing
  works around it any more. The underlying selection is still untouched, and whatever replaces
  those spawners meets it unmediated.
