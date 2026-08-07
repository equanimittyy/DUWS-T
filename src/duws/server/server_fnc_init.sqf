// Locality: server -- see callers.

// SERVER FUNCTIONS

[] call compile preprocessFileLineNumbers "duws\server\misc\fnc_economy_init.sqf";
publicVariable "fnc_escalation_cost";
publicVariable "fnc_coins_count";
publicVariable "fnc_coins_spend";
publicVariable "fnc_pool_spend";
publicVariable "fnc_pool_reply";
// Ahead of both state files below, which are its consumers: zones and towns share one attrition model.
[] call compile preprocessFileLineNumbers "duws\server\misc\fnc_garrison_strength_init.sqf";
// Ahead of them for the same reason: zones, towns and bases share one roster store.
[] call compile preprocessFileLineNumbers "duws\server\misc\fnc_site_stream_init.sqf";
[] call compile preprocessFileLineNumbers "duws\server\init_zones\fnc_zone_state_init.sqf";
fnc_fob_deregister = compile preprocessFileLineNumbers "duws\server\misc\fnc_fob_deregister.sqf";
[] call compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_state_init.sqf";
publicVariable "fnc_civ_moveToPlayerServer";
fnc_duws_bluforNear = compile preprocessFileLineNumbers "duws\server\misc\fnc_duws_bluforNear.sqf";
[] call compile preprocessFileLineNumbers "duws\server\supports\fnc_support_claim_init.sqf";
publicVariable "fnc_support_reply";
publicVariable "fnc_support_claim";
fnc_cs = compile preprocessFileLineNumbers "duws\shared\functions\fnc_cs.sqf";
publicVariable "fnc_cs";
fnc_duws_dialogue_channel = compile preprocessFileLineNumbers "duws\client\misc\fnc_duws_dialogue_channel.sqf";
publicVariable "fnc_duws_dialogue_channel";
[] call compile preprocessFileLineNumbers "duws\server\misc\fnc_composition_stream_init.sqf";
publicVariable "fnc_duws_disposeAfter";
publicVariable "fnc_duws_keep";
publicVariable "fnc_duws_release";
publicVariable "fnc_duws_stow";
publicVariable "fnc_duws_deploy";

// STARTUP FUNCTIONS
fnc_BluHQinit = compile preprocessFileLineNumbers "duws\server\init_hq\fnc_BluHQinit.sqf";
fnc_placeHQUnits = compile preprocessFileLineNumbers "duws\server\init_hq\fnc_placeHQUnits.sqf";
// Not broadcast: the client half of HQ placement reaches it by remoteExec to the server, which is
// the only machine allowed to hide a terrain object.
fnc_clear_foliage = compile preprocessFileLineNumbers "duws\server\misc\fnc_clear_foliage.sqf";
fnc_factions_check = compile preprocessFileLineNumbers "duws\server\misc\fnc_factions_check_modern.sqf";
fnc_intro_heli = compile preprocessFileLineNumbers "duws\server\misc\fnc_intro_heli.sqf";
publicVariable "fnc_intro_heli";
// SERVER INIT FUNCTIONS
fnc_init_OPFOR_WARCOM = compile preprocessFileLineNumbers "duws\server\warcom\fnc_init_OPFOR_WARCOM.sqf";
fnc_OPFOR_faction_init = compile preprocessFileLineNumbers "duws\server\warcom\fnc_OPFOR_faction_init.sqf";
// Broadcast: clients re-run the faction file for themselves on join and have to re-apply over it.
fnc_faction_apply_locked = compile preprocessFileLineNumbers "duws\server\warcom\fnc_faction_apply_locked.sqf";publicVariable "fnc_faction_apply_locked";
fnc_repetitive_cleanup = compile preprocessFileLineNumbers "duws\server\misc\fnc_repetitive_cleanup.sqf";
fnc_capture_zones_task = compile preprocessFileLineNumbers "duws\server\misc\fnc_capture_zones_task.sqf";
fnc_AI_Master_Control = compile preprocessFileLineNumbers "duws\server\misc\fnc_AI_Master_Control.sqf";
fnc_weather = compile preprocessFileLineNumbers "duws\server\dialog\fnc_weather.sqf";
fnc_zeus_objects_init = compile preprocessFileLineNumbers "duws\server\misc\fnc_zeus_objects_init.sqf";
fnc_usableBuildings = compile preprocessFileLineNumbers "duws\server\misc\fnc_usableBuildings.sqf";
fnc_factionRoles = compile preprocessFileLineNumbers "duws\server\misc\fnc_factionRoles.sqf";
fnc_holdBuildingPost = compile preprocessFileLineNumbers "duws\server\misc\fnc_holdBuildingPost.sqf";
fnc_spreadIntoBuildings = compile preprocessFileLineNumbers "duws\server\misc\fnc_spreadIntoBuildings.sqf";
fnc_search_drawKind = compile preprocessFileLineNumbers "duws\server\misc\fnc_search_drawKind.sqf";
fnc_search_flag_group = compile preprocessFileLineNumbers "duws\server\misc\fnc_search_flag_group.sqf";
fnc_search_dropItems = compile preprocessFileLineNumbers "duws\server\misc\fnc_search_dropItems.sqf";
fnc_search_claim = compile preprocessFileLineNumbers "duws\server\misc\fnc_search_claim.sqf";
fnc_garrisonBuildings = compile preprocessFileLineNumbers "duws\server\misc\fnc_garrisonBuildings.sqf";
fnc_fob_destroyed = compile preprocessFileLineNumbers "duws\server\misc\fnc_fob_destroyed.sqf";
// Not broadcast: it creates a global marker, so exactly one machine may run it.
fnc_baseRangeMarker = compile preprocessFileLineNumbers "duws\server\misc\fnc_baseRangeMarker.sqf";
// Not broadcast: it decides which players a base appearing is visible to, which only the server can.
fnc_baseFade = compile preprocessFileLineNumbers "duws\server\misc\fnc_baseFade.sqf";
fnc_create_ammo_lists = compile preprocessFileLineNumbers "duws\server\misc\fnc_create_ammo_lists.sqf";
fnc_basic_ammo_lists = compile preprocessFileLineNumbers "duws\server\misc\fnc_basic_ammo_lists.sqf";
fnc_escalation = compile preprocessFileLineNumbers "duws\server\misc\fnc_escalation.sqf";
fnc_civ_garrison = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_garrison.sqf";
fnc_opfor_count_at = compile preprocessFileLineNumbers "duws\server\misc\fnc_opfor_count_at.sqf";
// Not broadcast: read from the zone capture trigger's condition, and that trigger is created
// server-local precisely because this reads server-side zone state.
fnc_zone_capture_ready = compile preprocessFileLineNumbers "duws\server\init_zones\fnc_zone_capture_ready.sqf";
fnc_ai_rearm = compile preprocessFileLineNumbers "duws\client\misc\fnc_ai_rearm.sqf";publicVariable "fnc_ai_rearm";
fnc_addRandomLoot = compile preprocessFileLineNumbers "duws\server\misc\fnc_addRandomLoot.sqf";
publicVariable "fnc_addRandomLoot";
fnc_hirePartisans_spawnDeployed = compile preprocessFileLineNumbers "duws\server\misc\fnc_hirePartisans_spawnDeployed.sqf";
publicVariable "fnc_hirePartisans_spawnDeployed";
fnc_addBoardKillhouseActions = compile preprocessFileLineNumbers "duws\client\init_hq\fnc_addBoardKillhouseActions.sqf";
publicVariable "fnc_addBoardKillhouseActions";
fnc_killhouse_markers = compile preprocessFileLineNumbers "duws\client\misc\fnc_killhouse_markers.sqf";
publicVariable "fnc_killhouse_markers";
// SIDE MISSION FUNCTIONS
fnc_mission_reward = compile preprocessFileLineNumbers "duws\server\missions\fnc_mission_reward.sqf";
fnc_missionTargetPos = compile preprocessFileLineNumbers "duws\server\missions\fnc_missionTargetPos.sqf";
fnc_mission_abort = compile preprocessFileLineNumbers "duws\server\missions\fnc_mission_abort.sqf";
fnc_mission_site = compile preprocessFileLineNumbers "duws\server\missions\fnc_mission_site.sqf";
fnc_mission_end = compile preprocessFileLineNumbers "duws\server\missions\fnc_mission_end.sqf";
fnc_missionMarkerData = compile preprocessFileLineNumbers "duws\server\missions\fnc_missionMarkerData.sqf";
fnc_missionMarkerClear = compile preprocessFileLineNumbers "duws\server\missions\fnc_missionMarkerClear.sqf";
fnc_missionTaskCreate = compile preprocessFileLineNumbers "duws\server\missions\fnc_missionTaskCreate.sqf";
fnc_missionTaskEnd = compile preprocessFileLineNumbers "duws\server\missions\fnc_missionTaskEnd.sqf";
fnc_missionPatrols = compile preprocessFileLineNumbers "duws\server\missions\fnc_missionPatrols.sqf";
fnc_missionPatrolswithintel = compile preprocessFileLineNumbers "duws\server\missions\fnc_missionPatrolswithintel.sqf";
fnc_mission_cleanup = compile preprocessFileLineNumbers "duws\server\missions\fnc_mission_cleanup.sqf";
fnc_findSafeMissionPos = compile preprocessFileLineNumbers "duws\server\misc\fnc_findSafeMissionPos.sqf";
publicVariable "fnc_findSafeMissionPos";
fnc_mission_cooldown_left = compile preprocessFileLineNumbers "duws\shared\functions\fnc_mission_cooldown_left.sqf";publicVariable "fnc_mission_cooldown_left";
fnc_pos_claimed = compile preprocessFileLineNumbers "duws\shared\functions\fnc_pos_claimed.sqf";publicVariable "fnc_pos_claimed";
fnc_mission_cooldowns_show = compile preprocessFileLineNumbers "duws\client\misc\fnc_mission_cooldowns_show.sqf";publicVariable "fnc_mission_cooldowns_show";
fnc_mission_begin = compile preprocessFileLineNumbers "duws\server\missions\fnc_mission_begin.sqf";
fnc_mission_claim = compile preprocessFileLineNumbers "duws\server\missions\fnc_mission_claim.sqf";

