// Locality: server. Each hook sets state and calls the builder a fresh campaign calls, so there is one code path
// that builds a zone, a town or a base. Order: docs/plans/campaign_persistence_plan.md#restore. DUWS_restoring
// blocks every save until the last hook has run: a snapshot taken mid-replay would describe half a campaign.
if (!isServer) exitWith {};

DUWS_campaignLoaded = false;
DUWS_restoring = false;

DUWS_fnc_restoreCheck = {
    params ["_d"];
    if !(_d isEqualType createHashMap) exitWith { "STR_DUWS_T_LOAD_BAD_INPUT" };
    if ((_d getOrDefault ["version", -1]) isNotEqualTo DUWS_saveFormat) exitWith { "STR_DUWS_T_LOAD_BAD_VERSION" };
    if ((_d getOrDefault ["ended", ""]) isEqualTo "lost") exitWith { "STR_DUWS_T_LOAD_LOST" };
    if ((_d getOrDefault ["ended", ""]) isEqualTo "won") exitWith { "STR_DUWS_T_LOAD_WON" };
    if ((_d getOrDefault ["world", ""]) isNotEqualTo worldName) exitWith { "STR_DUWS_T_LOAD_BAD_WORLD" };
    private _types = [
        ["settings", createHashMap], ["factions", createHashMap], ["hq", []], ["zones", []], ["hardpoints", []]
    ];
    if ((_types findIf { !((_d getOrDefault [_x select 0, 0]) isEqualType (_x select 1)) }) >= 0) exitWith { "STR_DUWS_T_LOAD_BAD_INPUT" };
    if (count (_d get "hq") < 2 || {(_d get "zones") isEqualTo []}) exitWith { "STR_DUWS_T_LOAD_BAD_INPUT" };
    ""
};

// The fork's answer: [] for a new campaign, [id, usePrev] to load one. A load that fails leaves the fork open, so
// only the timeout's own pick falls through to a new campaign.
DUWS_fnc_saveChoose = {
    params [["_choice", []]];
    if (!isNil "DUWS_loadChoice") exitWith {};
    private _why = if (_choice isEqualTo []) then { "" } else { (_choice call DUWS_fnc_restoreRead) select 1 };
    if (_why isNotEqualTo "") exitWith {
        ["ERROR", "SAVE", format ["campaign %1 could not be loaded (%2); the load screen stays open", _choice, _why]] call fnc_log;
        ["loadRefused", _why] remoteExec ["fnc_campaign_reply", remoteExecutedOwner];
    };
    DUWS_loadChoice = _choice;
    ["INFO", "SAVE", format ["fork answered: %1", ["new campaign", format ["load %1", _choice]] select (_choice isNotEqualTo [])]] call fnc_log;
};

DUWS_fnc_saveDeleteRequest = {
    params ["_id"];
    [_id] call DUWS_fnc_saveDelete;
    call DUWS_fnc_saveScan;
};

// A new ID, never the payload's own, so an import cannot overwrite a campaign already on this machine.
DUWS_fnc_saveImport = {
    params ["_json"];
    private _d = if (_json isEqualType "") then { [fromJSON _json] param [0, 0] } else { 0 };
    private _why = [_d] call DUWS_fnc_restoreCheck;
    if (_why isNotEqualTo "") exitWith {
        ["WARN", "SAVE", format ["import refused (%1), %2 characters", _why, count _json]] call fnc_log;
        ["refused", _why] remoteExec ["fnc_campaign_reply", remoteExecutedOwner];
    };
    private _id = call DUWS_fnc_saveNewID;
    [_id, _json, [_d] call DUWS_fnc_campaignHeader] call DUWS_fnc_saveCommit;
    ["INFO", "SAVE", format ["imported a campaign as %1, %2 characters", _id, count _json]] call fnc_log;
    call DUWS_fnc_saveScan;
};

// Sent back to the machine that asked: copyToClipboard writes the clipboard of the machine it runs on.
DUWS_fnc_saveExport = {
    params ["_id"];
    private _json = (call DUWS_fnc_saveNamespace) getVariable [format ["DUWST_save_%1", _id], ""];
    if (_json isEqualTo "") exitWith {};
    ["export", _json] remoteExec ["fnc_campaign_reply", remoteExecutedOwner];
};

// -> [payload, refusal key]; the payload is 0 when neither save parses.
DUWS_fnc_restoreRead = {
    params ["_id", "_prev"];
    private _data = [_id, _prev] call DUWS_fnc_saveRead;
    // Writes are not atomic, so a payload that does not parse falls back to the one written an interval before.
    if (isNil "_data" && {!_prev}) then {
        _data = [_id, true] call DUWS_fnc_saveRead;
        if (!isNil "_data") then { ["WARN", "SAVE", format ["campaign %1 did not parse; loading the save before it", _id]] call fnc_log };
    };
    if (isNil "_data") exitWith { [0, "STR_DUWS_T_LOAD_BAD_INPUT"] };
    [_data, [_data] call DUWS_fnc_restoreCheck]
};

