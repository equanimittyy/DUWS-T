// Locality: server. DUWS_banditLooks: one [uniforms, headgear] pair per allowed source; "" headgear is a
// bare head. Read from unit config, not a hand-kept list, so it follows the game's own factions.
if (!isServer) exitWith {};

private _mode = ["DUWS_Bandits", 0] call BIS_fnc_getParamValue;

// [factions, parameter values that withhold them]: 1 No DLC, 2 No Apex DLC, 3 No Contact DLC.
private _sources = [
    [["BLU_G_F", "OPF_G_F", "IND_G_F"], []],    // FIA, base game
    [["IND_C_F"], [1, 2]],                       // Syndikat, Apex
    [["IND_L_F"], [1, 3]]                        // Looters, Contact
];
// A randomisation list alternates class and weight.
private _listClasses = { params ["_list"]; _list select { _x isEqualType "" } };

DUWS_banditLooks = [];
{
    _x params ["_factions", "_withheldBy"];
    if (_mode in _withheldBy) then { continue };
    private _uniforms = [];
    private _headgear = [];
    {
        _uniforms pushBackUnique getText (_x >> "uniformClass");
        { _uniforms pushBackUnique _x } forEach ([getArray (_x >> "uniformList")] call _listClasses);
        private _hats = [getArray (_x >> "headgearList")] call _listClasses;
        if (_hats isEqualTo []) then {
            _hats = (getArray (_x >> "linkedItems")) select {
                getNumber (configFile >> "CfgWeapons" >> _x >> "ItemInfo" >> "type") == 605
            };
            if (_hats isEqualTo []) then { _hats = [""] };
        };
        { _headgear pushBackUnique _x } forEach _hats;
    } forEach ("getNumber (_x >> 'scope') == 2 && {getText (_x >> 'faction') in _factions} && {configName _x isKindOf 'CAManBase'}"
        configClasses (configFile >> "CfgVehicles"));

    _uniforms = _uniforms select { _x != "" && {isClass (configFile >> "CfgWeapons" >> _x)} };
    _headgear = _headgear select { _x == "" || {isClass (configFile >> "CfgWeapons" >> _x)} };
    if (_uniforms isEqualTo []) then {
        ["WARN", "BANDIT", format ["no uniforms under factions %1; source dropped", _factions]] call fnc_log;
        continue;
    };
    DUWS_banditLooks pushBack [_uniforms, _headgear];
} forEach _sources;

["INFO", "BANDIT", format ["bandit looks: mode %1, %2 sources", _mode, count DUWS_banditLooks]] call fnc_log;
