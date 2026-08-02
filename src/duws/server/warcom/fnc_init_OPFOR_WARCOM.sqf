
if (!isServer) exitWith {};
["INFO", "WARCOM", format ["Opfor Warcom Start Zone Placement. Manual: %1",  manually_chosen]] call fnc_log;

 if (!manually_chosen) then {
	if (!zones_created) then {      // CHECK IF ZONES ALREADY PLACED,  RANDOM
		[50,0.2] spawn fnc_locatorZones_random; 
    };
 } else {
    if (!zones_created) then {      // CHECK IF ZONES ALREADY PLACED,  MANUAL
		[50,0.2] remoteExec ["fnc_locatorZones_manual", player1, false];
    };
 };

//Execution Order requires zone bonus and reward before WARCOM INIT
// Spawned exactly once, so territory income does not stack per zone captured.
[] spawn fnc_zonesundercontrol;

while {!(["ZONES", "serv_zones_array populated by the zone locator", {count serv_zones_array > 0}, 300] call fnc_waitLogged)} do {};
sleep 1;
["INFO", "WARCOM", "Opfor Warcom Zones Placement Complete."] call fnc_log;
sleep 1;
["INFO", "WARCOM", format ["Opfor Warcom serv_zones_array: %1", serv_zones_array]] call fnc_log;

// Civilian towns are chosen from the zones, so generation is a step of zone placement rather
// than a separate race against it. This is the one point both the random and the manual
// locator funnel through on the server, so the kick-off lives here instead of in each path.
// Spawned: WARCOM below must not wait for build-out. Counted against serv_zones_array, not
// zones_number -- the origin keep-out in fnc_locatorzones_random can drop a zone slot, and a
// zones_number target would then never be reached.
[] spawn {
    // Build-out threads keep running after the locator publishes positions and clears its
    // counter, so the map would otherwise sit blank until the civilian pass starts. Ticks on
    // its own rather than inside the wait below, whose condition is polled far too often to
    // hang a remoteExec off. Self-terminating on the same condition that wait gates on.
    [] spawn {
        while {zones_buildout_done < count serv_zones_array} do {
            [format ["Building zones...<br/>%1 of %2 complete",
                zones_buildout_done, count serv_zones_array]]
                remoteExec ["fnc_map_prompt", [0,-2] select isDedicated];
            sleep 2;
        };
    };

    while {!(["CIV", "all zones built out",
        {zones_buildout_done >= count serv_zones_array}, 300] call fnc_waitLogged)} do {};
    // The ticker exits on its own condition without redrawing, so clear its last frame here.
    // With civilians on the pass below overwrites it immediately; with civilians off nothing
    // would, and a stale "3 of 4 complete" would sit there until the map closed.
    [""] remoteExec ["fnc_map_prompt", [0,-2] select isDedicated];
    if (!isNil "CIV_PRESENCE" && {CIV_PRESENCE != "NONE"}) then { [] call fnc_civ_init_Tomata; };

    // The one thread that services every site, started once every site a campaign begins with has
    // registered itself. Outside the civilian gate above and after it deliberately: civilian init
    // gives up early on a map where no town qualifies, and starting the poller inside it left a
    // campaign with no civilians unable to spawn a zone garrison at all.
    //
    // A boolean rather than the script handle: a SCRIPT stored in the mission namespace has no
    // serialized form and would break the save (docs/info/arma_engine_gotchas.md). Nothing needs to
    // terminate this thread, so the handle is worth nothing anyway.
    if !(missionNamespace getVariable ["DUWS_sitePollerUp", false]) then {
        missionNamespace setVariable ["DUWS_sitePollerUp", true];
        [] spawn fnc_site_poller;
    };

    // Last step of generation, and called rather than spawned so it is: its census is a
    // multi-second frame stall, and the only way that is not felt as a hitch is for the player
    // to still be watching the generation banner when it happens. Spawned off WARCOM_init_done
    // it landed on the frame the banner cleared instead.
    // Outside the civilians-off gate above: the escalation counter never depends on the
    // civilian system. Only the town reputation charge inside it does, and with civilians off
    // that degrades to charging nothing.
    [] call fnc_escalation;

    // Every completion announcement lives here rather than at the end of the zone locators:
    // there they fired while civilian towns were still being placed, telling the player the
    // campaign was ready before it was. Wrapped in BIS_fnc_Spawn so profileName, the map
    // description and the settings all read on each client -- the random locator ran the
    // typeText server-side, which showed nobody anything on a dedicated host.
    [{player globalChat format[localize "STR_DUWS_T_d5e848d8",
        getText(configFile >> "cfgWorlds" >> worldName >> "description"), profileName]}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
    [{player globalChat localize "STR_DUWS_T_518bqchj"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
    [{hint format[localize "STR_DUWS_T_7mog9k78",
        zones_number,zones_max_radius,zones_min_radius,zones_max_dist_from_hq,
        weather_type,time_of_day,enable_fast_travel,
        ZeusStatus,staminaEnabled,VCOM_AI_enable,time_Multiplier,simple_zones_enable,CIV_PRESENCE
    ]}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
    [{[
        [
            [localize "STR_DUWS_T_518bqchj","<t align = 'center' shadow = '1' size = '0.7'>%1</t><br/>"],
            [localize "STR_DUWS_T_37xxl2nt","<t align = 'center' shadow = '1' size = '0.7'>%1</t><br/>"],
            [format[localize "STR_DUWS_T_dqxeffa2",getText(configFile >> "cfgWorlds" >> worldName >> "description"),profileName],"<t align = 'center' shadow = '1' size = '0.7'>%1</t><br/>"]
        ]
    ] spawn BIS_fnc_typeText}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];

    ["INFO", "BOOT", "Mission initialization complete: zones built and civilians registered."] call fnc_log;
    mission_init_complete = true;
    publicVariable "mission_init_complete";
};

["INFO", "WARCOM", "Opfor Warcom Start WARCOM zone patrols."] call fnc_log;

[serv_zones_array, PosOfBLUHQ, [0,0,0], WARCOM_blufor_ap, WARCOM_opfor_ap, 1800, blufor_ai_skill, opfor_ai_skill, 1800] spawn fnc_WARCOM_init; // 2700 is 40 mins
while {!(["WARCOM", "WARCOM_init_done", {WARCOM_init_done}, 300] call fnc_waitLogged)} do {};
sleep 1;