// -> true when the answer loaded a campaign.
DUWS_fnc_restoreAnswer = {
    params ["_choice"];
    (if (_choice isEqualTo []) then { [0, ""] } else { _choice call DUWS_fnc_restoreRead }) params ["_data", "_why"];
    if (_why isNotEqualTo "") then {
        ["ERROR", "SAVE", format ["campaign %1 could not be loaded (%2); starting a new campaign", _choice, _why]] call fnc_log;
    };
    if (_choice isEqualTo [] || {_why isNotEqualTo ""}) exitWith {
        if (isNil "DUWS_campaignID") then {
            DUWS_campaignID = call DUWS_fnc_saveNewID;
            DUWS_campaignStarted = systemTimeUTC;
            DUWS_campaignEnded = "";
            ["INFO", "SAVE", format ["new campaign %1", DUWS_campaignID]] call fnc_log;
        };
        DUWS_setupPhase = "new";
        publicVariable "DUWS_setupPhase";
        false
    };
    // Reached from the faction screen's Back, a table a confirmation locked would otherwise be laid over the load.
    duws_faction_locked = [];
    publicVariable "duws_faction_locked";
    [_choice select 0, _data] call DUWS_fnc_restoreApply;
    DUWS_setupPhase = "load";
    publicVariable "DUWS_setupPhase";
    true
};

// With nothing saved the terrain survey starts under the fork, so no new campaign waits on the screen. The bound
// is short while nobody is connected, so an unattended restart comes back up on its own campaign. Unbounded when
// nothing loads, so the game master lands on each save's refusal rather than on a new setup.
DUWS_fnc_restoreGate = {
    params ["_fnc_survey"];
    call DUWS_fnc_saveScan;
    private _survey = if (DUWS_saveList isEqualTo []) then { [] spawn _fnc_survey } else { scriptNull };
    DUWS_setupPhase = "choose";
    publicVariable "DUWS_setupPhase";
    private _start = time;
    waitUntil {
        sleep 1;
        !isNil "DUWS_loadChoice" || {time - _start > ([30, 600] select (([] call DUWS_fnc_humanCount) > 0))}
    };
    if (isNil "DUWS_loadChoice") then {
        private _i = DUWS_saveList findIf { (_x select 2) isEqualTo "" };
        private _newest = if (_i < 0) then { [] } else { [(DUWS_saveList select _i) select 0, false] };
        // A header can pass the scan over a payload that does not parse.
        if (_newest isNotEqualTo [] && {((_newest call DUWS_fnc_restoreRead) select 1) isEqualTo ""}) then {
            ["INFO", "SAVE", format ["fork unanswered after %1 s: loading the newest campaign %2", round (time - _start), _newest]] call fnc_log;
            DUWS_loadChoice = _newest;
        } else {
            ["INFO", "SAVE", format ["fork unanswered after %1 s: nothing loads, waiting for the game master", round (time - _start)]] call fnc_log;
            while {!(["SAVE", "the game master's answer to the load screen", {!isNil "DUWS_loadChoice"}, 600] call fnc_waitLogged)} do {};
        };
    };
    private _choice = DUWS_loadChoice;
    if ([_choice] call DUWS_fnc_restoreAnswer) then {
        if (!isNull _survey) then { terminate _survey };
    } else {
        if (isNull _survey) then { [] spawn _fnc_survey };
    };
};

// The faction screen's Back, for as long as nothing is built. A load chosen here applies on this thread; the boot
// thread is waiting in the faction screens' loop and leaves it once the load sets createzone_server.
DUWS_fnc_saveReopen = {
    if (DUWS_setupPhase isNotEqualTo "new" || {createzone_server}) exitWith {};
    DUWS_loadChoice = nil;
    call DUWS_fnc_saveScan;
    DUWS_setupPhase = "choose";
    publicVariable "DUWS_setupPhase";
    private _start = time;
    waitUntil { sleep 1; !isNil "DUWS_loadChoice" || {time - _start > 600} };
    [missionNamespace getVariable ["DUWS_loadChoice", []]] call DUWS_fnc_restoreAnswer;
};

DUWS_fnc_restoreKnown = {
    params ["_c"];
    isClass (configFile >> "CfgWeapons" >> _c) || {isClass (configFile >> "CfgMagazines" >> _c)}
        || {isClass (configFile >> "CfgVehicles" >> _c)} || {isClass (configFile >> "CfgGlasses" >> _c)}
};

// Containers match by class, not order: two copies of a class are interchangeable until they are filled.
DUWS_fnc_restoreCargo = {
    params ["_box", "_cargo"];
    _cargo params ["_weapons", "_mags", "_items", "_packs", "_nested"];
    clearWeaponCargoGlobal _box;
    clearMagazineCargoGlobal _box;
    clearItemCargoGlobal _box;
    clearBackpackCargoGlobal _box;
    private _known = { ((flatten [_this]) select { _x isEqualType "" && {_x != ""} }) findIf { !([_x] call DUWS_fnc_restoreKnown) } < 0 };
    private _dropped = 0;
    { if (_x call _known) then { _box addWeaponWithAttachmentsCargoGlobal [_x, 1] } else { _dropped = _dropped + 1 } } forEach _weapons;
    { if (_x call _known) then { _box addMagazineAmmoCargo [_x select 0, 1, _x select 1] } else { _dropped = _dropped + 1 } } forEach _mags;
    { if (_x call _known) then { _box addItemCargoGlobal [_x, 1] } else { _dropped = _dropped + 1 } } forEach _items;
    { if (_x call _known) then { _box addBackpackCargoGlobal [_x, 1] } else { _dropped = _dropped + 1 } } forEach _packs;
    DUWS_restoreDropped set ["crate", (DUWS_restoreDropped get "crate") + _dropped];
    private _free = everyContainer _box;
    {
        _x params ["_class", "_contents"];
        private _i = _free findIf { (_x select 0) isEqualTo _class };
        if (_i >= 0) then { [(_free deleteAt _i) select 1, _contents] call DUWS_fnc_restoreCargo };
    } forEach _nested;
};

