// =========================================================================================================
// DUWS_T server function registry. Compiled once on the server at mission start.
//
// Two halves, and the difference decides whether order matters.
//
//   INITIALISERS run the file they name, right there. One can read what an earlier one defined,
//   so their order is load-bearing and the per-entry comments say what depends on what.
//   tests/lint/check_load_order.py gates it.
//
//   DECLARATIONS bind a compiled body to a name and run nothing. Names inside resolve when the
//   function is called, long after this file has finished, so their order carries no meaning at
//   all. They are grouped by source folder for lookup, and regrouping them is free.
//
// KEEP THE SECTION BANNERS. SQF has no modules or namespaces, so this file can only ever be one
// flat load list; the banners are the only structure available to it. They are a standing exception
// to the no-section-banners rule in CLAUDE.md, not an oversight, and must survive any tidy-up.
// =========================================================================================================

// =========================================================================================================
// INITIALISERS -- these execute on load, in this order
// =========================================================================================================

[] call compile preprocessFileLineNumbers "duws\server\warcom\fnc_economy_init.sqf";
publicVariable "fnc_escalation_cost";
publicVariable "fnc_money_count";
publicVariable "fnc_money_spend";
publicVariable "fnc_pool_spend";
publicVariable "fnc_pool_reply";
// Ahead of both state files below, which are its consumers: zones and towns share one attrition model.
[] call compile preprocessFileLineNumbers "duws\server\garrison\fnc_garrison_strength_init.sqf";
// Ahead of them for the same reason: zones, towns and bases share one roster store.
[] call compile preprocessFileLineNumbers "duws\server\misc\fnc_site_stream_init.sqf";
[] call compile preprocessFileLineNumbers "duws\server\init_zones\fnc_zone_state_init.sqf";
[] call compile preprocessFileLineNumbers "duws\server\civilian\fnc_civ_state_init.sqf";
publicVariable "fnc_civ_moveToPlayerServer";
[] call compile preprocessFileLineNumbers "duws\server\supports\fnc_support_claim_init.sqf";
publicVariable "fnc_support_reply";
publicVariable "fnc_support_claim";
publicVariable "fnc_hcair_claim_request";
[] call compile preprocessFileLineNumbers "duws\server\misc\fnc_composition_stream_init.sqf";
publicVariable "fnc_duws_disposeAfter";
publicVariable "fnc_duws_keep";
publicVariable "fnc_duws_release";
// Broadcast so a client action's toggle forwards itself to the server.
[] call compile preprocessFileLineNumbers "duws\server\misc\fnc_unit_carry.sqf";
publicVariable "DUWS_fnc_unitCarry";
publicVariable "DUWS_fnc_unitDrop";
publicVariable "DUWS_fnc_unitCarryToggle";
publicVariable "DUWS_fnc_unitCarryAddDropAction";
publicVariable "DUWS_fnc_unitCarryRemoveDropAction";
publicVariable "fnc_duws_stow";
publicVariable "fnc_duws_deploy";
// After fnc_duws_keep, which it calls; server-only, so not broadcast.
[] call compile preprocessFileLineNumbers "duws\server\placement\fnc_composition_place.sqf";
// Settled-object counterpart to fnc_composition_place: seats simulated pieces (loot, live props) at rest
// instead of freezing them. After fnc_duws_keep, which it calls; server-only, so not broadcast.
[] call compile preprocessFileLineNumbers "duws\server\placement\fnc_place_settled.sqf";
// Both feed the placer below, so loaded ahead of it; server-only, not broadcast.
[] call compile preprocessFileLineNumbers "duws\server\placement\fnc_furnish_catalog.sqf";
[] call compile preprocessFileLineNumbers "duws\server\placement\fnc_furnish_grid.sqf";
// One furnished room, spawned per room by the placer below; loaded after place_settled/grid/catalog it calls.
[] call compile preprocessFileLineNumbers "duws\server\placement\fnc_furnish_room.sqf";
// Loaded after place_settled, the grid, the catalog and the room pass, which it calls; server-only, so not broadcast (the debug menu remoteExecs it to the server).
[] call compile preprocessFileLineNumbers "duws\server\placement\fnc_furnish_building.sqf";
// Defines fnc_guard_lock / fnc_guard_register / fnc_guard_watch (locks critical objects out of Zeus).
[] call compile preprocessFileLineNumbers "duws\server\misc\fnc_asset_guard.sqf";
// OPCOM (the opposing commander): server-only, so not broadcast. Two subsystems, one folder each under
// warcom\opcom\. belief\ -- the force model, strength, grid-coordinate and zone-contest helpers (executed to
// define their tables and resolvers), the belief store, sighting sweep, decay, and the perception grid with its
// per-tick run.
[] call compile preprocessFileLineNumbers "duws\server\warcom\opcom\belief\fnc_opcom_force.sqf";
[] call compile preprocessFileLineNumbers "duws\server\warcom\opcom\belief\fnc_opcom_strength.sqf";
[] call compile preprocessFileLineNumbers "duws\server\warcom\opcom\belief\fnc_opcom_grid_coords.sqf";
[] call compile preprocessFileLineNumbers "duws\server\warcom\opcom\belief\fnc_opcom_contested.sqf";
// taskings\: streaming, the movement core, the ferry trio (orchestrator, virtual, live), garrison, ports, delivery, fires, the order bodies and the order table executed to
// define them; the store init, router, recruit/task primitives, per-tick step and hand-drive harness compiled to names the loop and harness call.
// strength (belief\, above) loads before stream, whose deVirt calls matchStrength.
[] call compile preprocessFileLineNumbers "duws\server\warcom\opcom\taskings\fnc_opcom_stream.sqf";
[] call compile preprocessFileLineNumbers "duws\server\warcom\opcom\taskings\fnc_opcom_movement_core.sqf";
[] call compile preprocessFileLineNumbers "duws\server\warcom\opcom\taskings\fnc_opcom_ferry.sqf";
[] call compile preprocessFileLineNumbers "duws\server\warcom\opcom\taskings\fnc_opcom_ferry_virt.sqf";
[] call compile preprocessFileLineNumbers "duws\server\warcom\opcom\taskings\fnc_opcom_ferry_devirt.sqf";
[] call compile preprocessFileLineNumbers "duws\server\warcom\opcom\taskings\fnc_opcom_garrison.sqf";
[] call compile preprocessFileLineNumbers "duws\server\warcom\opcom\taskings\fnc_opcom_ports.sqf";
[] call compile preprocessFileLineNumbers "duws\server\warcom\opcom\taskings\fnc_opcom_deliver.sqf";
[] call compile preprocessFileLineNumbers "duws\server\warcom\opcom\taskings\fnc_opcom_fires.sqf";
[] call compile preprocessFileLineNumbers "duws\server\warcom\opcom\taskings\fnc_opcom_intercept.sqf";
[] call compile preprocessFileLineNumbers "duws\server\warcom\opcom\taskings\fnc_opcom_capture.sqf";
[] call compile preprocessFileLineNumbers "duws\server\warcom\opcom\taskings\fnc_opcom_move.sqf";
// orders last of the executed set: its table stores the handler values, so every one must already be defined.
[] call compile preprocessFileLineNumbers "duws\server\warcom\opcom\taskings\fnc_opcom_orders.sqf";
// Publishes DUWS_zoneHooks and the placers around it; after the zone state file it reads.
[] call compile preprocessFileLineNumbers "duws\server\init_zones\fnc_zone_stream_init.sqf";
// The zone reserve / reinforcement engine: the refill pass, the far-side placement and the two
// triggers that fire it. Server-only, so not broadcast; executed at load to define its functions the
// way fnc_zone_stream_init is. Its refill and accounting hook fnc_zone_spawn (defined when
// fnc_zone_spawn_sizes is spawned) and the state helpers in fnc_zone_state_init, both in hand before
// the first zone raise.
[] call compile preprocessFileLineNumbers "duws\server\init_zones\fnc_garrison_reserve.sqf";
// After the builders
// above so the zone set can reference them; the hardpoint resolver is read later by the placer.
[] call compile preprocessFileLineNumbers "duws\server\placement\fnc_composition_sets.sqf";
// The engine keeps exactly one onMapSingleClick handler per machine and offers no way to read back
// what is installed, so two features that each install one silently disarm each other and the
// loser waits on a click that never arrives. Everything mid-mission that wants a map click goes
// through these three instead of touching the command.
// Held in uiNamespace rather than missionNamespace because a claim must not be serialized into a
// savegame: restored from one, the slot would come back owned by a mode that no longer exists and
// every map click for the rest of the session would be dead.
// Mission generation (HQ placement, manual zone placement) still calls the command directly. Those
// run to completion before the player has a comm menu or a board to click, so they cannot collide
// with anything, and routing them through a function the server publishes would make map placement
// depend on the broadcast having landed.
[] call compile preprocessFileLineNumbers "duws\server\misc\fnc_mapclick_init.sqf";
publicVariable "fnc_mapclick_background";
publicVariable "fnc_mapclick_claim";
publicVariable "fnc_mapclick_release";
// Defines the confirmation screen's two prompts rather than being one function, so it is executed
// here and its pieces broadcast individually.
[] call compile preprocessFileLineNumbers "duws\client\dialog\fnc_faction_prompts.sqf";
publicVariable "fnc_faction_prompt_hide";
publicVariable "fnc_faction_prompt_clear";
publicVariable "fnc_faction_prompt_lock";
publicVariable "fnc_faction_key_clear";
// Executed rather than stored: the file defines
// several functions, and all of them run on the buyer's machine.
[] call compile preprocessFileLineNumbers "duws\client\supports\fnc_supports_init.sqf";
publicVariable "fnc_support_catalogue";
publicVariable "fnc_support_defs";
publicVariable "fnc_support_cost_bracket";
publicVariable "DUWS_support_tiers";
publicVariable "fnc_support_tier";
publicVariable "fnc_support_owned";
publicVariable "fnc_support_comm_add";
publicVariable "fnc_support_comm_used";
publicVariable "fnc_support_consume";
publicVariable "fnc_support_comm_drop";
publicVariable "fnc_support_buy";
publicVariable "fnc_support_apply";
publicVariable "fnc_support_refund";
publicVariable "fnc_support_wipe";
publicVariable "fnc_support_despawn";
// Ahead of faction init, which calls it. Not broadcast: generation and every spawn path are server.
[] call compile preprocessFileLineNumbers "duws\shared\faction_lib\fnc_faction_pools.sqf";
// Same idiom and the same reason: the table, the resolver reading it and the placer acting on the
// answer are one file, so which class a static is and how one is put down cannot drift apart.
[] call compile preprocessFileLineNumbers "duws\shared\functions\fnc_static_roles.sqf";
// The coverage primitives and dominance read by the rep drift and the
// hardpoint band siting. Ahead of the hardpoint placer, whose band pass reads it. Definitions only.
[] call compile preprocessFileLineNumbers "duws\server\warcom\fnc_aoi_init.sqf";
// Terrain scoring and the minefield generator: definitions only. Loaded here rather than at zone-gen
// time so both are in hand before generation runs.
[] call compile preprocessFileLineNumbers "duws\server\init_zones\fnc_hardpoint_siting.sqf";
[] call compile preprocessFileLineNumbers "duws\server\init_zones\fnc_hardpoint_minefield.sqf";
// Layout data the placer reads by name (DUWS_hardpointComp_<type>). Ahead of the placer so no build
// finds an empty composition and stands a hardpoint up as bare men on open ground.
[] call compile preprocessFileLineNumbers "duws\server\init_zones\hardpoint_compositions.sqf";
[] call compile preprocessFileLineNumbers "duws\server\init_zones\fnc_hardpoint_place.sqf";
[] call compile preprocessFileLineNumbers "duws\server\init_zones\fnc_hardpoint_stream.sqf";
// Same idiom again, and ahead of faction init, which is what leaves the keys it fills empty.
[] call compile preprocessFileLineNumbers "duws\shared\faction_lib\fnc_faction_backfill.sqf";
// The vanilla stand-in mop-up that runs after backfill for a preset or pasted faction's leftover keys.
[] call compile preprocessFileLineNumbers "duws\shared\faction_lib\fnc_faction_vanilla_fill.sqf";
// Before fnc_BLUFOR_squad_init and the zone spawn band, both of which name a team out of it.
[] call compile preprocessFileLineNumbers "duws\shared\functions\fnc_spawn_vocab.sqf";
// Broadcast: the request menus grey and sort rows by the AP ladder client-side, and the squad server
// guards read the same gate. The file sets the three globals; each is broadcast in turn.
[] call compile preprocessFileLineNumbers "duws\shared\functions\fnc_ap_gate.sqf";
publicVariable "DUWS_fnc_ap_unlocked";
publicVariable "DUWS_fnc_tierName";
publicVariable "DUWS_fnc_vehTier";
publicVariable "DUWS_fnc_tierListFill";
publicVariable "DUWS_blufor_squads";
publicVariable "DUWS_fnc_squadRow";
// Broadcast: the request-list reader reprices every vehicle client-side through DUWS_fnc_vehPrice,
// and DUWS_fnc_vehTier (above) shares the DUWS_fnc_vehKind classifier, so both halves must resolve
// on every machine. The file sets the tuning constants, the band map and the classifier chain.
[] call compile preprocessFileLineNumbers "duws\shared\functions\fnc_veh_price.sqf";
{ publicVariable _x } forEach [
    "DUWS_vehp_ARMOR_REF", "DUWS_vehp_WEAPON_REF", "DUWS_vehp_CAP_REF", "DUWS_vehp_SEAT_REF",
    "DUWS_vehp_RATE_PIVOT", "DUWS_vehp_RATE_W", "DUWS_vehp_CAP_W", "DUWS_vehp_PYLON_W",
    "DUWS_vehPriceBands", "DUWS_fnc_vehTurretWeapons", "DUWS_fnc_vehWeapons", "DUWS_fnc_vehPylonCount",
    "DUWS_fnc_vehArmed", "DUWS_fnc_vehHasMainGun", "DUWS_fnc_vehKind", "DUWS_fnc_vehWeaponScore", "DUWS_fnc_vehPrice"
];
// Broadcast: the depot menu reads the garage tier table, caps and pool usage client-side, and the
// server store/retrieve paths read the same globals. Loaded after fnc_veh_price and fnc_ap_gate,
// whose DUWS_fnc_vehKind and DUWS_fnc_ap_unlocked it calls.
[] call compile preprocessFileLineNumbers "duws\shared\functions\fnc_garage_spec.sqf";
{ publicVariable _x } forEach [
    "DUWS_garage_tiers", "DUWS_fnc_vehDomain", "DUWS_fnc_garageCaps", "DUWS_fnc_garageUsed",
    "DUWS_fnc_garageDomainIndex", "DUWS_fnc_vehAmmoFrac", "DUWS_fnc_vehSpecCapture", "DUWS_fnc_vehSpecApply"
];
// Broadcast: the fire-mission strike runs client-side and resolves a faction's real mortar/arty
// shell through this, so it must exist on every machine that can call a battery.
[] call compile preprocessFileLineNumbers "duws\shared\functions\fnc_derive_shell.sqf";
publicVariable "DUWS_fnc_deriveShell";
[] call compile preprocessFileLineNumbers "duws\server\misc\fnc_wbk_server_init.sqf";
publicVariable "fnc_wbk_survivorKilled_server";
[] call compile preprocessFileLineNumbers "duws\server\supports\fnc_pylon_init.sqf";
publicVariable "fnc_pylon_set_with_cost";
publicVariable "fnc_pylon_hint_nocp";
publicVariable "fnc_pylon_hint_success";
// Broadcast like the pylon purchase above: the depot menu only
// ever remoteExecs these to the server, but keeping them defined everywhere matches the pattern.
[] call compile preprocessFileLineNumbers "duws\server\supports\fnc_garage_init.sqf";
publicVariable "fnc_garage_store";
publicVariable "fnc_garage_retrieve";
publicVariable "fnc_depot_place_finish";

