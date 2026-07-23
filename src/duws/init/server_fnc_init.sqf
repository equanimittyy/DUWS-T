
// SERVER FUNCTIONS

// STARTUP FUNCTIONS
fnc_BluHQinit = compile preprocessFileLineNumbers "duws\functions\init_hq\fnc_BluHQinit.sqf";
fnc_factions_check = compile preprocessFileLineNumbers "duws\functions\misc\fnc_factions_check_modern.sqf";
fnc_intro_heli = compile preprocessFileLineNumbers "duws\functions\misc\fnc_intro_heli.sqf";
publicVariable "fnc_intro_heli";
// SERVER INIT FUNCTIONS
fnc_init_OPFOR_WARCOM = compile preprocessFileLineNumbers "duws\functions\warcom\fnc_init_OPFOR_WARCOM.sqf";
fnc_OPFOR_faction_init = compile preprocessFileLineNumbers "duws\functions\warcom\fnc_OPFOR_faction_init.sqf";
fnc_OPFOR_squad_init = compile preprocessFileLineNumbers "duws\functions\warcom\fnc_OPFOR_squad_init.sqf";
fnc_repetitive_cleanup = compile preprocessFileLineNumbers "duws\functions\misc\fnc_repetitive_cleanup.sqf";
fnc_capture_zones_task = compile preprocessFileLineNumbers "duws\functions\misc\fnc_capture_zones_task.sqf";
fnc_AI_Master_Control = compile preprocessFileLineNumbers "duws\functions\misc\fnc_AI_Master_Control.sqf";
fnc_weather = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_weather.sqf";
fnc_zeus_objects_init = compile preprocessFileLineNumbers "duws\functions\misc\fnc_zeus_objects_init.sqf";
fnc_usableBuildings = compile preprocessFileLineNumbers "duws\functions\misc\fnc_usableBuildings.sqf";
fnc_fob_destroyed = compile preprocessFileLineNumbers "duws\functions\misc\fnc_fob_destroyed.sqf";
fnc_missionLocator = compile preprocessFileLineNumbers "duws\functions\missions\fnc_missionLocator.sqf";
fnc_create_ammo_lists = compile preprocessFileLineNumbers "duws\functions\misc\fnc_create_ammo_lists.sqf";
fnc_basic_ammo_lists = compile preprocessFileLineNumbers "duws\functions\misc\fnc_basic_ammo_lists.sqf";
fnc_warcrimes_script = compile preprocessFileLineNumbers "duws\functions\misc\fnc_warcrimes_script.sqf";
fnc_ai_rearm = compile preprocessFileLineNumbers "duws\functions\misc\fnc_ai_rearm.sqf";publicVariable "fnc_ai_rearm";
fnc_addRandomLoot = compile preprocessFileLineNumbers "duws\functions\misc\fnc_addRandomLoot.sqf";
publicVariable "fnc_addRandomLoot";
fnc_addFaceChangeAction = compile preprocessFileLineNumbers "duws\functions\misc\fnc_addFaceChangeAction.sqf";
publicVariable "fnc_addFaceChangeAction";
fnc_hirePartisans_spawnDeployed = compile preprocessFileLineNumbers "duws\functions\misc\fnc_hirePartisans_spawnDeployed.sqf";
publicVariable "fnc_hirePartisans_spawnDeployed";
fnc_addBoardKillhouseActions = compile preprocessFileLineNumbers "duws\functions\init_hq\fnc_addBoardKillhouseActions.sqf";
publicVariable "fnc_addBoardKillhouseActions";
// SIDE MISSION FUNCTIONS
fnc_mission_reward = compile preprocessFileLineNumbers "duws\functions\missions\fnc_mission_reward.sqf";
fnc_missionTimer = compile preprocessFileLineNumbers "duws\functions\missions\fnc_missionTimer.sqf";
fnc_missionTargetPos = compile preprocessFileLineNumbers "duws\functions\missions\fnc_missionTargetPos.sqf";
fnc_missionMarkerData = compile preprocessFileLineNumbers "duws\functions\missions\fnc_missionMarkerData.sqf";
fnc_missionPatrols = compile preprocessFileLineNumbers "duws\functions\missions\fnc_missionPatrols.sqf";
fnc_missionPatrolswithintel = compile preprocessFileLineNumbers "duws\functions\missions\fnc_missionPatrolswithintel.sqf";
fnc_missionPatrolsSmall = compile preprocessFileLineNumbers "duws\functions\missions\fnc_missionPatrolsSmall.sqf";
fnc_mission_cleanup = compile preprocessFileLineNumbers "duws\functions\missions\fnc_mission_cleanup.sqf";
fnc_mission_cleanup_agressive = compile preprocessFileLineNumbers "duws\functions\missions\fnc_mission_cleanup_agressive.sqf";
fnc_opf_heli_reinforce = compile preprocessFileLineNumbers "duws\functions\missions\fnc_opf_heli_reinforce.sqf";
publicVariable "fnc_opf_heli_reinforce";
// 动态氛围任务系统
fnc_findSafeMissionPos = compile preprocessFileLineNumbers "duws\functions\misc\fnc_findSafeMissionPos.sqf";
publicVariable "fnc_findSafeMissionPos";
fnc_dynamicAtmosphere_init = compile preprocessFileLineNumbers "duws\functions\missions\dyna\fnc_dynamicAtmosphere_init.sqf";
publicVariable "fnc_dynamicAtmosphere_init";