DUWS_fnc_restoreApply = {
    params ["_id", "_d"];
    DUWS_restore = _d;
    DUWS_restoring = true;
    DUWS_campaignLoaded = true;
    DUWS_restoreDropped = createHashMapFromArray [["units", 0], ["vehicles", 0], ["gear", 0], ["crate", 0]];
    DUWS_restorePending = ["bases", "opcom"];
    DUWS_dialogueMuted = true;
    publicVariable "DUWS_dialogueMuted";
    DUWS_campaignID = _id;
    DUWS_campaignStarted = _d getOrDefault ["started", systemTimeUTC];
    DUWS_campaignEnded = _d getOrDefault ["ended", ""];

    // Re-broadcast, not only assigned: a client set these and published them, and every client needs them.
    { missionNamespace setVariable [_x, _y, true] } forEach (_d get "settings");
    private _params = _d getOrDefault ["params", createHashMap];
    {
        _x params ["_param", "_global"];
        missionNamespace setVariable [_global, _params getOrDefault [_param, missionNamespace getVariable _global], true];
    } forEach DUWS_campaignParams;
    DUWS_arsenalLimited = DUWS_paramArsenal == 2; publicVariable "DUWS_arsenalLimited";
    DUWS_trackAmmo = DUWS_paramTrackAmmo == 1; publicVariable "DUWS_trackAmmo";

    private _f = _d get "factions";
    BLUFOR_FactionFile_X = _f getOrDefault ["blu", BLUFOR_FactionFile_X]; publicVariable "BLUFOR_FactionFile_X";
    OPFOR_FactionFile_X = _f getOrDefault ["opf", OPFOR_FactionFile_X]; publicVariable "OPFOR_FactionFile_X";
    BLUfactionDataTemp = _f getOrDefault ["bluData", ""]; publicVariable "BLUfactionDataTemp";
    OPFfactionDataTemp = _f getOrDefault ["opfData", ""]; publicVariable "OPFfactionDataTemp";
    // Only a class this install defines: the AutoDetect wrappers generate from whatever these name.
    {
        _x params ["_var", "_sel"];
        if (_sel isEqualType "" && {isClass (configFile >> "CfgFactionClasses" >> _sel)}) then { missionNamespace setVariable [_var, _sel, true] };
    } forEach [["selectedFaction_BLU", _f getOrDefault ["bluSel", ""]], ["selectedFaction_OPF", _f getOrDefault ["opfSel", ""]]];

    PosOfBLUHQ = _d get "hq"; publicVariable "PosOfBLUHQ";
    AO_direction = _d getOrDefault ["ao", []]; publicVariable "AO_direction";
    manually_chosen = false; publicVariable "manually_chosen";
    (_d getOrDefault ["clock", [date, 0]]) params ["_date", "_skew"];
    DUWS_restoreDate = _date;
    DUWS_timeSkew = _skew; publicVariable "DUWS_timeSkew";

    // Nothing else recounts the levels, and a radio flag without its level is a tower with no reach.
    DUWS_support_permanent = +(_d getOrDefault ["unlocks", []]);
    publicVariable "DUWS_support_permanent";
    private _catalogue = [] call fnc_support_catalogue;
    {
        private _key = _x;
        private _i = _catalogue findIf { (_x select 0) isEqualTo _key };
        if (_i >= 0) then { missionNamespace setVariable [(_catalogue select _i) select 3, true, true] };
    } forEach DUWS_support_permanent;
    DUWS_bluforRadioLevel = { _x in ["radio1", "radio2", "radio3"] } count DUWS_support_permanent;
    DUWS_intelLevel = { _x in ["intel1", "intel2", "intel3", "intel4"] } count DUWS_support_permanent;
    DUWS_fortLevel = { _x in ["fort1", "fort2", "fort3", "fort4"] } count DUWS_support_permanent;

    // Classes a removed mod defined are dropped here rather than restored as names that spawn nothing.
    private _garage = (_d getOrDefault ["garage", []]) select { isClass (configFile >> "CfgVehicles" >> (_x param [0, ""])) };
    DUWS_restoreDropped set ["vehicles", count (_d getOrDefault ["garage", []]) - count _garage];
    DUWS_garage_stored = _garage; publicVariable "DUWS_garage_stored";
    private _pool = (_d getOrDefault ["capturedPool", []]) select { [_x param [0, ""]] call DUWS_fnc_restoreKnown };
    DUWS_restoreDropped set ["gear", count (_d getOrDefault ["capturedPool", []]) - count _pool];
    DUWS_capturedPool = _pool; publicVariable "DUWS_capturedPool";
    DUWS_limitedSeeded = _d getOrDefault ["seeded", []];

    // The one setting whose effect is terrain, and terrain resets with the session.
    if (missionNamespace getVariable ["apocalypse_mode", false]) then { [] spawn fnc_apocalypse_buildings };

    chosen_hq_placement = true; publicVariable "chosen_hq_placement";
    createzone_server = true; publicVariable "createzone_server";
    chosen_settings = true; publicVariable "chosen_settings";
    ["INFO", "SAVE", format ["loading campaign %1, saved %2, day %3", _id, _d get "saved",
        (_d getOrDefault ["clock", [[2035, 8, 3]]]) select 0]] call fnc_log;
};