// =========================================================================================================
// STATIC DECLARATIONS -- compiled and named only, nothing runs; order is free
// =========================================================================================================

// =========================================================================================================
// server/arsenal
// =========================================================================================================
fnc_create_ammo_lists = compile preprocessFileLineNumbers "duws\server\arsenal\fnc_create_ammo_lists.sqf";
fnc_basic_ammo_lists = compile preprocessFileLineNumbers "duws\server\arsenal\fnc_basic_ammo_lists.sqf";
fnc_arsenal_base_weapons = compile preprocessFileLineNumbers "duws\server\arsenal\fnc_arsenal_base_weapons.sqf";
fnc_arsenal_reward = compile preprocessFileLineNumbers "duws\server\arsenal\fnc_arsenal_reward.sqf";
fnc_fill_ammobox = compile preprocessFileLineNumbers "duws\server\arsenal\fnc_fill_ammobox.sqf";publicVariable "fnc_fill_ammobox";
fnc_buildQuickKits = compile preprocessFileLineNumbers "duws\server\arsenal\fnc_buildQuickKits.sqf";
publicVariable "fnc_buildQuickKits";
fnc_rearmUnit = compile preprocessFileLineNumbers "duws\server\arsenal\fnc_rearmUnit.sqf";
publicVariable "fnc_rearmUnit";

// =========================================================================================================
// server/civilian
// =========================================================================================================
fnc_civ_garrison = compile preprocessFileLineNumbers "duws\server\civilian\fnc_civ_garrison.sqf";
fnc_civ_init_Tomata = compile preprocessFileLineNumbers "duws\server\civilian\fnc_civ_init_Tomata.sqf";
fnc_civ_setup_array = compile preprocessFileLineNumbers "duws\server\civilian\fnc_civ_setup_array.sqf";
fnc_civ_selectTowns = compile preprocessFileLineNumbers "duws\server\civilian\fnc_civ_selectTowns.sqf";
// Broadcast for the same reason the RAVAGE and WBK handlers are: the town presence trigger names
// it, and that trigger is global, so every machine evaluates it and every machine runs the body.
fnc_civ_town_reveal = compile preprocessFileLineNumbers "duws\server\civilian\fnc_civ_town_reveal.sqf";
publicVariable "fnc_civ_town_reveal";
fnc_civ_wp_Tomata = compile preprocessFileLineNumbers "duws\server\civilian\fnc_civ_wp_Tomata.sqf";
// Server-only, and deliberately not broadcast: the FiredNear handler that calls it is added on
// this machine alone, and a client that could run it could scatter a town at will.
fnc_civ_panic = compile preprocessFileLineNumbers "duws\server\civilian\fnc_civ_panic.sqf";
// Shared loadout helper for the safehouse raid, angry mob, informant flee and protect-civ protectee.
fnc_civ_arm = compile preprocessFileLineNumbers "duws\server\civilian\fnc_civ_arm.sqf";
fnc_civ_rep_Tomata = compile preprocessFileLineNumbers "duws\server\civilian\fnc_civ_rep_Tomata.sqf";
fnc_recruit_civilian_server = compile preprocessFileLineNumbers "duws\server\civilian\fnc_recruit_civilian_server.sqf";
publicVariable "fnc_recruit_civilian_server";
fnc_civ_healed = compile preprocessFileLineNumbers "duws\server\civilian\fnc_civ_healed.sqf";
fnc_civ_release = compile preprocessFileLineNumbers "duws\server\civilian\fnc_civ_release.sqf";
publicVariable "fnc_civ_release";
// Not broadcast, unlike the two below it: the plain civilian path is a server-side thread started
// at town registration, so no trigger anywhere names it.
fnc_civ_handler = compile preprocessFileLineNumbers "duws\server\civilian\fnc_civ_handler.sqf";
fnc_civ_handler_ravage = compile preprocessFileLineNumbers "duws\server\civilian\fnc_civ_handler_ravage.sqf";
publicVariable "fnc_civ_handler_ravage";
fnc_civ_handler_wbk = compile preprocessFileLineNumbers "duws\server\civilian\fnc_civ_handler_wbk.sqf";
publicVariable "fnc_civ_handler_wbk";
// Shared by the two mode handlers above and by nothing else -- fnc_civ_handler runs mod-free and
// takes no mutex, so it must not reach these.
fnc_civ_mode_releaseLock = compile preprocessFileLineNumbers "duws\server\civilian\fnc_civ_mode_releaseLock.sqf";
fnc_civ_mode_spawnGate = compile preprocessFileLineNumbers "duws\server\civilian\fnc_civ_mode_spawnGate.sqf";
// Server-only: every caller is a handler thread or its trigger, and the trigger already resolves
// on the machine that runs the spawn. The recycle pass is RAVAGE and WBK's alone; the ceiling is
// shared with the plain path.
fnc_civ_liveTarget = compile preprocessFileLineNumbers "duws\server\civilian\fnc_civ_liveTarget.sqf";
fnc_civ_spawnUnit = compile preprocessFileLineNumbers "duws\server\civilian\fnc_civ_spawnUnit.sqf";
fnc_civ_roadDir = compile preprocessFileLineNumbers "duws\server\civilian\fnc_civ_roadDir.sqf";
fnc_civ_spawnCar = compile preprocessFileLineNumbers "duws\server\civilian\fnc_civ_spawnCar.sqf";
fnc_civ_loopRoute = compile preprocessFileLineNumbers "duws\server\civilian\fnc_civ_loopRoute.sqf";
fnc_civ_traffic = compile preprocessFileLineNumbers "duws\server\civilian\fnc_civ_traffic.sqf";
fnc_civ_recycle = compile preprocessFileLineNumbers "duws\server\civilian\fnc_civ_recycle.sqf";
fnc_civ_pickHiddenRoad = compile preprocessFileLineNumbers "duws\server\civilian\fnc_civ_pickHiddenRoad.sqf";
// Only fnc_civ_request and fnc_civ_bribe_answer are reached from a client, but
// the rest are broadcast too so a headless client running civilian logic resolves them.
fnc_civ_request = compile preprocessFileLineNumbers "duws\server\civilian\fnc_civ_request.sqf";
publicVariable "fnc_civ_request";
fnc_civ_serve = compile preprocessFileLineNumbers "duws\server\civilian\fnc_civ_serve.sqf";
publicVariable "fnc_civ_serve";
fnc_civ_close = compile preprocessFileLineNumbers "duws\server\civilian\fnc_civ_close.sqf";
publicVariable "fnc_civ_close";
fnc_civ_bribe_answer = compile preprocessFileLineNumbers "duws\server\civilian\fnc_civ_bribe_answer.sqf";
publicVariable "fnc_civ_bribe_answer";
fnc_civ_arrest = compile preprocessFileLineNumbers "duws\server\civilian\fnc_civ_arrest.sqf";
publicVariable "fnc_civ_arrest";
fnc_disguiseAsCivilian = compile preprocessFileLineNumbers "duws\server\civilian\fnc_disguiseAsCivilian.sqf";
publicVariable "fnc_disguiseAsCivilian";
fnc_scanCivilianGear = compile preprocessFileLineNumbers "duws\server\civilian\fnc_scanCivilianGear.sqf";
publicVariable "fnc_scanCivilianGear";
fnc_civ_resume = compile preprocessFileLineNumbers "duws\server\civilian\fnc_civ_resume.sqf";

// =========================================================================================================
// server/convoy
// =========================================================================================================
// A self-generated road-graph route builder, a slot layout that seats the column ON
// that route, and a driver that puts every hull on the route with setDriveOnPath (no native lead pathing).
// Used by the HVT hunt, the deny-armour convoy and the roving vehicle patrol.
fnc_convoy_path = compile preprocessFileLineNumbers "duws\server\convoy\fnc_convoy_path.sqf";
fnc_convoy_slots = compile preprocessFileLineNumbers "duws\server\convoy\fnc_convoy_slots.sqf";
fnc_convoy_drive = compile preprocessFileLineNumbers "duws\server\convoy\fnc_convoy_drive.sqf";
fnc_convoy_release_hull = compile preprocessFileLineNumbers "duws\server\convoy\fnc_convoy_release_hull.sqf";
fnc_convoy_fit = compile preprocessFileLineNumbers "duws\server\convoy\fnc_convoy_fit.sqf";

