
if (!isServer) exitWith {};
["INFO", "WARCOM", format ["Opfor Warcom Start Zone Placement. Manual: %1",  manually_chosen]] call fnc_log;

if (DUWS_campaignLoaded) then {
	call DUWS_fnc_restoreZones;
} else {
	if (!manually_chosen) then {
		if (!zones_created) then {
			[50,0.2] spawn fnc_locatorZones_random;
		};
	} else {
		if (!zones_created) then {
			[50,0.2] remoteExec ["fnc_locatorZones_manual", player1, false];
		};
	};
};

//Execution Order requires zone bonus and reward before WARCOM INIT
// Spawned exactly once, so territory income does not stack per zone captured. The period counts only time a human
// is on: a campaign left running overnight must not pay out, or arm the enemy, against nobody.
[] spawn {
    private _elapsed = 0;
    private _last = time;
    while {true} do {
        // A throw would kill this daemon for the whole session (see fnc_repetitive_cleanup).
        try {
            sleep 10;
            if (([] call DUWS_fnc_humanCount) > 0) then { _elapsed = _elapsed + (time - _last) };
            _last = time;
            if (_elapsed >= DUWS_econ_period) then {
                _elapsed = 0;
                call fnc_zonesundercontrol;
            };
        } catch {
            ["ERROR", "ECON", format ["econ tick threw, thread held alive: %1", _exception]] call fnc_log;
            _last = time;
            sleep 10;
        };
    };
};

while {!(["ZONES", "serv_zones_array populated by the zone locator", {count serv_zones_array > 0}, 300] call fnc_waitLogged)} do {};
sleep 1;
["INFO", "WARCOM", "Opfor Warcom Zones Placement Complete."] call fnc_log;
sleep 1;
["INFO", "WARCOM", format ["Opfor Warcom serv_zones_array: %1", serv_zones_array]] call fnc_log;