// The used names go back too, or a later zone could draw a name already on the map.
DUWS_fnc_restoreZones = {
    missionNamespace setVariable ["DUWS_zoneNames", +(DUWS_restore getOrDefault ["zoneNames", []])];
    {
        _x params ["_num", "_name", "_pos", "_size", "_points", "_fortified", "_prefab", ["_kind", ""]];
        [_name, _points, _size, _pos, _fortified, _prefab, _num, _kind] spawn fnc_createZone;
        sleep 0.5;
    } forEach (DUWS_restore get "zones");
    serv_zones_array = +(DUWS_restore getOrDefault ["zoneOrder", (DUWS_restore get "zones") apply { _x select 2 }]);
    publicVariable "serv_zones_array";
};

// A fresh roll would move every hardpoint and orphan what the players cleared. A civilian job's field is laid whole
// as the job's prop, so it has no belt saved and goes with its job.
DUWS_fnc_restoreHardpoints = {
    {
        missionNamespace setVariable [format ["DUWS_hpCap_%1", [_x select 2] call fnc_zone_key], (round ((_x select 3) / 250)) max 1];
    } forEach (DUWS_restore get "zones");
    missionNamespace setVariable ["DUWS_radioSeq", DUWS_restore getOrDefault ["radioSeq", 0]];
    private _belts = createHashMapFromArray ((DUWS_restore getOrDefault ["belts", []]) apply { [_x select 0, _x select [1, 3]] });
    private _rows = DUWS_restore get "hardpoints";
    {
        _x params ["_key", "_pos", "_type", "_side", "_zoneKey", "_shown", ["_dir", 0]];
        [format ["Restoring hardpoints...<br/>%1 of %2", _forEachIndex + 1, count _rows]] remoteExec ["fnc_map_prompt", [0,-2] select isDedicated];
        private _built = false;
        if (_type isEqualTo "MINEFIELD") then {
            (_belts getOrDefault [_key, []]) params [["_centres", []], ["_ring", 0], ["_variant", "AT"]];
            if (_centres isNotEqualTo [] && {([_centres, _dir, _variant, _key] call fnc_hardpoint_minefield_stream) > 0}) then {
                [_centres, _dir, _key] call fnc_hardpoint_minefield_signs;
                [_key, _type, _pos, _side, _zoneKey, _dir, _ring] call fnc_hardpoint_register;
                _built = true;
            };
        } else {
            if (([_type, _pos, _dir, _side, _key] call fnc_hardpoint_build) isNotEqualTo []) then {
                [_key, _type, _pos, _side, _zoneKey, _dir] call fnc_hardpoint_register;
                _built = true;
            };
        };
        // Registration stamps generation's reveal rule; the snapshot's flag is what the players had found.
        private _i = DUWS_hardpoints findIf { (_x select 0) isEqualTo _key };
        if (_built && {_i >= 0}) then {
            (DUWS_hardpoints select _i) set [5, _shown];
            (format ["hpm_%1", _key]) setMarkerAlpha ([0, 1] select _shown);
        };
        if (!_built) then { ["INFO", "SAVE", format ["hardpoint %1 (%2) not restored", _key, _type]] call fnc_log };
    } forEach _rows;
    publicVariable "DUWS_hardpoints";
    [""] remoteExec ["fnc_map_prompt", [0,-2] select isDedicated];
    ["INFO", "SAVE", format ["%1 of %2 hardpoints restored", count DUWS_hardpoints, count _rows]] call fnc_log;
};

// A position the map no longer names a town at gets a Location of its own: every town record downstream is keyed
// by its index in this list.
DUWS_fnc_restoreTownQueue = {
    private _types = ["NameCityCapital", "NameCity", "NameVillage", "NameLocal"];
    [(DUWS_restore getOrDefault ["towns", []]) apply {
        _x params ["_pos", "_radius", "_pop"];
        private _loc = (nearestLocations [_pos, _types, 50]) param [0, locationNull];
        if (isNull _loc || {((getPos _loc) distance2D _pos) > 1}) then {
            ["WARN", "SAVE", format ["no town at %1 on this map; standing one in", _pos]] call fnc_log;
            _loc = createLocation ["NameVillage", _pos, _radius, _radius];
        };
        [_loc, _pop, false, [getPos _loc, 2, 350] call fnc_usableBuildings, _radius]
    }, []]
};