// =========================================================================================================
// server/debug
// =========================================================================================================
// Not broadcast: the debug menu remoteExecs it to the server by name, having re-checked game_master first.
fnc_debug_random_event = compile preprocessFileLineNumbers "duws\server\debug\fnc_debug_random_event.sqf";
fnc_debug_intel_search = compile preprocessFileLineNumbers "duws\server\debug\fnc_debug_intel_search.sqf";
fnc_debug_force_mission = compile preprocessFileLineNumbers "duws\server\debug\fnc_debug_force_mission.sqf";
fnc_debug_spawn_hardpoint = compile preprocessFileLineNumbers "duws\server\debug\fnc_debug_spawn_hardpoint.sqf";
fnc_debug_clear_hardpoints = compile preprocessFileLineNumbers "duws\server\debug\fnc_debug_clear_hardpoints.sqf";
// Server gather for the OPCOM grid/belief overlay; remoteExec'd to 2 by fnc_debug_opcom_view. Read-only.
fnc_debug_opcom_grid = compile preprocessFileLineNumbers "duws\server\debug\fnc_debug_opcom_grid.sqf";
fnc_debug_search_flag = compile preprocessFileLineNumbers "duws\server\debug\fnc_debug_search_flag.sqf";
fnc_debug_spawn_intel = compile preprocessFileLineNumbers "duws\server\debug\fnc_debug_spawn_intel.sqf";
fnc_debug_garrison_query = compile preprocessFileLineNumbers "duws\server\debug\fnc_debug_garrison_query.sqf";
fnc_debug_force_emission = compile preprocessFileLineNumbers "duws\server\debug\fnc_debug_force_emission.sqf";
// Server-only: remoteExec'd to 2 by the OPCOM debug menu; runs the hand-drive verbs and reads the store the
// menu's remote pickers cannot.
fnc_debug_opcom = compile preprocessFileLineNumbers "duws\server\debug\fnc_debug_opcom.sqf";
// Not broadcast: the window remoteExecs it to the server by name, and it re-checks game_master
// itself because any client could send it.
fnc_debug_econ_server = compile preprocessFileLineNumbers "duws\server\debug\fnc_debug_econ_server.sqf";
fnc_furnish_grid_gather = compile preprocessFileLineNumbers "duws\server\debug\fnc_furnish_grid_gather.sqf";
fnc_furnish_calibrate_spawn = compile preprocessFileLineNumbers "duws\server\debug\fnc_furnish_calibrate_spawn.sqf";

// =========================================================================================================
// server/dialog
// =========================================================================================================
fnc_weather = compile preprocessFileLineNumbers "duws\server\dialog\fnc_weather.sqf";
fnc_custom_faction_init = compile preprocessFileLineNumbers "duws\server\dialog\fnc_custom_faction_init.sqf";publicVariable "fnc_custom_faction_init";
fnc_rest_heal = compile preprocessFileLineNumbers "duws\server\dialog\fnc_rest_heal.sqf";publicVariable "fnc_rest_heal";
fnc_FOB_cleanup = compile preprocessFileLineNumbers "duws\server\dialog\fnc_FOB_cleanup.sqf";publicVariable "fnc_FOB_cleanup";
fnc_MHQ_deploy = compile preprocessFileLineNumbers "duws\server\dialog\fnc_MHQ_deploy.sqf";publicVariable "fnc_MHQ_deploy";
fnc_MHQ_undeploy = compile preprocessFileLineNumbers "duws\server\dialog\fnc_MHQ_undeploy.sqf";publicVariable "fnc_MHQ_undeploy";
fnc_MHQ_release = compile preprocessFileLineNumbers "duws\server\dialog\fnc_MHQ_release.sqf";

// =========================================================================================================
// server/events
// =========================================================================================================
fnc_night_horde_event = compile preprocessFileLineNumbers "duws\server\events\fnc_night_horde_event.sqf";
publicVariable "fnc_night_horde_event";
// Server-side only, so left un-broadcast like the other directors.
fnc_random_event_runner = compile preprocessFileLineNumbers "duws\server\events\fnc_random_event_runner.sqf";
fnc_random_event_table = compile preprocessFileLineNumbers "duws\server\events\fnc_random_event_table.sqf";
fnc_random_event_fire = compile preprocessFileLineNumbers "duws\server\events\fnc_random_event_fire.sqf";
fnc_random_event_allowed = compile preprocessFileLineNumbers "duws\server\events\fnc_random_event_allowed.sqf";
fnc_random_event_car = compile preprocessFileLineNumbers "duws\server\events\fnc_random_event_car.sqf";
fnc_random_event_heli = compile preprocessFileLineNumbers "duws\server\events\fnc_random_event_heli.sqf";
fnc_random_event_stranded = compile preprocessFileLineNumbers "duws\server\events\fnc_random_event_stranded.sqf";
fnc_random_event_convoy = compile preprocessFileLineNumbers "duws\server\events\fnc_random_event_convoy.sqf";
fnc_random_event_car_bomb = compile preprocessFileLineNumbers "duws\server\events\fnc_random_event_car_bomb.sqf";
fnc_random_event_recon_patrol = compile preprocessFileLineNumbers "duws\server\events\fnc_random_event_recon_patrol.sqf";
fnc_random_event_enemy_car = compile preprocessFileLineNumbers "duws\server\events\fnc_random_event_enemy_car.sqf";
fnc_random_event_enemy_sniper = compile preprocessFileLineNumbers "duws\server\events\fnc_random_event_enemy_sniper.sqf";
fnc_random_event_ied = compile preprocessFileLineNumbers "duws\server\events\fnc_random_event_ied.sqf";
// A client's completed defuse hold remoteExecs this to the server by name; not broadcast, clients never run it.
fnc_random_event_ied_defuse = compile preprocessFileLineNumbers "duws\server\events\fnc_random_event_ied_defuse.sqf";
fnc_random_event_mob = compile preprocessFileLineNumbers "duws\server\events\fnc_random_event_mob.sqf";

// =========================================================================================================
// server/garrison
// =========================================================================================================
fnc_usableBuildings = compile preprocessFileLineNumbers "duws\server\garrison\fnc_usableBuildings.sqf";
fnc_holdBuildingPost = compile preprocessFileLineNumbers "duws\server\garrison\fnc_holdBuildingPost.sqf";
fnc_spreadIntoBuildings = compile preprocessFileLineNumbers "duws\server\garrison\fnc_spreadIntoBuildings.sqf";
fnc_garrisonBuildings = compile preprocessFileLineNumbers "duws\server\garrison\fnc_garrisonBuildings.sqf";

// =========================================================================================================
// server/init_hq
// =========================================================================================================
fnc_fob_deregister = compile preprocessFileLineNumbers "duws\server\init_hq\fnc_fob_deregister.sqf";
fnc_BluHQinit = compile preprocessFileLineNumbers "duws\server\init_hq\fnc_BluHQinit.sqf";
fnc_placeHQUnits = compile preprocessFileLineNumbers "duws\server\init_hq\fnc_placeHQUnits.sqf";
fnc_fob_destroyed = compile preprocessFileLineNumbers "duws\server\init_hq\fnc_fob_destroyed.sqf";
fnc_BLUFOR_squad_init = compile preprocessFileLineNumbers "duws\server\init_hq\fnc_BLUFOR_squad_init.sqf";publicVariable "fnc_BLUFOR_squad_init";
fnc_BLUFOR_faction_init = compile preprocessFileLineNumbers "duws\server\init_hq\fnc_BLUFOR_faction_init.sqf";publicVariable "fnc_BLUFOR_faction_init";
fnc_fortifyFOB = compile preprocessFileLineNumbers "duws\server\init_hq\fnc_fortifyFOB.sqf";publicVariable "fnc_fortifyFOB";
fnc_guardsFOB = compile preprocessFileLineNumbers "duws\server\init_hq\fnc_guardsFOB.sqf";publicVariable "fnc_guardsFOB";
// Not broadcast: server-only, so an accidental client call fails loud.
fnc_redeployFOBUnits = compile preprocessFileLineNumbers "duws\server\init_hq\fnc_redeployFOBUnits.sqf";
fnc_redeployHQUnits = compile preprocessFileLineNumbers "duws\server\init_hq\fnc_redeployHQUnits.sqf";
publicVariable "fnc_redeployHQUnits";

// =========================================================================================================
// server/init_zones
// =========================================================================================================
fnc_locatorZones_random = compile preprocessFileLineNumbers "duws\server\init_zones\fnc_locatorZones_random.sqf";
fnc_captured = compile preprocessFileLineNumbers "duws\server\init_zones\fnc_captured.sqf";
fnc_blufor_cap = compile preprocessFileLineNumbers "duws\server\init_zones\fnc_blufor_cap.sqf";
fnc_opfor_cap = compile preprocessFileLineNumbers "duws\server\init_zones\fnc_opfor_cap.sqf";
fnc_zone_reveal = compile preprocessFileLineNumbers "duws\server\init_zones\fnc_zone_reveal.sqf";
fnc_zone_spawn_sizes = compile preprocessFileLineNumbers "duws\server\init_zones\fnc_zone_spawn_sizes.sqf";
// MODERN is the baseline composition era, always compiled: fnc_zone_prefab_set falls back to it for
// any era that ships no set of its own.
fnc_modern_CommStation = compile preprocessFileLineNumbers "duws\server\init_zones\prefabs\modern\fnc_modern_CommStation.sqf";
fnc_modern_outpost1 = compile preprocessFileLineNumbers "duws\server\init_zones\prefabs\modern\fnc_modern_outpost1.sqf";
fnc_modern_Outpost2 = compile preprocessFileLineNumbers "duws\server\init_zones\prefabs\modern\fnc_modern_Outpost2.sqf";
fnc_modern_reconOutpost = compile preprocessFileLineNumbers "duws\server\init_zones\prefabs\modern\fnc_modern_reconOutpost.sqf";
fnc_modern_simple_zone = compile preprocessFileLineNumbers "duws\server\init_zones\prefabs\modern\fnc_modern_simple_zone.sqf";
fnc_modern_StorageBunker = compile preprocessFileLineNumbers "duws\server\init_zones\prefabs\modern\fnc_modern_StorageBunker.sqf";
fnc_modern_vehfittingstation = compile preprocessFileLineNumbers "duws\server\init_zones\prefabs\modern\fnc_modern_vehfittingstation.sqf";
fnc_modern_FieldHospital = compile preprocessFileLineNumbers "duws\server\init_zones\prefabs\modern\fnc_modern_FieldHospital.sqf";
fnc_locatorZones_manual = compile preprocessFileLineNumbers "duws\server\init_zones\fnc_locatorZones_manual.sqf";publicVariable "fnc_locatorZones_manual";
fnc_createZone = compile preprocessFileLineNumbers "duws\server\init_zones\fnc_createZone.sqf";publicVariable "fnc_createZone";
// Reveals a hardpoint to the intel system, the way fnc_zone_reveal does a zone: flips the row's
// revealed flag and its marker alpha. Read by fnc_intel_payout. Whole-file-is-the-function idiom, not
// the [] call above: its body opens with params, so running it at registration errors on the missing
// argument and defines nothing -- it must be compiled into the global the callers name.
fnc_hardpoint_reveal = compile preprocessFileLineNumbers "duws\server\init_zones\fnc_hardpoint_reveal.sqf";
fnc_moreUrban_locations = compile preprocessFileLineNumbers "duws\server\init_zones\fnc_moreUrban_locations.sqf";publicVariable "fnc_moreUrban_locations";

// =========================================================================================================
// server/killhouse
// =========================================================================================================
fnc_createKillhouse = compile preprocessFileLineNumbers "duws\server\killhouse\fnc_createKillhouse.sqf";
publicVariable "fnc_createKillhouse";