// SIDE MISSION THREADS
fnc_rescue_squad_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\rescue_squad\fnc_rescue_squad_mission.sqf";
fnc_rescue_squad_success = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\rescue_squad\fnc_rescue_squad_success.sqf";
fnc_steal_supply_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\steal_supply\fnc_steal_supply_mission.sqf";
fnc_transport_IDAP_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\transport_idap\fnc_transport_IDAP_mission.sqf";
fnc_target_hvt_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\target_hvt\fnc_target_hvt_mission.sqf";
fnc_destroy_tower_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\destroy_tower\fnc_destroy_tower_mission.sqf";
fnc_rescue_pilot_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\rescue_pilot\fnc_rescue_pilot_mission.sqf";
fnc_target_sniper_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\target_sniper\fnc_target_sniper_mission.sqf";
fnc_domination_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\domination\fnc_domination_mission.sqf";
fnc_clearthearea_cqb_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\clearthearea_cqb\fnc_clearthearea_cqb_mission.sqf";
fnc_holdposition_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\holdpos\fnc_holdposition_mission.sqf";
fnc_protect_civ_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\protect_civ\fnc_protect_civ.sqf";
fnc_steal_builder_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\steal_builder\fnc_steal_builder_mission.sqf";
fnc_target_armor_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\target_armor\fnc_target_armor_mission.sqf";
fnc_sabotage_laptop_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\sabotage_laptop\fnc_sabotage_laptop_mission.sqf";
fnc_sabotage_laptop_success = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\sabotage_laptop\fnc_sabotage_laptop_success.sqf";
fnc_destroy_cache_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\destroy_cache\fnc_destroy_cache_mission.sqf";
fnc_destroy_radar_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\destroy_radar\fnc_destroy_radar_mission.sqf";
fnc_intel_gathering_mission = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\intel_gathering\fnc_intel_gathering_mission.sqf";
publicVariable "fnc_intel_gathering_mission";
// CIVILIAN FUNCTIONS
fnc_civ_init_Tomata = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_init_Tomata.sqf";
fnc_civ_setup_array = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_setup_array.sqf";
fnc_civ_selectTowns = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_selectTowns.sqf";
// Broadcast for the same reason the RAVAGE and WBK handlers are: the town presence trigger names
// it, and that trigger is global, so every machine evaluates it and every machine runs the body.
fnc_civ_town_reveal = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_town_reveal.sqf";
publicVariable "fnc_civ_town_reveal";
// The board's map readout. The query is broadcast because a client is what calls it, and the
// two display halves because the server is what calls them back.
fnc_map_readout_query = compile preprocessFileLineNumbers "duws\server\misc\fnc_map_readout_query.sqf";
publicVariable "fnc_map_readout_query";
fnc_map_readout_draw = compile preprocessFileLineNumbers "duws\client\misc\fnc_map_readout_draw.sqf";
publicVariable "fnc_map_readout_draw";
fnc_map_readout_open = compile preprocessFileLineNumbers "duws\client\misc\fnc_map_readout_open.sqf";
publicVariable "fnc_map_readout_open";
fnc_civ_wp_Tomata = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_wp_Tomata.sqf";
// Server-only, and deliberately not broadcast: the FiredNear handler that calls it is added on
// this machine alone, and a client that could run it could scatter a town at will.
fnc_civ_panic = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_panic.sqf";
fnc_civ_rep_Tomata = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_rep_Tomata.sqf";
fnc_recruit_civilian = compile preprocessFileLineNumbers "duws\shared\functions\fnc_recruit_civilian.sqf";
publicVariable "fnc_recruit_civilian";
fnc_recruit_civilian_server = compile preprocessFileLineNumbers "duws\server\misc\fnc_recruit_civilian_server.sqf";
publicVariable "fnc_recruit_civilian_server";
fnc_addRecruitAction = compile preprocessFileLineNumbers "duws\shared\functions\fnc_addRecruitAction.sqf";
publicVariable "fnc_addRecruitAction";
fnc_night_horde_event = compile preprocessFileLineNumbers "duws\server\misc\fnc_night_horde_event.sqf";
publicVariable "fnc_night_horde_event";
fnc_civ_healed = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_healed.sqf";
fnc_civ_stopCommand = compile preprocessFileLineNumbers "duws\shared\functions\fnc_civ_stopCommand.sqf";
publicVariable "fnc_civ_stopCommand";
fnc_civ_release_action = compile preprocessFileLineNumbers "duws\shared\functions\fnc_civ_release_action.sqf";
publicVariable "fnc_civ_release_action";
fnc_civ_release = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_release.sqf";
publicVariable "fnc_civ_release";
// Not broadcast, unlike the two below it: the plain civilian path is a server-side thread started
// at town registration, so no trigger anywhere names it.
fnc_civ_handler = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_handler.sqf";
fnc_civ_handler_ravage = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_handler_ravage.sqf";
publicVariable "fnc_civ_handler_ravage";
fnc_civ_handler_wbk = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_handler_wbk.sqf";
publicVariable "fnc_civ_handler_wbk";
// Shared by the two mode handlers above and by nothing else -- fnc_civ_handler runs mod-free and
// takes no mutex, so it must not reach these.
fnc_civ_mode_releaseLock = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_mode_releaseLock.sqf";
fnc_civ_mode_spawnGate = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_mode_spawnGate.sqf";
// Server-only: every caller is a handler thread or its trigger, and the trigger already resolves
// on the machine that runs the spawn. The recycle pass is RAVAGE and WBK's alone; the ceiling is
// shared with the plain path.
fnc_civ_liveTarget = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_liveTarget.sqf";
fnc_civ_spawnUnit = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_spawnUnit.sqf";
fnc_civ_recycle = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_recycle.sqf";
// Broadcast: the spawn paths remoteExec it to every client to hang the civilian's actions.
fnc_civ_clientActions = compile preprocessFileLineNumbers "duws\shared\functions\fnc_civ_clientActions.sqf";
publicVariable "fnc_civ_clientActions";
// Civilian menu. Only fnc_civ_request and fnc_civ_bribe_answer are reached from a client, but
// the rest are broadcast too so a headless client running civilian logic resolves them.
fnc_civ_request = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_request.sqf";
publicVariable "fnc_civ_request";
fnc_civ_serve = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_serve.sqf";
publicVariable "fnc_civ_serve";
fnc_civ_close = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_close.sqf";
publicVariable "fnc_civ_close";
fnc_civ_bribe_answer = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_bribe_answer.sqf";
publicVariable "fnc_civ_bribe_answer";
fnc_civ_arrest = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_arrest.sqf";
publicVariable "fnc_civ_arrest";
fnc_civ_menuAction = compile preprocessFileLineNumbers "duws\shared\functions\fnc_civ_menuAction.sqf";
publicVariable "fnc_civ_menuAction";
fnc_civ_menu = compile preprocessFileLineNumbers "duws\client\dialog\fnc_civ_menu.sqf";
publicVariable "fnc_civ_menu";
fnc_civ_bribe_prompt = compile preprocessFileLineNumbers "duws\client\dialog\fnc_civ_bribe_prompt.sqf";
publicVariable "fnc_civ_bribe_prompt";
fnc_disguiseAsCivilian = compile preprocessFileLineNumbers "duws\server\misc\fnc_disguiseAsCivilian.sqf";
publicVariable "fnc_disguiseAsCivilian";
fnc_scanCivilianGear = compile preprocessFileLineNumbers "duws\server\misc\fnc_scanCivilianGear.sqf";
publicVariable "fnc_scanCivilianGear";
fnc_civ_resume = compile preprocessFileLineNumbers "duws\server\misc\fnc_civ_resume.sqf";
fnc_recruitSuccessServer = compile preprocessFileLineNumbers "duws\server\misc\fnc_recruitSuccessServer.sqf";
publicVariable "fnc_recruitSuccessServer";