// fnc_captured's repaint, without its payouts or announcements.
DUWS_fnc_restorePaintHeld = {
    params ["_held"];
    private _key = [_held] call fnc_zone_key;
    private _meta = (DUWS_restore get "zones") select { ([_x select 2] call fnc_zone_key) isEqualTo _key };
    if (_meta isEqualTo []) exitWith {};
    (_meta select 0) params ["", "_name", "_pos", "_size", "_points"];
    private _marker = format ["%1%2", round (_pos select 0), round (_pos select 1)];
    str(_marker) setMarkerColor "ColorBlue";
    str(_marker + "ellipse") setMarkerColor "ColorBlue";
    str(_marker + "port") setMarkerColor "ColorBlue";
    private _flg = missionNamespace getVariable [format ["flag_%1_%2", floor abs (_pos select 0), floor abs (_pos select 1)], objNull];
    if (!isNull _flg) then {
        _flg setFlagTexture "\A3\Data_F\Flags\flag_blue_CO.paa";
        [_flg, true] call fnc_zone_flag_logistics;
    };
    private _trg = missionNamespace getVariable [format ["trigger_%1_%2", floor abs (_pos select 0), floor abs (_pos select 1)], objNull];
    if (!isNull _trg) then {
        _trg setTriggerStatements ["[thisTrigger getVariable 'DUWS_zoneKey', 'zone', EAST, WEST] call DUWS_fnc_siteTaken",
            format ["[""%1"",%2,""%3"",""%4"",%5,%6,%7] spawn fnc_opfor_cap", _name, _points, _marker, _marker + "ellipse", _pos, _size, 0], ""];
    };
};

// The outcomes, on the generation thread once zones, hardpoints and towns are built and before the site poller
// starts: a site the poller raised first would stand up the builders' defaults instead of what was saved.
DUWS_fnc_restoreWorld = {
    private _r = DUWS_restore;

    private _held = _r getOrDefault ["held", []];
    WARCOM_zones_controled_by_BLUFOR = +_held;
    publicVariable "WARCOM_zones_controled_by_BLUFOR";
    amount_zones_captured = count _held; publicVariable "amount_zones_captured";
    zoneundercontrolblu = count _held; publicVariable "zoneundercontrolblu";
    { [_x] call DUWS_fnc_restorePaintHeld } forEach _held;
    DUWS_zone_first_captured = +(_r getOrDefault ["firstCaptured", []]);

    { missionNamespace setVariable [format ["DUWS_zoneTier_%1", _x select 0], _x select 1] } forEach (_r getOrDefault ["zoneTiers", []]);
    // After the repaint, whose capture gate zeroes each held flag's balance.
    {
        _x params ["_zoneKey", "_credits", "_rows"];
        if (_rows isNotEqualTo []) then {
            DUWS_stowed set [format ["%1_builds", _zoneKey], _rows apply {
                _x params ["_class", "_pos", "_dirUp"];
                [_class, _pos, _dirUp, true, true, [], 0]
            }];
            if !(_zoneKey in DUWS_stowed) then { [_zoneKey] call DUWS_fnc_siteBuildDeploy };
        };
        ([_zoneKey] call DUWS_fnc_zoneFlag) setVariable ["R3F_LOG_CF_credits", _credits, true];
    } forEach (_r getOrDefault ["zoneBuilds", []]);
    // A site the save held no ledger for had forgotten it, as a capture does; fnc_createZone has since stamped a
    // fresh OPFOR one over every zone, which would hand a held zone the enemy's garrison.
    if ("garrisons" in _r) then {
        private _saved = (_r get "garrisons") apply { _x select 0 };
        private _sites = (_r get "zones") apply { [_x select 2] call fnc_zone_key };
        for "_i" from 0 to (count (_r getOrDefault ["towns", []]) - 1) do { _sites pushBack ([_i] call fnc_town_site_key) };
        {
            if !(_x in _saved) then {
                missionNamespace setVariable [format ["DUWS_garrisonFull_%1", _x], nil];
                missionNamespace setVariable [format ["DUWS_garrisonLost_%1", _x], nil];
            };
        } forEach _sites;
    };
    {
        _x params ["_key", "_full", "_lost"];
        missionNamespace setVariable [format ["DUWS_garrisonFull_%1", _key], _full];
        missionNamespace setVariable [format ["DUWS_garrisonLost_%1", _key], _lost];
    } forEach (_r getOrDefault ["garrisons", []]);

    private _rep = _r getOrDefault ["townRep", []];
    if (!isNil "civ_town_rep" && {count _rep isEqualTo count civ_town_rep}) then {
        civ_town_rep = +_rep;
        civ_town_ap = +(_r getOrDefault ["townAp", civ_town_ap]);
        (_r getOrDefault ["townGarrison", [DUWS_townGarrisonTier, DUWS_townGarrisonOwner]]) params ["_tiers", "_owners"];
        DUWS_townGarrisonTier = +_tiers;
        DUWS_townGarrisonOwner = +_owners;
        for "_i" from 0 to (count civ_town_rep - 1) do {
            [_i] call fnc_civ_townRender;
            { [_i, _forEachIndex] call fnc_vendor_markerPaint } forEach ([_i] call fnc_vendor_recs);
        };
        [] call fnc_enemy_towns_refresh;
    };

    { ["ONE", _x, true] call fnc_zone_reveal } forEach (_r getOrDefault ["revealedZones", []]);
    { [_x, true] call fnc_civ_town_reveal } forEach (_r getOrDefault ["revealedTowns", []]);

    // Deleted rather than killed: the officer's watcher would announce the death and judge the lose condition
    // again, and a campaign that ended on it is already carried as ended.
    if !(_r getOrDefault ["officerAlive", true]) then {
        DUWS_officerLost = true;
        deleteVehicle hq_blu1;
    };
    if ("vehicle_depot" in DUWS_support_permanent) then {
        [] call fnc_activateBaseRepairStation;
        [] call fnc_activateBaseRecycleStation;
    };
    [] spawn DUWS_fnc_restoreBases;
    ["INFO", "SAVE", format ["world restored: %1 zones held, %2 zones and %3 towns revealed", count _held,
        count (_r getOrDefault ["revealedZones", []]), count (_r getOrDefault ["revealedTowns", []])]] call fnc_log;
};

