// Locality: client -- inherited from client/client_init.sqf.
// Builds the "DUWS Config" subject in the map's Notes (diary), separate from the
// DUWS-T Manual: one read-only page group listing the live campaign config -- the lobby
// parameters and the setup-screen choices as they were actually committed for this run.
// Spawned after the manual so it lists second, and after chosen_settings so every
// generation variable has been broadcast.
//
// Snapshot, not a live counter: the setup values (starting CP, AP tiers, ...) are read once
// at mission start, before the player spends anything, so they show the chosen setting.
//
// Diary rendering (docs/info/architecture/arma_engine_gotchas.md, same as fnc_duws_help): records show
// newest-first, so the list is reversed before creation; colour comes from <font color=...>,
// the diary ignores <t>; <font size> is absolute px.

// Setup is committed before serverinit_complete (server holds zone build on chosen_settings),
// so by the time client_init reaches here these have arrived; the guard only covers a JIP
// client still draining the publicVariables.
waitUntil { !isNil "commandpointsblu1" && {!isNil "chosen_settings"} };

private _hdr = { format ["<font size='22' color='#4da6ff'>%1</font><br/><br/>", _this] };
private _sub = { format ["<br/><font color='#7fbfff'>%1</font><br/>", _this] };
// One "label: value" row; value in amber so it reads apart from the label. The value is escaped
// for structured text: a runtime string (faction name, callsign) carrying &, < or > would open an
// XML entity or tag the diary cannot close and void the whole body, blanking the tab while its
// title still lists. & first, so the &amp; it writes is not re-hit by the < and > passes. Labels
// are hardcoded and need no escape.
private _row = {
    params ["_label", "_val"];
    _val = _val regexReplace ["&", "&amp;"];
    _val = _val regexReplace ["<", "&lt;"];
    _val = _val regexReplace [">", "&gt;"];
    format ["<font color='#4da6ff'>%1:</font> <font color='#ffcc66'>%2</font>", _label, _val]
};

// Nil-safe read of a namespace variable to a display string. Missing (a co-op client that
// never received a non-broadcast var) shows a dash rather than breaking the row.
private _S = {
    if (isNil _this) exitWith {"-"};
    private _v = missionNamespace getVariable _this;
    if (_v isEqualType "") exitWith {_v};
    if (_v isEqualType true) exitWith {if (_v) then {"Yes"} else {"No"}};
    str _v
};
// Lobby parameter to its chosen row text, indexed by the committed value.
private _param = {
    params ["_class", "_default", "_texts", "_values"];
    private _v = [_class, _default] call BIS_fnc_getParamValue;
    private _i = _values find _v;
    if (_i < 0) then { str _v } else { _texts select _i }
};
// Some flags are stored as 1/0 numbers (moreUrban, AttackHeli, ...), others as booleans;
// coerce numbers so `if` never sees a Number.
private _yn = { params ["_var", ["_yes", "Yes"], ["_no", "No"]];
    if (isNil _var) exitWith {"-"};
    private _v = missionNamespace getVariable _var;
    if (if (_v isEqualType 0) then {_v != 0} else {_v}) then {_yes} else {_no}
};
// AP counter to its ladder rung. Threshold, not exact match: WARCOM_*_ap is the live army-power
// counter seeded from the chosen tier, and the war economy may have nudged it off the exact rung
// (0/60/150/350/600) by the time this runs, so floor to the highest rung reached.
private _tier = {
    if (isNil _this) exitWith {"-"};
    private _ap = missionNamespace getVariable _this;
    // Index of the first rung above _ap (never 0, AP is non-negative); -1 means at/above the top rung.
    private _i = [0,60,150,350,600] findIf {_ap < _x};
    private _n = if (_i < 0) then {5} else {_i};
    format ["%1 (%2)", _n, localize (format ["STR_DUWS_T_tiername%1", _n])]
};
// AI skill [min,max] bracket back to the setup label it was picked from.
private _skill = {
    if (isNil _this) exitWith {"-"};
    private _p = missionNamespace getVariable _this;
    switch (true) do {
        case (_p isEqualTo [0.85,1.0]):  { "Elite" };
        case (_p isEqualTo [0.75,0.85]): { "Commando" };
        case (_p isEqualTo [0.55,0.75]): { "Veteran" };
        case (_p isEqualTo [0.35,0.55]): { "Trained" };
        case (_p isEqualTo [0.25,0.35]): { "Rookie" };
        default { str _p };
    }
};
// Faction display name from the resolved side token, falling back to the picked faction file.
private _faction = {
    params ["_tokVar", "_fileVar"];
    private _tok = _tokVar call _S;
    private _dn = getText (configFile >> "CfgFactionClasses" >> _tok >> "displayName");
    if (_dn != "") exitWith {_dn};
    _fileVar call _S
};

