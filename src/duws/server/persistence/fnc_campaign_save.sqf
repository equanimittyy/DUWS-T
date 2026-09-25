// Locality: server. What each group holds: docs/plans/campaign_persistence_plan.md#the-snapshot.
if (!isServer) exitWith {};

// Seconds; 0 leaves only the manual, last-disconnect and mission-end writes. The host's, never the snapshot's.
DUWS_autosaveInterval = ["DUWS_AutosaveInterval", 900] call BIS_fnc_getParamValue;

// Humans only: a headless client is in allPlayers, and one alone would hold the campaign open with nobody playing.
DUWS_fnc_humanCount = {
    params [["_exceptUID", ""]];
    { getPlayerUID _x isNotEqualTo _exceptUID } count (allPlayers - entities "HeadlessClient_F")
};

// Day 1 is the date boot sets (server/server_init.sqf).
DUWS_fnc_campaignDay = {
    params ["_d"];
    1 + floor ((((_d select 0) - 2035) + dateToNumber _d - dateToNumber [2035, 8, 3, 0, 0]) * 365)
};

// A tasking holds no handle, only netIds (its group, a helipad, the group an intercept hunts), and none resolves in
// the next session. A live group is read the way a stow reads it, so the unit comes back at the strength it had.
DUWS_fnc_campaignTaskings = {
    (missionNamespace getVariable ["DUWS_opcom_taskings", []]) apply {
        private _t = +_x;
        private _grp = groupFromNetId (_t getOrDefault ["grp", ""]);
        if (!isNull _grp && {count units _grp > 0}) then {
            _t set ["effForce", [_grp] call DUWS_fnc_opcom_effForceLive];
            _t set ["pos", getPosASL (leader _grp)];
            _t set ["route", []];
        };
        _t set ["grp", ""];
        _t set ["ferryPad", ""];
        if ("interceptKey" in _t) then { _t set ["interceptKey", ""] };
        // A mission-time stamp would sit in the next session's future and hold the capture for as long as this one ran.
        _t deleteAt "inZoneAt";
        if !((_t getOrDefault ["status", ""]) in ["dead", "done"]) then { _t set ["status", "virtual"] };
        _t
    }
};

// A streamed belt's squares are its whole state: the registry row names no geometry, and a field restored
// without them would read as cleared on the first pass. Only squares still holding mines are kept.
DUWS_fnc_campaignBelts = {
    (DUWS_hardpoints select { (_x select 2) isEqualTo "MINEFIELD" }) apply {
        private _key = _x select 0;
        private _squares = missionNamespace getVariable [format ["DUWS_hpMineSquares_%1", _key], []];
        [_key, (_squares select { (_x select 1) isNotEqualTo [] }) apply { _x select 0 },
            ([_key] call fnc_site_at) getOrDefault ["radius", 0]]
    } select { (_x select 1) isNotEqualTo [] }
};