// One FOB at a time: fnc_fob_server appends to three index-parallel registries across a suspension, and two
// builds in flight could interleave them. Vehicles last, once every anchor stands.
DUWS_fnc_restoreBases = {
    { _x params ["_pos", "_name"]; [_pos, 0, "", _name] call fnc_fob_server } forEach (DUWS_restore getOrDefault ["fobs", []]);
    // After the FOBs stand, since each is found by the position its build was saved under.
    {
        _x params ["_ref", "_credits", "_rows"];
        private _factory = if (_ref isEqualType "") then { bluHQ_object } else {
            private _i = Array_of_FOBpos findIf { (_x distance2D _ref) < 5 };
            if (_i < 0) then { objNull } else { Array_of_FOBS select _i }
        };
        if (!isNull _factory) then {
            private _site = _factory getVariable "DUWS_buildSite";
            DUWS_stowed set [format ["%1_builds", _site], _rows apply {
                _x params ["_class", "_pos", "_dirUp"];
                [_class, _pos, _dirUp, true, true, [], 0]
            }];
            [_site] call DUWS_fnc_siteBuildDeploy;
            [DUWS_compositions getOrDefault [format ["%1_builds", _site], []], _site] spawn DUWS_fnc_buildCrewSite;
            _factory setVariable ["R3F_LOG_CF_credits", _credits, true];
        };
    } forEach (DUWS_restore getOrDefault ["baseBuilds", []]);
    if ("hqCrate" in DUWS_restore) then { [DUWS_hqCrate, DUWS_restore get "hqCrate"] call DUWS_fnc_restoreCargo };

    private _fnc_spawnSpec = {
        params ["_spec", "_pos", "_dir"];
        if !(isClass (configFile >> "CfgVehicles" >> (_spec select 0))) exitWith {
            DUWS_restoreDropped set ["vehicles", (DUWS_restoreDropped get "vehicles") + 1];
            objNull
        };
        private _veh = createVehicle [_spec select 0, _pos, [], 0, "NONE"];
        _veh setDir _dir;
        _veh setPosATL _pos;
        [_veh, _spec] call DUWS_fnc_vehSpecApply;
        _veh
    };

    (DUWS_restore getOrDefault ["mhq", [[], false, [], 0, 0]]) params ["_spec", "_deployed", "_pos", "_dir", "_lockout"];
    if (_lockout > 0) then { MHQ_lockout_until = time + _lockout; publicVariable "MHQ_lockout_until" };
    private _veh = if (_spec isEqualTo []) then { objNull } else { [_spec, _pos, _dir] call _fnc_spawnSpec };
    if (!isNull _veh) then {
        _veh setVehicleVarName "MHQ1";
        MHQ1 = _veh;
        publicVariable "MHQ1";
        ["select"] call fnc_MHQ_addActions;
        ["deploy"] remoteExec ["fnc_MHQ_addActions", [0,-2] select isDedicated, "duws_mhq_actions"];
        MHQ1 forceFlagTexture "\A3\Data_F\Flags\flag_blue_CO.paa";
        if (_deployed) then { [] call fnc_MHQ_deploy };
    };

    (DUWS_restore getOrDefault ["builder", []]) params [["_bSpec", []], ["_bPos", []], ["_bDir", 0]];
    private _bld = if (_bSpec isEqualTo []) then { objNull } else { [_bSpec, _bPos, _bDir] call _fnc_spawnSpec };
    if (!isNull _bld) then {
        _bld setVehicleVarName "BLD1";
        BLD1 = _bld;
        publicVariable "BLD1";
        [_bld] call DUWS_fnc_builderEnlist;
    };
    // The factory flag is what lets a player sell a build back.
    {
        _x params ["_class", "_posASL", "_vDir", "_vUp"];
        if (isClass (configFile >> "CfgVehicles" >> _class)) then {
            private _obj = createVehicle [_class, ASLToAGL _posASL, [], 0, "CAN_COLLIDE"];
            _obj setPosASL _posASL;
            _obj setVectorDirAndUp [_vDir, _vUp];
            _obj setVariable ["R3F_LOG_CF_depuis_usine", true, true];
            _obj setVariable ["DUWS_buildLastGood", getPosATL _obj];
            DUWS_builds pushBack _obj;
        };
    } forEach (DUWS_restore getOrDefault ["builds", []]);
    { _x call _fnc_spawnSpec } forEach (DUWS_restore getOrDefault ["parked", []]);
    [_fnc_spawnSpec] call DUWS_fnc_restoreTaskforces;
    ["bases"] call DUWS_fnc_restoreStepDone;
};

