# Protect Informant (13): defend-and-build rework

Full gameplay rewrite of the Protect Informant side mission, replacing the escort-in-place shape
described in [`side_missions_working.md`](side_missions_working.md#protect-informant-13). This
supersedes that stale section: when this ships, fold the design back there and drop the placeholder.

The mission becomes a **defended siege**: the player reaches an informant hidden in a building, gets a
fixed prep window to fortify a position around him from a limited build budget, then holds off escalating
OPFOR waves long enough for the informant to survive. It is the mission's whole point that the player
*prepares* ground and then *holds* it — the two verbs no other side mission asks for.

## The flow

One thread drives four phases in order. Timings are the decided design; the tunables table collects the
numbers so a playtest pass can move them in one place.

1. **Offer / travel.** Sited by a map survey plus a building finder (below). Informant, crate and their
   3D icons stand at spawn; no enemies yet. The player is briefed and moves to the building.
2. **Arrival.** The prep clock starts when a player first comes within 30 m of the informant — not at
   spawn — so a long approach does not eat the build window. Before arrival the mission just waits (the
   deadline is the abandon backstop, below).
3. **Prep (10 min, skippable).** A countdown hint ("You have X minute(s).") runs; no waves spawn. The
   player builds defenses from the crate (R3F creation factory, 250-point budget). A **Skip Prep Phase**
   action on the informant — added 10 s after mission start — ends prep immediately and starts the waves.
4. **Defend (20 min).** OPFOR waves attack the informant under a concurrent-strength budget until the
   20-minute survival clock elapses. Win when it does with the informant alive.

**Win:** informant alive when the 20-minute defend clock elapses.
**Loss:** informant killed by fire, **or** no BLUFOR within 300 m of the informant for 20 continuous seconds
(a looping "will fail in Xs." hint, reset the moment any BLUFOR re-enters — the killhouse abandon-timer
pattern; on expiry the informant is killed, so both share the one `pc_killed` line). A never-engaged
deadline is the separate exception — the shared timeout notice, asserting no death.
**Backstop:** the hpp deadline fails an offer that is never engaged — but it **disarms the moment prep is
triggered** (arrival or skip), so once the player commits, the internal 10 + 20-minute clocks own the
outcome and the deadline can no longer fail the mission (starting prep with a minute left still succeeds).

## Data: `mission_types.hpp` row 13

Single-source the numbers here as every other mission does — the thread reads `DUWS_curReward` /
`DUWS_curDeadlineAt`, so the row moves the briefing and the payout together.

- **CP / AP / REP:** `20 / 10 / 5` → **`30 / 30 / 3`**. Prices the sustained siege up (30/30), and drops
  REP to 3 to match the +3 the win actually grants (was a display-only 5).
- **surveyKind:** `"town"` → **`"map"`**. The mission no longer belongs to a town; it wants any building
  on contested ground. The building finder does the gating.
- **deadline:** keep the existing `[3, 3]`. It is only the never-engaged backstop now; the real clocks are
  internal. (Open: the ask recalled a "2–3 h" band — `[2, 3]` — confirm before shipping; see tunables.)
- **category / objective:** unchanged (`"civilian"` / `"defend"`).

## Siting: `fnc_protect_civ_site` (new)

A building-finder that **snaps the offer onto the chosen building**, resolved by `fnc_mission_findSite`
from the thread name (`fnc_protect_civ_mission` → `fnc_protect_civ_site`). Runs **client-side** inside the
picker, so terrain queries only — no server globals.

Unlike
[`fnc_sabotage_laptop_site`](../../src/duws/server/missions/mission_threads/sabotage_laptop/fnc_sabotage_laptop_site.sqf),
which accepts a cluster and lets the objective sit on a fuzzy dot, this finder returns the **exact building
position** — the same snap Destroy Signal Tower / Destroy Hardpoint use to pin the offer on the real
emplacement, and the same "return the precise target, not the candidate" move
[`fnc_recon_observe_site`](../../src/duws/server/missions/mission_threads/recon/fnc_recon_observe_site.sqf)
makes. The finder contract keeps only `select 0` (the picker flattens the accept to a 2-D position), so
returning the building's own position is what makes `_MissionPos` land on the building rather than near it.

- From the map-survey candidate, take `nearestTerrainObjects [_pos, ["House","BUILDING"], ACCEPT_RADIUS,
  true]` and keep those with a real interior — the spec's "2+ doors, no small building" reads in engine
  terms as **≥ 4 building positions** (`count (_x buildingPositions -1) >= 4`). A lone shed (0–1 positions)
  is skipped.
- No qualifying building → return `[]` (reject); the offer is dropped rather than sited on open ground.
- Otherwise pick the nearest qualifying building and **return its position** (`getPosATL _building`), so
  the offer, the marker and the 300 m objective ring all centre on that building.

Because the offer is snapped, the thread re-derives the *same* building deterministically from `_MissionPos`
(nearest qualifying building at that exact point), the way recon re-derives its target — no fuzzy search
that could drift to a neighbour.

## Thread: `fnc_protect_civ.sqf` (rewrite)

Keep the file; replace the body. The current escort logic (OPFOR wave `spawn` block, the fixed 360 s
hold, the `civ_locIndex` REP) all goes.

### Building, informant, crate

- **Building:** `_MissionPos` is already snapped onto the building by the finder, so re-derive it directly —
  `nearestTerrainObjects [_MissionPos, ["House","BUILDING"], ~30, true]`, take the nearest with ≥ 4 building
  positions — rather than the fuzzy `fnc_mission_site` search (which drifts ±radius then 10–50 m off a
  building and could land on a neighbour). Informant and crate go on interior positions of that building.
  Abort (`fnc_mission_abort`, reason `no_building`) if somehow none resolves — the snap makes this rare.
- **Informant:** a civilian-costume unit in a **WEST** group (side follows the group, so OPFOR treats him
  as the enemy to kill), `setCaptive false`, `disableAI "PATH"`, seated on an interior building position.
  Borrow the costume from the live civilian pool rather than a hardcoded fisherman, so he reads as a local.
  Looping idle animation, broadcast (`playMoveNow` via `remoteExec 0`) as today.
- **Armed with a BLUFOR pistol — chamber via `addWeaponItem`, not `addMagazine`.** He is a random
  civ-costume body, and several vanilla civilian costumes carry **no uniform container**, so a bare
  `addMagazine` drops the round nowhere and the pistol chambers empty — the exact trap fixed for the manhunt
  informant ([`arma_engine_gotchas.md`](../info/architecture/arma_engine_gotchas.md#addmagazine-needs-a-container-arm-a-containerless-civilian-with-addweaponitem)).
  Load one round straight into the weapon (container-independent), spares into pockets where the costume has
  one:
  ```sqf
  _inf addWeapon "hgun_P07_F";
  _inf addWeaponItem ["hgun_P07_F", "16Rnd_9x21_Mag", true];  // chambers regardless of container
  _inf addMagazines ["16Rnd_9x21_Mag", 2];                    // spares only land if the costume has a container
  ```
  A last-ditch self-defense weapon (vanilla NATO pistol, mod-free; the BLUFOR faction handgun role if one is
  defined). A pocketless body fights with the chambered round alone. **Behaviour note:** for the
  pistol to actually be fired when the line is overrun, his `combatMode` must allow it — `CARELESS` / `BLUE`
  (hold fire) means he carries it but never shoots. Loosen to `AWARE` / `YELLOW` (return fire only) so he
  defends himself, while `disableAI "PATH"` still keeps him from repositioning out of the building. This also
  means dropping the forced looping idle animation while he is under attack — a re-issued `playMoveNow`
  snaps him back to the seated pose and cancels his aim, so the two cannot both run. Default: he sits idle
  during prep, and once the assault opens the idle loop stops and he goes `AWARE`/`YELLOW` to use the pistol.
- **Survivability: takes 50% damage.** Drop the old `setDamage 0.8` pre-damage entirely. He stands at
  full health, `allowDamage true`, with a `HandleDamage` handler that **halves incoming damage** (returns
  `_damage * 0.5`) — double effective health, so a stray round or single burst does not end a 30-minute
  mission; he goes down only under sustained fire (overrun). The 0.5 factor is the playtest tunable. Death
  is still the killed-loss the spec wants; the halving only stops a fluke deciding it. (`HandleDamage`
  fires per hitpoint — return the scaled value for each, and handle the multiple-EH-call quirk so the
  factor is applied once, not compounded.)
- **Crate:** a supply crate on an interior slot near the informant, marked with a floating 3D icon (the
  laptop marker system,
  [`fnc_sabotage_laptop_markers`](../../src/duws/client/misc/fnc_sabotage_laptop_markers.sqf) /
  [`fnc_draw_world_icons`](../../src/duws/client/misc/fnc_draw_world_icons.sqf)). The informant gets his
  own icon too.

### The build crate = R3F creation factory (250 points)

The "builder vehicle mechanic": the crate is registered as an R3F *usine de création*, exactly as
[`fnc_steal_builder_mission.sqf:51`](../../src/duws/server/missions/mission_threads/steal_builder/fnc_steal_builder_mission.sqf)
does for its prize — but with a **250-credit** budget instead of `-1` (unlimited):

```
[CRATE, 250, west, _whitelist] execVM "modules\R3F_LOG\USER_FUNCT\init_creation_factory.sqf";
```

- **Locality.** `init_creation_factory.sqf` is `if (!isDedicated)` and waits on `R3F_LOG_active`, so it
  must run on every client, not the server. Follow steal_builder's pattern: publish the crate to a global,
  then `[[[], _init_code], "BIS_fnc_spawn", true, true] spawn BIS_fnc_MP` with `_init_code` that
  `waitUntil {!isNil "<crateGlobal>"}` before registering. The 250-credit ledger lives on the crate as
  `R3F_LOG_CF_credits` (broadcast) and is decremented on the building client
  ([`creer_objet.sqf:79-82`](../../src/modules/R3F_LOG/usine_creation/creer_objet.sqf)).
- **Whitelist.** Restrict categories to defensive kit so the budget buys fortifications, not cars — pass
  an explicit array (e.g. `["Fortifications","Cargo","Structures_Fences","Structures_Walls","Static"]`)
  rather than `"LIGHT"`, which also exposes furniture/flags/signs. Categories are the CfgVehicleClasses
  tree, listed in
  [`config_creation_factory.sqf`](../../src/modules/R3F_LOG/config_creation_factory.sqf).
- **Budget sizing.** Cost is `factor * max(1, ceil(0.01 * cfg "cost"))`
  ([`determiner_cout_creation.sqf`](../../src/modules/R3F_LOG/usine_creation/determiner_cout_creation.sqf));
  the default factor is 1 and sandbags/HBarriers are cheap (~1–5 pts each), so 250 raw points buys a large
  perimeter. If that is too generous in playtest, raise the fortification cost via
  `R3F_LOG_CFG_CF_creation_cost_factor` rather than cutting the budget number the briefing shows.
- **Open the whole mission.** The factory stays live through the defend phase, not just prep — players may
  spend leftover budget under fire from the same 250 pool. No lock at assault start (no `R3F_LOG_CF_disabled`
  toggle); the pool cap alone bounds the total, and the teardown deregisters it at the end.

### Prep phase + skip

- On mission start, wait ~10 s, then add a **Skip Prep Phase** action to the informant (reach-gated, so it
  is usable only from beside him). Its body `remoteExec`s a server flag-setter that ends prep early.
- Gate the prep clock on **arrival**: `waitUntil` a player within 30 m of the informant (or the deadline
  backstop trips). On arrival, start the 10-minute countdown and drive a periodic hint to nearby players
  ("You have X minute(s).") — server-side, `remoteExec ["hint", …]` to players in range, the
  `killhouse_srv_hint` shape.
- Prep ends on **timer elapse or skip**, whichever first → begin the defend phase.

Any new client-called server function (skip setter, success reporter) must be `publicVariable`'d in
`server_fnc_init`, or it is undefined on non-host clients — see
[support fns server-defined + broadcast](side_missions_working.md) precedent.

### Wave controller (defend phase)

A bespoke loop — the garrison reserve model's *pool* accounting does not fit (this site has no designed
strength to drain), but its *placement and delivery* do. Reuse the far-side anti-flank point and the
truck-borne debus:

- **Combined budget.** Live attacker groups ≤ **`7 + BLUFOR player count`**, where that count is
  **derived once** — sampled a single time at defend start and held fixed for the rest of the mission, not
  re-polled. Count **all players on the BLUFOR side, not only the living ones** — a player dead or
  respawning still counts, so the wave strength does not dip when the defenders take casualties. `allPlayers`
  is living-only, so derive from the connected BLUFOR roster instead (exact API a build detail; in this
  mission every human player is BLUFOR, so it is effectively the session headcount at defend start). A JIP
  joiner after that does not change the budget. Vehicles are a sub-limit **within** the budget:
  ≤ **`rand(2,4)`** live at once (also rolled once at defend start). Track the mission's own roster of
  spawned groups + vehicles and count the living — `DUWS_fnc_opforGroupCount` is global to the whole war and
  cannot answer "how many are on *this* objective".
- **Wave trigger.** Spawn a wave when live tokens `< 0.6 * budget` **or** every 5 minutes since the last —
  the deep-dip + heartbeat pair the garrison reserve uses.
- **Composition.** Infantry token `selectRandom ["team","wp_team","squad","recon"]`; vehicle token
  `selectRandom` of the **fieldable** subset of `["car","apc","ifv","tank"]` — `DUWS_fnc_tokenClass`
  returns `""` for a token gated out by OPFOR's earned AP or a disabled setting, so armour only appears
  once OPFOR has unlocked it. Fill toward the budget, respecting the vehicle sub-limit.
- **Objective radius.** **300 m** — the ring the player must stay inside (the abandon test below) and the
  radius handed to the reused garrison helpers, so one number drives the fail test, the spawn and the
  debus together.
- **Placement / delivery.** Every OPFOR vehicle enters at the far-side point,
  `[_infPos, 300] call DUWS_fnc_garrisonReservePos` (past the players, anti-flank). That helper adds a
  fixed `DUWS_zoneReserveSpawnDist` (400), so the spawn lands at **`300 + 400 = 700 m`** out — exactly the
  garrison default at this radius.
  - **Infantry ride in — no foot spawn.** Squads board a troop truck at the 700 m point, the truck drives
    to the debus point `_center getPos [300 + DUWS_reserveDebusOffset(200), bearing]` = **500 m** from
    centre (200 m outside the ring), the squads hard-eject there and `"hunt"` the informant, running the
    last 200 m. Reuse `DUWS_fnc_garrisonReserveTruckSpawn` (picks the faction troop transport, seats a
    driver) for the truck, and drive/eject with the `DUWS_fnc_garrisonReserveDispatch` logic. That
    function is coupled to a garrison **site-key + held-state** (`DUWS_fnc_garrisonHeld`, roster), which
    the informant has no equivalent of, so use a **lean mission-local dispatch** that reuses the truck
    spawn + debus geometry but drops the held/pool/batch machinery — the informant site is "held" until
    the mission ends by definition, so the mid-ride capture-abort has nothing to test.
  - **Combat vehicles drive themselves in.** `car`/`apc`/`ifv`/`tank` spawn at the same 700 m point via
    `fnc_spawn_vehicle` with posture **`"hunt"`** and that point as `_spawnPos`; they need no debus.
  - **Delivery trucks are taxis, not combatants.** They do not count against the `rand(2,4)` vehicle
    sub-cap (only `car`/`apc`/`ifv`/`tank` do), and after debus the empty truck drives off and despawns
    (the dispatch's own escape + `DUWS_binMe` sweep). Claim every fighting group (`fnc_mission_claim`) for
    teardown.
- **Clocks.** The 20-minute survival clock runs in parallel; win when it elapses with the informant alive.

### Fail conditions

Two loss surfaces: the informant's death (killed by fire or overrun), and the plain never-engaged timeout.

- **Killed by fire** → loss directly (`!alive _informant`), line `pc_killed`.
- **Abandoned** → no BLUFOR within the 300 m objective radius for 20 continuous seconds. A server monitor
  polls `bluforNear`; on breach it runs a 20 s countdown with a looping hint (`pc_abandon`, "No friendly
  forces within 300m of the informant. The mission will fail in %1s."), cancelled the instant any BLUFOR
  re-enters 300 m. On expiry it **kills the informant** — the hit team gets him — routing into the same
  `pc_killed` loss (world state genuinely is that he died). Pattern: `killhouse_srv_player_died` / the
  killhouse loop hint.
- **Deadline** → the hpp `[3,3]` backstop covers only a *never-engaged* offer, and routes to the **shared
  timeout notice** (`STR_DUWS_T_mission_deadline_fail`), like every other mission — it does **not** kill the
  informant or assert he died (a timeout must not claim world state; nobody engaged, so nothing is proven
  but that time ran out).

**The deadline disarms the moment prep is triggered.** Once a player arrives (or hits Skip Prep Phase), the
internal 10-min prep + 20-min defend clocks own the outcome; the hpp deadline is switched off and can no
longer fail the mission. So starting prep with one minute left on the deadline still gives the full 30-minute
run and a fair shot at the win. The deadline only ever fires against an offer nobody engaged.

### Teardown

Route every end through `fnc_mission_finish`, the standard ownership teardown: `fnc_mission_claim` tags
each wave unit/vehicle with `DUWS_missionOwner`; finish stamps `DUWS_binMe` / `DUWS_binAt = time + 300` on
them; the always-on `fnc_repetitive_cleanup` sweep deletes each only once **no BLUFOR is within
`KEEP_RADIUS` (300 m)** and the 300 s lifetime passed. So leftover OPFOR never blink out in front of a
player — they stay alive and keep their last orders until reaped.

**On win, one override — vehicles disengage:** before calling finish, give each surviving OPFOR **vehicle**
group a retreat waypoint (MOVE, `CARELESS`, `FULL` speed) to the nearest OPFOR-held zone
(`WARCOM_zones_controled_by_OPFOR`; none in reach → drive off away from the informant). Surviving
**infantry** keep their `hunt` orders and fight on — that is already the flagged-but-alive default, no code
needed. Both are then reaped by the standard 300 m / 300 s sweep. (Despawn range is the shared `KEEP_RADIUS`
300 m, not a per-mission 600 m — decided, to stay consistent with every other mission's teardown.)

**On loss** (killed / abandoned / deadline): plain finish, no retreat — leftover OPFOR keep hunting and are
reaped by the same sweep.

On top of the ownership sweep, the mission's own entities. Two tracks, because the standard
`allUnits + vehicles` owner census (`fnc_mission_cleanup`) reaches living things and vehicles but **not**
static fortification props — those are tracked by composition key instead, the way every mission tracks its
built objects:

- **Informant** (living) → `fnc_mission_claim`, reaped by the owned-entity sweep like the wave groups.
- **Crate + player-built objects** (props) → tracked by **composition-key membership**, which is what
  separates this crate's props from a persisted builder vehicle's. Two steps, matching how
  `fnc_composition_stream_init` already works:
  1. **On creation from this crate → persist + enroll.** `fnc_duws_keep [_obj, _compKey]` flags the object
     **persistent** (so the ambient GC sweep spares it for the duration of the siege) and adds it to this
     mission's key list in `DUWS_compositions` — an explicitly *tracked* membership, not inferred from a
     class or a radius
     ([`fnc_composition_stream_init.sqf:29`](../../src/duws/server/misc/fnc_composition_stream_init.sqf)).
     Only objects built from **this** crate are enrolled, so the builder vehicle's own R3F props — which are
     never keyed here — are untouched. The crate itself is kept at spawn under the same key.
  2. **On teardown → binMe the whole key.** `fnc_mission_finish` releases the key; `fnc_duws_release`
     iterates exactly the tracked members, clears persistence and `fnc_duws_disposeAfter`s each (stamps
     `DUWS_binMe` / `DUWS_binAt`), handing precisely this crate's props to the cleanup sweep and nothing
     else.
- **Enrolling only this crate's objects.** R3F `publicVariable`s every new object as
  `R3F_LOG_PUBVAR_reveler_au_joueur`
  ([`creer_objet.sqf`](../../src/modules/R3F_LOG/usine_creation/creer_objet.sqf)); a server
  `addPublicVariableEventHandler` on it runs the `fnc_duws_keep` enroll above, gated to objects created
  adjacent to *this* crate (R3F spawns a new object next to the factory that made it, so a distance-to-crate
  test at that instant is the enrollment gate). The global `R3F_LOG_CF_depuis_usine` flag is not used — it
  cannot tell one factory's objects from another's.
- **Deregister the factory**: remove the crate from `R3F_LOG_CF_liste_usines` so no orphaned build action
  survives the crate's deletion.

## Dialogue + descriptions

Written from scratch — the old `STR_DUWS_T_pc*` escort lines mostly do not fit the siege. Everything below
follows [`player_text_style_guide.md`](../info/gameplay/player_text_style_guide.md): flat military
present-tense declaratives, no theatrics or exclamation marks, no em-dashes in player prose, numbers
spelled out in spoken lines and numerals in HUD text. Speakers and channels obey the NET/SUB-NET/VOICE
split — **Overlord** tasks the player and calls results on NET; **Allseer** is the ISR feed and addresses
*Overlord*, never the player, on SUB-NET; the **informant** is a civilian in the world, so VOICE; the
player's team (**Alpha 1-1**, host-settable) is VOICE. English is the source of truth; DE/ES/ZH tags lag on
purpose and are not aligned here. Dialogue lines pass the raw `localize`d key (`fnc_duws_dialogue` runs
`fnc_cs` itself); a hint that contained `Alpha 1-1` would need `fnc_cs`, but none here do.

Model shapes: the **brief borrows the simplest side-mission pattern** —
[`destroy_hardpoint`](../../src/duws/server/missions/mission_threads/destroy_hardpoint/fnc_destroy_hardpoint_mission.sqf)'s
two-beat `fnc_mission_present` list, Overlord directive then team copy, with no mission-specific distress
speaker. The win/loss closes take the IDAP hand-over register (`idapoverlordclose` / `idaptruckdown`), and
the description names the concrete nouns the informant brief does.

### Strategic-map description + note

Replaces the current `STR_DUWS_T_protectciv`. Prose, terminal period, names the ground, the crate, the two
phases and the no-extraction fiction (the win close answers this last clause):

> `STR_DUWS_T_protectciv` — *An enemy hit team is closing on one of our informants, holed up in a building
> in this area. Reach him, then use the supply crate to fortify his position while it is quiet. Hold against
> repeated assaults until they are spent. There is no extraction, we need him in place and still gathering.*

New `note` column key (its own "Note:" briefing line, mirroring the informant's 300 m note):

> `STR_DUWS_T_protectciv_note` — *Keep a squad member within 300 m of the informant, or the position is
> judged abandoned and the mission fails.*

### Beats

Trimmed to the simple pattern: Overlord opens with a directive (the player's team copies), the informant
speaks only once on arrival, and hints carry the build directive and the countdowns; the close names the
concrete outcome (informant held, still gathering), not a swappable stamp. One event, one surface.

| Beat | Trigger | Speaker / surface | Channel | Key | Proposed English |
|---|---|---|---|---|---|
| Directive | offer / spawn (`fnc_mission_present`) | Overlord | NET | `pc_directive` | *Priority directive, Alpha 1-1. An informant has been compromised and needs his position held against enemy attack. He is a high value asset, we need him alive.* |
| Copy | back-to-back | Alpha 1-1 | VOICE | `pc_copy` | *Copy, Overlord. Moving to the informant now.* |
| Prep directive | a player within 30 m, once | — (hint) | — | `pc_prep_hint` | *Fortify the informant's position. Build defenses from the supply crate. The assault begins in 10 minutes.* |
| Arrival greeting | on arrival, after the prep directive | Informant | VOICE | `pc_arrive` | *Thank god you're here. They'll be here any minute now. We should make ready while we still can.* |
| Prep countdown | each prep minute | — (hint) | — | `pc_prep_count` | *You have %1 minute(s) before the assault.* |
| Assault opens | prep ends (timer or skip); `sleep 2` after this line | Allseer | SUB-NET | `pc_assault` | *Be advised, we have reports of multiple contacts converging on the informant's position.* |
| Hold order | after the 2 s beat | Overlord | NET | `pc_hold` | *Alpha 1-1, hold the line. Do not let them reach him.* |
| Hold directive | defend phase opens, once | — (hint) | — | `pc_hold_hint` | *Hold your position for 20 minutes and stay within 300m of the informant.* |
| Abandon warning | no BLUFOR in 300 m, looping | — (hint) | — | `pc_abandon` | *No friendly forces within 300m of the informant. The mission will fail in %1s.* |
| Win | informant alive at 20 min | Overlord | NET | `pc_win` | *Good work Alpha 1-1. The assault is breaking off. Ensure the area is clear and RTB. Overlord out.* |
| Loss — informant dead | killed by fire, or abandon timer expiry (kills him) | Overlord | NET | `pc_killed` | *Alpha 1-1, the informant is dead. Nothing more we can do. Disengage and RTB.* |
| Loss — deadline | never engaged | shared notice | NET | `STR_DUWS_T_mission_deadline_fail` (existing) | *(no new key — the shared timeout line, no death asserted)* |

- **Skip Prep Phase action** (scroll label on the informant, no terminal period): `pc_skip` — *Skip Prep
  Phase*. Bucket `ACT_COMMIT` (red, "not freely undone") since it irreversibly starts the assault; confirm
  vs a plain command bucket.
- **Informant speaks once, on arrival** (`pc_arrive`, above) — otherwise silent; hints carry the build
  directive and the countdowns.
- **Markers** (map/3D icon text, no period): informant icon *Informant*; crate icon *Supplies*.
- **Drop the notification card.** The old thread fires a `BIS_fnc_showNotification` "alert" on the
  informant's death (`STR_DUWS_T_cycuqbvj` / `ayhemuj4`); the win/loss are voiced by Overlord now, so the
  card doubles a radio line — remove it (one event, one surface).

### Stringtable work

- Add the keys above under the mission's container, `<Original>` + `<English>` in lockstep.
- Retire the dead escort keys once unreferenced: `pcletsdothis`, `pcwhoau`, `pciminfo`, `pcoverlord`,
  `pcroger`, `pcbequick`, `pcend`, `pcfail`, `pcbehindme`, and the two card strings `cycuqbvj` / `ayhemuj4`.

## Edge cases + engine gotchas

- **AIS does not touch the informant (checked) — opt-out is belt-and-suspenders.** The revive module is
  configured `AIS_REVIVE_INIT_UNITS = "allplayables"`, which resolves to `switchableUnits` (SP) /
  `playableUnits` (MP) — the player squad and their commandable AI, i.e. "players + their AI". The only AI
  enrollment is a **one-shot loop at mission start** (`Core/fn_postinit.sqf:32-40`) over that playable set;
  it never re-runs, so dynamically-spawned AI — the informant, garrison, enemies, civilians — are never
  enrolled (nothing calls `loadAIS` on them bar recruited operatives). So the informant dies normally and our
  `HandleDamage` survives under this config. Still set `AIS_noReviveInit = true` on him at spawn (honored by
  `Core/fn_aisInitHost.sqf:3` / `System/fn_loadAISlocalToPlayer.sqf`) as cheap insurance against a future
  setting change to `allUnitsBLUFOR`, which would `removeAllEventHandlers "handleDamage"` (stripping our 50 %
  handler) and revive him unconscious instead of dead. **Do not change the setting to `"allplayers"`** to
  "tighten" it — that empties the postinit set and the group-AI fallback in `aisInitPlayer` is `!isServer`-
  gated (dedicated only), so a host player's own AI squad would get no AIS in SP. Worth a note in
  [`arma_engine_gotchas.md`](../info/architecture/arma_engine_gotchas.md) when built (AIS strips foreign
  HandleDamage; multiple HandleDamage handlers on one unit; `allplayables` is the right SP setting).
- **Costume must not depend on civilian presence.** The mission now sites by map survey and can run with
  civilians off (RAVAGE/WBK or `CIV_PRESENCE == "NONE"`), so drawing the informant's costume from the *live*
  civilian pool can hand back nothing. Fall back to a hardcoded civilian class (e.g. `C_man_1`) when the pool
  is unavailable — the disguise is flavour, not a dependency.
- **Skip Prep Phase action lifecycle.** Attach it object-keyed from the server
  (`remoteExec ["addAction", [0,-2] select isDedicated, _informant]`) with a machine-local duplicate guard,
  per the [call-site conventions](../info/gameplay/player_text_style_guide.md#call-site-conventions). Remove
  or condition it off once prep ends — it does nothing during the defend phase and should not linger on the
  scroll wheel.
- **3D icons are JIP-safe.** Draw the informant and crate icons keyed to all clients including late joiners
  (the laptop marker system's JIP keying), or a JIP player sees no objective.
- **Concurrent build in MP.** R3F decrements `R3F_LOG_CF_credits` on each building client without a lock, so
  two players building in the same instant can both read 250 and overspend slightly. R3F's own limitation,
  not worth a bespoke lock; accept it, or (if it matters) serialise builds through a server check later.
- **Run flag, not `Mission_Active`.** Let `fnc_mission_begin` / `fnc_mission_finish` own the one-mission-at-a-time
  slot; drive the wave/defend loops off the thread's own local run flag rather than resurrecting the old
  thread's global `Mission_Active` toggling.

## Files

New:
- `src/duws/server/missions/mission_threads/protect_civ/fnc_protect_civ_site.sqf` — building finder.

Changed:
- `src/duws/server/missions/mission_threads/protect_civ/fnc_protect_civ.sqf` — full rewrite.
- `src/duws/shared/includes/mission_types.hpp` — row 13 (CP/AP/REP, surveyKind).
- `src/duws/server/server_fnc_init.sqf` — `publicVariable` any new client-called server fns.
- `src/stringtable.xml` — new keys; retire the dead `STR_DUWS_T_pc*` escort lines.

## Build order

1. hpp row + finder — offer sites correctly on `map` with a building near.
2. Thread skeleton: building, informant, crate (no R3F yet), icons, brief, arrival gate, deadline backstop.
3. R3F factory registration (250 pts) + whitelist + keep-on-creation hook (built objects filed under the mission compKey).
4. Prep countdown + Skip Prep Phase action.
5. Wave controller (budget, cadence, composition, 700 m far-side spawn, troop-truck debus at 500 m).
6. Fail conditions (killed, abandoned loop-timer) + win clock + reward/REP.
7. Dialogue/stringtable pass; dead-line cleanup.

Verify in a local run: offer appears off-town; informant + crate + icons stand; arrival starts the prep
hint; a build spends credits and is torn down at end; skip jumps to waves; trucks spawn ~700 m out, debus
at ~500 m and their squads run in; combat vehicles scale with OPFOR AP; abandon timer fires and resets;
win pays 30/30 and +3 REP to the nearest discovered town.

## Open tuning (confirm before / during playtest)

- **Deadline band:** keep `[3, 3]` or move to `[2, 3]` per the recalled "2–3 h".
- **Build budget realism:** whether 250 raw points needs a fortification `cost_factor` to feel limited.
- **REP target:** the win grants +3 to the **nearest discovered town** (`fnc_town_rep_adjust`); no
  discovered town in range → no REP. Confirm this over the old civ-of-spawn index.
- **Wave cadence / vehicle sub-cap:** the `0.6` dip, the 5-minute heartbeat, and whether `rand(2,4)` is
  rolled once or re-rolled.
- **Spawn / debus distance:** decided — all vehicles spawn 700 m far-side, troop trucks debus at 500 m
  (200 m buffer), infantry run the last 200 m. These fall straight out of the garrison defaults at
  radius 300; no override needed.
- **Skip visibility:** the Skip Prep Phase action appears 10 s after start but is only reachable at the
  informant — confirm that reads clearly (vs. gating it on arrival).