// =========================================================================================================
// server/misc
// =========================================================================================================
fnc_duws_bluforNear = compile preprocessFileLineNumbers "duws\server\misc\fnc_duws_bluforNear.sqf";
// Not broadcast: the client half of HQ placement reaches it by remoteExec to the server, which is
// the only machine allowed to hide a terrain object.
fnc_clear_foliage = compile preprocessFileLineNumbers "duws\server\misc\fnc_clear_foliage.sqf";
fnc_intro_heli = compile preprocessFileLineNumbers "duws\server\misc\fnc_intro_heli.sqf";
publicVariable "fnc_intro_heli";
fnc_repetitive_cleanup = compile preprocessFileLineNumbers "duws\server\misc\fnc_repetitive_cleanup.sqf";
fnc_capture_zones_task = compile preprocessFileLineNumbers "duws\server\misc\fnc_capture_zones_task.sqf";
fnc_zeus_objects_init = compile preprocessFileLineNumbers "duws\server\misc\fnc_zeus_objects_init.sqf";
fnc_zone_flag_logistics = compile preprocessFileLineNumbers "duws\server\misc\fnc_zone_flag_logistics.sqf";
// Not broadcast: it creates a global marker, so exactly one machine may run it.
fnc_baseRangeMarker = compile preprocessFileLineNumbers "duws\server\misc\fnc_baseRangeMarker.sqf";
// Not broadcast: it decides which players a base appearing is visible to, which only the server can.
fnc_baseFade = compile preprocessFileLineNumbers "duws\server\misc\fnc_baseFade.sqf";
fnc_side_count_at = compile preprocessFileLineNumbers "duws\server\misc\fnc_side_count_at.sqf";
fnc_hirePartisans_spawnDeployed = compile preprocessFileLineNumbers "duws\server\misc\fnc_hirePartisans_spawnDeployed.sqf";
publicVariable "fnc_hirePartisans_spawnDeployed";
// Repair gate read on hit points (raw getDammage never moves under field repair), a
// uniform component-damage spawn, and an engine-kill that immobilises a spawned derelict until repaired.
fnc_veh_comp_damage = compile preprocessFileLineNumbers "duws\server\misc\fnc_veh_comp_damage.sqf";
fnc_veh_disable_engine = compile preprocessFileLineNumbers "duws\server\misc\fnc_veh_disable_engine.sqf";
fnc_veh_set_comp_damage = compile preprocessFileLineNumbers "duws\server\misc\fnc_veh_set_comp_damage.sqf";
fnc_recruitSuccessServer = compile preprocessFileLineNumbers "duws\server\misc\fnc_recruitSuccessServer.sqf";
publicVariable "fnc_recruitSuccessServer";
// fnc_throw (server) creates a dynamic body and launches it with setVelocity, so PhysX flies and
// bounces it. createVehicle is global, so the one server-simulated object networks to every machine on its own.
fnc_throw = compile preprocessFileLineNumbers "duws\server\misc\fnc_throw.sqf";
fnc_enterlocation = compile preprocessFileLineNumbers "duws\server\misc\fnc_enterlocation.sqf";
// Not broadcast: the two triggers that name it are created server-local, and it creates global
// markers, so exactly one machine may run it.
fnc_enemy_contact = compile preprocessFileLineNumbers "duws\server\misc\fnc_enemy_contact.sqf";
// Straight-line water probe the convoy threads and the client-side HVT offer picker use to reject an
// approach bearing that crosses the sea. Broadcast for that picker call site (fnc_hvt_dest_pick).
fnc_route_has_water = compile preprocessFileLineNumbers "duws\server\misc\fnc_route_has_water.sqf";publicVariable "fnc_route_has_water";
// Not broadcast: it fans out to clients itself, so a client call would fan out a second time.
fnc_duws_report = compile preprocessFileLineNumbers "duws\server\misc\fnc_duws_report.sqf";
fnc_restHealServer = compile preprocessFileLineNumbers "duws\server\misc\fnc_restHealServer.sqf";
publicVariable "fnc_restHealServer";
fnc_blackMarketPurchase = compile preprocessFileLineNumbers "duws\server\misc\fnc_blackMarketPurchase.sqf";
publicVariable "fnc_blackMarketPurchase";
fnc_hirePartisans = compile preprocessFileLineNumbers "duws\server\misc\fnc_hirePartisans.sqf";
publicVariable "fnc_hirePartisans";
fnc_hirePMC = compile preprocessFileLineNumbers "duws\server\misc\fnc_hirePMC.sqf";
publicVariable "fnc_hirePMC";
// Not broadcast: server-only, so an accidental client call fails loud.
fnc_HCsquad_spawn = compile preprocessFileLineNumbers "duws\server\misc\fnc_HCsquad_spawn.sqf";

// =========================================================================================================
// server/missions
// =========================================================================================================
fnc_mission_reward = compile preprocessFileLineNumbers "duws\server\missions\fnc_mission_reward.sqf";
fnc_mission_abort = compile preprocessFileLineNumbers "duws\server\missions\fnc_mission_abort.sqf";
fnc_site_generic = compile preprocessFileLineNumbers "duws\server\missions\fnc_site_generic.sqf";publicVariable "fnc_site_generic";
// Broadcast: per-type finders defer to these in the client-side picker, so the shared bodies must exist there too.
fnc_site_cluster = compile preprocessFileLineNumbers "duws\server\missions\fnc_site_cluster.sqf";publicVariable "fnc_site_cluster";
fnc_site_town = compile preprocessFileLineNumbers "duws\server\missions\fnc_site_town.sqf";publicVariable "fnc_site_town";
fnc_site_terrain = compile preprocessFileLineNumbers "duws\server\missions\fnc_site_terrain.sqf";publicVariable "fnc_site_terrain";
fnc_site_civ_town = compile preprocessFileLineNumbers "duws\server\missions\fnc_site_civ_town.sqf";publicVariable "fnc_site_civ_town";
fnc_score_placement = compile preprocessFileLineNumbers "duws\server\missions\fnc_score_placement.sqf";
// Broadcast: fnc_mission_findSite scores candidates through this inside the client-side picker.
fnc_offer_weight = compile preprocessFileLineNumbers "duws\server\missions\fnc_offer_weight.sqf";publicVariable "fnc_offer_weight";
fnc_mission_findSite = compile preprocessFileLineNumbers "duws\server\missions\fnc_mission_findSite.sqf";publicVariable "fnc_mission_findSite";
fnc_mission_end = compile preprocessFileLineNumbers "duws\server\missions\fnc_mission_end.sqf";
fnc_mission_timeout_notice = compile preprocessFileLineNumbers "duws\server\missions\fnc_mission_timeout_notice.sqf";
fnc_missionMarkerData = compile preprocessFileLineNumbers "duws\server\missions\fnc_missionMarkerData.sqf";
fnc_place_name = compile preprocessFileLineNumbers "duws\server\missions\fnc_place_name.sqf";
fnc_missionMarkerClear = compile preprocessFileLineNumbers "duws\server\missions\fnc_missionMarkerClear.sqf";
fnc_missionTaskCreate = compile preprocessFileLineNumbers "duws\server\missions\fnc_missionTaskCreate.sqf";
fnc_missionTaskEnd = compile preprocessFileLineNumbers "duws\server\missions\fnc_missionTaskEnd.sqf";
fnc_mission_present = compile preprocessFileLineNumbers "duws\server\missions\fnc_mission_present.sqf";
fnc_mission_finish = compile preprocessFileLineNumbers "duws\server\missions\fnc_mission_finish.sqf";
fnc_mission_watch = compile preprocessFileLineNumbers "duws\server\missions\fnc_mission_watch.sqf";
fnc_spawn_aid_crew = compile preprocessFileLineNumbers "duws\server\missions\fnc_spawn_aid_crew.sqf";
fnc_missionPatrols = compile preprocessFileLineNumbers "duws\server\missions\fnc_missionPatrols.sqf";
fnc_mission_cleanup = compile preprocessFileLineNumbers "duws\server\missions\fnc_mission_cleanup.sqf";
fnc_mission_notice = compile preprocessFileLineNumbers "duws\server\missions\fnc_mission_notice.sqf";
fnc_campaign_now = compile preprocessFileLineNumbers "duws\server\missions\fnc_campaign_now.sqf";
fnc_time_roll = compile preprocessFileLineNumbers "duws\server\missions\fnc_time_roll.sqf";
fnc_time_remaining = compile preprocessFileLineNumbers "duws\server\missions\fnc_time_remaining.sqf";
fnc_time_deadline = compile preprocessFileLineNumbers "duws\server\missions\fnc_time_deadline.sqf";
fnc_time_clock = compile preprocessFileLineNumbers "duws\server\missions\fnc_time_clock.sqf";
fnc_time_expired = compile preprocessFileLineNumbers "duws\server\missions\fnc_time_expired.sqf";
// Broadcast: the offer picker (fnc_stratmap) renders the band client-side; the journal task renders it server-side.
fnc_time_band = compile preprocessFileLineNumbers "duws\server\missions\fnc_time_band.sqf";publicVariable "fnc_time_band";
fnc_mission_begin = compile preprocessFileLineNumbers "duws\server\missions\fnc_mission_begin.sqf";
fnc_mission_claim = compile preprocessFileLineNumbers "duws\server\missions\fnc_mission_claim.sqf";
fnc_mission_dressing = compile preprocessFileLineNumbers "duws\server\missions\fnc_mission_dressing.sqf";
fnc_place_bunker_guns = compile preprocessFileLineNumbers "duws\server\missions\fnc_place_bunker_guns.sqf";
fnc_mission_safepos = compile preprocessFileLineNumbers "duws\server\missions\fnc_mission_safepos.sqf";
fnc_rescue_squad_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\rescue_squad\fnc_rescue_squad_mission.sqf";
// Broadcast: the finder runs client-side in the picker; else the squad-seating gate is lost to the generic.
fnc_rescue_squad_site = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\rescue_squad\fnc_rescue_squad_site.sqf";publicVariable "fnc_rescue_squad_site";
fnc_rescue_squad_success = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\rescue_squad\fnc_rescue_squad_success.sqf";
fnc_steal_supply_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\steal_supply\fnc_steal_supply_mission.sqf";
fnc_transport_IDAP_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\transport_idap\fnc_transport_IDAP_mission.sqf";
// Gates the offer on a neutral/BLUFOR town existing for the crew to wait in; runs client-side in the picker.
fnc_transport_IDAP_site = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\transport_idap\fnc_transport_IDAP_site.sqf";publicVariable "fnc_transport_IDAP_site";
fnc_target_hvt_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\target_hvt\fnc_target_hvt_mission.sqf";
// Broadcast: the site-finder runs client-side in the
// offer picker (fnc_stratmap), and it calls the destination picker, which calls fnc_route_has_water.
fnc_hvt_dest_pick = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\target_hvt\fnc_hvt_dest_pick.sqf";publicVariable "fnc_hvt_dest_pick";
fnc_target_hvt_site = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\target_hvt\fnc_target_hvt_site.sqf";publicVariable "fnc_target_hvt_site";
fnc_destroy_tower_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\destroy_tower\fnc_destroy_tower_mission.sqf";
// Broadcast: the site-finder runs client-side in the offer picker (fnc_stratmap), which gates the offer
// on a live RADIO hardpoint being in reach. Undefined on a non-host client, findSite falls back to the
// accept-all generic and the RADIO gate is silently lost.
fnc_destroy_tower_site = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\destroy_tower\fnc_destroy_tower_site.sqf";publicVariable "fnc_destroy_tower_site";
fnc_destroy_hardpoint_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\destroy_hardpoint\fnc_destroy_hardpoint_mission.sqf";
// Broadcast: the site-finder runs client-side in the offer picker (fnc_stratmap), which gates the offer
// on a live, revealed, destructible OPFOR hardpoint being in reach. Undefined on a non-host client,
// findSite falls back to the accept-all generic and the hardpoint gate is silently lost.
fnc_destroy_hardpoint_site = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\destroy_hardpoint\fnc_destroy_hardpoint_site.sqf";publicVariable "fnc_destroy_hardpoint_site";
fnc_capture_zone_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\capture_zone\fnc_capture_zone_mission.sqf";
// Broadcast: the finder runs client-side in the picker to enumerate the revealed OPFOR zones to target;
// without it a non-host client falls back to the accept-all generic and the enumerate is lost.
fnc_capture_zone_site = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\capture_zone\fnc_capture_zone_site.sqf";publicVariable "fnc_capture_zone_site";
fnc_rescue_pilot_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\rescue_pilot\fnc_rescue_pilot_mission.sqf";
fnc_target_sniper_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\target_sniper\fnc_target_sniper_mission.sqf";
fnc_target_recon_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\target_recon\fnc_target_recon_mission.sqf";
fnc_protect_civ_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\protect_civ\fnc_protect_civ.sqf";
// Broadcast: the finder runs client-side in the picker; else the building gate is lost to the generic.
fnc_protect_civ_site = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\protect_civ\fnc_protect_civ_site.sqf";publicVariable "fnc_protect_civ_site";
// Broadcast: the informant's Skip Prep Phase action remoteExecs this from clients.
fnc_protect_civ_skip = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\protect_civ\fnc_protect_civ_skip.sqf";publicVariable "fnc_protect_civ_skip";
// Broadcast: the informant's DEBUG: Skip Assault action remoteExecs this from clients.
fnc_protect_civ_skip_assault = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\protect_civ\fnc_protect_civ_skip_assault.sqf";publicVariable "fnc_protect_civ_skip_assault";
fnc_steal_builder_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\steal_builder\fnc_steal_builder_mission.sqf";
fnc_target_armor_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\target_armor\fnc_target_armor_mission.sqf";
fnc_deny_armor_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\deny_armor\fnc_deny_armor_mission.sqf";
fnc_sabotage_laptop_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\sabotage_laptop\fnc_sabotage_laptop_mission.sqf";
fnc_sabotage_laptop_success = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\sabotage_laptop\fnc_sabotage_laptop_success.sqf";
fnc_sabotage_laptop_decoy = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\sabotage_laptop\fnc_sabotage_laptop_decoy.sqf";
fnc_destroy_cache_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\destroy_cache\fnc_destroy_cache_mission.sqf";
fnc_destroy_radar_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\destroy_radar\fnc_destroy_radar_mission.sqf";
fnc_informant_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\informant\fnc_informant_mission.sqf";
publicVariable "fnc_informant_mission";
fnc_informant_site = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\informant\fnc_informant_site.sqf";publicVariable "fnc_informant_site";
fnc_informant_ask_addAction = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\informant\fnc_informant_ask_addAction.sqf";publicVariable "fnc_informant_ask_addAction";
fnc_informant_ask_request = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\informant\fnc_informant_ask_request.sqf";
fnc_informant_ask_reveal = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\informant\fnc_informant_ask_reveal.sqf";
fnc_recon_observe_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\recon\fnc_recon_observe_mission.sqf";
fnc_recon_observe_pick = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\recon\fnc_recon_observe_pick.sqf";publicVariable "fnc_recon_observe_pick";
fnc_recon_observe_site = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\recon\fnc_recon_observe_site.sqf";publicVariable "fnc_recon_observe_site";
fnc_recon_observe_success = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\recon\fnc_recon_observe_success.sqf";
fnc_destroy_patrol_camp_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\destroy_patrol_camp\fnc_destroy_patrol_camp_mission.sqf";
fnc_destroy_air_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\destroy_air\fnc_destroy_air_mission.sqf";
fnc_escort_informant_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\escort_informant\fnc_escort_informant_mission.sqf";
// Broadcast: the informant's Join/Leave Group actions remoteExec this from clients.
fnc_escort_informant_group = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\escort_informant\fnc_escort_informant_group.sqf";publicVariable "fnc_escort_informant_group";
fnc_deliver_supplies_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\deliver_supplies\fnc_deliver_supplies_mission.sqf";
fnc_raid_safehouse_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\raid_safehouse\fnc_raid_safehouse_mission.sqf";
// Broadcast: the site-finder runs client-side in the offer picker (fnc_stratmap); undefined there, findSite
// falls back to the accept-all generic and the door/cluster gate is silently lost.
fnc_raid_safehouse_site = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\raid_safehouse\fnc_raid_safehouse_site.sqf";publicVariable "fnc_raid_safehouse_site";
// Broadcast: adds the breach HitPart and the ask action on every client (remoteExec'd out from the thread).
fnc_raid_safehouse_arm = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\raid_safehouse\fnc_raid_safehouse_arm.sqf";publicVariable "fnc_raid_safehouse_arm";
fnc_raid_safehouse_ask_addAction = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\raid_safehouse\fnc_raid_safehouse_ask_addAction.sqf";publicVariable "fnc_raid_safehouse_ask_addAction";
fnc_raid_safehouse_ask_request = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\raid_safehouse\fnc_raid_safehouse_ask_request.sqf";
fnc_raid_safehouse_ask_reveal = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\raid_safehouse\fnc_raid_safehouse_ask_reveal.sqf";
fnc_raid_safehouse_breach = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\raid_safehouse\fnc_raid_safehouse_breach.sqf";
fnc_rescue_hostage_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\rescue_hostage\fnc_rescue_hostage_mission.sqf";
// Broadcast: the site-finder runs client-side in the offer picker (fnc_stratmap); undefined there, findSite
// falls back to the accept-all generic and the cluster / zone-standoff / side-held-town gate is silently lost.
fnc_rescue_hostage_site = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\rescue_hostage\fnc_rescue_hostage_site.sqf";publicVariable "fnc_rescue_hostage_site";
// The query is broadcast because a client is what calls it, and the
// two display halves because the server is what calls them back.
fnc_map_readout_query = compile preprocessFileLineNumbers "duws\server\missions\fnc_map_readout_query.sqf";
publicVariable "fnc_map_readout_query";
fnc_missionLocator = compile preprocessFileLineNumbers "duws\server\missions\fnc_missionLocator.sqf";publicVariable "fnc_missionLocator";
fnc_operative_mission_complete = compile preprocessFileLineNumbers "duws\server\missions\fnc_operative_mission_complete.sqf";publicVariable "fnc_operative_mission_complete";