// A dropped man is logged, not counted: the load hint's unit count is of enemy units.
DUWS_fnc_restoreTaskforces = {
    params ["_fnc_spawnSpec"];
    {
        _x params ["_tfName", "_hulls", "_men"];
        private _vehs = _hulls apply { _x call _fnc_spawnSpec };
        private _group = createGroup [west, true];
        {
            _x params ["_class", "_loadout", "_damage", "_skill", "_pos", "_seat"];
            if (isClass (configFile >> "CfgVehicles" >> _class)) then {
                private _man = _group createUnit [_class, ASLToAGL _pos, [], 0, "CAN_COLLIDE"];
                _man setUnitLoadout _loadout;
                _man setDamage _damage;
                _man setSkill _skill;
                _seat params [["_hull", -1], ["_role", ""], ["_cargo", -1], ["_turret", []]];
                private _veh = if (_hull < 0) then { objNull } else { _vehs select _hull };
                if (!isNull _veh) then {
                    switch (toLower _role) do {
                        case "driver": { _man moveInDriver _veh };
                        case "cargo": { _man moveInCargo [_veh, _cargo] };
                        default { _man moveInTurret [_veh, _turret] };
                    };
                };
            } else {
                ["WARN", "SAVE", format ["task force %1: %2 is not loaded, dropped", _tfName, _class]] call fnc_log;
            };
        } forEach _men;
        { if (!isNull _x) then { _group addVehicle _x } } forEach _vehs;
        if (units _group isEqualTo []) then { deleteGroup _group } else { [_group, _tfName] call fnc_taskforce_create };
    } forEach (DUWS_restore getOrDefault ["taskforces", []]);
};

// After fnc_WARCOM_init's seed, which would derive the tiers from a wallet since spent down.
DUWS_fnc_restoreLedger = {
    (DUWS_restore getOrDefault ["pools", []]) params [["_cp", commandpointsblu1], ["_bluAp", WARCOM_blufor_ap],
        ["_opfAp", WARCOM_opfor_ap], ["_bluEarned", WARCOM_blufor_ap_earned], ["_opfEarned", WARCOM_opfor_ap_earned]];
    commandpointsblu1 = _cp;
    WARCOM_blufor_ap = _bluAp;
    WARCOM_opfor_ap = _opfAp;
    WARCOM_blufor_ap_earned = _bluEarned;
    WARCOM_opfor_ap_earned = _opfEarned;
    WARCOM_blufor_tier = [_bluEarned] call DUWS_fnc_ap_tier;
    WARCOM_opfor_tier = [_opfEarned] call DUWS_fnc_ap_tier;
    {
        publicVariable _x;
    } forEach ["commandpointsblu1", "WARCOM_blufor_ap", "WARCOM_opfor_ap", "WARCOM_blufor_ap_earned",
        "WARCOM_opfor_ap_earned", "WARCOM_blufor_tier", "WARCOM_opfor_tier"];
};

// After the census, which counts the same total on the same world, so one integer reproduces the level.
DUWS_fnc_restoreEscalation = {
    if (isNil "escalation_tier") exitWith {};
    escalation_destroyed = DUWS_restore getOrDefault ["escalation", 0];
    [true] call fnc_escalation_apply;
};

