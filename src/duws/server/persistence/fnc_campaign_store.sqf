// Locality: server. Shape and reasons: docs/info/architecture/campaign_save_format.md. The namespace and its flush
// are named only in the first two functions, so a host whose store does not read back is a one-line change.
if (!isServer) exitWith {};

// Compared as a number: a snapshot written by another format is refused, never read field by field.
DUWS_saveFormat = 1;

DUWS_fnc_saveNamespace = { missionProfileNamespace };
DUWS_fnc_saveFlush = { saveMissionProfileNamespace };

// Every global the setup screens broadcast. One list, so the save and the re-broadcast cannot drift apart.
DUWS_campaignSettings = [
    "zones_number", "zones_max_radius", "zones_min_radius", "zones_spacing", "zones_max_dist_from_hq", "moreUrban",
    "cp_reward_multiplier", "DUWSMP_CP_death_cost", "enemyunitMultiplier", "garrison_density",
    "blufor_ai_skill", "opfor_ai_skill", "blufor_ai_skill_random", "opfor_ai_skill_random", "AttackHeli", "HeavyArmor",
    "weather_type", "dynamic_weather_enable", "time_of_day", "enable_fast_travel", "ZeusStatus", "escalation_enabled",
    "simple_zones_enable", "hardcore_mode_enable", "insurgent_mode_enable", "apocalypse_mode", "CIV_PRESENCE",
    "civ_density", "duws_gamemode", "duws_callsign"
];

// [param, global, default]: the lobby params that are campaign rules. The snapshot outranks the lobby for these,
// so each is read once into its global and every reader takes the global. Revive stays the lobby's: the vendored
// AIS reads the param itself at client start, before any snapshot reaches the client.
DUWS_campaignParams = [
    ["DUWS_Fatigue", "DUWS_paramFatigue", 1],
    ["DUWS_RestrictFirstPerson", "DUWS_paramFirstPerson", 0],
    ["DUWS_ArsenalMode", "DUWS_paramArsenal", 0],
    ["DUWS_TrackAmmo", "DUWS_paramTrackAmmo", 0],
    ["DUWS_RestWeather", "DUWS_paramRestWeather", 1],
    ["DUWS_LoseConditions", "DUWS_paramLoseConditions", 0]
];

// The input groups: a snapshot without one of these would roll fresh ground under the campaign's name.
DUWS_saveInputs = ["settings", "factions", "hq", "zones", "hardpoints"];
// A snapshot missing one of these still loads, with that part at its boot value; the load screen names it.
DUWS_saveOutcomes = ["fobs", "towns", "vendors", "belts", "unlocks", "officerAlive", "clock", "pools", "held",
    "firstCaptured", "escalation", "zoneTiers", "garrisons", "revealedZones", "revealedTowns", "opcom", "garage",
    "parked", "mhq", "builder", "builds", "zoneBuilds", "baseBuilds", "capturedPool"];
publicVariable "DUWS_saveOutcomes";

// Minutes since 2020-01-01 from a systemTimeUTC array. Minutes, not seconds: a float holds whole minutes
// exactly for decades from that epoch, where seconds since 1970 lose precision.
DUWS_fnc_saveStamp = {
    params ["_t"];
    _t params ["_y", "_m", "_d", ["_h", 0], ["_mi", 0]];
    private _yy = _y - ([0, 1] select (_m <= 2));
    private _era = floor (_yy / 400);
    private _yoe = _yy - _era * 400;
    private _doy = floor ((153 * ((_m + 9) % 12) + 2) / 5) + _d - 1;
    private _doe = _yoe * 365 + floor (_yoe / 4) - floor (_yoe / 100) + _doy;
    (_era * 146097 + _doe - 719468 - 18262) * 1440 + _h * 60 + _mi
};

DUWS_fnc_saveIndex = {
    private _rows = (call DUWS_fnc_saveNamespace) getVariable ["DUWST_saves", []];
    if !(_rows isEqualType []) exitWith { [] };
    _rows select { _x isEqualType [] && {count _x >= 3} }
};

DUWS_fnc_saveNewID = {
    private _ids = (call DUWS_fnc_saveIndex) apply { _x select 0 };
    private _id = "";
    while { _id isEqualTo "" || {_id in _ids} } do { _id = str (10000 + floor random 90000) };
    _id
};

// Insert or replace by ID: an index that appended on every write would grow a row per autosave. The row count
// is also kept in profileNamespace, a second store, so a scan can tell a store that lost its rows from a
// machine that never saved.
DUWS_fnc_saveCommit = {
    params ["_id", "_payload", "_header"];
    private _ns = call DUWS_fnc_saveNamespace;
    private _key = format ["DUWST_save_%1", _id];
    private _old = _ns getVariable [_key, ""];
    if (_old isNotEqualTo "") then { _ns setVariable [_key + "_prev", _old] };
    _ns setVariable [_key, _payload];
    private _rows = call DUWS_fnc_saveIndex;
    private _row = [_id, worldName, toJSON _header];
    private _i = _rows findIf { (_x select 0) isEqualTo _id };
    if (_i < 0) then { _rows pushBack _row } else { _rows set [_i, _row] };
    _ns setVariable ["DUWST_saves", _rows];
    call DUWS_fnc_saveFlush;
    profileNamespace setVariable ["DUWST_saveRows", count _rows];
    saveProfileNamespace;
    true
};