// WARCOM FUNCTIONS
fnc_WARCOM_init = compile preprocessFileLineNumbers "duws\server\warcom\fnc_WARCOM_init.sqf";
fnc_WARCOM_wp_blu_assault = compile preprocessFileLineNumbers "duws\server\warcom\fnc_WARCOM_wp_blu_assault.sqf";
fnc_WARCOM_blu_patrol = compile preprocessFileLineNumbers "duws\server\warcom\fnc_WARCOM_blu_patrol.sqf";
fnc_WARCOM_wp_blu_patrol = compile preprocessFileLineNumbers "duws\server\warcom\fnc_WARCOM_wp_blu_patrol.sqf";
fnc_random_veh_blu_patrol = compile preprocessFileLineNumbers "duws\server\warcom\fnc_random_veh_blu_patrol.sqf";
fnc_WARCOM_gps_marker = compile preprocessFileLineNumbers "duws\server\warcom\fnc_WARCOM_gps_marker.sqf";
// OPCOM's hardpoint director: the AP-priced tick that tops up zones, thickens the band and raises radio
// towers. Server-only, spawned once by fnc_WARCOM_init.
fnc_WARCOM_opf_hardpoints = compile preprocessFileLineNumbers "duws\server\warcom\fnc_WARCOM_opf_hardpoints.sqf";

// ZONE FUNCTIONS
fnc_zonesundercontrol = compile preprocessFileLineNumbers "duws\server\misc\fnc_zonesundercontrol.sqf";
fnc_locatorZones_random = compile preprocessFileLineNumbers "duws\server\init_zones\fnc_locatorZones_random.sqf";
fnc_captured = compile preprocessFileLineNumbers "duws\server\init_zones\fnc_captured.sqf";
fnc_blufor_cap = compile preprocessFileLineNumbers "duws\server\init_zones\fnc_blufor_cap.sqf";
fnc_opfor_cap = compile preprocessFileLineNumbers "duws\server\init_zones\fnc_opfor_cap.sqf";
fnc_enterlocation = compile preprocessFileLineNumbers "duws\server\misc\fnc_enterlocation.sqf";
// Not broadcast: the two triggers that name it are created server-local, and it creates global
// markers, so exactly one machine may run it.
fnc_enemy_contact = compile preprocessFileLineNumbers "duws\server\misc\fnc_enemy_contact.sqf";
// Publishes DUWS_zoneHooks and the placers around it; after the zone state file it reads.
[] call compile preprocessFileLineNumbers "duws\server\init_zones\fnc_zone_stream_init.sqf";
// The standing orders half of every spawner below, and of the base guards: a group is raised by one
// of them and ordered by this.
fnc_apply_posture = compile preprocessFileLineNumbers "duws\server\init_zones\fnc_apply_posture.sqf";
fnc_spawn_team = compile preprocessFileLineNumbers "duws\server\init_zones\fnc_spawn_team.sqf";
fnc_spawn_vehicle = compile preprocessFileLineNumbers "duws\server\init_zones\fnc_spawn_vehicle.sqf";
fnc_zone_reveal = compile preprocessFileLineNumbers "duws\server\init_zones\fnc_zone_reveal.sqf";
fnc_hardcore_visible_recalc = compile preprocessFileLineNumbers "duws\server\init_zones\fnc_hardcore_visible_recalc.sqf";
fnc_zone_spawn_sizes = compile preprocessFileLineNumbers "duws\server\init_zones\fnc_zone_spawn_sizes.sqf";