// =========================================================================================================
// server/persistence
// =========================================================================================================
fnc_autoSave = compile preprocessFileLineNumbers "duws\server\persistence\fnc_autoSave.sqf";publicVariable "fnc_autoSave";

// =========================================================================================================
// server/placement
// =========================================================================================================
// The furnisher remoteExecs this to clients per piece, so it must reach them.
fnc_furnish_push_addAction = compile preprocessFileLineNumbers "duws\server\placement\fnc_furnish_push_addAction.sqf";publicVariable "fnc_furnish_push_addAction";
// The standing orders half of every spawner below, and of the base guards: a group is raised by one
// of them and ordered by this.
fnc_apply_posture = compile preprocessFileLineNumbers "duws\server\placement\fnc_apply_posture.sqf";
fnc_spawn_team = compile preprocessFileLineNumbers "duws\server\placement\fnc_spawn_team.sqf";
fnc_spawn_vehicle = compile preprocessFileLineNumbers "duws\server\placement\fnc_spawn_vehicle.sqf";

// =========================================================================================================
// server/search
// =========================================================================================================
fnc_search_drawKind = compile preprocessFileLineNumbers "duws\server\search\fnc_search_drawKind.sqf";
fnc_search_flag_group = compile preprocessFileLineNumbers "duws\server\search\fnc_search_flag_group.sqf";
fnc_search_claim = compile preprocessFileLineNumbers "duws\server\search\fnc_search_claim.sqf";
fnc_addRandomLoot = compile preprocessFileLineNumbers "duws\server\search\fnc_addRandomLoot.sqf";
publicVariable "fnc_addRandomLoot";
fnc_intel_payout = compile preprocessFileLineNumbers "duws\server\search\fnc_intel_payout.sqf";
fnc_intelAnalysis = compile preprocessFileLineNumbers "duws\server\search\fnc_intelAnalysis.sqf";
publicVariable "fnc_intelAnalysis";

// =========================================================================================================
// server/supports
// =========================================================================================================
fnc_support_perm_grant = compile preprocessFileLineNumbers "duws\server\supports\fnc_support_perm_grant.sqf";
fnc_fob_server = compile preprocessFileLineNumbers "duws\server\supports\fnc_fob_server.sqf";publicVariable "fnc_fob_server";
fnc_uav_scanner = compile preprocessFileLineNumbers "duws\server\supports\fnc_uav_scanner.sqf";publicVariable "fnc_uav_scanner";
fnc_sitrep_support = compile preprocessFileLineNumbers "duws\server\supports\fnc_sitrep_support.sqf";publicVariable "fnc_sitrep_support";
// Not broadcast: fnc_helolift only ever remoteExecs these to target 2, which resolves the
// name on the server, and every one of them needs the helo group local to run at all.
fnc_helolift_spawnHeli = compile preprocessFileLineNumbers "duws\server\supports\fnc_helolift_spawnHeli.sqf";
fnc_helolift_ropes = compile preprocessFileLineNumbers "duws\server\supports\fnc_helolift_ropes.sqf";
fnc_helolift_waypoints = compile preprocessFileLineNumbers "duws\server\supports\fnc_helolift_waypoints.sqf";
fnc_sitrep_fanout = compile preprocessFileLineNumbers "duws\server\supports\fnc_sitrep_fanout.sqf";
fnc_delete_napalm = compile preprocessFileLineNumbers "duws\server\supports\fnc_delete_napalm.sqf";publicVariable "fnc_delete_napalm";
fnc_activateBaseRecycleStation = compile preprocessFileLineNumbers "duws\server\supports\fnc_activateBaseRecycleStation.sqf";
publicVariable "fnc_activateBaseRecycleStation";
fnc_activateBaseRepairStation = compile preprocessFileLineNumbers "duws\server\supports\fnc_activateBaseRepairStation.sqf";
publicVariable "fnc_activateBaseRepairStation";
fnc_apocalypse_buildings = compile preprocessFileLineNumbers "duws\server\supports\fnc_apocalypse_buildings.sqf";
publicVariable "fnc_apocalypse_buildings";