DUWS_fnc_campaignSnapshot = {
    private _s = createHashMap;
    _s set ["version", DUWS_saveFormat];
    _s set ["world", worldName];
    _s set ["started", DUWS_campaignStarted];
    _s set ["saved", systemTimeUTC];
    _s set ["ended", DUWS_campaignEnded];
    _s set ["lost", [missionNamespace getVariable ["campaign_lost_body", ""], missionNamespace getVariable ["campaign_lost_ending", ""]]];

    _s set ["settings", createHashMapFromArray ((DUWS_campaignSettings select { !isNil _x }) apply { [_x, missionNamespace getVariable _x] })];
    _s set ["params", createHashMapFromArray (DUWS_campaignParams apply { [_x select 0, missionNamespace getVariable [_x select 1, _x select 2]] })];
    _s set ["factions", createHashMapFromArray [
        ["blu", BLUFOR_FactionFile_X], ["opf", OPFOR_FactionFile_X],
        ["bluSel", missionNamespace getVariable ["selectedFaction_BLU", ""]],
        ["opfSel", missionNamespace getVariable ["selectedFaction_OPF", ""]],
        ["bluData", BLUfactionDataTemp], ["opfData", OPFfactionDataTemp],
        ["edits", missionNamespace getVariable ["DUWS_factionListEdits", []]]
    ]];

    _s set ["hq", PosOfBLUHQ];
    _s set ["ao", AO_direction];
    _s set ["zones", zone_meta_array apply {
        _x params ["_num", "_pos", "_size", "_points", "_fortified", "_prefab"];
        private _i = zone_namePOS_pairs findIf { (_x select 1) isEqualTo _pos };
        [_num, (zone_namePOS_pairs param [_i, [""]]) select 0, _pos, _size, _points, _fortified, _prefab,
            missionNamespace getVariable [format ["DUWS_zoneKind_%1", [_pos] call fnc_zone_key], ""]]
    }];
    _s set ["zoneOrder", serv_zones_array];
    _s set ["zoneNames", missionNamespace getVariable ["DUWS_zoneNames", []]];
    private _fobs = [];
    { _fobs pushBack [_x, Array_of_FOBname param [_forEachIndex, ""]] } forEach Array_of_FOBpos;
    _s set ["fobs", _fobs];

    private _locs = missionNamespace getVariable ["civ_locations", []];
    private _radii = missionNamespace getVariable ["civ_radii", []];
    private _towns = [];
    {
        private _p = getPos _x;
        _towns pushBack [[_p select 0, _p select 1], _radii param [_forEachIndex, 100],
            missionNamespace getVariable [format ["civ_pop_%1", _forEachIndex], 0]];
    } forEach _locs;
    _s set ["towns", _towns];
    _s set ["vendors", missionNamespace getVariable ["DUWS_vendors", []]];

    _s set ["hardpoints", DUWS_hardpoints];
    _s set ["belts", call DUWS_fnc_campaignBelts];
    _s set ["radioSeq", missionNamespace getVariable ["DUWS_radioSeq", 0]];
    _s set ["unlocks", DUWS_support_permanent];

    _s set ["officerAlive", !isNil "hq_blu1" && {alive hq_blu1}];
    _s set ["clock", [date, DUWS_timeSkew]];
    _s set ["pools", [commandpointsblu1, WARCOM_blufor_ap, WARCOM_opfor_ap, WARCOM_blufor_ap_earned, WARCOM_opfor_ap_earned]];
    _s set ["held", WARCOM_zones_controled_by_BLUFOR];
    _s set ["firstCaptured", DUWS_zone_first_captured];
    _s set ["escalation", missionNamespace getVariable ["escalation_destroyed", 0]];

    private _siteKeys = zone_meta_array apply { [_x select 1] call fnc_zone_key };
    _s set ["zoneTiers", _siteKeys apply { [_x, [_x] call fnc_zone_tier] }];
    for "_i" from 0 to (count _locs - 1) do { _siteKeys pushBack ([_i] call fnc_town_site_key) };
    _s set ["garrisons", (_siteKeys select { !isNil { missionNamespace getVariable format ["DUWS_garrisonFull_%1", _x] } }) apply {
        [_x, missionNamespace getVariable format ["DUWS_garrisonFull_%1", _x],
            missionNamespace getVariable [format ["DUWS_garrisonLost_%1", _x], []]]
    }];

    // Absent, not empty, where towns keep no reputation (RAVAGE, WBK, NONE): a restore reads the group as missing.
    if (!isNil "civ_town_rep") then {
        _s set ["townRep", civ_town_rep];
        _s set ["townAp", civ_town_ap];
        _s set ["townGarrison", [DUWS_townGarrisonTier, DUWS_townGarrisonOwner]];
    };

    _s set ["revealedZones", (zone_namePOS_pairs select { _x select 2 }) apply { _x select 1 }];
    private _revealed = [];
    { if (_x) then { _revealed pushBack _forEachIndex } } forEach (missionNamespace getVariable ["civ_visible", []]);
    _s set ["revealedTowns", _revealed];

    // Defaults cover the few seconds between mission_init_complete and the OPCOM thread's first init.
    _s set ["opcom", createHashMapFromArray [
        ["archetype", DUWS_opcom_archetype],
        ["taskings", call DUWS_fnc_campaignTaskings], ["taskSeq", missionNamespace getVariable ["DUWS_opcom_taskSeq", 0]],
        ["attacks", missionNamespace getVariable ["DUWS_opcom_attacks", []]], ["attackSeq", missionNamespace getVariable ["DUWS_opcom_attackSeq", 0]],
        ["tick", missionNamespace getVariable ["DUWS_opcom_tick", 0]], ["hqKnown", missionNamespace getVariable ["DUWS_opcom_hqKnown", false]],
        ["mineVariants", DUWS_opcom_mineVariants], ["hpSeq", missionNamespace getVariable ["DUWS_hpOpcomSeq", 0]]
    ]];

    _s set ["garage", DUWS_garage_stored];
    private _lockout = ((missionNamespace getVariable ["MHQ_lockout_until", 0]) - time) max 0;
    _s set ["mhq", if (!isNil "MHQ1" && {alive MHQ1}) then {
        [[MHQ1] call DUWS_fnc_vehSpecCapture, missionNamespace getVariable ["MHQ_deployed", false], getPosATL MHQ1, getDir MHQ1, _lockout]
    } else {
        [[], false, [], 0, _lockout]
    }];
    _s set ["capturedPool", DUWS_capturedPool];
    // A spent-down class leaves the pool, so what was seeded is kept to tell it from a class a mod added since.
    if (DUWS_arsenalLimited) then { _s set ["seeded", missionNamespace getVariable ["DUWS_friendlyArsenal", []]] };
    _s
};