// Before OPCOM's first tick. A rider left bound to no carry refuses every order, and one left unloading never steps
// again once it streams in.
DUWS_fnc_restoreOpcom = {
    private _o = DUWS_restore getOrDefault ["opcom", createHashMap];
    DUWS_opcom_archetype = _o getOrDefault ["archetype", DUWS_opcom_archetype];
    DUWS_opcom_tick = _o getOrDefault ["tick", 0];
    DUWS_opcom_hqKnown = _o getOrDefault ["hqKnown", false];
    DUWS_opcom_taskSeq = _o getOrDefault ["taskSeq", 0];
    DUWS_opcom_attackSeq = _o getOrDefault ["attackSeq", 0];
    DUWS_opcom_attackReadyTick = _o getOrDefault ["attackReadyTick", 0];
    DUWS_opcom_supplyReadyTick = _o getOrDefault ["supplyReadyTick", createHashMap];
    DUWS_opcom_mineVariants = _o getOrDefault ["mineVariants", createHashMap];
    missionNamespace setVariable ["DUWS_hpOpcomSeq", _o getOrDefault ["hpSeq", 0]];

    private _saved = _o getOrDefault ["taskings", []];
    DUWS_opcom_taskings = _saved select {
        private _token = (_x getOrDefault ["comp", []]) param [0, ""];
        private _cls = _x getOrDefault ["spawnClass", ""];
        if (_cls isEqualTo "" || {isClass (configFile >> "CfgVehicles" >> _cls)} || {([[_token] call DUWS_fnc_tokenName] call DUWS_fnc_teamRow) isNotEqualTo []}) then {
            true
        } else {
            private _new = [_token, "OPF"] call DUWS_fnc_tokenClass;
            ["WARN", "SAVE", format ["tasking %1: %2 is not loaded, %3", _x get "id", _cls,
                ["redrawn as " + _new, "dropped"] select (_new isEqualTo "")]] call fnc_log;
            _x set ["spawnClass", _new];
            _new isNotEqualTo ""
        }
    };
    DUWS_restoreDropped set ["units", count _saved - count DUWS_opcom_taskings];
    private _ids = DUWS_opcom_taskings apply { _x get "id" };
    DUWS_opcom_attacks = _o getOrDefault ["attacks", []];
    { { _x set ["units", (_x get "units") select { _x in _ids }] } forEach (_x get "roles") } forEach DUWS_opcom_attacks;
    // The FOBs stand by now (fnc_opcom_perception_run).
    private _fobs = DUWS_restore getOrDefault ["fobs", []];
    private _rekey = createHashMap;
    {
        private _at = (_fobs select _forEachIndex) select 0;
        private _i = Array_of_FOBpos findIf { (_x distance2D _at) < 5 };
        if (_i >= 0) then { _rekey set [_x, (Array_of_FOBS select _i) getVariable ["DUWS_siteKey", ""]] };
    } forEach (_o getOrDefault ["fobKeys", []]);
    DUWS_opcom_fobsKnown = ((_o getOrDefault ["fobsKnown", []]) select { _x in _rekey }) apply { _rekey get _x };
    if (DUWS_opcom_hqKnown) then { [str blu_hq_markername] call fnc_baseMarkDiscovered };
    { if ((_x getVariable ["DUWS_siteKey", ""]) in DUWS_opcom_fobsKnown) then { [_x getVariable "DUWS_marker"] call fnc_baseMarkDiscovered } } forEach Array_of_FOBS;
    { if ((_x get "target") in _rekey) then { _x set ["target", _rekey get (_x get "target")] } } forEach DUWS_opcom_attacks;
    {
        if ((_x getOrDefault ["targetZone", ""]) in _rekey) then { _x set ["targetZone", _rekey get (_x get "targetZone")] };
    } forEach DUWS_opcom_taskings;

    {
        private _r = [_x get "carrying"] call DUWS_fnc_opcom_byId;
        if (!isNil "_r") then {
            _r set ["ridingOn", _x get "id"];
            _r set ["unloading", false];
            if !(_x getOrDefault ["embarked", false]) then { _r set ["ferryFrozen", false] };
        };
    } forEach (DUWS_opcom_taskings select { (_x getOrDefault ["carrying", -1]) >= 0 });
    {
        private _tr = [_x get "ridingOn"] call DUWS_fnc_opcom_byId;
        if (isNil "_tr" || {(_tr getOrDefault ["carrying", -1]) != (_x get "id")}) then {
            _x set ["unloading", false];
            [_x] call DUWS_fnc_opcom_ferryUnbind;
        };
    } forEach (DUWS_opcom_taskings select { (_x getOrDefault ["ridingOn", -1]) >= 0 });
    ["INFO", "SAVE", format ["OPCOM restored at tick %1: %2 taskings, %3 attacks", DUWS_opcom_tick,
        count DUWS_opcom_taskings, count DUWS_opcom_attacks]] call fnc_log;
    ["opcom"] call DUWS_fnc_restoreStepDone;
};

// The two late hooks run on their own threads; whichever finishes second closes the restore.
DUWS_fnc_restoreStepDone = {
    params ["_step"];
    private _last = false;
    isNil {
        DUWS_restorePending = DUWS_restorePending - [_step];
        _last = DUWS_restorePending isEqualTo [];
    };
    if (_last) then { call DUWS_fnc_restoreFinish };
};

// A hint rather than a card: a line of counts does not fit the card's 60 characters. Silent when nothing was lost.
DUWS_fnc_restoreFinish = {
    DUWS_restore = nil;
    DUWS_restoring = false;
    DUWS_dialogueMuted = false;
    publicVariable "DUWS_dialogueMuted";
    if (missionNamespace getVariable ["support_FOB_available", false]) then { ["fob_support"] remoteExec ["fnc_support_comm_add", 0] };
    private _lost = values DUWS_restoreDropped;
    if ((_lost findIf { _x > 0 }) >= 0) then {
        [format [localize "STR_DUWS_T_LOAD_DROPPED", DUWS_restoreDropped get "units", DUWS_restoreDropped get "vehicles",
            DUWS_restoreDropped get "gear", DUWS_restoreDropped get "crate"]] remoteExec ["hint", [0,-2] select isDedicated];
    };
    ["INFO", "SAVE", format ["restore of campaign %1 complete, not restored: %2", DUWS_campaignID, DUWS_restoreDropped]] call fnc_log;
};