// =========================================================================================================
// server/warcom
// =========================================================================================================
fnc_init_OPFOR_WARCOM = compile preprocessFileLineNumbers "duws\server\warcom\fnc_init_OPFOR_WARCOM.sqf";
fnc_OPFOR_faction_init = compile preprocessFileLineNumbers "duws\server\warcom\fnc_OPFOR_faction_init.sqf";
// Broadcast: clients re-run the faction file for themselves on join and have to re-apply over it.
fnc_faction_apply_locked = compile preprocessFileLineNumbers "duws\server\warcom\fnc_faction_apply_locked.sqf";publicVariable "fnc_faction_apply_locked";
fnc_AI_Master_Control = compile preprocessFileLineNumbers "duws\server\warcom\fnc_AI_Master_Control.sqf";
fnc_escalation = compile preprocessFileLineNumbers "duws\server\warcom\fnc_escalation.sqf";
// Broadcast: fnc_escalation arms this on every machine (BuildingChanged is a local event) so a
// building a client razed still reaches the server-side counter.
fnc_escalation_watch = compile preprocessFileLineNumbers "duws\server\warcom\fnc_escalation_watch.sqf"; publicVariable "fnc_escalation_watch";
fnc_WARCOM_init = compile preprocessFileLineNumbers "duws\server\warcom\fnc_WARCOM_init.sqf";
fnc_WARCOM_opf_hardpoints = compile preprocessFileLineNumbers "duws\server\warcom\fnc_WARCOM_opf_hardpoints.sqf";
fnc_opcom_belief_init = compile preprocessFileLineNumbers "duws\server\warcom\opcom\belief\fnc_opcom_belief_init.sqf";
fnc_opcom_belief_upsert = compile preprocessFileLineNumbers "duws\server\warcom\opcom\belief\fnc_opcom_belief_upsert.sqf";
fnc_opcom_belief_deleteAt = compile preprocessFileLineNumbers "duws\server\warcom\opcom\belief\fnc_opcom_belief_deleteAt.sqf";
fnc_opcom_sense = compile preprocessFileLineNumbers "duws\server\warcom\opcom\belief\fnc_opcom_sense.sqf";
fnc_opcom_recon_sense = compile preprocessFileLineNumbers "duws\server\warcom\opcom\belief\fnc_opcom_recon_sense.sqf";
fnc_opcom_decay = compile preprocessFileLineNumbers "duws\server\warcom\opcom\belief\fnc_opcom_decay.sqf";
fnc_opcom_belief_prune = compile preprocessFileLineNumbers "duws\server\warcom\opcom\belief\fnc_opcom_belief_prune.sqf";
fnc_opcom_grid_init = compile preprocessFileLineNumbers "duws\server\warcom\opcom\belief\fnc_opcom_grid_init.sqf";
fnc_opcom_grid_rebuild = compile preprocessFileLineNumbers "duws\server\warcom\opcom\belief\fnc_opcom_grid_rebuild.sqf";
fnc_opcom_cover_stamp = compile preprocessFileLineNumbers "duws\server\warcom\opcom\belief\fnc_opcom_cover_stamp.sqf";
fnc_opcom_cover_clear = compile preprocessFileLineNumbers "duws\server\warcom\opcom\belief\fnc_opcom_cover_clear.sqf";
fnc_opcom_perception_run = compile preprocessFileLineNumbers "duws\server\warcom\opcom\belief\fnc_opcom_perception_run.sqf";
fnc_opcom_tasking_init = compile preprocessFileLineNumbers "duws\server\warcom\opcom\taskings\fnc_opcom_tasking_init.sqf";
fnc_opcom_route = compile preprocessFileLineNumbers "duws\server\warcom\opcom\taskings\fnc_opcom_route.sqf";
fnc_opcom_recruit = compile preprocessFileLineNumbers "duws\server\warcom\opcom\taskings\fnc_opcom_recruit.sqf";
fnc_opcom_task = compile preprocessFileLineNumbers "duws\server\warcom\opcom\taskings\fnc_opcom_task.sqf";
fnc_opcom_task_step = compile preprocessFileLineNumbers "duws\server\warcom\opcom\taskings\fnc_opcom_task_step.sqf";
fnc_opcom_debug_task = compile preprocessFileLineNumbers "duws\server\warcom\opcom\taskings\fnc_opcom_debug_task.sqf";
fnc_zonesundercontrol = compile preprocessFileLineNumbers "duws\server\warcom\fnc_zonesundercontrol.sqf";
// Server-only: remoteExec'd to 2 by the OPCOM debug view, it gathers the AoI reach circles and hands
// them back to the caller to draw. Read-only, so an accidental client call fails loud, not harmfully.
fnc_debug_aoi_circles = compile preprocessFileLineNumbers "duws\server\warcom\fnc_debug_aoi_circles.sqf";

// =========================================================================================================
// client/arsenal
// =========================================================================================================
fnc_ai_rearm = compile preprocessFileLineNumbers "duws\client\arsenal\fnc_ai_rearm.sqf";publicVariable "fnc_ai_rearm";
fnc_duws_Arsenal = compile preprocessFileLineNumbers "duws\client\arsenal\fnc_duws_Arsenal.sqf";publicVariable "fnc_duws_Arsenal";
fnc_quick_kits_menu = compile preprocessFileLineNumbers "duws\client\arsenal\fnc_quick_kits_menu.sqf";
publicVariable "fnc_quick_kits_menu";

// =========================================================================================================
// client/chatter
// =========================================================================================================
fnc_duws_dialogue_channel = compile preprocessFileLineNumbers "duws\client\chatter\fnc_duws_dialogue_channel.sqf";
publicVariable "fnc_duws_dialogue_channel";
fnc_duws_dialogue = compile preprocessFileLineNumbers "duws\client\chatter\fnc_duws_dialogue.sqf";publicVariable "fnc_duws_dialogue";
fnc_duws_subnet_log = compile preprocessFileLineNumbers "duws\client\chatter\fnc_duws_subnet_log.sqf";publicVariable "fnc_duws_subnet_log";
fnc_duws_subnet_render = compile preprocessFileLineNumbers "duws\client\chatter\fnc_duws_subnet_render.sqf";publicVariable "fnc_duws_subnet_render";
fnc_duws_dialogue_drain = compile preprocessFileLineNumbers "duws\client\chatter\fnc_duws_dialogue_drain.sqf";publicVariable "fnc_duws_dialogue_drain";

// =========================================================================================================
// client/debug
// =========================================================================================================
fnc_debug_menu = compile preprocessFileLineNumbers "duws\client\debug\fnc_debug_menu.sqf";publicVariable "fnc_debug_menu";
fnc_debug_quickstart = compile preprocessFileLineNumbers "duws\client\debug\fnc_debug_quickstart.sqf";publicVariable "fnc_debug_quickstart";
fnc_debug_econ_menu = compile preprocessFileLineNumbers "duws\client\debug\fnc_debug_econ_menu.sqf";publicVariable "fnc_debug_econ_menu";
fnc_debug_econ_fill = compile preprocessFileLineNumbers "duws\client\debug\fnc_debug_econ_fill.sqf";publicVariable "fnc_debug_econ_fill";
fnc_debug_mission_menu = compile preprocessFileLineNumbers "duws\client\debug\fnc_debug_mission_menu.sqf";publicVariable "fnc_debug_mission_menu";
fnc_debug_hardpoint_menu = compile preprocessFileLineNumbers "duws\client\debug\fnc_debug_hardpoint_menu.sqf";publicVariable "fnc_debug_hardpoint_menu";
fnc_debug_random_event_menu = compile preprocessFileLineNumbers "duws\client\debug\fnc_debug_random_event_menu.sqf";publicVariable "fnc_debug_random_event_menu";
// Broadcast: each view is a menu-row handler every
// client holds, and the server remoteExecs the callback back to whichever client asked.
fnc_debug_opcom_view = compile preprocessFileLineNumbers "duws\client\debug\fnc_debug_opcom_view.sqf";publicVariable "fnc_debug_opcom_view";
fnc_debug_aoi_view = compile preprocessFileLineNumbers "duws\client\debug\fnc_debug_aoi_view.sqf";publicVariable "fnc_debug_aoi_view";
fnc_debug_aoi_draw = compile preprocessFileLineNumbers "duws\client\debug\fnc_debug_aoi_draw.sqf";publicVariable "fnc_debug_aoi_draw";
fnc_debug_opcom_grid_draw = compile preprocessFileLineNumbers "duws\client\debug\fnc_debug_opcom_grid_draw.sqf";publicVariable "fnc_debug_opcom_grid_draw";
// Broadcast so a client can open them, then remoteExec fnc_debug_opcom back.
fnc_debug_opcom_menu = compile preprocessFileLineNumbers "duws\client\debug\fnc_debug_opcom_menu.sqf";publicVariable "fnc_debug_opcom_menu";
fnc_debug_opcom_pick = compile preprocessFileLineNumbers "duws\client\debug\fnc_debug_opcom_pick.sqf";publicVariable "fnc_debug_opcom_pick";
fnc_debug_opcom_step = compile preprocessFileLineNumbers "duws\client\debug\fnc_debug_opcom_step.sqf";publicVariable "fnc_debug_opcom_step";
fnc_debug_search_menu = compile preprocessFileLineNumbers "duws\client\debug\fnc_debug_search_menu.sqf";publicVariable "fnc_debug_search_menu";
fnc_debug_furnish_menu = compile preprocessFileLineNumbers "duws\client\debug\fnc_debug_furnish_menu.sqf";publicVariable "fnc_debug_furnish_menu";
// The view/draw/calibrate handlers are broadcast
// (menu-row handlers every client holds; the server remoteExecs the draw back to the asker); the gather
// and calibrate-spawn are server-only, remoteExec'd to 2.
fnc_debug_furnish_view = compile preprocessFileLineNumbers "duws\client\debug\fnc_debug_furnish_view.sqf";publicVariable "fnc_debug_furnish_view";
fnc_debug_furnish_grid_draw = compile preprocessFileLineNumbers "duws\client\debug\fnc_debug_furnish_grid_draw.sqf";publicVariable "fnc_debug_furnish_grid_draw";
fnc_debug_furnish_calibrate = compile preprocessFileLineNumbers "duws\client\debug\fnc_debug_furnish_calibrate.sqf";publicVariable "fnc_debug_furnish_calibrate";