DUWS_fnc_campaignHeader = {
    params ["_s"];
    private _f = _s get "factions";
    createHashMapFromArray [
        ["version", _s get "version"], ["world", _s get "world"], ["saved", _s get "saved"],
        ["stamp", [_s get "saved"] call DUWS_fnc_saveStamp], ["day", [(_s get "clock") select 0] call DUWS_fnc_campaignDay],
        ["held", count (_s get "held")], ["zones", count (_s get "zones")], ["cp", (_s get "pools") select 0],
        ["blu", _f get "blu"], ["opf", _f get "opf"], ["bluSel", _f get "bluSel"], ["opfSel", _f get "opfSel"],
        ["ended", _s get "ended"], ["groups", keys _s]
    ]
};

// Called, never spawned: the last-disconnect write runs in the frame the mission may end in. Unscheduled inside,
// so no other script can move a pool between the reads that make one snapshot.
DUWS_fnc_campaignSave = {
    params [["_reason", ""]];
    if !(missionNamespace getVariable ["mission_init_complete", false]) exitWith {
        ["INFO", "SAVE", format ["%1 save skipped: the campaign is still being built", _reason]] call fnc_log; false
    };
    if (missionNamespace getVariable ["DUWS_restoring", false]) exitWith {
        ["INFO", "SAVE", format ["%1 save skipped: the restore is still replaying", _reason]] call fnc_log; false
    };
    private _done = false;
    isNil {
        private _s = call DUWS_fnc_campaignSnapshot;
        ([] call DUWS_fnc_campaignReconcile) params ["_cp", "_bluAp", "_opfAp"];
        private _p = _s get "pools";
        _p set [0, (_p select 0) + _cp];
        _p set [1, (_p select 1) + _bluAp];
        _p set [2, (_p select 2) + _opfAp];
        private _json = toJSON _s;
        _done = [DUWS_campaignID, _json, [_s] call DUWS_fnc_campaignHeader] call DUWS_fnc_saveCommit;
        ["INFO", "SAVE", format ["%1 save of campaign %2: %3 zones, %4 held, %5 garaged, %6 taskings, %7 bytes, refunds %8 CP %9 AP %10 OPF AP",
            _reason, DUWS_campaignID, count (_s get "zones"), count (_s get "held"), count (_s get "garage"),
            count ((_s get "opcom") get "taskings"), count _json, _cp, _bluAp, _opfAp]] call fnc_log;
    };
    if (DUWS_autosaveInterval > 0) then { DUWS_saveDue = time + DUWS_autosaveInterval };
    _done
};

// A write sets the next deadline, so a manual save pushes the timer out rather than being followed seconds later
// by an automatic one. Writes while anybody was on since the last pass, so the first empty pass banks the session.
DUWS_fnc_autosaveLoop = {
    ["INFO", "SAVE", format ["autosave every %1 s", DUWS_autosaveInterval]] call fnc_log;
    if (DUWS_autosaveInterval <= 0) exitWith {};
    DUWS_saveDue = time + DUWS_autosaveInterval;
    private _hadPlayers = true;
    while {true} do {
        try {
            sleep 10;
            if (time >= DUWS_saveDue) then {
                private _now = ([] call DUWS_fnc_humanCount) > 0;
                if (_now || _hadPlayers) then { ["interval"] call DUWS_fnc_campaignSave } else { DUWS_saveDue = time + DUWS_autosaveInterval };
                _hadPlayers = _now;
            };
        } catch {
            ["ERROR", "SAVE", format ["autosave pass threw, thread held alive: %1", _exception]] call fnc_log;
        };
    };
};