// SIDE MISSION THREADS
fnc_rescue_squad_mission = compile preprocessFileLineNumbers "duws\functions\missions\mission_threads\rescue_squad\fnc_rescue_squad_mission.sqf";
fnc_rescue_squad_success = compile preprocessFileLineNumbers "duws\functions\missions\mission_threads\rescue_squad\fnc_rescue_squad_success.sqf";
fnc_steal_supply_mission = compile preprocessFileLineNumbers "duws\functions\missions\mission_threads\steal_supply\fnc_steal_supply_mission.sqf";
fnc_transport_IDAP_mission = compile preprocessFileLineNumbers "duws\functions\missions\mission_threads\transport_idap\fnc_transport_IDAP_mission.sqf";
fnc_target_hvt_mission = compile preprocessFileLineNumbers "duws\functions\missions\mission_threads\target_hvt\fnc_target_hvt_mission.sqf";
fnc_destroy_tower_mission = compile preprocessFileLineNumbers "duws\functions\missions\mission_threads\destroy_tower\fnc_destroy_tower_mission.sqf";
fnc_rescue_pilot_mission = compile preprocessFileLineNumbers "duws\functions\missions\mission_threads\rescue_pilot\fnc_rescue_pilot_mission.sqf";
fnc_target_sniper_mission = compile preprocessFileLineNumbers "duws\functions\missions\mission_threads\target_sniper\fnc_target_sniper_mission.sqf";
fnc_domination_mission = compile preprocessFileLineNumbers "duws\functions\missions\mission_threads\domination\fnc_domination_mission.sqf";
fnc_clearthearea_cqb_mission = compile preprocessFileLineNumbers "duws\functions\missions\mission_threads\clearthearea_cqb\fnc_clearthearea_cqb_mission.sqf";
fnc_holdposition_mission = compile preprocessFileLineNumbers "duws\functions\missions\mission_threads\holdpos\fnc_holdposition_mission.sqf";
fnc_protect_civ_mission = compile preprocessFileLineNumbers "duws\functions\missions\mission_threads\protect_civ\fnc_protect_civ.sqf";
fnc_steal_builder_mission = compile preprocessFileLineNumbers "duws\functions\missions\mission_threads\steal_builder\fnc_steal_builder_mission.sqf";
fnc_target_armor_mission = compile preprocessFileLineNumbers "duws\functions\missions\mission_threads\target_armor\fnc_target_armor_mission.sqf";
fnc_sabotage_laptop_mission = compile preprocessFileLineNumbers "duws\functions\missions\mission_threads\sabotage_laptop\fnc_sabotage_laptop_mission.sqf";
fnc_sabotage_laptop_success = compile preprocessFileLineNumbers "duws\functions\missions\mission_threads\sabotage_laptop\fnc_sabotage_laptop_success.sqf";
fnc_destroy_cache_mission = compile preprocessFileLineNumbers "duws\functions\missions\mission_threads\destroy_cache\fnc_destroy_cache_mission.sqf";
fnc_destroy_radar_mission = compile preprocessFileLineNumbers "duws\functions\missions\mission_threads\destroy_radar\fnc_destroy_radar_mission.sqf";
fnc_dyna_mission_mortarspotter = compile preprocessFileLineNumbers "duws\functions\missions\dyna\fnc_dyna_mission_mortarspotter.sqf";
publicVariable "fnc_dyna_mission_mortarspotter";
fnc_dyna_mission_supply_recovery = compile preprocessFileLineNumbers "duws\functions\missions\dyna\fnc_dyna_mission_supply_recovery.sqf";
publicVariable "fnc_dyna_mission_supply_recovery";
fnc_add_intel_on_death = compile preprocessFileLineNumbers "duws\functions\misc\fnc_add_intel_on_death.sqf";
publicVariable "fnc_add_intel_on_death";
fnc_corpse_search_action = compile preprocessFileLineNumbers "duws\functions\misc\fnc_corpse_search_action.sqf";
publicVariable "fnc_corpse_search_action";
fnc_add_intel_to_group = compile preprocessFileLineNumbers "duws\functions\misc\fnc_add_intel_to_group.sqf";
publicVariable "fnc_add_intel_to_group";
fnc_intel_gathering_mission = compile preprocessFileLineNumbers "duws\functions\missions\mission_threads\intel_gathering\fnc_intel_gathering_mission.sqf";
publicVariable "fnc_intel_gathering_mission";
// CIVILIAN FUNCTIONS
fnc_civ_init_Tomata = compile preprocessFileLineNumbers "duws\functions\misc\fnc_civ_init_Tomata.sqf";
fnc_civ_locator_Tomata = compile preprocessFileLineNumbers "duws\functions\misc\fnc_civ_locator_Tomata.sqf";
fnc_civ_wp_Tomata = compile preprocessFileLineNumbers "duws\functions\misc\fnc_civ_wp_Tomata.sqf";
fnc_civ_rep_Tomata = compile preprocessFileLineNumbers "duws\functions\misc\fnc_civ_rep_Tomata.sqf";
fnc_civ_informant_wp_Tomata = compile preprocessFileLineNumbers "duws\functions\misc\fnc_civ_informant_wp_Tomata.sqf";
fnc_recruit_civilian = compile preprocessFileLineNumbers "duws\functions\misc\fnc_recruit_civilian.sqf";
publicVariable "fnc_recruit_civilian";
fnc_recruit_civilian_server = compile preprocessFileLineNumbers "duws\functions\misc\fnc_recruit_civilian_server.sqf";
publicVariable "fnc_recruit_civilian_server";
fnc_addRecruitAction = compile preprocessFileLineNumbers "duws\functions\misc\fnc_addRecruitAction.sqf";
publicVariable "fnc_addRecruitAction";
fnc_night_horde_event = compile preprocessFileLineNumbers "duws\functions\misc\fnc_night_horde_event.sqf";
publicVariable "fnc_night_horde_event";
fnc_addAskEnemyAction = compile preprocessFileLineNumbers "duws\functions\misc\fnc_addAskEnemyAction.sqf";
publicVariable "fnc_addAskEnemyAction";
fnc_civ_informant_system = compile preprocessFileLineNumbers "duws\functions\misc\fnc_civ_informant_system.sqf";
fnc_civ_healAction = compile preprocessFileLineNumbers "duws\functions\misc\fnc_civ_healAction.sqf";
publicVariable "fnc_civ_healAction";
fnc_civ_stopCommand = compile preprocessFileLineNumbers "duws\functions\misc\fnc_civ_stopCommand.sqf";
publicVariable "fnc_civ_stopCommand";
fnc_civ_recruitAction = compile preprocessFileLineNumbers "duws\functions\misc\fnc_civ_recruitAction.sqf";
publicVariable "fnc_civ_recruitAction";
fnc_civ_addDevelopInformantAction = compile preprocessFileLineNumbers "duws\functions\misc\fnc_civ_addDevelopInformantAction.sqf";
publicVariable "fnc_civ_addDevelopInformantAction";
fnc_civ_developInformantServer = compile preprocessFileLineNumbers "duws\functions\misc\fnc_civ_developInformantServer.sqf";
publicVariable "fnc_civ_developInformantServer";
fnc_civ_lootAction = compile preprocessFileLineNumbers "duws\functions\misc\fnc_civ_lootAction.sqf";
publicVariable "fnc_civ_lootAction";
fnc_civ_lootAction_handleArmed = compile preprocessFileLineNumbers "duws\functions\misc\fnc_civ_lootAction.sqf";
publicVariable "fnc_civ_lootAction_handleArmed";
fnc_civ_detectClusters = compile preprocessFileLineNumbers "duws\functions\misc\fnc_civ_detectClusters.sqf";
publicVariable "fnc_civ_detectClusters";
fnc_civ_suicideBomberBehaviour = compile preprocessFileLineNumbers "duws\functions\misc\fnc_civ_suicideBomberBehaviour.sqf";
publicVariable "fnc_civ_suicideBomberBehaviour";
fnc_civ_handler = compile preprocessFileLineNumbers "duws\functions\misc\fnc_civ_handler.sqf";
publicVariable "fnc_civ_handler";
fnc_civ_handler_wbk = compile preprocessFileLineNumbers "duws\functions\misc\fnc_civ_handler_wbk.sqf";
publicVariable "fnc_civ_handler_wbk";
fnc_civ_fast_travel_add_action = compile preprocessFileLineNumbers "duws\functions\misc\fnc_civ_fast_travel_add_action.sqf";
publicVariable "fnc_civ_fast_travel_add_action";
fnc_civ_fast_travel_request = compile preprocessFileLineNumbers "duws\functions\misc\fnc_civ_fast_travel_request.sqf";
publicVariable "fnc_civ_fast_travel_request";
fnc_civ_fast_travel_server = compile preprocessFileLineNumbers "duws\functions\misc\fnc_civ_fast_travel_server.sqf";
publicVariable "fnc_civ_fast_travel_server";
fnc_civ_fast_travel_execute = compile preprocessFileLineNumbers "duws\functions\misc\fnc_civ_fast_travel_execute.sqf";
publicVariable "fnc_civ_fast_travel_execute";
fnc_addCivilianMoney = compile preprocessFileLineNumbers "duws\functions\misc\fnc_addCivilianMoney.sqf";
publicVariable "fnc_addCivilianMoney";
fnc_civ_askForAid = compile preprocessFileLineNumbers "duws\functions\misc\fnc_civ_askForAid.sqf";
publicVariable "fnc_civ_askForAid";
fnc_civ_askForAid_server = compile preprocessFileLineNumbers "duws\functions\misc\fnc_civ_askForAid_server.sqf";
publicVariable "fnc_civ_askForAid_server";
fnc_civ_askForToolkit = compile preprocessFileLineNumbers "duws\functions\misc\fnc_civ_askForToolkit.sqf";
publicVariable "fnc_civ_askForToolkit";
fnc_civ_askForToolkit_server = compile preprocessFileLineNumbers "duws\functions\misc\fnc_civ_askForToolkit_server.sqf";
publicVariable "fnc_civ_askForToolkit_server";
fnc_disguiseAsCivilian = compile preprocessFileLineNumbers "duws\functions\misc\fnc_disguiseAsCivilian.sqf";
publicVariable "fnc_disguiseAsCivilian";
fnc_scanCivilianGear = compile preprocessFileLineNumbers "duws\functions\misc\fnc_scanCivilianGear.sqf";
publicVariable "fnc_scanCivilianGear";
fnc_civ_moveToPlayerServer = {
    params ["_unit", "_caller"];
    if (!isServer) exitWith {};
    if (isNull _unit || isNull _caller) exitWith {};
    
    // 清除平民所在组的所有路点
    { deleteWaypoint _x } forEach waypoints (group _unit);
    _unit doMove (getPos _caller);
    _unit setBehaviour "AWARE";
    _unit setSpeedMode "NORMAL";
    sleep 5;
    doStop _unit;
};
publicVariable "fnc_civ_moveToPlayerServer";