// =========================================================================================================
// client/dialog
// =========================================================================================================
fnc_civ_menu = compile preprocessFileLineNumbers "duws\client\dialog\fnc_civ_menu.sqf";
publicVariable "fnc_civ_menu";
fnc_civ_bribe_prompt = compile preprocessFileLineNumbers "duws\client\dialog\fnc_civ_bribe_prompt.sqf";
publicVariable "fnc_civ_bribe_prompt";
fnc_HQ_faction_dialog = compile preprocessFileLineNumbers "duws\client\dialog\fnc_HQ_faction_dialog.sqf";publicVariable "fnc_HQ_faction_dialog";
fnc_HQ_manual_place = compile preprocessFileLineNumbers "duws\client\dialog\fnc_HQ_manual_place.sqf";publicVariable "fnc_HQ_manual_place";
fnc_HQ_random_place = compile preprocessFileLineNumbers "duws\client\dialog\fnc_HQ_random_place.sqf";publicVariable "fnc_HQ_random_place";
fnc_HQ_placement_finish = compile preprocessFileLineNumbers "duws\client\dialog\fnc_HQ_placement_finish.sqf";publicVariable "fnc_HQ_placement_finish";
fnc_map_prompt = compile preprocessFileLineNumbers "duws\client\dialog\fnc_map_prompt.sqf";publicVariable "fnc_map_prompt";
fnc_map_pick_pos = compile preprocessFileLineNumbers "duws\client\dialog\fnc_map_pick_pos.sqf";publicVariable "fnc_map_pick_pos";
fnc_enviro_menu = compile preprocessFileLineNumbers "duws\client\dialog\fnc_enviro_menu.sqf";publicVariable "fnc_enviro_menu";
fnc_campaign_menu = compile preprocessFileLineNumbers "duws\client\dialog\fnc_campaign_menu.sqf";publicVariable "fnc_campaign_menu";
fnc_startup_preset_apply = compile preprocessFileLineNumbers "duws\client\dialog\fnc_startup_preset_apply.sqf";publicVariable "fnc_startup_preset_apply";
fnc_process_campaign_menu = compile preprocessFileLineNumbers "duws\client\dialog\fnc_process_campaign_menu.sqf";publicVariable "fnc_process_campaign_menu";
fnc_callsign_menu = compile preprocessFileLineNumbers "duws\client\dialog\fnc_callsign_menu.sqf";publicVariable "fnc_callsign_menu";
fnc_callsign_back = compile preprocessFileLineNumbers "duws\client\dialog\fnc_callsign_back.sqf";publicVariable "fnc_callsign_back";
fnc_callsign_confirm = compile preprocessFileLineNumbers "duws\client\dialog\fnc_callsign_confirm.sqf";publicVariable "fnc_callsign_confirm";
fnc_process_enviro_menu = compile preprocessFileLineNumbers "duws\client\dialog\fnc_process_enviro_menu.sqf";publicVariable "fnc_process_enviro_menu";
fnc_startup_closed = compile preprocessFileLineNumbers "duws\client\dialog\fnc_startup_closed.sqf";publicVariable "fnc_startup_closed";
fnc_startup_next = compile preprocessFileLineNumbers "duws\client\dialog\fnc_startup_next.sqf";publicVariable "fnc_startup_next";
fnc_startup_back = compile preprocessFileLineNumbers "duws\client\dialog\fnc_startup_back.sqf";publicVariable "fnc_startup_back";
fnc_startup_faction_flow = compile preprocessFileLineNumbers "duws\client\dialog\fnc_startup_faction_flow.sqf";publicVariable "fnc_startup_faction_flow";
fnc_startup_faction_resolve = compile preprocessFileLineNumbers "duws\client\dialog\fnc_startup_faction_resolve.sqf";publicVariable "fnc_startup_faction_resolve";
fnc_hq_placement = compile preprocessFileLineNumbers "duws\client\dialog\fnc_hq_placement.sqf";publicVariable "fnc_hq_placement";
fnc_faction_confirm = compile preprocessFileLineNumbers "duws\client\dialog\fnc_faction_confirm.sqf";publicVariable "fnc_faction_confirm";
fnc_faction_confirm_rows = compile preprocessFileLineNumbers "duws\client\dialog\fnc_faction_confirm_rows.sqf";publicVariable "fnc_faction_confirm_rows";
fnc_faction_row_paint = compile preprocessFileLineNumbers "duws\client\dialog\fnc_faction_row_paint.sqf";publicVariable "fnc_faction_row_paint";
fnc_faction_key_edit = compile preprocessFileLineNumbers "duws\client\dialog\fnc_faction_key_edit.sqf";publicVariable "fnc_faction_key_edit";
fnc_faction_key_apply = compile preprocessFileLineNumbers "duws\client\dialog\fnc_faction_key_apply.sqf";publicVariable "fnc_faction_key_apply";
fnc_enviro_back = compile preprocessFileLineNumbers "duws\client\dialog\fnc_enviro_back.sqf";publicVariable "fnc_enviro_back";
fnc_startup_enviro_closed = compile preprocessFileLineNumbers "duws\client\dialog\fnc_startup_enviro_closed.sqf";publicVariable "fnc_startup_enviro_closed";
fnc_request_unit = compile preprocessFileLineNumbers "duws\client\dialog\fnc_request_unit.sqf";publicVariable "fnc_request_unit";
fnc_request_squad = compile preprocessFileLineNumbers "duws\client\dialog\fnc_request_squad.sqf";publicVariable "fnc_request_squad";
fnc_request_vehicle = compile preprocessFileLineNumbers "duws\client\dialog\fnc_request_vehicle.sqf";publicVariable "fnc_request_vehicle";
fnc_request_support = compile preprocessFileLineNumbers "duws\client\dialog\fnc_request_support.sqf";publicVariable "fnc_request_support";
fnc_support_list_fill = compile preprocessFileLineNumbers "duws\client\dialog\fnc_support_list_fill.sqf";publicVariable "fnc_support_list_fill";
fnc_support_sel_changed = compile preprocessFileLineNumbers "duws\client\dialog\fnc_support_sel_changed.sqf";publicVariable "fnc_support_sel_changed";
fnc_custom_faction_capture = compile preprocessFileLineNumbers "duws\client\dialog\fnc_custom_faction_capture.sqf";publicVariable "fnc_custom_faction_capture";
fnc_request_menu = compile preprocessFileLineNumbers "duws\client\dialog\fnc_request_menu.sqf";publicVariable "fnc_request_menu";
fnc_request_map_view = compile preprocessFileLineNumbers "duws\client\dialog\fnc_request_map_view.sqf";publicVariable "fnc_request_map_view";
fnc_command_fill = compile preprocessFileLineNumbers "duws\client\dialog\fnc_command_fill.sqf";publicVariable "fnc_command_fill";
fnc_command_select = compile preprocessFileLineNumbers "duws\client\dialog\fnc_command_select.sqf";publicVariable "fnc_command_select";
fnc_squad_manage = compile preprocessFileLineNumbers "duws\client\dialog\fnc_squad_manage.sqf";publicVariable "fnc_squad_manage";
fnc_open_action_menu = compile preprocessFileLineNumbers "duws\client\dialog\fnc_open_action_menu.sqf";publicVariable "fnc_open_action_menu";
fnc_user_options_menu = compile preprocessFileLineNumbers "duws\client\dialog\fnc_user_options_menu.sqf";publicVariable "fnc_user_options_menu";
fnc_no_gm_prompt = compile preprocessFileLineNumbers "duws\client\dialog\fnc_no_gm_prompt.sqf";publicVariable "fnc_no_gm_prompt";
fnc_disguise_menu = compile preprocessFileLineNumbers "duws\client\dialog\fnc_disguise_menu.sqf";publicVariable "fnc_disguise_menu";
fnc_dismissHC = compile preprocessFileLineNumbers "duws\client\dialog\fnc_dismissHC.sqf";publicVariable "fnc_dismissHC";
fnc_dismiss_playerAI = compile preprocessFileLineNumbers "duws\client\dialog\fnc_dismiss_playerAI.sqf";publicVariable "fnc_dismiss_playerAI";
fnc_squad_rename = compile preprocessFileLineNumbers "duws\client\dialog\fnc_squad_rename.sqf";publicVariable "fnc_squad_rename";
fnc_groupReset = compile preprocessFileLineNumbers "duws\client\dialog\fnc_groupReset.sqf";publicVariable "fnc_groupReset";
fnc_rest_menu = compile preprocessFileLineNumbers "duws\client\dialog\fnc_rest_menu.sqf";publicVariable "fnc_rest_menu";
fnc_FOBmanager = compile preprocessFileLineNumbers "duws\client\dialog\fnc_FOBmanager.sqf";publicVariable "fnc_FOBmanager";
fnc_FOB_remove = compile preprocessFileLineNumbers "duws\client\dialog\fnc_FOB_remove.sqf";publicVariable "fnc_FOB_remove";
fnc_FOB_fast_travel = compile preprocessFileLineNumbers "duws\client\dialog\fnc_FOB_fast_travel.sqf";publicVariable "fnc_FOB_fast_travel";
fnc_MHQ_select = compile preprocessFileLineNumbers "duws\client\dialog\fnc_MHQ_select.sqf";publicVariable "fnc_MHQ_select";
fnc_vehicle_depot_menu = compile preprocessFileLineNumbers "duws\client\dialog\fnc_vehicle_depot_menu.sqf";
publicVariable "fnc_vehicle_depot_menu";
fnc_depot_menu_fill = compile preprocessFileLineNumbers "duws\client\dialog\fnc_depot_menu_fill.sqf";
publicVariable "fnc_depot_menu_fill";
fnc_depot_recycle_confirm = compile preprocessFileLineNumbers "duws\client\dialog\fnc_depot_recycle_confirm.sqf";
publicVariable "fnc_depot_recycle_confirm";
fnc_depot_repair_confirm = compile preprocessFileLineNumbers "duws\client\dialog\fnc_depot_repair_confirm.sqf";
publicVariable "fnc_depot_repair_confirm";
fnc_depot_retrieve = compile preprocessFileLineNumbers "duws\client\dialog\fnc_depot_retrieve.sqf";
publicVariable "fnc_depot_retrieve";
fnc_depot_place_r3f = compile preprocessFileLineNumbers "duws\client\dialog\fnc_depot_place_r3f.sqf";
publicVariable "fnc_depot_place_r3f";
fnc_veh_appearance_dialog = compile preprocessFileLineNumbers "duws\client\dialog\fnc_veh_appearance_dialog.sqf";
publicVariable "fnc_veh_appearance_dialog";
fnc_veh_pylons_dialog = compile preprocessFileLineNumbers "duws\client\dialog\fnc_veh_pylons_dialog.sqf";
publicVariable "fnc_veh_pylons_dialog";

// =========================================================================================================
// client/events
// =========================================================================================================
fnc_random_event_ied_markers = compile preprocessFileLineNumbers "duws\client\events\fnc_random_event_ied_markers.sqf";
publicVariable "fnc_random_event_ied_markers";

// =========================================================================================================
// client/init_hq
// =========================================================================================================
fnc_addBoardKillhouseActions = compile preprocessFileLineNumbers "duws\client\init_hq\fnc_addBoardKillhouseActions.sqf";
publicVariable "fnc_addBoardKillhouseActions";
// Broadcast: it is the FOB redeploy action's function value, so every client needs it.
fnc_redeployFOB = compile preprocessFileLineNumbers "duws\client\init_hq\fnc_redeployFOB.sqf";publicVariable "fnc_redeployFOB";
fnc_HQaddactions = compile preprocessFileLineNumbers "duws\client\init_hq\fnc_HQaddactions.sqf";publicVariable "fnc_HQaddactions";

// =========================================================================================================
// client/killhouse
// =========================================================================================================
fnc_killhouse_markers = compile preprocessFileLineNumbers "duws\client\killhouse\fnc_killhouse_markers.sqf";
publicVariable "fnc_killhouse_markers";

// =========================================================================================================
// client/misc
// =========================================================================================================
fnc_ghst_halo = compile preprocessFileLineNumbers "duws\client\misc\fnc_ghst_halo.sqf";publicVariable "fnc_ghst_halo";
fnc_addHQBuildingActions = compile preprocessFileLineNumbers "duws\client\misc\fnc_addHQBuildingActions.sqf";
publicVariable "fnc_addHQBuildingActions";
fnc_draw_world_icons = compile preprocessFileLineNumbers "duws\client\misc\fnc_draw_world_icons.sqf";publicVariable "fnc_draw_world_icons";
fnc_hc_init = compile preprocessFileLineNumbers "duws\client\misc\fnc_hc_init.sqf";publicVariable "fnc_hc_init";
fnc_kndr_unit_markers = compile preprocessFileLineNumbers "duws\client\misc\fnc_kndr_unit_markers.sqf";publicVariable "fnc_kndr_unit_markers";
fnc_player_markers = compile preprocessFileLineNumbers "duws\client\misc\fnc_player_markers.sqf";publicVariable "fnc_player_markers";
fnc_earplugs = compile preprocessFileLineNumbers "duws\client\misc\fnc_earplugs.sqf";publicVariable "fnc_earplugs";
fnc_duws_help = compile preprocessFileLineNumbers "duws\client\misc\fnc_duws_help.sqf";publicVariable "fnc_duws_help";
fnc_duws_config = compile preprocessFileLineNumbers "duws\client\misc\fnc_duws_config.sqf";publicVariable "fnc_duws_config";
fnc_bottom_right_message = compile preprocessFileLineNumbers "duws\client\misc\fnc_bottom_right_message.sqf";publicVariable "fnc_bottom_right_message";
fnc_addQuickChangeActions = compile preprocessFileLineNumbers "duws\client\misc\fnc_addQuickChangeActions.sqf";
publicVariable "fnc_addQuickChangeActions";

// =========================================================================================================
// client/missions
// =========================================================================================================
fnc_sabotage_laptop_markers = compile preprocessFileLineNumbers "duws\client\missions\fnc_sabotage_laptop_markers.sqf";
publicVariable "fnc_sabotage_laptop_markers";
fnc_protect_civ_markers = compile preprocessFileLineNumbers "duws\client\missions\fnc_protect_civ_markers.sqf";
publicVariable "fnc_protect_civ_markers";
fnc_recon_observe_layer = compile preprocessFileLineNumbers "duws\client\missions\fnc_recon_observe_layer.sqf";publicVariable "fnc_recon_observe_layer";
fnc_stealth_layer = compile preprocessFileLineNumbers "duws\client\missions\fnc_stealth_layer.sqf";publicVariable "fnc_stealth_layer";
fnc_map_readout_draw = compile preprocessFileLineNumbers "duws\client\missions\fnc_map_readout_draw.sqf";
publicVariable "fnc_map_readout_draw";
fnc_map_readout_open = compile preprocessFileLineNumbers "duws\client\missions\fnc_map_readout_open.sqf";
publicVariable "fnc_map_readout_open";
fnc_stratmap = compile preprocessFileLineNumbers "duws\client\missions\fnc_stratmap.sqf";publicVariable "fnc_stratmap";
// Broadcast: the strategic map's mission blocks call it on whoever opened the map.
fnc_mission_launch = compile preprocessFileLineNumbers "duws\client\missions\fnc_mission_launch.sqf";publicVariable "fnc_mission_launch";