// ZONE PREFABS

switch (VERSION_X) do {
	case "MODERN": {
		fnc_modern_CommStation = compile preprocessFileLineNumbers "duws\server\init_zones\prefabs\modern\fnc_modern_CommStation.sqf";
		fnc_modern_outpost1 = compile preprocessFileLineNumbers "duws\server\init_zones\prefabs\modern\fnc_modern_outpost1.sqf";
		fnc_modern_Outpost2 = compile preprocessFileLineNumbers "duws\server\init_zones\prefabs\modern\fnc_modern_Outpost2.sqf";
		fnc_modern_reconOutpost = compile preprocessFileLineNumbers "duws\server\init_zones\prefabs\modern\fnc_modern_reconOutpost.sqf";
		fnc_modern_simple_zone = compile preprocessFileLineNumbers "duws\server\init_zones\prefabs\modern\fnc_modern_simple_zone.sqf";
		fnc_modern_StorageBunker = compile preprocessFileLineNumbers "duws\server\init_zones\prefabs\modern\fnc_modern_StorageBunker.sqf";
		fnc_modern_vehfittingstation = compile preprocessFileLineNumbers "duws\server\init_zones\prefabs\modern\fnc_modern_vehfittingstation.sqf";
        fnc_modern_FieldHospital = compile preprocessFileLineNumbers "duws\server\init_zones\prefabs\modern\fnc_modern_FieldHospital.sqf";
	};
};

// --- Map-click slot ------------------------------------------------------------------
// The engine keeps exactly one onMapSingleClick handler per machine and offers no way to read
// back what is installed, so two features that each install one silently disarm each other and
// the loser waits on a click that never arrives. Everything mid-mission that wants a map click
// goes through these three instead of touching the command.
//
// Held in uiNamespace rather than missionNamespace because a claim must not be serialized into
// a savegame: restored from one, the slot would come back owned by a mode that no longer
// exists and every map click for the rest of the session would be dead.
//
// Mission generation (HQ placement, manual zone placement) still calls the command directly.
// Those run to completion before the player has a comm menu or a board to click, so they
// cannot collide with anything, and routing them through a function the server publishes would
// make map placement depend on the broadcast having landed.

[] call compile preprocessFileLineNumbers "duws\server\misc\fnc_mapclick_init.sqf";
publicVariable "fnc_mapclick_background";
publicVariable "fnc_mapclick_claim";
publicVariable "fnc_mapclick_release";

// GLOBAL FUNCTIONS
fnc_duws_Arsenal = compile preprocessFileLineNumbers "duws\client\misc\fnc_duws_Arsenal.sqf";publicVariable "fnc_duws_Arsenal";
fnc_ghst_halo = compile preprocessFileLineNumbers "duws\client\misc\fnc_ghst_halo.sqf";publicVariable "fnc_ghst_halo";
fnc_WARCOM_blu_assault = compile preprocessFileLineNumbers "duws\server\warcom\fnc_WARCOM_blu_assault.sqf";publicVariable "fnc_WARCOM_blu_assault";
fnc_random_name = compile preprocessFileLineNumbers "duws\shared\functions\fnc_random_name.sqf";publicVariable "fnc_random_name";
fnc_BLUFOR_squad_init = compile preprocessFileLineNumbers "duws\server\init_hq\fnc_BLUFOR_squad_init.sqf";publicVariable "fnc_BLUFOR_squad_init";
fnc_BLUFOR_faction_init = compile preprocessFileLineNumbers "duws\server\init_hq\fnc_BLUFOR_faction_init.sqf";publicVariable "fnc_BLUFOR_faction_init";
fnc_fortifyFOB = compile preprocessFileLineNumbers "duws\server\init_hq\fnc_fortifyFOB.sqf";publicVariable "fnc_fortifyFOB";
fnc_guardsFOB = compile preprocessFileLineNumbers "duws\server\init_hq\fnc_guardsFOB.sqf";publicVariable "fnc_guardsFOB";
// Broadcast: it is the FOB redeploy action's function value, so every client needs it.
fnc_redeployFOB = compile preprocessFileLineNumbers "duws\client\init_hq\fnc_redeployFOB.sqf";publicVariable "fnc_redeployFOB";
// Not broadcast: server-only, so an accidental client call fails loud.
fnc_redeployFOBUnits = compile preprocessFileLineNumbers "duws\server\misc\fnc_redeployFOBUnits.sqf";
fnc_locatorZones_manual = compile preprocessFileLineNumbers "duws\server\init_zones\fnc_locatorZones_manual.sqf";publicVariable "fnc_locatorZones_manual";
fnc_createZone = compile preprocessFileLineNumbers "duws\server\init_zones\fnc_createZone.sqf";publicVariable "fnc_createZone";
fnc_intel_payout = compile preprocessFileLineNumbers "duws\server\misc\fnc_intel_payout.sqf";
// Not broadcast: it fans out to clients itself, so a client call would fan out a second time.
fnc_duws_report = compile preprocessFileLineNumbers "duws\server\misc\fnc_duws_report.sqf";
fnc_debug_intel_search = compile preprocessFileLineNumbers "duws\server\misc\fnc_debug_intel_search.sqf";
fnc_debug_force_mission = compile preprocessFileLineNumbers "duws\server\misc\fnc_debug_force_mission.sqf";
fnc_debug_spawn_hardpoint = compile preprocessFileLineNumbers "duws\server\misc\fnc_debug_spawn_hardpoint.sqf";
fnc_debug_clear_hardpoints = compile preprocessFileLineNumbers "duws\server\misc\fnc_debug_clear_hardpoints.sqf";
// Server-only: remoteExec'd to 2 by the OPCOM debug view, it gathers the AoI reach circles and hands
// them back to the caller to draw. Read-only, so an accidental client call fails loud, not harmfully.
fnc_debug_aoi_circles = compile preprocessFileLineNumbers "duws\server\misc\fnc_debug_aoi_circles.sqf";
fnc_debug_search_flag = compile preprocessFileLineNumbers "duws\server\misc\fnc_debug_search_flag.sqf";
fnc_intel_search_action = compile preprocessFileLineNumbers "duws\client\misc\fnc_intel_search_action.sqf";publicVariable "fnc_intel_search_action";
fnc_restHealServer = compile preprocessFileLineNumbers "duws\server\misc\fnc_restHealServer.sqf";
publicVariable "fnc_restHealServer";