DUWS_fnc_saveDelete = {
    params ["_id"];
    private _ns = call DUWS_fnc_saveNamespace;
    private _key = format ["DUWST_save_%1", _id];
    _ns setVariable [_key, nil];
    _ns setVariable [_key + "_prev", nil];
    private _rows = (call DUWS_fnc_saveIndex) select { (_x select 0) isNotEqualTo _id };
    _ns setVariable ["DUWST_saves", _rows];
    call DUWS_fnc_saveFlush;
    profileNamespace setVariable ["DUWST_saveRows", count _rows];
    saveProfileNamespace;
    ["INFO", "SAVE", format ["campaign %1 deleted, %2 left", _id, count _rows]] call fnc_log;
};

DUWS_fnc_saveRead = {
    params ["_id", ["_prev", false]];
    private _json = (call DUWS_fnc_saveNamespace) getVariable [format ["DUWST_save_%1%2", _id, ["", "_prev"] select _prev], ""];
    if !(_json isEqualType "" && {_json isNotEqualTo ""}) exitWith { nil };
    private _data = [fromJSON _json] param [0, 0];
    if !(_data isEqualType createHashMap) exitWith { nil };
    _data
};

DUWS_fnc_saveFactionMissing = {
    params ["_file", "_sel", "_available"];
    if (_file isEqualTo "CUSTOM") exitWith { false };
    if (_file isEqualTo "AUTODETECT") exitWith { !(_sel isEqualType "" && {isClass (configFile >> "CfgFactionClasses" >> _sel)}) };
    (_available findIf { (_x select 2) isEqualTo _file }) < 0
};

DUWS_fnc_saveRefusal = {
    params ["_h"];
    if ((_h getOrDefault ["version", -1]) isNotEqualTo DUWS_saveFormat) exitWith { "STR_DUWS_T_LOAD_BAD_VERSION" };
    if ((_h getOrDefault ["ended", ""]) isEqualTo "lost") exitWith { "STR_DUWS_T_LOAD_LOST" };
    if ((_h getOrDefault ["ended", ""]) isEqualTo "won") exitWith { "STR_DUWS_T_LOAD_WON" };
    if ((_h getOrDefault ["world", ""]) isNotEqualTo worldName) exitWith { "STR_DUWS_T_LOAD_BAD_WORLD" };
    private _groups = _h getOrDefault ["groups", []];
    if ((DUWS_saveInputs findIf { !(_x in _groups) }) >= 0) exitWith { "STR_DUWS_T_LOAD_BAD_INPUT" };
    if ([_h getOrDefault ["blu", ""], _h getOrDefault ["bluSel", ""], Factions_Available_BLUFOR_X] call DUWS_fnc_saveFactionMissing
        || {[_h getOrDefault ["opf", ""], _h getOrDefault ["opfSel", ""], Factions_Available_OPFOR_X] call DUWS_fnc_saveFactionMissing}) exitWith {
        "STR_DUWS_T_LOAD_BAD_FACTION"
    };
    ""
};

// [id, header pairs, refusal key] per row: pairs, so the broadcast stays plain arrays. The status tells a store
// that did not read back from one that holds nothing, which would otherwise look the same.
DUWS_fnc_saveScan = {
    private _list = [];
    private _now = [systemTimeUTC] call DUWS_fnc_saveStamp;
    {
        _x params ["_id", "", "_json"];
        private _h = if (_json isEqualType "") then { [fromJSON _json] param [0, 0] } else { 0 };
        if (_h isEqualType createHashMap) then {
            _h set ["age", (_now - (_h getOrDefault ["stamp", _now])) max 0];
            _list pushBack [_h getOrDefault ["stamp", 0], _id, (keys _h) apply { [_x, _h get _x] }, [_h] call DUWS_fnc_saveRefusal];
        } else {
            ["WARN", "SAVE", format ["campaign %1 has an unreadable header", _id]] call fnc_log;
        };
    } forEach (call DUWS_fnc_saveIndex);
    _list sort false;
    DUWS_saveList = _list apply { _x select [1, 3] };
    DUWS_saveStatus = if (_list isNotEqualTo []) then { "found" } else {
        ["none", "unreadable"] select ((profileNamespace getVariable ["DUWST_saveRows", 0]) > 0)
    };
    publicVariable "DUWS_saveList";
    publicVariable "DUWS_saveStatus";
    ["INFO", "SAVE", format ["scan: %1 campaigns, %2 loadable here, store %3", count DUWS_saveList,
        { (_x select 2) isEqualTo "" } count DUWS_saveList, DUWS_saveStatus]] call fnc_log;
};