// =========================================================================================================
// client/operative
// =========================================================================================================
fnc_lbselected = compile preprocessFileLineNumbers "duws\client\operative\fnc_lbselected.sqf";publicVariable "fnc_lbselected";
fnc_operator_init = compile preprocessFileLineNumbers "duws\client\operative\fnc_operator_init.sqf";publicVariable "fnc_operator_init";
fnc_operator_open = compile preprocessFileLineNumbers "duws\client\operative\fnc_operator_open.sqf";publicVariable "fnc_operator_open";
fnc_operator_recruit = compile preprocessFileLineNumbers "duws\client\operative\fnc_operator_recruit.sqf";publicVariable "fnc_operator_recruit";

// =========================================================================================================
// client/search
// =========================================================================================================
fnc_intel_search_action = compile preprocessFileLineNumbers "duws\client\search\fnc_intel_search_action.sqf";publicVariable "fnc_intel_search_action";
fnc_search_pick = compile preprocessFileLineNumbers "duws\client\search\fnc_search_pick.sqf";publicVariable "fnc_search_pick";

// =========================================================================================================
// client/supports
// =========================================================================================================
fnc_ammobox = compile preprocessFileLineNumbers "duws\client\supports\fnc_ammobox.sqf";publicVariable "fnc_ammobox";
fnc_arty = compile preprocessFileLineNumbers "duws\client\supports\fnc_arty.sqf";publicVariable "fnc_arty";
fnc_mapclickarty = compile preprocessFileLineNumbers "duws\client\supports\fnc_mapclickarty.sqf";publicVariable "fnc_mapclickarty";
fnc_mapclickuav = compile preprocessFileLineNumbers "duws\client\supports\fnc_mapclickuav.sqf";publicVariable "fnc_mapclickuav";
fnc_spawn_delivery_transport = compile preprocessFileLineNumbers "duws\client\supports\fnc_spawn_delivery_transport.sqf";publicVariable "fnc_spawn_delivery_transport";
fnc_paradrop = compile preprocessFileLineNumbers "duws\client\supports\fnc_paradrop.sqf";publicVariable "fnc_paradrop";
fnc_request_fob = compile preprocessFileLineNumbers "duws\client\supports\fnc_request_fob.sqf";publicVariable "fnc_request_fob";
fnc_hcair_sortie = compile preprocessFileLineNumbers "duws\client\supports\fnc_hcair_sortie.sqf";publicVariable "fnc_hcair_sortie";
fnc_request_hcATTchop = compile preprocessFileLineNumbers "duws\client\supports\fnc_request_hcATTchop.sqf";publicVariable "fnc_request_hcATTchop";
fnc_request_hcCAS = compile preprocessFileLineNumbers "duws\client\supports\fnc_request_hcCAS.sqf";publicVariable "fnc_request_hcCAS";
fnc_veh_drop = compile preprocessFileLineNumbers "duws\client\supports\fnc_veh_drop.sqf";publicVariable "fnc_veh_drop";
fnc_helotaxi = compile preprocessFileLineNumbers "duws\client\supports\taxi\fnc_helotaxi.sqf";publicVariable "fnc_helotaxi";
fnc_helolift = compile preprocessFileLineNumbers "duws\client\supports\fnc_helolift.sqf";publicVariable "fnc_helolift";
fnc_mapclicklift = compile preprocessFileLineNumbers "duws\client\supports\fnc_mapclicklift.sqf";publicVariable "fnc_mapclicklift";
fnc_mapclickhelo = compile preprocessFileLineNumbers "duws\client\supports\taxi\fnc_mapclickhelo.sqf";publicVariable "fnc_mapclickhelo";
fnc_boattaxi = compile preprocessFileLineNumbers "duws\client\supports\taxi\fnc_boattaxi.sqf";publicVariable "fnc_boattaxi";
fnc_mapclickboat = compile preprocessFileLineNumbers "duws\client\supports\taxi\fnc_mapclickboat.sqf";publicVariable "fnc_mapclickboat";
fnc_taxi_music = compile preprocessFileLineNumbers "duws\client\supports\taxi\fnc_taxi_music.sqf";publicVariable "fnc_taxi_music";
// Broadcast because every one of these is client-side -- the action registration, the dialog
// opener and fill, the recycle confirmation, and the two hoisted modification sub-dialogs the
// menu opens on the selected vehicle.
fnc_client_addDepotActions = compile preprocessFileLineNumbers "duws\client\supports\fnc_client_addDepotActions.sqf";
publicVariable "fnc_client_addDepotActions";

// =========================================================================================================
// client/warcom
// =========================================================================================================
fnc_fob_unlock_notice = compile preprocessFileLineNumbers "duws\client\warcom\fnc_fob_unlock_notice.sqf";publicVariable "fnc_fob_unlock_notice";
fnc_sitrep_display = compile preprocessFileLineNumbers "duws\client\warcom\fnc_sitrep_display.sqf";publicVariable "fnc_sitrep_display";

// =========================================================================================================
// shared/civ
// =========================================================================================================
fnc_civ_stopCommand = compile preprocessFileLineNumbers "duws\shared\civ\fnc_civ_stopCommand.sqf";
publicVariable "fnc_civ_stopCommand";
fnc_civ_release_action = compile preprocessFileLineNumbers "duws\shared\civ\fnc_civ_release_action.sqf";
publicVariable "fnc_civ_release_action";
// Broadcast: the spawn paths remoteExec it to every client to hang the civilian's actions.
fnc_civ_clientActions = compile preprocessFileLineNumbers "duws\shared\civ\fnc_civ_clientActions.sqf";
publicVariable "fnc_civ_clientActions";
fnc_civ_menuAction = compile preprocessFileLineNumbers "duws\shared\civ\fnc_civ_menuAction.sqf";
publicVariable "fnc_civ_menuAction";

// =========================================================================================================
// shared/faction_lib
// =========================================================================================================
fnc_factions_check = compile preprocessFileLineNumbers "duws\shared\faction_lib\fnc_factions_check_modern.sqf";
fnc_factionRoles = compile preprocessFileLineNumbers "duws\shared\faction_lib\fnc_factionRoles.sqf";
// Server only: pools are read only by the spawn paths, which are server-side.
fnc_faction_augment = compile preprocessFileLineNumbers "duws\shared\faction_lib\fnc_faction_augment.sqf";
// The two AutoDetect wrappers and fnc_custom_faction_parse build their key lists from it. Broadcast
// because the confirmation screen builds its rows from it client-side.
fnc_faction_schema = compile preprocessFileLineNumbers "duws\shared\faction_lib\fnc_faction_schema.sqf";publicVariable "fnc_faction_schema";
fnc_custom_faction_parse = compile preprocessFileLineNumbers "duws\shared\faction_lib\fnc_custom_faction_parse.sqf";publicVariable "fnc_custom_faction_parse";
// Broadcast: both request menus and all four request handlers are client-side.
fnc_faction_rqst_list = compile preprocessFileLineNumbers "duws\shared\faction_lib\fnc_faction_rqst_list.sqf";publicVariable "fnc_faction_rqst_list";
fnc_faction_unit_keylist = compile preprocessFileLineNumbers "duws\shared\faction_lib\fnc_faction_unit_keylist.sqf";

// =========================================================================================================
// shared/functions
// =========================================================================================================
// Shared with the client (the arsenal overlay's live-count loop); economy_init's settle and deposit
// call it too.
fnc_captured_loadout_counts = compile preprocessFileLineNumbers "duws\shared\functions\fnc_captured_loadout_counts.sqf";
fnc_cs = compile preprocessFileLineNumbers "duws\shared\functions\fnc_cs.sqf";
publicVariable "fnc_cs";
fnc_gm_occupant = compile preprocessFileLineNumbers "duws\shared\functions\fnc_gm_occupant.sqf";
publicVariable "fnc_gm_occupant";
fnc_mission_gate_left = compile preprocessFileLineNumbers "duws\shared\functions\fnc_mission_gate_left.sqf";publicVariable "fnc_mission_gate_left";
fnc_mission_gate_time = compile preprocessFileLineNumbers "duws\shared\functions\fnc_mission_gate_time.sqf";publicVariable "fnc_mission_gate_time";
fnc_pos_claimed = compile preprocessFileLineNumbers "duws\shared\functions\fnc_pos_claimed.sqf";publicVariable "fnc_pos_claimed";
fnc_in_base_keep = compile preprocessFileLineNumbers "duws\shared\functions\fnc_in_base_keep.sqf";publicVariable "fnc_in_base_keep";
fnc_house_doors = compile preprocessFileLineNumbers "duws\shared\functions\fnc_house_doors.sqf";publicVariable "fnc_house_doors";
fnc_house_door_pts = compile preprocessFileLineNumbers "duws\shared\functions\fnc_house_door_pts.sqf";publicVariable "fnc_house_door_pts";
// Broadcast: the layer and the helper it calls both run client-side, undefined there unless published.
fnc_stealth_coef = compile preprocessFileLineNumbers "duws\shared\functions\fnc_stealth_coef.sqf";publicVariable "fnc_stealth_coef";
fnc_recruit_civilian = compile preprocessFileLineNumbers "duws\shared\functions\fnc_recruit_civilian.sqf";
publicVariable "fnc_recruit_civilian";
fnc_addRecruitAction = compile preprocessFileLineNumbers "duws\shared\functions\fnc_addRecruitAction.sqf";
publicVariable "fnc_addRecruitAction";
fnc_random_name = compile preprocessFileLineNumbers "duws\shared\functions\fnc_random_name.sqf";publicVariable "fnc_random_name";
fnc_MHQ_addActions = compile preprocessFileLineNumbers "duws\shared\functions\fnc_MHQ_addActions.sqf";publicVariable "fnc_MHQ_addActions";
fnc_MHQ_destroyed = compile preprocessFileLineNumbers "duws\shared\functions\fnc_MHQ_destroyed.sqf";publicVariable "fnc_MHQ_destroyed";
fnc_FOBactions = compile preprocessFileLineNumbers "duws\shared\functions\fnc_FOBactions.sqf";publicVariable "fnc_FOBactions";
fnc_medtent_actions = compile preprocessFileLineNumbers "duws\shared\functions\fnc_medtent_actions.sqf";publicVariable "fnc_medtent_actions";
fnc_field_box_actions = compile preprocessFileLineNumbers "duws\shared\functions\fnc_field_box_actions.sqf";publicVariable "fnc_field_box_actions";
fnc_pos_near_enemy = compile preprocessFileLineNumbers "duws\shared\functions\fnc_pos_near_enemy.sqf";publicVariable "fnc_pos_near_enemy";
fnc_sightline_foliageClear = compile preprocessFileLineNumbers "duws\shared\functions\fnc_sightline_foliageClear.sqf";publicVariable "fnc_sightline_foliageClear";
fnc_duws_senior_name = compile preprocessFileLineNumbers "duws\shared\functions\fnc_duws_senior_name.sqf";publicVariable "fnc_duws_senior_name";

// =========================================================================================================
// REGISTRY SELF-CHECK
// =========================================================================================================

// Registry self-check. preprocessFile on a path that does not resolve returns "", which
// compiles to an empty {} and then no-ops at every call site with no error anywhere -- a
// mistyped or moved path is otherwise invisible until some later stage silently never
// happens. Runs once, right after the last entry above.
private _fncs = (allVariables missionNamespace) select {(_x select [0, 4]) == "fnc_"};
private _empty = _fncs select {
    private _v = missionNamespace getVariable _x;
    // An empty body stringifies to "" or "{}" depending on how it was produced; strip
    // whitespace and treat both as the missing-file signature.
    _v isEqualType {} && {((str _v) splitString " " joinString "") in ["", "{}"]}
};
["INFO", "REGISTRY", format ["%1 fnc_* defined", count _fncs]] call fnc_log;
if (count _empty > 0) then {
    ["ERROR", "REGISTRY", format ["%1 compiled EMPTY -- missing or unresolved file: %2",
        count _empty, _empty]] call fnc_log;
};