fnc_addHQBuildingActions = compile preprocessFileLineNumbers "duws\client\misc\fnc_addHQBuildingActions.sqf";
publicVariable "fnc_addHQBuildingActions";
fnc_blackMarketPurchase = compile preprocessFileLineNumbers "duws\server\misc\fnc_blackMarketPurchase.sqf";
publicVariable "fnc_blackMarketPurchase";
fnc_intelAnalysis = compile preprocessFileLineNumbers "duws\server\misc\fnc_intelAnalysis.sqf";
publicVariable "fnc_intelAnalysis";
// MISSION FUNCTIONS
fnc_stratmap = compile preprocessFileLineNumbers "duws\client\missions\fnc_stratmap.sqf";publicVariable "fnc_stratmap";
// Broadcast: the strategic map's mission blocks call it on whoever opened the map.
fnc_mission_launch = compile preprocessFileLineNumbers "duws\client\missions\fnc_mission_launch.sqf";publicVariable "fnc_mission_launch";
fnc_missionLocator = compile preprocessFileLineNumbers "duws\server\missions\fnc_missionLocator.sqf";publicVariable "fnc_missionLocator";

// DIALOG FUNCTIONS
fnc_HQ_faction_dialog = compile preprocessFileLineNumbers "duws\client\dialog\fnc_HQ_faction_dialog.sqf";publicVariable "fnc_HQ_faction_dialog";
fnc_HQ_manual_place = compile preprocessFileLineNumbers "duws\client\dialog\fnc_HQ_manual_place.sqf";publicVariable "fnc_HQ_manual_place";
fnc_HQ_random_place = compile preprocessFileLineNumbers "duws\client\dialog\fnc_HQ_random_place.sqf";publicVariable "fnc_HQ_random_place";
fnc_HQ_placement_finish = compile preprocessFileLineNumbers "duws\client\dialog\fnc_HQ_placement_finish.sqf";publicVariable "fnc_HQ_placement_finish";
fnc_map_prompt = compile preprocessFileLineNumbers "duws\client\dialog\fnc_map_prompt.sqf";publicVariable "fnc_map_prompt";
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
// Defines the confirmation screen's two prompts rather than being one function, so it is executed
// here and its pieces broadcast individually.
[] call compile preprocessFileLineNumbers "duws\client\dialog\fnc_faction_prompts.sqf";
publicVariable "fnc_faction_prompt_hide";
publicVariable "fnc_faction_prompt_clear";
publicVariable "fnc_faction_prompt_lock";
publicVariable "fnc_faction_key_clear";
fnc_enviro_back = compile preprocessFileLineNumbers "duws\client\dialog\fnc_enviro_back.sqf";publicVariable "fnc_enviro_back";
fnc_startup_enviro_closed = compile preprocessFileLineNumbers "duws\client\dialog\fnc_startup_enviro_closed.sqf";publicVariable "fnc_startup_enviro_closed";
fnc_request_unit = compile preprocessFileLineNumbers "duws\client\dialog\fnc_request_unit.sqf";publicVariable "fnc_request_unit";
fnc_request_squad = compile preprocessFileLineNumbers "duws\client\dialog\fnc_request_squad.sqf";publicVariable "fnc_request_squad";
fnc_request_vehicle = compile preprocessFileLineNumbers "duws\client\dialog\fnc_request_vehicle.sqf";publicVariable "fnc_request_vehicle";
fnc_request_support = compile preprocessFileLineNumbers "duws\client\dialog\fnc_request_support.sqf";publicVariable "fnc_request_support";
fnc_support_list_fill = compile preprocessFileLineNumbers "duws\client\dialog\fnc_support_list_fill.sqf";publicVariable "fnc_support_list_fill";
fnc_support_sel_changed = compile preprocessFileLineNumbers "duws\client\dialog\fnc_support_sel_changed.sqf";publicVariable "fnc_support_sel_changed";
// The support catalogue and both of its mechanisms. Executed rather than stored: the file defines
// several functions, and all of them run on the buyer's machine.
[] call compile preprocessFileLineNumbers "duws\client\supports\fnc_supports_init.sqf";
publicVariable "fnc_support_defs";
publicVariable "fnc_support_owned";
publicVariable "fnc_support_comm_add";
publicVariable "fnc_support_comm_used";
publicVariable "fnc_support_comm_drop";
publicVariable "fnc_support_buy";
publicVariable "fnc_support_apply";
publicVariable "fnc_support_refund";
publicVariable "fnc_support_wipe";
fnc_support_perm_grant = compile preprocessFileLineNumbers "duws\server\supports\fnc_support_perm_grant.sqf";
fnc_convertAPtoCP = compile preprocessFileLineNumbers "duws\client\dialog\fnc_convertAPtoCP.sqf";publicVariable "fnc_convertAPtoCP";
fnc_request_unit_fob = compile preprocessFileLineNumbers "duws\client\dialog\fnc_request_unit_fob.sqf";publicVariable "fnc_request_unit_fob";
fnc_request_squad_fob = compile preprocessFileLineNumbers "duws\client\dialog\fnc_request_squad_fob.sqf";publicVariable "fnc_request_squad_fob";
fnc_request_vehicle_fob = compile preprocessFileLineNumbers "duws\client\dialog\fnc_request_vehicle_fob.sqf";publicVariable "fnc_request_vehicle_fob";
fnc_custom_faction_capture = compile preprocessFileLineNumbers "duws\client\dialog\fnc_custom_faction_capture.sqf";publicVariable "fnc_custom_faction_capture";
// Ahead of faction init, which calls it. Not broadcast: generation and every spawn path are server.
[] call compile preprocessFileLineNumbers "duws\shared\functions\fnc_faction_pools.sqf";
// Same idiom and the same reason: the table, the resolver reading it and the placer acting on the
// answer are one file, so which class a static is and how one is put down cannot drift apart.
[] call compile preprocessFileLineNumbers "duws\shared\functions\fnc_static_roles.sqf";
// The area-of-influence field: the coverage primitives and dominance read by the rep drift and the
// hardpoint band siting. Ahead of the hardpoint placer, whose band pass reads it. Definitions only.
[] call compile preprocessFileLineNumbers "duws\server\misc\fnc_aoi_init.sqf";
// Terrain scoring and the minefield generator: definitions only, read by the siting loop that is yet
// to be written. Loaded here rather than at zone-gen time so both are in hand before generation runs.
[] call compile preprocessFileLineNumbers "duws\server\init_zones\fnc_hardpoint_siting.sqf";
[] call compile preprocessFileLineNumbers "duws\server\init_zones\fnc_hardpoint_minefield.sqf";
// Layout data the placer reads by name (DUWS_hardpointComp_<type>). Ahead of the placer so no build
// finds an empty composition and stands a hardpoint up as bare men on open ground.
[] call compile preprocessFileLineNumbers "duws\server\init_zones\hardpoint_compositions.sqf";
[] call compile preprocessFileLineNumbers "duws\server\init_zones\fnc_hardpoint_place.sqf";
[] call compile preprocessFileLineNumbers "duws\server\init_zones\fnc_hardpoint_stream.sqf";
// Reveals a hardpoint to the intel system, the way fnc_zone_reveal does a zone: flips the row's
// revealed flag and its marker alpha. Read by fnc_intel_payout. Whole-file-is-the-function idiom, not
// the [] call above: its body opens with params, so running it at registration errors on the missing
// argument and defines nothing -- it must be compiled into the global the callers name.
fnc_hardpoint_reveal = compile preprocessFileLineNumbers "duws\server\init_zones\fnc_hardpoint_reveal.sqf";
// Same idiom again, and ahead of faction init, which is what leaves the keys it fills empty.
[] call compile preprocessFileLineNumbers "duws\shared\functions\fnc_faction_backfill.sqf";
// The commit-time pass that turns each side's one-class-per-role globals into per-spawn pools. Server
// only: pools are read only by the spawn paths, which are server-side.
fnc_faction_augment = compile preprocessFileLineNumbers "duws\shared\functions\fnc_faction_augment.sqf";
// Before fnc_BLUFOR_squad_init and the zone spawn band, both of which name a team out of it.
[] call compile preprocessFileLineNumbers "duws\shared\functions\fnc_spawn_vocab.sqf";
// Ahead of the two AutoDetect wrappers and fnc_custom_faction_parse, which both build their key
// lists from it. Broadcast because the confirmation screen builds its rows from it client-side.
fnc_faction_schema = compile preprocessFileLineNumbers "duws\shared\functions\fnc_faction_schema.sqf";publicVariable "fnc_faction_schema";
fnc_custom_faction_parse = compile preprocessFileLineNumbers "duws\shared\functions\fnc_custom_faction_parse.sqf";publicVariable "fnc_custom_faction_parse";
// Broadcast: both request menus and all four request handlers are client-side.
fnc_faction_rqst_list = compile preprocessFileLineNumbers "duws\shared\functions\fnc_faction_rqst_list.sqf";publicVariable "fnc_faction_rqst_list";
fnc_custom_faction_init = compile preprocessFileLineNumbers "duws\server\dialog\fnc_custom_faction_init.sqf";publicVariable "fnc_custom_faction_init";
fnc_request_menu = compile preprocessFileLineNumbers "duws\client\dialog\fnc_request_menu.sqf";publicVariable "fnc_request_menu";
fnc_request_map_view = compile preprocessFileLineNumbers "duws\client\dialog\fnc_request_map_view.sqf";publicVariable "fnc_request_map_view";
fnc_command_fill = compile preprocessFileLineNumbers "duws\client\dialog\fnc_command_fill.sqf";publicVariable "fnc_command_fill";
fnc_command_select = compile preprocessFileLineNumbers "duws\client\dialog\fnc_command_select.sqf";publicVariable "fnc_command_select";
fnc_squad_manage = compile preprocessFileLineNumbers "duws\client\dialog\fnc_squad_manage.sqf";publicVariable "fnc_squad_manage";
fnc_open_action_menu = compile preprocessFileLineNumbers "duws\client\dialog\fnc_open_action_menu.sqf";publicVariable "fnc_open_action_menu";
fnc_disguise_menu = compile preprocessFileLineNumbers "duws\client\dialog\fnc_disguise_menu.sqf";publicVariable "fnc_disguise_menu";
fnc_debug_menu = compile preprocessFileLineNumbers "duws\client\dialog\fnc_debug_menu.sqf";publicVariable "fnc_debug_menu";
fnc_debug_econ_menu = compile preprocessFileLineNumbers "duws\client\dialog\fnc_debug_econ_menu.sqf";publicVariable "fnc_debug_econ_menu";
fnc_debug_econ_fill = compile preprocessFileLineNumbers "duws\client\dialog\fnc_debug_econ_fill.sqf";publicVariable "fnc_debug_econ_fill";
// Not broadcast: the window remoteExecs it to the server by name, and it re-checks game_master
// itself because any client could send it.
fnc_debug_econ_server = compile preprocessFileLineNumbers "duws\server\misc\fnc_debug_econ_server.sqf";
fnc_debug_mission_menu = compile preprocessFileLineNumbers "duws\client\dialog\fnc_debug_mission_menu.sqf";publicVariable "fnc_debug_mission_menu";
fnc_debug_hardpoint_menu = compile preprocessFileLineNumbers "duws\client\dialog\fnc_debug_hardpoint_menu.sqf";publicVariable "fnc_debug_hardpoint_menu";
// The OPCOM debug view and its draw callback. Broadcast: the view is a menu-row handler every client
// holds, and the server remoteExecs the callback back to whichever client asked.
fnc_debug_opcom_view = compile preprocessFileLineNumbers "duws\client\dialog\fnc_debug_opcom_view.sqf";publicVariable "fnc_debug_opcom_view";
fnc_debug_aoi_draw = compile preprocessFileLineNumbers "duws\client\dialog\fnc_debug_aoi_draw.sqf";publicVariable "fnc_debug_aoi_draw";
fnc_debug_search_menu = compile preprocessFileLineNumbers "duws\client\dialog\fnc_debug_search_menu.sqf";publicVariable "fnc_debug_search_menu";
fnc_dismissHC = compile preprocessFileLineNumbers "duws\client\dialog\fnc_dismissHC.sqf";publicVariable "fnc_dismissHC";
fnc_dismiss_playerAI = compile preprocessFileLineNumbers "duws\client\dialog\fnc_dismiss_playerAI.sqf";publicVariable "fnc_dismiss_playerAI";
fnc_squad_rename = compile preprocessFileLineNumbers "duws\client\dialog\fnc_squad_rename.sqf";publicVariable "fnc_squad_rename";
fnc_groupReset = compile preprocessFileLineNumbers "duws\client\dialog\fnc_groupReset.sqf";publicVariable "fnc_groupReset";
fnc_rest_heal = compile preprocessFileLineNumbers "duws\server\dialog\fnc_rest_heal.sqf";publicVariable "fnc_rest_heal";
fnc_FOBmanager = compile preprocessFileLineNumbers "duws\client\dialog\fnc_FOBmanager.sqf";publicVariable "fnc_FOBmanager";
fnc_FOB_remove = compile preprocessFileLineNumbers "duws\client\dialog\fnc_FOB_remove.sqf";publicVariable "fnc_FOB_remove";
fnc_FOB_cleanup = compile preprocessFileLineNumbers "duws\server\dialog\fnc_FOB_cleanup.sqf";publicVariable "fnc_FOB_cleanup";
fnc_FOB_fast_travel = compile preprocessFileLineNumbers "duws\client\dialog\fnc_FOB_fast_travel.sqf";publicVariable "fnc_FOB_fast_travel";
fnc_MHQ_select = compile preprocessFileLineNumbers "duws\client\dialog\fnc_MHQ_select.sqf";publicVariable "fnc_MHQ_select";
fnc_MHQ_addActions = compile preprocessFileLineNumbers "duws\shared\functions\fnc_MHQ_addActions.sqf";publicVariable "fnc_MHQ_addActions";
fnc_MHQ_deploy = compile preprocessFileLineNumbers "duws\server\dialog\fnc_MHQ_deploy.sqf";publicVariable "fnc_MHQ_deploy";
fnc_MHQ_undeploy = compile preprocessFileLineNumbers "duws\server\dialog\fnc_MHQ_undeploy.sqf";publicVariable "fnc_MHQ_undeploy";
fnc_MHQ_release = compile preprocessFileLineNumbers "duws\server\dialog\fnc_MHQ_release.sqf";
fnc_MHQ_destroyed = compile preprocessFileLineNumbers "duws\shared\functions\fnc_MHQ_destroyed.sqf";publicVariable "fnc_MHQ_destroyed";

