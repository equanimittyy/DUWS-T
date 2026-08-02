// Locality: server -- spawns OPFOR, so only the server may run it.
//
// The mortar pair: a zone's only indirect fire, and the reason clearing one from a distance is not
// free. Two men, one carrying the tube and one the ammunition.
//
// usage: [_pos, _radius, _strength] call fnc_garrisonMortar
//
// _strength is accepted and deliberately ignored. Scaling a pair by a fraction takes the tube away
// entirely -- one man with the ammunition and nothing to fire it from -- which changes what the zone
// is rather than how strong it is. The exemption lives here rather than at the caller so that a
// composition naming this token gets the pair whatever else has been ground down.
params ["_pos", "_radius", ["_strength", 1]];

private _men = [[["opfor_SOLDIER_X"] call fnc_faction_pick, ["opfor_SOLDIER_X"] call fnc_faction_pick]] call fnc_opforRoles;
private _group = [_pos, EAST, _men, [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;

private _units = units _group;
if (count _units < 2) exitWith {
    ["WARN", "ZONES", format ["mortar pair raised %1 men at %2; no tube placed", count _units, _pos]] call fnc_log;
    _group
};
(_units select 0) addBackpack "O_Mortar_01_support_F";
(_units select 1) addBackpack "O_Mortar_01_weapon_F";

// Left on the centre while the rifles fan out. The tube and its ammunition are a backpack each on
// two different men, so the pair has to stay together, and a mortar belongs behind the position it
// is firing over rather than out on the perimeter with the patrols.
[_group, _pos] call BIS_fnc_taskDefend;

{ [_x] call fnc_addRandomLoot } forEach _units;
[_group, "garrison"] call fnc_search_flag_group;

_group
