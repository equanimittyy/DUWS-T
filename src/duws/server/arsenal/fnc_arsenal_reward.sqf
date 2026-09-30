// Locality: server. Rolls a bounded bundle of a faction's gear onto the captured-arsenal shelf
// (DUWS_capturedPool) and pops the arsenal notification. The reusable "looted gear" reward shape:
// any mission that hands the player enemy kit calls this instead of open-coding a roll. Depositing to
// the pool (not a standalone box on some object) is deliberate -- fnc_captured_pool_settle then tracks
// every withdrawal exactly as it does all other foreign gear, so the reward obeys the same economy.
//
// _spec is [weapons, vests, uniforms, helmets, bags, attachments]: how many DISTINCT classes of each to
// grant. Each granted class stocks 4-10; a weapon also seeds 20-50 of its default magazine so the rifle
// is actually usable rather than a dry shelf line. Category pools come from the faction's role-unit
// loadouts (fnc_faction_class_loadout), not the ammobox lists -- those hold neither worn nor mounted
// gear -- which keeps this faction-agnostic: pass any DUWS side key.
if (!isServer) exitWith {};
params [["_factionKey", "opfor"], ["_spec", [3, 2, 2, 2, 2, 2]], ["_notify", []]];
_spec params [["_nWeap", 3], ["_nVest", 2], ["_nUni", 2], ["_nHelm", 2], ["_nBag", 2], ["_nAtt", 2]];

// Distinct random draw of _n from _src, leaving _src untouched (+ copies by value).
private _pick = {
    params ["_src", "_n"];
    private _bag = +_src;
    private _out = [];
    for "_i" from 1 to (_n min (count _bag)) do { _out pushBack (_bag deleteAt (floor random (count _bag))); };
    _out
};

private _weapons = [];
private _uniforms = [];
private _vests = [];
private _bags = [];
private _helmets = [];
private _attachments = [];
{
    private _l = [_x] call fnc_faction_class_loadout;
    { private _w = (_l param [_x, []]) param [0, ""]; if (_w != "") then { _weapons pushBackUnique ([_w] call fnc_arsenal_weapon_row); }; } forEach [0, 1, 2];
    private _u = (_l param [3, []]) param [0, ""]; if (_u != "") then { _uniforms pushBackUnique _u; };
    private _v = (_l param [4, []]) param [0, ""]; if (_v != "") then { _vests pushBackUnique _v; };
    private _b = (_l param [5, []]) param [0, ""]; if (_b != "") then { _bags pushBackUnique _b; };
    private _h = _l param [6, ""]; if (_h != "") then { _helmets pushBackUnique _h; };
    { _attachments pushBackUnique _x; } forEach ([_l] call fnc_loadout_attachments);
} forEach ([_factionKey] call fnc_faction_unit_keylist);

private _pairs = [];
{
    _pairs pushBack [_x, 4 + floor random 7];
    private _mags = getArray (configFile >> "CfgWeapons" >> _x >> "magazines");
    if (count _mags > 0) then { _pairs pushBack [_mags select 0, 20 + floor random 31]; };
} forEach ([_weapons, _nWeap] call _pick);
{ _pairs pushBack [_x, 4 + floor random 7]; } forEach (
    ([_vests, _nVest] call _pick) + ([_uniforms, _nUni] call _pick)
    + ([_helmets, _nHelm] call _pick) + ([_bags, _nBag] call _pick) + ([_attachments, _nAtt] call _pick)
);
[_pairs] call fnc_captured_pool_deposit_counts;

if (_notify isEqualTo []) then { _notify = [localize "STR_DUWS_T_arsenalfound", localize "STR_DUWS_T_arsenalfound2"]; };
["arsenal", _notify] remoteExec ["BIS_fnc_showNotification", [0, -2] select isDedicated];