fnc_recruitSuccessServer = {
    params ["_target", "_caller", "_civNetId"];
    if (!isServer) exitWith {};
    
    // 如果_target为空，用网络ID重建
    if (isNull _target) then {
        _target = objectFromNetId _civNetId;
    };
    if (isNull _caller) exitWith {};
    if (isNull _target || !alive _target) exitWith {
        diag_log "[RECRUIT] Server: target is null or dead";
    };
    
    // ========== 扣除 2 个 Money_roll ==========
    private _moneyCount = { _x == "Money_roll" } count (magazines _caller);
    if (_moneyCount < 2) exitWith {
        [localize "STR_DUWS_T_nocpinf2"] remoteExec ["hint", _caller];
        diag_log "[RECRUIT] Server: Money roll insufficient, recruitment aborted";
    };
    for "_i" from 1 to 2 do {
        _caller removeMagazineGlobal "Money_roll";
    };
    // =========================================
    
    // 原有代码：设置俘虏状态，广播等
    _target setCaptive false;
    private _netId = netId _target;
    [_netId, false] remoteExec ["fnc_globalSetCaptive", 0];
    
    // 清除死亡事件和路点
    _target removeAllEventHandlers "Killed";
    private _oldGroup = group _target;
    while {count (waypoints _oldGroup) > 0} do {
        deleteWaypoint ((waypoints _oldGroup) select 0);
    };
    // 加入玩家组
    [_target] joinSilent (group _caller);
    _target allowDamage true;
    // 多次加入确保（原代码有重复，保留）
    [_target] joinSilent (group _caller);
    [_target] joinSilent (group _caller);
    [_target] joinSilent (group _caller);
    [_target] joinSilent (group _caller);
    [_target] joinSilent (group _caller);
    
    // 设置战斗行为
    _target enableAI "PATH";
    _target setBehaviour "AWARE";
    _target setCombatMode "RED";
    _target enableAI "AUTOTARGET";
    _target enableAI "TARGET";
    _target setUnitPos "AUTO";
    [_target] joinSilent (group _caller);
    
    // 武装
    private _weaponPool = [
        ["hgun_PDW2000_F", "30Rnd_9x21_Mag"],
        ["arifle_AKS_F", "30Rnd_545x39_Mag_F"],
        ["SMG_05_F", "30Rnd_9x21_Mag_SMG_02"],
        ["sgun_HunterShotgun_01_F", "2Rnd_12Gauge_Pellets"],
        ["sgun_HunterShotgun_01_sawedoff_F", "2Rnd_12Gauge_Pellets"],
        ["srifle_DMR_06_hunter_F", "10Rnd_762x51_Mag"],
        ["hgun_P07_F", "16Rnd_9x21_Mag"],
        ["hgun_Pistol_01_F", "10Rnd_9x21_Mag"]
    ];
    private _weaponEntry = selectRandom _weaponPool;
    private _weapon = _weaponEntry select 0;
    private _magazine = _weaponEntry select 1;
    [_target] joinSilent (group _caller);
    
    removeAllWeapons _target;
    for "_i" from 1 to 3 do {
        _target addMagazineGlobal _magazine;
    };
    _target addWeapon _weapon;
    [_target] joinSilent (group _caller);
    
    // 提示执行者
    [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_RECRUIT_SUCCESS"] remoteExec ["BIS_fnc_showSubtitle", _caller];
    [localize "STR_DUWS_T_RECRUIT_SUCCESS_HINT"] remoteExec ["hint", _caller];
    [_target] joinSilent (group _caller);
};
publicVariable "fnc_recruitSuccessServer";

// WARCOM FUNCTIONS
fnc_WARCOM_init = compile preprocessFileLineNumbers "duws\functions\warcom\fnc_WARCOM_init.sqf";
fnc_WARCOM_wp_blu_assault = compile preprocessFileLineNumbers "duws\functions\warcom\fnc_WARCOM_wp_blu_assault.sqf";
fnc_WARCOM_blu_patrol = compile preprocessFileLineNumbers "duws\functions\warcom\fnc_WARCOM_blu_patrol.sqf";
fnc_WARCOM_wp_blu_patrol = compile preprocessFileLineNumbers "duws\functions\warcom\fnc_WARCOM_wp_blu_patrol.sqf";
fnc_WARCOM_opf_patrol = compile preprocessFileLineNumbers "duws\functions\warcom\fnc_WARCOM_opf_patrol.sqf";
fnc_WARCOM_wp_opf_patrol = compile preprocessFileLineNumbers "duws\functions\warcom\fnc_WARCOM_wp_opf_patrol.sqf";
fnc_WARCOM_opf_assault = compile preprocessFileLineNumbers "duws\functions\warcom\fnc_WARCOM_opf_assault.sqf";
fnc_WARCOM_wp_opf_assault = compile preprocessFileLineNumbers "duws\functions\warcom\fnc_WARCOM_wp_opf_assault.sqf";
fnc_WARCOM_wp_opf_qrf = compile preprocessFileLineNumbers "duws\functions\warcom\fnc_WARCOM_wp_opf_qrf.sqf";
fnc_WARCOM_opf_air = compile preprocessFileLineNumbers "duws\functions\warcom\fnc_WARCOM_opf_air.sqf";
fnc_random_veh_blu_patrol = compile preprocessFileLineNumbers "duws\functions\warcom\fnc_random_veh_blu_patrol.sqf";
fnc_random_veh_opf_patrol = compile preprocessFileLineNumbers "duws\functions\warcom\fnc_random_veh_opf_patrol.sqf";
fnc_WARCOM_gps_marker = compile preprocessFileLineNumbers "duws\functions\warcom\fnc_WARCOM_gps_marker.sqf";

// ZONE FUNCTIONS
fnc_zonesundercontrol = compile preprocessFileLineNumbers "duws\functions\misc\fnc_zonesundercontrol.sqf";
fnc_locatorZones_random = compile preprocessFileLineNumbers "duws\functions\init_zones\fnc_locatorZones_random.sqf";
fnc_captured = compile preprocessFileLineNumbers "duws\functions\init_zones\fnc_captured.sqf";
fnc_blufor_cap = compile preprocessFileLineNumbers "duws\functions\init_zones\fnc_blufor_cap.sqf";
fnc_opfor_cap = compile preprocessFileLineNumbers "duws\functions\init_zones\fnc_opfor_cap.sqf";
fnc_enterlocation = compile preprocessFileLineNumbers "duws\functions\misc\fnc_enterlocation.sqf";
fnc_spawnWait = compile preprocessFileLineNumbers "duws\functions\init_zones\fnc_spawnWait.sqf";
fnc_createopfortified = compile preprocessFileLineNumbers "duws\functions\init_zones\fnc_createopfortified.sqf";
fnc_createoppatrol_sniper = compile preprocessFileLineNumbers "duws\functions\init_zones\fnc_createoppatrol_sniper.sqf";
fnc_createoppatrol2 = compile preprocessFileLineNumbers "duws\functions\init_zones\fnc_createoppatrol2.sqf";
fnc_createopteam = compile preprocessFileLineNumbers "duws\functions\init_zones\fnc_createopteam.sqf";
fnc_createopteam2 = compile preprocessFileLineNumbers "duws\functions\init_zones\fnc_createopteam2.sqf";
fnc_createopwpteam = compile preprocessFileLineNumbers "duws\functions\init_zones\fnc_createopwpteam.sqf";
fnc_random_veh = compile preprocessFileLineNumbers "duws\functions\init_zones\fnc_random_veh.sqf";
fnc_zone_reveal = compile preprocessFileLineNumbers "duws\functions\init_zones\fnc_zone_reveal.sqf";
fnc_zone_spawn_sizes = compile preprocessFileLineNumbers "duws\functions\init_zones\fnc_zone_spawn_sizes.sqf";

//////////////////
// ZONE PREFABS
//////////////////

switch (VERSION_X) do {
	case "MODERN": {
		fnc_modern_CommStation = compile preprocessFileLineNumbers "duws\functions\init_zones\prefabs\modern\fnc_modern_CommStation.sqf";
		fnc_modern_outpost1 = compile preprocessFileLineNumbers "duws\functions\init_zones\prefabs\modern\fnc_modern_outpost1.sqf";
		fnc_modern_Outpost2 = compile preprocessFileLineNumbers "duws\functions\init_zones\prefabs\modern\fnc_modern_Outpost2.sqf";
		fnc_modern_reconOutpost = compile preprocessFileLineNumbers "duws\functions\init_zones\prefabs\modern\fnc_modern_reconOutpost.sqf";
		fnc_modern_simple_zone = compile preprocessFileLineNumbers "duws\functions\init_zones\prefabs\modern\fnc_modern_simple_zone.sqf";
		fnc_modern_StorageBunker = compile preprocessFileLineNumbers "duws\functions\init_zones\prefabs\modern\fnc_modern_StorageBunker.sqf";
		fnc_modern_vehfittingstation = compile preprocessFileLineNumbers "duws\functions\init_zones\prefabs\modern\fnc_modern_vehfittingstation.sqf";
        fnc_modern_FieldHospital = compile preprocessFileLineNumbers "duws\functions\init_zones\prefabs\modern\fnc_modern_FieldHospital.sqf";
	};
};



//////////////////////////////
// GLOBAL FUNCTIONS
//////////////////////////////
fnc_ambient_musicloop = compile preprocessFileLineNumbers "duws\functions\sounds\fnc_ambient_musicloop.sqf";publicVariable "fnc_ambient_musicloop";
fnc_duws_Arsenal = compile preprocessFileLineNumbers "duws\functions\misc\fnc_duws_Arsenal.sqf";publicVariable "fnc_duws_Arsenal";
fnc_ghst_halo = compile preprocessFileLineNumbers "duws\functions\misc\fnc_ghst_halo.sqf";publicVariable "fnc_ghst_halo";
fnc_WARCOM_blu_assault = compile preprocessFileLineNumbers "duws\functions\warcom\fnc_WARCOM_blu_assault.sqf";publicVariable "fnc_WARCOM_blu_assault";
fnc_random_name = compile preprocessFileLineNumbers "duws\functions\misc\fnc_random_name.sqf";publicVariable "fnc_random_name";
fnc_BLUFOR_squad_init = compile preprocessFileLineNumbers "duws\functions\init_hq\fnc_BLUFOR_squad_init.sqf";publicVariable "fnc_BLUFOR_squad_init";
fnc_BLUFOR_faction_init = compile preprocessFileLineNumbers "duws\functions\init_hq\fnc_BLUFOR_faction_init.sqf";publicVariable "fnc_BLUFOR_faction_init";
fnc_fortifyFOB = compile preprocessFileLineNumbers "duws\functions\init_hq\fnc_fortifyFOB.sqf";publicVariable "fnc_fortifyFOB";
fnc_refortifyFOB = compile preprocessFileLineNumbers "duws\functions\init_hq\fnc_refortifyFOB.sqf";publicVariable "fnc_refortifyFOB";
fnc_guardsFOB = compile preprocessFileLineNumbers "duws\functions\init_hq\fnc_guardsFOB.sqf";publicVariable "fnc_guardsFOB";
fnc_reguardFOB = compile preprocessFileLineNumbers "duws\functions\init_hq\fnc_reguardFOB.sqf";publicVariable "fnc_reguardFOB";
fnc_createpatrolFOB = compile preprocessFileLineNumbers "duws\functions\init_hq\fnc_createpatrolFOB.sqf";publicVariable "fnc_createpatrolFOB";
fnc_locatorZones_manual = compile preprocessFileLineNumbers "duws\functions\init_zones\fnc_locatorZones_manual.sqf";publicVariable "fnc_locatorZones_manual";
fnc_createZone = compile preprocessFileLineNumbers "duws\functions\init_zones\fnc_createZone.sqf";publicVariable "fnc_createZone";
fnc_found_intel = compile preprocessFileLineNumbers "duws\functions\misc\fnc_found_intel.sqf";publicVariable "fnc_found_intel";
fnc_addHQSatelliteActions = compile preprocessFileLineNumbers "duws\functions\misc\fnc_addHQSatelliteActions.sqf";
publicVariable "fnc_addHQSatelliteActions";
fnc_restHealServer = compile preprocessFileLineNumbers "duws\functions\misc\fnc_restHealServer.sqf";
publicVariable "fnc_restHealServer";

// 如果实现了 HQ 建筑动作，也需添加：
fnc_addHQLaptopActions = compile preprocessFileLineNumbers "duws\functions\misc\fnc_addHQLaptopActions.sqf";
publicVariable "fnc_addHQLaptopActions";
fnc_addHQOfficerActions = compile preprocessFileLineNumbers "duws\functions\misc\fnc_addHQOfficerActions.sqf";
publicVariable "fnc_addHQOfficerActions";
fnc_addTerminalBlackMarketActions = compile preprocessFileLineNumbers "duws\functions\misc\fnc_addTerminalBlackMarketActions.sqf";
publicVariable "fnc_addTerminalBlackMarketActions";
fnc_blackMarketPurchase = compile preprocessFileLineNumbers "duws\functions\misc\fnc_blackMarketPurchase.sqf";
publicVariable "fnc_blackMarketPurchase";
fnc_intelAnalysis = compile preprocessFileLineNumbers "duws\functions\misc\fnc_intelAnalysis.sqf";
publicVariable "fnc_intelAnalysis";
// MISSION FUNCTIONS
fnc_stratmap = compile preprocessFileLineNumbers "duws\functions\missions\fnc_stratmap.sqf";publicVariable "fnc_stratmap";
fnc_missionLocator = compile preprocessFileLineNumbers "duws\functions\missions\fnc_missionLocator.sqf";publicVariable "fnc_missionLocator";


// DIALOG FUNCTIONS
fnc_HQ_faction_dialog = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_HQ_faction_dialog.sqf";publicVariable "fnc_HQ_faction_dialog";
fnc_HQ_manual_place = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_HQ_manual_place.sqf";publicVariable "fnc_HQ_manual_place";
fnc_HQ_random_place = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_HQ_random_place.sqf";publicVariable "fnc_HQ_random_place";
fnc_map_prompt = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_map_prompt.sqf";publicVariable "fnc_map_prompt";
fnc_HQ_endCampaign = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_HQ_endCampaign.sqf";publicVariable "fnc_HQ_endCampaign";
fnc_enviro_menu = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_enviro_menu.sqf";publicVariable "fnc_enviro_menu";
fnc_campaign_menu = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_campaign_menu.sqf";publicVariable "fnc_campaign_menu";
fnc_process_campaign_menu = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_process_campaign_menu.sqf";publicVariable "fnc_process_campaign_menu";
fnc_process_enviro_menu = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_process_enviro_menu.sqf";publicVariable "fnc_process_enviro_menu";
fnc_startup_closed = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_startup_closed.sqf";publicVariable "fnc_startup_closed";
fnc_startup_manual_zones = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_startup_manual_zones.sqf";publicVariable "fnc_startup_manual_zones";
fnc_startup_random_zones = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_startup_random_zones.sqf";publicVariable "fnc_startup_random_zones";
fnc_startup_back = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_startup_back.sqf";publicVariable "fnc_startup_back";
fnc_startup_faction_flow = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_startup_faction_flow.sqf";publicVariable "fnc_startup_faction_flow";
fnc_enviro_back = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_enviro_back.sqf";publicVariable "fnc_enviro_back";
fnc_startup_enviro_closed = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_startup_enviro_closed.sqf";publicVariable "fnc_startup_enviro_closed";
fnc_request_unit = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_request_unit.sqf";publicVariable "fnc_request_unit";
fnc_request_squad = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_request_squad.sqf";publicVariable "fnc_request_squad";
fnc_request_vehicle = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_request_vehicle.sqf";publicVariable "fnc_request_vehicle";
fnc_request_support = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_request_support.sqf";publicVariable "fnc_request_support";
fnc_convertAPtoCP = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_convertAPtoCP.sqf";publicVariable "fnc_convertAPtoCP";
fnc_request_unit_fob = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_request_unit_fob.sqf";publicVariable "fnc_request_unit_fob";
fnc_request_squad_fob = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_request_squad_fob.sqf";publicVariable "fnc_request_squad_fob";
fnc_request_vehicle_fob = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_request_vehicle_fob.sqf";publicVariable "fnc_request_vehicle_fob";
fnc_custom_faction_capture = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_custom_faction_capture.sqf";publicVariable "fnc_custom_faction_capture";
fnc_custom_faction_init = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_custom_faction_init.sqf";publicVariable "fnc_custom_faction_init";
fnc_HQ_Request_Menu = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_HQ_Request_Menu.sqf";publicVariable "fnc_HQ_Request_Menu";
fnc_FOB_Request_Menu = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_FOB_Request_Menu.sqf";publicVariable "fnc_FOB_Request_Menu";
fnc_squad_manage = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_squad_manage.sqf";publicVariable "fnc_squad_manage";
fnc_dismissHC = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_dismissHC.sqf";publicVariable "fnc_dismissHC";
fnc_dismiss_playerAI = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_dismiss_playerAI.sqf";publicVariable "fnc_dismiss_playerAI";
fnc_squad_rename = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_squad_rename.sqf";publicVariable "fnc_squad_rename";
fnc_groupReset = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_groupReset.sqf";publicVariable "fnc_groupReset";
fnc_rest_heal = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_rest_heal.sqf";publicVariable "fnc_rest_heal";
fnc_FOBmanager = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_FOBmanager.sqf";publicVariable "fnc_FOBmanager";
fnc_FOB_remove = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_FOB_remove.sqf";publicVariable "fnc_FOB_remove";
fnc_FOB_cleanup = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_FOB_cleanup.sqf";publicVariable "fnc_FOB_cleanup";
fnc_FOB_fast_travel = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_FOB_fast_travel.sqf";publicVariable "fnc_FOB_fast_travel";
fnc_MHQ_select = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_MHQ_select.sqf";publicVariable "fnc_MHQ_select";
fnc_MHQ_addActions = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_MHQ_addActions.sqf";publicVariable "fnc_MHQ_addActions";
fnc_MHQ_deploy = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_MHQ_deploy.sqf";publicVariable "fnc_MHQ_deploy";
fnc_MHQ_undeploy = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_MHQ_undeploy.sqf";publicVariable "fnc_MHQ_undeploy";
fnc_MHQ_destroyed = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_MHQ_destroyed.sqf";publicVariable "fnc_MHQ_destroyed";
fnc_actionRotary = compile preprocessFileLineNumbers "duws\functions\dialog\fnc_actionRotary.sqf";publicVariable "fnc_actionRotary";


// HQ & FOB FUNCTIONS
fnc_draw_HQicon = compile preprocessFileLineNumbers "duws\functions\init_hq\fnc_draw_HQicon.sqf";publicVariable "fnc_draw_HQicon";
fnc_HQaddactions = compile preprocessFileLineNumbers "duws\functions\init_hq\fnc_HQaddactions.sqf";publicVariable "fnc_HQaddactions";
fnc_FOBactions = compile preprocessFileLineNumbers "duws\functions\supports\fnc_FOBactions.sqf";publicVariable "fnc_FOBactions";
fnc_fob_server = compile preprocessFileLineNumbers "duws\functions\supports\fnc_fob_server.sqf";publicVariable "fnc_fob_server";


// SUPPORTS FUNCTIONS
fnc_ammobox = compile preprocessFileLineNumbers "duws\functions\supports\fnc_ammobox.sqf";publicVariable "fnc_ammobox";
fnc_arty = compile preprocessFileLineNumbers "duws\functions\supports\fnc_arty.sqf";publicVariable "fnc_arty";
fnc_mapclickarty = compile preprocessFileLineNumbers "duws\functions\supports\fnc_mapclickarty.sqf";publicVariable "fnc_mapclickarty";
fnc_mapclickuav = compile preprocessFileLineNumbers "duws\functions\supports\fnc_mapclickuav.sqf";publicVariable "fnc_mapclickuav";
fnc_uav_scanner = compile preprocessFileLineNumbers "duws\functions\supports\fnc_uav_scanner.sqf";publicVariable "fnc_uav_scanner";
fnc_paradrop = compile preprocessFileLineNumbers "duws\functions\supports\fnc_paradrop.sqf";publicVariable "fnc_paradrop";
fnc_request_fob = compile preprocessFileLineNumbers "duws\functions\supports\fnc_request_fob.sqf";publicVariable "fnc_request_fob";
fnc_request_hcATTchop = compile preprocessFileLineNumbers "duws\functions\supports\fnc_request_hcATTchop.sqf";publicVariable "fnc_request_hcATTchop";
fnc_request_hcCAS = compile preprocessFileLineNumbers "duws\functions\supports\fnc_request_hcCAS.sqf";publicVariable "fnc_request_hcCAS";
fnc_request_hcCAP = compile preprocessFileLineNumbers "duws\functions\supports\fnc_request_hcCAP.sqf";publicVariable "fnc_request_hcCAP";
fnc_sitrep_support = compile preprocessFileLineNumbers "duws\functions\supports\fnc_sitrep_support.sqf";publicVariable "fnc_sitrep_support";
fnc_veh_drop = compile preprocessFileLineNumbers "duws\functions\supports\fnc_veh_drop.sqf";publicVariable "fnc_veh_drop";
fnc_sawp_drop = compile preprocessFileLineNumbers "duws\functions\supports\fnc_sawp_drop.sqf";publicVariable "fnc_sawp_drop";
fnc_siva_drop = compile preprocessFileLineNumbers "duws\functions\supports\fnc_siva_drop.sqf";publicVariable "fnc_siva_drop";
fnc_helotaxi = compile preprocessFileLineNumbers "duws\functions\supports\taxi\fnc_helotaxi.sqf";publicVariable "fnc_helotaxi";
fnc_helolift = compile preprocessFileLineNumbers "duws\functions\supports\fnc_helolift.sqf";publicVariable "fnc_helolift";
fnc_mapclicklift = compile preprocessFileLineNumbers "duws\functions\supports\fnc_mapclicklift.sqf";publicVariable "fnc_mapclicklift";

fnc_mapclickhelo = compile preprocessFileLineNumbers "duws\functions\supports\taxi\fnc_mapclickhelo.sqf";publicVariable "fnc_mapclickhelo";
fnc_boattaxi = compile preprocessFileLineNumbers "duws\functions\supports\taxi\fnc_boattaxi.sqf";publicVariable "fnc_boattaxi";
fnc_mapclickboat = compile preprocessFileLineNumbers "duws\functions\supports\taxi\fnc_mapclickboat.sqf";publicVariable "fnc_mapclickboat";
fnc_taxi_music = compile preprocessFileLineNumbers "duws\functions\supports\taxi\fnc_taxi_music.sqf";publicVariable "fnc_taxi_music";


// MISC FUNCTIONS
fnc_hirePartisans = compile preprocessFileLineNumbers "duws\functions\misc\fnc_hirePartisans.sqf";
publicVariable "fnc_hirePartisans";
fnc_hirePMC = compile preprocessFileLineNumbers "duws\functions\misc\fnc_hirePMC.sqf";
publicVariable "fnc_hirePMC";
fnc_scanEnemyGear = compile preprocessFileLineNumbers "duws\functions\misc\fnc_scanEnemyGear.sqf";
publicVariable "fnc_scanEnemyGear";
fnc_disguiseAsEnemy = compile preprocessFileLineNumbers "duws\functions\misc\fnc_disguiseAsEnemy.sqf";
publicVariable "fnc_disguiseAsEnemy";
fnc_moreUrban_locations = compile preprocessFileLineNumbers "duws\functions\misc\fnc_moreUrban_locations.sqf";publicVariable "fnc_moreUrban_locations";
fnc_hc_init = compile preprocessFileLineNumbers "duws\functions\misc\fnc_hc_init.sqf";publicVariable "fnc_hc_init";
fnc_zones_bonus = compile preprocessFileLineNumbers "duws\functions\misc\fnc_zones_bonus.sqf";publicVariable "fnc_zones_bonus";
fnc_kndr_unit_markers = compile preprocessFileLineNumbers "duws\functions\misc\fnc_kndr_unit_markers.sqf";publicVariable "fnc_kndr_unit_markers";
fnc_player_markers = compile preprocessFileLineNumbers "duws\functions\misc\fnc_player_markers.sqf";publicVariable "fnc_player_markers";
fnc_earplugs = compile preprocessFileLineNumbers "duws\functions\misc\fnc_earplugs.sqf";publicVariable "fnc_earplugs";
fnc_duws_help = compile preprocessFileLineNumbers "duws\functions\misc\fnc_duws_help.sqf";publicVariable "fnc_duws_help";
fnc_bottom_right_message = compile preprocessFileLineNumbers "duws\functions\misc\fnc_bottom_right_message.sqf";publicVariable "fnc_bottom_right_message";
fnc_autoSave = compile preprocessFileLineNumbers "duws\functions\misc\fnc_autoSave.sqf";publicVariable "fnc_autoSave";
fnc_playerTF_spawn = compile preprocessFileLineNumbers "duws\functions\misc\fnc_playerTF_spawn.sqf";publicVariable "fnc_playerTF_spawn";
fnc_sideChat_filter = compile preprocessFileLineNumbers "duws\functions\misc\fnc_sideChat_filter.sqf";publicVariable "fnc_sideChat_filter";
fnc_sitrep_display = compile preprocessFileLineNumbers "duws\functions\misc\fnc_sitrep_display.sqf";publicVariable "fnc_sitrep_display";
fnc_fill_ammobox = compile preprocessFileLineNumbers "duws\functions\misc\fnc_fill_ammobox.sqf";publicVariable "fnc_fill_ammobox";
fnc_fill_sawpbox = compile preprocessFileLineNumbers "duws\functions\misc\fnc_fill_sawpbox.sqf";publicVariable "fnc_fill_sawpbox";
fnc_delete_napalm = compile preprocessFileLineNumbers "duws\functions\misc\fnc_delete_napalm.sqf";publicVariable "fnc_delete_napalm";
fnc_addQuickChangeActions = compile preprocessFileLineNumbers "duws\functions\misc\fnc_addQuickChangeActions.sqf";
publicVariable "fnc_addQuickChangeActions";
fnc_addNearbyUnitsGearToArsenal = compile preprocessFileLineNumbers "duws\functions\misc\fnc_addNearbyUnitsGearToArsenal.sqf";
publicVariable "fnc_addNearbyUnitsGearToArsenal";
fnc_scanNearbyUnitsForQuickChange = compile preprocessFileLineNumbers "duws\functions\misc\fnc_scanNearbyUnitsForQuickChange.sqf";
publicVariable "fnc_scanNearbyUnitsForQuickChange";
fnc_rearmUnit = compile preprocessFileLineNumbers "duws\functions\misc\fnc_rearmUnit.sqf";
publicVariable "fnc_rearmUnit";
fnc_activateBaseRecycleStation = compile preprocessFileLineNumbers "duws\functions\supports\fnc_activateBaseRecycleStation.sqf";
publicVariable "fnc_activateBaseRecycleStation";
fnc_activateBaseRepairStation = compile preprocessFileLineNumbers "duws\functions\supports\fnc_activateBaseRepairStation.sqf";
publicVariable "fnc_activateBaseRepairStation";
fnc_client_addRecycleActions = compile preprocessFileLineNumbers "duws\functions\supports\fnc_client_addRecycleActions.sqf";
publicVariable "fnc_client_addRecycleActions";
fnc_client_addRepairActions = compile preprocessFileLineNumbers "duws\functions\supports\fnc_client_addRepairActions.sqf";
publicVariable "fnc_client_addRepairActions";
fnc_redeployHQUnits = compile preprocessFileLineNumbers "duws\functions\misc\fnc_redeployHQUnits.sqf";
publicVariable "fnc_redeployHQUnits";
fnc_addRedeployAction = compile preprocessFileLineNumbers "duws\functions\misc\fnc_addRedeployAction.sqf";
publicVariable "fnc_addRedeployAction";
fnc_createKillhouse = compile preprocessFileLineNumbers "duws\functions\misc\fnc_createKillhouse.sqf";
publicVariable "fnc_createKillhouse";
// WARCOM FUNCTIONS
fnc_WARCOM_mapclick_assault = compile preprocessFileLineNumbers "duws\functions\warcom\fnc_WARCOM_mapclick_assault.sqf";publicVariable "fnc_WARCOM_mapclick_assault";

fnc_lbselected = compile preprocessFileLineNumbers "duws\operative\modern\fnc_lbselected.sqf";publicVariable "fnc_lbselected";
fnc_operative_mission_complete = compile preprocessFileLineNumbers "duws\operative\modern\fnc_operative_mission_complete.sqf";publicVariable "fnc_operative_mission_complete";
fnc_operator_init = compile preprocessFileLineNumbers "duws\operative\modern\fnc_operator_init.sqf";publicVariable "fnc_operator_init";
fnc_operator_open = compile preprocessFileLineNumbers "duws\operative\modern\fnc_operator_open.sqf";publicVariable "fnc_operator_open";
fnc_operator_recruit = compile preprocessFileLineNumbers "duws\operative\modern\fnc_operator_recruit.sqf";publicVariable "fnc_operator_recruit";
fnc_blu_taskforces_launch = compile preprocessFileLineNumbers "duws\functions\warcom\fnc_blu_taskforces_launch.sqf";
publicVariable "fnc_blu_taskforces_launch";
fnc_apocalypse_buildings = {
    diag_log "[Apocalypse] Starting building destruction with asset protection.";

    // ---------- 1. 收集所有需要保护的对象 ----------
    private _protected = [];

    // 总部主建筑
    if (!isNil "bluHQ_object" && {!isNull bluHQ_object}) then {
        _protected pushBack bluHQ_object;
    };
    // 军官
    if (!isNil "hq_blu1" && {!isNull hq_blu1}) then {
        _protected pushBack hq_blu1;
    };
    // 移动 HQ（如果存在）
    if (!isNil "MHQ1" && {!isNull MHQ1}) then {
        _protected pushBack MHQ1;
    };
    // 所有已建立的 FOB
    if (!isNil "Array_of_FOBS") then {
        {
            if (!isNull _x) then {
                _protected pushBack _x;
            };
        } forEach Array_of_FOBS;
    };
    // 如果 MHQ 已部署，保护其帐篷和弹药箱
    if (!isNil "MHQ_tent" && {!isNull MHQ_tent}) then {
        _protected pushBack MHQ_tent;
    };
    if (!isNil "MHQ_ammobox" && {!isNull MHQ_ammobox}) then {
        _protected pushBack MHQ_ammobox;
    };

    diag_log format ["[Apocalypse] Protected %1 key assets.", count _protected];

    // ---------- 2. 获取地图中心点（用于全图扫描） ----------
    private _center = getArray (configFile >> "CfgWorlds" >> worldName >> "centerPosition");
    if (_center isEqualTo []) then {
        _center = [worldSize / 2, worldSize / 2, 0];
    };

    // ---------- 3. 施加随机伤害（跳过保护对象） ----------
    private _buildings = nearestObjects [_center, ["Building", "House", "Ruins"], worldSize];
    diag_log format ["[Apocalypse] Found %1 potential buildings.", count _buildings];

    private _damagedCount = 0;
    {
        if (!isNull _x && {!(_x in _protected)}) then {
            _x allowDamage true;
            private _damage = 0.7 + random 0.15; // 0.7 ~ 0.85
            _x setDamage _damage;
            _damagedCount = _damagedCount + 1;
        };
    } forEach _buildings;

    diag_log format ["[Apocalypse] Successfully damaged %1 buildings.", _damagedCount];
};
publicVariable "fnc_apocalypse_buildings";
fnc_removeArsenalAction = {
    params ["_obj"];
    if (!hasInterface) exitWith {};
    if (!isNull _obj) then {
        private _id = _obj getVariable ["arsenalActionID", -1];
        if (_id != -1) then {
            _obj removeAction _id;
            _obj setVariable ["arsenalActionID", nil];
        };
    };
};
publicVariable "fnc_removeArsenalAction";
fnc_wbk_survivorKilled_server = {
    params ["_dead", "_killer", "_instigator"];
    private _idx = _dead getVariable ["civ_locIndex", -1];
    if (_idx == -1) exitWith {};
    
    private _popVar = format ["civ_pop_%1", _idx];
    private _remainingVar = format ["civ_remaining_%1", _idx];
    private _curPop = missionNamespace getVariable [_popVar, 0];
    if (_curPop <= 0) exitWith {};
    
    // 总人口减 1
    private _newPop = _curPop - 1;
    missionNamespace setVariable [_popVar, _newPop];
    
    // 更新地图图标（所有客户端）
    private _iconName = format ["civ_icon_%1", _idx];
    [_iconName, _newPop] remoteExec ["fnc_updateIcon", 0];
    
    // 检查是否有剩余人口可以补充
    private _remaining = missionNamespace getVariable [_remainingVar, 0];
    if (_remaining > 0) then {
        private _isZombie = _dead getVariable ["isZombie", false];
        private _newUnit = objNull;
        private _newGroup = grpNull;
        private _spawnPos = [_dead, 10, 50, 3, 0, 0.2, 0] call BIS_fnc_findSafePos;
        if (_spawnPos isEqualTo [0,0,0]) then { _spawnPos = getPos _dead; };
        
        if (_isZombie) then {
            // 生成僵尸
            private _zombieType = "";
            if (random 1 < 0.9) then {
                _zombieType = selectRandom ["Zombie_Special_OPFOR_Boomer", "Zombie_Special_OPFOR_Leaper_1", "Zombie_Special_OPFOR_Leaper_2", "Zombie_Special_OPFOR_Screamer", "WBK_SpecialZombie_Corrupted_3"];
            } else {
                _zombieType = selectRandom ["WBK_SpecialZombie_Smasher_3", "WBK_SpecialZombie_Smasher_Hellbeast_3", "WBK_SpecialZombie_Smasher_Acid_3", "WBK_Goliaph_3"];
            };
            _newGroup = createGroup EAST;
            _newUnit = _newGroup createUnit [_zombieType, _spawnPos, [], 0, "NONE"];
            _newUnit setBehaviour "COMBAT";
            _newUnit setCombatMode "RED";
            _newUnit setVariable ["isZombie", true, true];
            _newUnit addEventHandler ["Killed", {
                params ["_dead", "_killer", "_instigator"];
                [_dead, _killer, _instigator] remoteExec ["fnc_wbk_zombieKilled_server", 2];
            }];
        } else {
            // 生成幸存者
            private _survivorType = selectRandom ["C_man_p_beggar_F", "C_Man_casual_1_F", "C_Man_casual_3_F", "C_Man_casual_8_F", "C_Man_casual_6_v2_F", "C_Man_casual_2_F", "C_Man_UtilityWorker_01_F", "C_Man_Fisherman_01_F", "C_Man_p_shorts_1_F", "C_Man_w_worker_F"];
            _newGroup = createGroup RESISTANCE;
            _newUnit = _newGroup createUnit [_survivorType, _spawnPos, [], 0, "NONE"];
            // 添加装备等
            if (random 1 < 0.7) then {
                private _uniformList = if (random 1 < 0.7) then { blufor_uniforms } else { opfor_uniforms };
                if (count _uniformList > 0) then { _newUnit forceAddUniform (selectRandom _uniformList); };
            };
            if (random 1 < 0.5) then {
                private _helmetList = if (random 1 < 0.7) then { blufor_helmets } else { opfor_helmets };
                if (count _helmetList > 0) then { _newUnit addHeadgear (selectRandom _helmetList); };
            };
            if (random 1 < 0.7) then {
                private _vestList = if (random 1 < 0.7) then { blufor_vests } else { opfor_vests };
                if (count _vestList > 0) then { _newUnit addVest (selectRandom _vestList); };
            };
            _newUnit setBehaviour "CARELESS";
            _newUnit setCombatMode "BLUE";
            [_newUnit] remoteExec ["fnc_addRecruitAction", 0, true];
            _newUnit addEventHandler ["Killed", {
                params ["_dead", "_killer", "_instigator"];
                [_dead, _killer, _instigator] remoteExec ["fnc_wbk_survivorKilled_server", 2];
            }];
        };
        
        _newUnit setVariable ["civ_locIndex", _idx];
        // 将新单位加入城镇的组列表
        private _groups = missionNamespace getVariable [format ["civ_groups_%1", _idx], []];
        _groups pushBack _newGroup;
        missionNamespace setVariable [format ["civ_groups_%1", _idx], _groups];
        
        // 减少剩余人口
        missionNamespace setVariable [_remainingVar, _remaining - 1];
        diag_log format ["[WBK] Replacement spawned at location %1, remaining now %2", _idx, _remaining - 1];
    };
    
    diag_log format ["[WBK] Survivor killed at location %1, pop now %2", _idx, _newPop];
};
publicVariable "fnc_wbk_survivorKilled_server";

// WBK 模式死亡处理函数（服务器执行）
fnc_wbk_unitKilled_server = {
    params ["_dead", "_killer", "_instigator"];
    private _idx = _dead getVariable ["civ_locIndex", -1];
    if (_idx == -1) exitWith {};

    private _popVar = format ["civ_pop_%1", _idx];
    private _curPop = missionNamespace getVariable [_popVar, 0];
    if (_curPop <= 0) exitWith {};

    // 总人口减 1
    private _newPop = _curPop - 1;
    missionNamespace setVariable [_popVar, _newPop];

    // 增加剩余人口（用于下次补充）
    private _remVar = format ["civ_remaining_%1", _idx];
    private _rem = missionNamespace getVariable [_remVar, 0];
    missionNamespace setVariable [_remVar, _rem + 1];

    // 更新地图图标（所有客户端）
    private _iconName = format ["civ_icon_%1", _idx];
    [_iconName, _newPop] remoteExec ["fnc_updateIcon", 0];

    // 如果人口归零，发送鬼城通知，改变区域标记
    if (_newPop == 0) then {
        private _townName = text (missionNamespace getVariable ["civ_locations", []] select _idx);
        private _title = localize "STR_DUWS_T_TOWN_DEPOPULATED_TITLE";
        private _desc = format [localize "STR_DUWS_T_TOWN_DEPOPULATED_DESC", _townName];
        ["biohazard", [_title, _desc]] remoteExec ["BIS_fnc_showNotification", 0];
        private _areaMarker = format ["civ_area_%1", _idx];
        _areaMarker setMarkerColor "ColorBlack";
        _areaMarker setMarkerAlpha 0.3;
        _iconName setMarkerText "X";
        diag_log format ["[WBK] Town %1 is now depopulated.", _townName];
    };

    diag_log format ["[WBK] Unit killed at location %1, remaining total pop: %2", _idx, _newPop];
};
publicVariable "fnc_wbk_unitKilled_server";

// 辅助函数：更新图标
fnc_updateIcon = {
    params ["_iconName", "_pop"];
    if (_pop > 0) then {
        _iconName setMarkerText format ["%1", _pop];
    } else {
        _iconName setMarkerText "X";
    };
};
publicVariable "fnc_updateIcon";
fnc_changeFaceServer = {
    params ["_callerUID"];
    if (!isServer) exitWith {};
    private _player = objNull;
    {
        if (getPlayerUID _x == _callerUID) exitWith { _player = _x; };
    } forEach allPlayers;
    if (isNull _player) exitWith { diag_log "[FACE] Player not found"; };
    
    // 获取所有可用面部
    private _faces = getArray (configFile >> "CfgFaces" >> "Man" >> "faces");
    if (count _faces == 0) then {
        // 后备列表（原版常用）
        _faces = [
            "AfricanHead_01", "AfricanHead_02", "AfricanHead_03",
            "GreekHead_A3_01", "GreekHead_A3_02", "GreekHead_A3_03", "GreekHead_A3_04", "GreekHead_A3_05", "GreekHead_A3_06", "GreekHead_A3_07", "GreekHead_A3_08", "GreekHead_A3_09",
            "PersianHead_A3_01", "PersianHead_A3_02", "PersianHead_A3_03",
            "WhiteHead_01", "WhiteHead_02", "WhiteHead_03", "WhiteHead_04", "WhiteHead_05", "WhiteHead_06", "WhiteHead_07", "WhiteHead_08", "WhiteHead_09", "WhiteHead_10",
            "WhiteHead_11", "WhiteHead_12", "WhiteHead_13", "WhiteHead_14", "WhiteHead_15", "WhiteHead_16", "WhiteHead_17", "WhiteHead_18", "WhiteHead_19", "WhiteHead_20",
            "WhiteHead_21", "WhiteHead_22", "WhiteHead_23", "WhiteHead_24", "WhiteHead_25", "WhiteHead_26", "WhiteHead_27", "WhiteHead_28", "WhiteHead_29", "WhiteHead_30"
        ];
    };
    private _newFace = selectRandom _faces;
    _player setFace _newFace;
    
    private _msg = format [localize "STR_DUWS_T_FACE_CHANGED", _newFace];
    [_msg] remoteExec ["hint", _player];
};
publicVariable "fnc_changeFaceServer";

// 【新增】挂架设置（消耗 5 CP）
fnc_pylon_set_with_cost = {
    if (!isServer) exitWith {};
    params ["_netId", "_pylonIndex", "_magazine", ["_turret", []], "_requestingPlayerUID"];

    private _cost = 5;

    // 查找请求玩家
    private _player = objNull;
    { if (getPlayerUID _x == _requestingPlayerUID) exitWith { _player = _x } } forEach allPlayers;
    if (isNull _player) exitWith { diag_log "fnc_pylon_set_with_cost: player not found" };

    // CP 检查
    if (commandpointsblu1 < _cost) exitWith {
        [_cost] remoteExec ["fnc_pylon_hint_nocp", _player];
    };

    // 扣除 CP 并广播
    commandpointsblu1 = commandpointsblu1 - _cost;
    publicVariable "commandpointsblu1";

    // 执行挂架设置
    private _veh = objectFromNetId _netId;
    if (isNull _veh) exitWith { diag_log "fnc_pylon_set_with_cost: invalid netId" };
    _veh setPylonLoadout [_pylonIndex, _magazine, true, _turret];

    // 成功提示 → 仅通知操作者
    [_cost] remoteExec ["fnc_pylon_hint_success", _player];
};
publicVariable "fnc_pylon_set_with_cost";

// 客户端提示辅助函数
fnc_pylon_hint_nocp = {
    params ["_cost"];
    hint format [localize "STR_DUWS_T_PYLON_NO_CP", _cost];
};
publicVariable "fnc_pylon_hint_nocp";

fnc_pylon_hint_success = {
    params ["_cost"];
    hint format [localize "STR_DUWS_T_PYLON_SET_SUCCESS", _cost];
};
publicVariable "fnc_pylon_hint_success";

fnc_broadcastRadioChatter = {
    // 仅客户端执行
    if (!hasInterface) exitWith {};

    // ===== 互斥锁：防止多个广播重叠 =====
    if (missionNamespace getVariable ["DUWS_radioChatterRunning", false]) exitWith {};
    missionNamespace setVariable ["DUWS_radioChatterRunning", true];

    // ===== 自定义开头音效 =====
    private _startSound = "DUWS_Radio_Start";
    if (_startSound != "") then {
        playSound _startSound;
        sleep 0.2;   // 占位音效很短，等 0.2 秒足够（后续可根据实际音效长度调整）
    };

    // ===== 音效时长对照表（索引 0 对应 RadioAmbient1） =====
    private _durations = [
        18,  // RadioAmbient1
        11,  // RadioAmbient2
        12,  // RadioAmbient3
        8,   // RadioAmbient4
        10,  // RadioAmbient5
        8,   // RadioAmbient6
        8,   // RadioAmbient7
        13,  // RadioAmbient8
        9,   // RadioAmbient9
        10,  // RadioAmbient10
        7,   // RadioAmbient11
        19,  // RadioAmbient12
        8,   // RadioAmbient13
        9,   // RadioAmbient14
        9,   // RadioAmbient15
        13,  // RadioAmbient16
        8,   // RadioAmbient17
        11,  // RadioAmbient18
        12,  // RadioAmbient19
        7,   // RadioAmbient20
        4,   // RadioAmbient21
        5,   // RadioAmbient22
        10,  // RadioAmbient23
        9,   // RadioAmbient24
        11,  // RadioAmbient25
        10,  // RadioAmbient26
        10,  // RadioAmbient27
        11,  // RadioAmbient28
        20,  // RadioAmbient29
        10   // RadioAmbient30
    ];

    // RadioAmbient1..30 are vanilla CfgSounds, not shipped by the mission. A game
    // build may define fewer than 30, so a blind random pick can name a sound the
    // engine lacks and error out ("RadioAmbientN missing"). Pick only from names
    // that resolve, pairing each with its duration.
    private _pool = [];
    {
        private _name = format ["RadioAmbient%1", _forEachIndex + 1];
        if (isClass (configFile >> "CfgSounds" >> _name)) then {
            _pool pushBack [_name, _x];
        };
    } forEach _durations;

    if (_pool isEqualTo []) exitWith {
        missionNamespace setVariable ["DUWS_radioChatterRunning", false];
    };

    // 播放选中的无线电杂音
    private _pick = selectRandom _pool;
    playSound (_pick select 0);
    sleep (_pick select 1);   // 等待音效自然播完
    // 释放锁
    missionNamespace setVariable ["DUWS_radioChatterRunning", false];
};
publicVariable "fnc_broadcastRadioChatter";