private _paramsBody = ("MISSION PARAMETERS" call _hdr) + ([
    ["Revive", ["Revive", 0,
        ["None", "AIS (drag/carry)", "Vanilla"], [0,1,2]] call _param],
    ["Fatigue", ["DUWS_Fatigue", 1, ["Off", "On"], [0,1]] call _param],
    ["Restrict to 1P", ["DUWS_RestrictFirstPerson", 0,
        ["Off", "On (all)", "Vehicle 3P"], [0,1,2]] call _param],
    ["Arsenal Mode", ["DUWS_ArsenalMode", 0,
        ["Hybrid (captured gear tracked)", "Full (unlimited)", "Limited (all tracked)"], [0,1,2]] call _param],
    ["Track Ammo", ["DUWS_TrackAmmo", 0, ["Off", "On"], [0,1]] call _param],
    ["Rest Weather", ["DUWS_RestWeather", 1, ["Off", "On"], [0,1]] call _param],
    ["Lose Conditions", ["DUWS_LoseConditions", 0,
        ["Full", "Officer death only", "Escalation only", "Off"], [0,1,2,3]] call _param],
    ["Default Garbage Lifetime", format ["%1 min",
        (["DUWS_CleanupLifetime", 300] call BIS_fnc_getParamValue) / 60]],
    ["Map Group Icons", ["DUWS_GroupIcons", 0, ["Off", "On"], [0,1]] call _param],
    ["Bandits", ["DUWS_Bandits", 0,
        ["Full", "No DLC", "No Apex DLC", "No Contact DLC"], [0,1,2,3]] call _param],
    ["Debug Menu", ["DUWS_Debug", 0, ["Disabled", "Enabled"], [0,1]] call _param],
    ["Logging Level", ["DUWS_LogLevel", 3,
        ["Off", "Errors only", "Errors + warnings", "Normal", "Debug"], [0,1,2,3,4]] call _param]
] apply {_x call _row} joinString "<br/>");

private _hqGrid = if (isNil "PosOfBLUHQ" || {(PosOfBLUHQ isEqualType []) && {PosOfBLUHQ isEqualTo []}})
    then {"-"} else {mapGridPosition PosOfBLUHQ};
private _campBody = ("CAMPAIGN SETUP" call _hdr) + ([
    ["Squad Callsign", "duws_callsign" call _S],
    ["Game Mode", "duws_gamemode" call _S],
    ["Zone Style", if ((["VERSION_X" call _S] isEqualTo ["MODERN"]) || {!isNil "simple_zones_enable" && {simple_zones_enable}}) then {"Modern"} else {"Legacy"}],
    ["Zone Placement", ["manually_chosen", "Hand-placed", "Random"] call _yn],
    ["Number of Zones", "zones_number" call _S],
    ["Zone Radius", format ["%1 - %2 m", "zones_min_radius" call _S, "zones_max_radius" call _S]],
    ["Zone Spacing", format ["%1 m", "zones_spacing" call _S]],
    ["Max Distance from HQ", format ["%1 km",
        if (isNil "zones_max_dist_from_hq") then {"-"} else {zones_max_dist_from_hq / 1000}]],
    ["More Urban", ["moreUrban", "Yes", "No"] call _yn],
    ["Simple Zones", ["simple_zones_enable"] call _yn],
    ["HQ Location", _hqGrid],
    ["BLUFOR Faction", ["BLUFOR_Faction_X", "BLUFOR_FactionFile_X"] call _faction],
    ["OPFOR Faction", ["OPFOR_Faction_X", "OPFOR_FactionFile_X"] call _faction]
] apply {_x call _row} joinString "<br/>");