// HQ & FOB FUNCTIONS
fnc_draw_world_icons = compile preprocessFileLineNumbers "duws\client\misc\fnc_draw_world_icons.sqf";publicVariable "fnc_draw_world_icons";
fnc_HQaddactions = compile preprocessFileLineNumbers "duws\client\init_hq\fnc_HQaddactions.sqf";publicVariable "fnc_HQaddactions";
fnc_FOBactions = compile preprocessFileLineNumbers "duws\shared\functions\fnc_FOBactions.sqf";publicVariable "fnc_FOBactions";
fnc_fob_server = compile preprocessFileLineNumbers "duws\server\supports\fnc_fob_server.sqf";publicVariable "fnc_fob_server";

// SUPPORTS FUNCTIONS
fnc_ammobox = compile preprocessFileLineNumbers "duws\client\supports\fnc_ammobox.sqf";publicVariable "fnc_ammobox";
fnc_medtent_actions = compile preprocessFileLineNumbers "duws\shared\functions\fnc_medtent_actions.sqf";publicVariable "fnc_medtent_actions";
fnc_ammobox_actions = compile preprocessFileLineNumbers "duws\shared\functions\fnc_ammobox_actions.sqf";publicVariable "fnc_ammobox_actions";
fnc_arty = compile preprocessFileLineNumbers "duws\client\supports\fnc_arty.sqf";publicVariable "fnc_arty";
fnc_mapclickarty = compile preprocessFileLineNumbers "duws\client\supports\fnc_mapclickarty.sqf";publicVariable "fnc_mapclickarty";
fnc_mapclickuav = compile preprocessFileLineNumbers "duws\client\supports\fnc_mapclickuav.sqf";publicVariable "fnc_mapclickuav";
fnc_uav_scanner = compile preprocessFileLineNumbers "duws\server\supports\fnc_uav_scanner.sqf";publicVariable "fnc_uav_scanner";
fnc_paradrop = compile preprocessFileLineNumbers "duws\client\supports\fnc_paradrop.sqf";publicVariable "fnc_paradrop";
fnc_request_fob = compile preprocessFileLineNumbers "duws\client\supports\fnc_request_fob.sqf";publicVariable "fnc_request_fob";
fnc_request_hcATTchop = compile preprocessFileLineNumbers "duws\client\supports\fnc_request_hcATTchop.sqf";publicVariable "fnc_request_hcATTchop";
fnc_request_hcCAS = compile preprocessFileLineNumbers "duws\client\supports\fnc_request_hcCAS.sqf";publicVariable "fnc_request_hcCAS";
fnc_sitrep_support = compile preprocessFileLineNumbers "duws\server\supports\fnc_sitrep_support.sqf";publicVariable "fnc_sitrep_support";
fnc_veh_drop = compile preprocessFileLineNumbers "duws\client\supports\fnc_veh_drop.sqf";publicVariable "fnc_veh_drop";
fnc_sawp_drop = compile preprocessFileLineNumbers "duws\client\supports\fnc_sawp_drop.sqf";publicVariable "fnc_sawp_drop";
fnc_siva_drop = compile preprocessFileLineNumbers "duws\client\supports\fnc_siva_drop.sqf";publicVariable "fnc_siva_drop";
fnc_helotaxi = compile preprocessFileLineNumbers "duws\client\supports\taxi\fnc_helotaxi.sqf";publicVariable "fnc_helotaxi";
fnc_helolift = compile preprocessFileLineNumbers "duws\client\supports\fnc_helolift.sqf";publicVariable "fnc_helolift";
// Not broadcast: fnc_helolift only ever remoteExecs these to target 2, which resolves the
// name on the server, and every one of them needs the helo group local to run at all.
fnc_helolift_spawnHeli = compile preprocessFileLineNumbers "duws\server\supports\fnc_helolift_spawnHeli.sqf";
fnc_helolift_ropes = compile preprocessFileLineNumbers "duws\server\supports\fnc_helolift_ropes.sqf";
fnc_helolift_waypoints = compile preprocessFileLineNumbers "duws\server\supports\fnc_helolift_waypoints.sqf";
fnc_mapclicklift = compile preprocessFileLineNumbers "duws\client\supports\fnc_mapclicklift.sqf";publicVariable "fnc_mapclicklift";
fnc_mapclickhelo = compile preprocessFileLineNumbers "duws\client\supports\taxi\fnc_mapclickhelo.sqf";publicVariable "fnc_mapclickhelo";
fnc_boattaxi = compile preprocessFileLineNumbers "duws\client\supports\taxi\fnc_boattaxi.sqf";publicVariable "fnc_boattaxi";
fnc_mapclickboat = compile preprocessFileLineNumbers "duws\client\supports\taxi\fnc_mapclickboat.sqf";publicVariable "fnc_mapclickboat";
fnc_taxi_music = compile preprocessFileLineNumbers "duws\client\supports\taxi\fnc_taxi_music.sqf";publicVariable "fnc_taxi_music";