// Civilian towns come from the zones, so generation is a step of zone placement, not a race against
// it. Kicked off here because this is the one point both the random and manual locator funnel through
// on the server. Spawned (WARCOM below must not wait for build-out), and counted against
// serv_zones_array, not zones_number -- the origin keep-out in fnc_locatorzones_random can drop a zone
// slot, so a zones_number target would then never be reached.
[] spawn {
    // Build-out threads keep running after the locator clears its counter, so the map would sit blank
    // until the civilian pass starts unless ticked here on its own -- not inside the wait below, whose
    // condition polls far too often to hang a remoteExec off. Self-terminates on that same condition.
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
    // A loaded campaign with civilians off draws nothing after it, and a stale "3 of 4 complete"
    // would sit there until the map closed.
    [""] remoteExec ["fnc_map_prompt", [0,-2] select isDedicated];

    if (DUWS_campaignLoaded) then { call DUWS_fnc_restoreHardpoints };

    // Before a new campaign's hardpoints: the start tower weighs the towns, and every band pass reads the towns
    // that start in the OPFOR band.
    if (!isNil "CIV_PRESENCE" && {CIV_PRESENCE != "NONE"}) then { [] call fnc_civ_init_Tomata; };

    if (DUWS_campaignLoaded) then { call DUWS_fnc_restoreWorld };

    // Hard Point Generation is its own phase after zones and civilians, so emplacements read a fully-built
    // map. Reads zone_meta_array (complete by the wait above). Called, not spawned: fnc_hardpoint_site_zone
    // sleeps in its crew-drop, and running zones in sequence keeps the banner honest. Idempotent per zone
    // (the stored cap guards a rebuild), keyed by fnc_zone_key of the centre.
    //
    // The whole emplacement plan -- every zone's ring, the roadblock net, the two flank lines -- is
    // fixed before laying any of it, so the banner counts hardpoints toward a real total, not zones.
    // The roadblock net comes back pre-expanded to a [zonePos, endpointPos] target per block.
    if (!DUWS_campaignLoaded) then {
        ([] call fnc_hardpoint_plan_counts) params ["_zoneCounts", "_backline", "_frontline", "_roadTargets", "_obsN", "_hpTotal"];
        private _aaN = count serv_zones_array;
        private _hpDone = 0;
        // One banner draw per emplacement, across every pass alike, so the count climbs 1..N as each gun goes
        // down rather than jumping a whole pass's batch at once. _hpDone is read live off this scope (dynamic
        // scope holds across the call chain) and holds what prior passes finished, so _hpDone + _this is the
        // absolute number of the emplacement just laid; each pass then advances _hpDone by its own plan.
        private _tick = {
            private _msg = format ["Generating hardpoints...<br/>%1 of %2", _hpDone + _this, _hpTotal];
            [_msg] remoteExec ["fnc_map_prompt", [0,-2] select isDedicated];
            // Same climb in text chat, for when the map is closed and the overlay is unseen -- the mirror
            // zone generation runs (fnc_locatorzones_random). globalChat must run where player is local, so
            // it fires client-side via BIS_fnc_Spawn; the spawned code can only reach globals, so the line
            // crosses as a publicVariable rather than a captured local. Chat drops the <br/> the overlay uses.
            DUWS_hpChatMsg = format ["Placing hardpoint %1 of %2...", _hpDone + _this, _hpTotal];
            publicVariable "DUWS_hpChatMsg";
            [{player globalChat DUWS_hpChatMsg}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated, false];
        };
        // Opening frame so the banner is not blank through the first zone's crew drop; the first tick
        // redraws the same "1 of N".
        1 call _tick;

        // Zone rings first: each zone's own fortification, capped by its radius and tier.
        {
            _x params ["", "_hpPos", "_hpSize"];
            [_hpPos, _hpSize, [_hpPos] call fnc_zone_key, _zoneCounts select _forEachIndex, _tick] call fnc_hardpoint_site_zone;
            _hpDone = _hpDone + (_zoneCounts select _forEachIndex);
        } forEach zone_meta_array;

        // Then the standalone passes across the area of influence -- the countryside the enemy holds outside
        // its zones. Called, not spawned, like the zone loop: each sleeps in its crew drop, so finishing here
        // under the one generation banner keeps it honest.

        // The tower first: its reach widens the band every pass below samples.
        [_tick] call fnc_hardpoint_site_radio;
        _hpDone = _hpDone + 1;

        // Flank lines: gun nests in the half of the band farther from HQ (backline) and nearer to it (frontline),
        // offset from the zones rather than ringing them. The observation posts below site off the same draw.
        private _bandPts = call fnc_hardpoint_band_pool;
        [_backline, false, _bandPts, _tick] call fnc_hardpoint_site_flank;
        _hpDone = _hpDone + _backline;
        [_frontline, true, _bandPts, _tick] call fnc_hardpoint_site_flank;
        _hpDone = _hpDone + _frontline;

        // AA through the countryside to deny the airspace; the net reuses the band sampler with an AA-only mix.
        [_aaN, "hpaa", "", fnc_hardpoint_band_cand, _tick, fnc_hardpoint_band_anchor, createHashMapFromArray [["AA", 1]]] call fnc_hardpoint_lay;
        _hpDone = _hpDone + _aaN;
        // Observation posts -- eyes on the countryside between the zones, manned by a loose team but carrying no
        // gun. A per-zone coin flip rolled in fnc_hardpoint_plan_counts.
        [_obsN, _bandPts, _tick] call fnc_hardpoint_site_obs;
        _hpDone = _hpDone + _obsN;
        [_roadTargets, _tick] call fnc_hardpoint_site_roadblocks;
        _hpDone = _hpDone + count _roadTargets;

        // Ends on civilian init's parting banner, not a blank: a map with no towns keeps its warning up.
        [missionNamespace getVariable ["DUWS_civPrompt", ""]] remoteExec ["fnc_map_prompt", [0,-2] select isDedicated];
    };

    // The one thread that services every site, started once every site a campaign begins with has
    // registered itself. Outside the civilian gate above and after it deliberately: civilian init
    // gives up early on a map where no town qualifies, and starting the poller inside it left a
    // campaign with no civilians unable to spawn a zone garrison at all.
    //
    // A boolean rather than the script handle: a SCRIPT stored in the mission namespace has no
    // serialized form and would break the save (docs/info/architecture/arma_engine_gotchas.md). Nothing needs to
    // terminate this thread, so the handle is worth nothing anyway.
    if !(missionNamespace getVariable ["DUWS_sitePollerUp", false]) then {
        missionNamespace setVariable ["DUWS_sitePollerUp", true];
        [] spawn fnc_site_poller;
        // The reserve heartbeat rides beside the poller, and on the same latch: one server loop that
        // refills fought-over zones from their pools every few minutes. Inert until a zone with a
        // multiplier pool is contested, so starting it here costs nothing on a campaign at x1.
        [] spawn DUWS_fnc_garrisonReserveLoop;
    };

    // Last step of generation, called (not spawned) so it stays one: its census is a multi-second frame
    // stall, felt as a hitch unless the player is still watching the generation banner when it happens --
    // which spawning off WARCOM_init_done missed, landing right on the frame the banner cleared.
    // Outside the civilians-off gate above: the escalation counter never depends on the
    // civilian system. Only the town reputation charge inside it does, and with civilians off
    // that degrades to charging nothing.
    [] call fnc_escalation;
    if (DUWS_campaignLoaded) then { call DUWS_fnc_restoreEscalation };

    // After generation, not racing it: the OPCOM director WARCOM launches must read a fully built map.
    // Fire-and-forget -- mission_init_complete below must release the start even if WARCOM stalls.
    ["INFO", "WARCOM", "Starting WARCOM (OPCOM director)"] call fnc_log;
    [serv_zones_array, PosOfBLUHQ, WARCOM_blufor_ap, WARCOM_opfor_ap] spawn fnc_WARCOM_init;

    // Every completion announcement lives here rather than at the end of the zone locators: there they
    // fired while civilian towns were still being placed, telling the player the campaign was ready
    // before it was. Wrapped in BIS_fnc_Spawn so profileName, the map description and settings all read
    // on each client -- the random locator ran typeText server-side, showing nobody anything on a
    // dedicated host.
    [{player globalChat format[localize "STR_DUWS_T_d5e848d8",
        getText(configFile >> "cfgWorlds" >> worldName >> "description"), profileName]}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
    [{player globalChat localize "STR_DUWS_T_518bqchj"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
    // Eleven arguments in the order the summary rows expect -- order matters as much as count: a surplus or
    // missing arg pushes every later row onto the wrong label, and format discards the overflow silently
    // (docs/info/architecture/arma_engine_gotchas.md). Stamina has no row -- client/client_init.sqf forces
    // it on for everyone.
    [{hint format[localize "STR_DUWS_T_7mog9k78",
        zones_number,zones_max_radius,zones_min_radius,zones_max_dist_from_hq,
        weather_type,time_of_day,enable_fast_travel,
        ZeusStatus,simple_zones_enable,CIV_PRESENCE
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