private _weather = if (["dynamic_weather_enable" call _S] isEqualTo ["No"]) then {"Disabled (static)"}
    else {"weather_type" call _S};
private _tod = if (isNil "time_of_day") then {"-"} else {
    switch (time_of_day) do {
        case 6:  {"06:00 (Dawn)"}; case 12: {"12:00 (Noon)"};
        case 18: {"18:00 (Evening)"}; case 0: {"00:00 (Midnight)"};
        default { str time_of_day };
    }
};
private _zeus = if (isNil "ZeusStatus") then {"-"} else {
    switch (ZeusStatus) do { case 2:{"Full"}; case 1:{"BLUFOR only"}; default {"None"} }
};
private _civ = if (["CIV_PRESENCE" call _S] in [["-"], ["NONE"]]) then {"Off"}
    else { format ["%1 (density %2)", "CIV_PRESENCE" call _S, "civ_density" call _S] };
private _preset = if (isNil "duws_preset") then {"-"} else {
    switch (duws_preset) do { case "hardcore":{"Hardcore"}; case "custom":{"Custom"}; default {"Classic"} }
};

private _forcesBody = ("FORCES, ECONOMY &amp; WORLD" call _hdr)
    + ("Forces &amp; Economy" call _sub) + ([
    ["Starting CP", "commandpointsblu1" call _S],
    ["Reward Multiplier", format ["%1x", "cp_reward_multiplier" call _S]],
    ["CP Death Penalty", "DUWSMP_CP_death_cost" call _S],
    ["BLUFOR Start Tier", "WARCOM_blufor_ap" call _tier],
    ["OPFOR Start Tier", "WARCOM_opfor_ap" call _tier],
    ["BLUFOR AI Skill", "blufor_ai_skill" call _skill],
    ["OPFOR AI Skill", "opfor_ai_skill" call _skill],
    ["Enemy Unit Multiplier", format ["%1x", "enemyunitMultiplier" call _S]],
    ["Garrison Density", if (isNil "garrison_density") then {"-"} else {format ["%1%", round (garrison_density * 100)]}],
    ["OPFOR Heavy Armour", ["HeavyArmor", "Yes", "No"] call _yn],
    ["OPFOR Attack Helis", ["AttackHeli", "Yes", "No"] call _yn],
    ["War Escalation", ["escalation_enabled"] call _yn]
] apply {_x call _row} joinString "<br/>")
    + ("World &amp; Rules" call _sub) + ([
    ["Weather", _weather],
    ["Time of Day", _tod],
    ["Civilians", _civ],
    ["Zeus", _zeus],
    ["Fast Travel", ["enable_fast_travel"] call _yn],
    ["Hardcore Mode", ["hardcore_mode_enable"] call _yn],
    ["Insurgent Mode", ["insurgent_mode_enable"] call _yn],
    ["Restricted Arsenal", ["restricted_arsenal"] call _yn],
    ["Preset", _preset]
] apply {_x call _row} joinString "<br/>");

// Records in display order, top first.
private _records = [
    ["Mission Parameters", _paramsBody],
    ["Campaign Setup", _campBody],
    ["Forces & World", _forcesBody]
];

player createDiarySubject ["duws_config", "DUWS Config"];
reverse _records;
{ player createDiaryRecord ["duws_config", _x] } forEach _records;