// MISC FUNCTIONS
fnc_hirePartisans = compile preprocessFileLineNumbers "duws\server\misc\fnc_hirePartisans.sqf";
publicVariable "fnc_hirePartisans";
fnc_hirePMC = compile preprocessFileLineNumbers "duws\server\misc\fnc_hirePMC.sqf";
publicVariable "fnc_hirePMC";
fnc_scanEnemyGear = compile preprocessFileLineNumbers "duws\server\misc\fnc_scanEnemyGear.sqf";
publicVariable "fnc_scanEnemyGear";
fnc_disguiseAsEnemy = compile preprocessFileLineNumbers "duws\server\misc\fnc_disguiseAsEnemy.sqf";
publicVariable "fnc_disguiseAsEnemy";
fnc_moreUrban_locations = compile preprocessFileLineNumbers "duws\server\misc\fnc_moreUrban_locations.sqf";publicVariable "fnc_moreUrban_locations";
fnc_hc_init = compile preprocessFileLineNumbers "duws\client\misc\fnc_hc_init.sqf";publicVariable "fnc_hc_init";
fnc_zones_bonus = compile preprocessFileLineNumbers "duws\client\misc\fnc_zones_bonus.sqf";publicVariable "fnc_zones_bonus";
fnc_kndr_unit_markers = compile preprocessFileLineNumbers "duws\client\misc\fnc_kndr_unit_markers.sqf";publicVariable "fnc_kndr_unit_markers";
fnc_player_markers = compile preprocessFileLineNumbers "duws\client\misc\fnc_player_markers.sqf";publicVariable "fnc_player_markers";
fnc_earplugs = compile preprocessFileLineNumbers "duws\client\misc\fnc_earplugs.sqf";publicVariable "fnc_earplugs";
fnc_duws_help = compile preprocessFileLineNumbers "duws\client\misc\fnc_duws_help.sqf";publicVariable "fnc_duws_help";
fnc_bottom_right_message = compile preprocessFileLineNumbers "duws\client\misc\fnc_bottom_right_message.sqf";publicVariable "fnc_bottom_right_message";
fnc_duws_senior_name = compile preprocessFileLineNumbers "duws\shared\functions\fnc_duws_senior_name.sqf";publicVariable "fnc_duws_senior_name";
fnc_duws_dialogue = compile preprocessFileLineNumbers "duws\client\misc\fnc_duws_dialogue.sqf";publicVariable "fnc_duws_dialogue";
fnc_duws_dialogue_drain = compile preprocessFileLineNumbers "duws\client\misc\fnc_duws_dialogue_drain.sqf";publicVariable "fnc_duws_dialogue_drain";
fnc_autoSave = compile preprocessFileLineNumbers "duws\server\misc\fnc_autoSave.sqf";publicVariable "fnc_autoSave";
fnc_playerTF_spawn = compile preprocessFileLineNumbers "duws\server\misc\fnc_playerTF_spawn.sqf";publicVariable "fnc_playerTF_spawn";
// Not broadcast: server-only, so an accidental client call fails loud.
fnc_HCsquad_spawn = compile preprocessFileLineNumbers "duws\server\misc\fnc_HCsquad_spawn.sqf";
fnc_sitrep_fanout = compile preprocessFileLineNumbers "duws\server\supports\fnc_sitrep_fanout.sqf";
fnc_sitrep_display = compile preprocessFileLineNumbers "duws\client\misc\fnc_sitrep_display.sqf";publicVariable "fnc_sitrep_display";
fnc_fill_ammobox = compile preprocessFileLineNumbers "duws\server\misc\fnc_fill_ammobox.sqf";publicVariable "fnc_fill_ammobox";
fnc_fill_sawpbox = compile preprocessFileLineNumbers "duws\server\misc\fnc_fill_sawpbox.sqf";publicVariable "fnc_fill_sawpbox";
fnc_delete_napalm = compile preprocessFileLineNumbers "duws\server\misc\fnc_delete_napalm.sqf";publicVariable "fnc_delete_napalm";
fnc_addQuickChangeActions = compile preprocessFileLineNumbers "duws\client\misc\fnc_addQuickChangeActions.sqf";
publicVariable "fnc_addQuickChangeActions";
fnc_quick_kits_menu = compile preprocessFileLineNumbers "duws\client\misc\fnc_quick_kits_menu.sqf";
publicVariable "fnc_quick_kits_menu";
fnc_addNearbyUnitsGearToArsenal = compile preprocessFileLineNumbers "duws\server\misc\fnc_addNearbyUnitsGearToArsenal.sqf";
publicVariable "fnc_addNearbyUnitsGearToArsenal";
fnc_scanNearbyUnitsForQuickChange = compile preprocessFileLineNumbers "duws\server\misc\fnc_scanNearbyUnitsForQuickChange.sqf";
publicVariable "fnc_scanNearbyUnitsForQuickChange";
fnc_rearmUnit = compile preprocessFileLineNumbers "duws\server\misc\fnc_rearmUnit.sqf";
publicVariable "fnc_rearmUnit";
fnc_activateBaseRecycleStation = compile preprocessFileLineNumbers "duws\server\supports\fnc_activateBaseRecycleStation.sqf";
publicVariable "fnc_activateBaseRecycleStation";
fnc_activateBaseRepairStation = compile preprocessFileLineNumbers "duws\server\supports\fnc_activateBaseRepairStation.sqf";
publicVariable "fnc_activateBaseRepairStation";
fnc_client_addRecycleActions = compile preprocessFileLineNumbers "duws\client\supports\fnc_client_addRecycleActions.sqf";
publicVariable "fnc_client_addRecycleActions";
fnc_client_addRepairActions = compile preprocessFileLineNumbers "duws\client\supports\fnc_client_addRepairActions.sqf";
publicVariable "fnc_client_addRepairActions";
fnc_redeployHQUnits = compile preprocessFileLineNumbers "duws\server\misc\fnc_redeployHQUnits.sqf";
publicVariable "fnc_redeployHQUnits";
fnc_createKillhouse = compile preprocessFileLineNumbers "duws\server\misc\fnc_createKillhouse.sqf";
publicVariable "fnc_createKillhouse";
// WARCOM FUNCTIONS
fnc_WARCOM_mapclick_assault = compile preprocessFileLineNumbers "duws\client\warcom\fnc_WARCOM_mapclick_assault.sqf";publicVariable "fnc_WARCOM_mapclick_assault";
fnc_lbselected = compile preprocessFileLineNumbers "duws\client\operative\fnc_lbselected.sqf";publicVariable "fnc_lbselected";
fnc_operative_mission_complete = compile preprocessFileLineNumbers "duws\server\misc\fnc_operative_mission_complete.sqf";publicVariable "fnc_operative_mission_complete";
fnc_operator_init = compile preprocessFileLineNumbers "duws\client\operative\fnc_operator_init.sqf";publicVariable "fnc_operator_init";
fnc_operator_open = compile preprocessFileLineNumbers "duws\client\operative\fnc_operator_open.sqf";publicVariable "fnc_operator_open";
fnc_operator_recruit = compile preprocessFileLineNumbers "duws\client\operative\fnc_operator_recruit.sqf";publicVariable "fnc_operator_recruit";
fnc_blu_taskforces_launch = compile preprocessFileLineNumbers "duws\server\warcom\fnc_blu_taskforces_launch.sqf";
publicVariable "fnc_blu_taskforces_launch";
fnc_apocalypse_buildings = compile preprocessFileLineNumbers "duws\server\supports\fnc_apocalypse_buildings.sqf";
publicVariable "fnc_apocalypse_buildings";
fnc_removeArsenalAction = compile preprocessFileLineNumbers "duws\client\misc\fnc_removeArsenalAction.sqf";
publicVariable "fnc_removeArsenalAction";
[] call compile preprocessFileLineNumbers "duws\server\misc\fnc_wbk_server_init.sqf";
publicVariable "fnc_wbk_survivorKilled_server";
[] call compile preprocessFileLineNumbers "duws\server\supports\fnc_pylon_init.sqf";
publicVariable "fnc_pylon_set_with_cost";
publicVariable "fnc_pylon_hint_nocp";
publicVariable "fnc_pylon_hint_success";

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
