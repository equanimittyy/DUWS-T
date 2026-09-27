// Locality: server; the trigger bodies below run on the machine that triggers them, not here (callers remoteExec to target 2).

_foundPickupPos = _this select 0;
_fob_owner = _this select 2;

_fobname = _this param [3, ""];
if (_fobname isEqualTo "") then { _fobname = [1] call fnc_random_name };

_markername = format["fob%1%2",round (_foundPickupPos select 0),round (_foundPickupPos select 1)];
_markerstr = createMarker [str(_markername), _foundPickupPos];
_markerstr setMarkerShape "ICON";
str(_markername) setMarkerType "loc_Bunker";
str(_markername) setMarkerColor "ColorBlue";
str(_markername) setMarkerText format["FOB %1",_fobname];
str(_markername) setMarkerSize [2.5, 2.5];

// The ring showing what a vehicle parked here keeps, same as the HQ carries.
[_foundPickupPos] call fnc_baseRangeMarker;

sleep 5;

// A FOB is a building and a ring of fortifications appearing out of nothing, and anyone stood on
// that ground sees it pop in around them.
private _fadePlayers = ["OUT", _foundPickupPos] call fnc_baseFade;

// Before the building: a hidden terrain object loses its collision, so createVehicle below is not
// shoved off the requested spot by a house it would otherwise stand in.
[_foundPickupPos, 15] call fnc_clear_buildings;

_fob = "";
switch (VERSION_X) do {
	case "MODERN": {
		_fob = "Land_Cargo_HQ_V1_F" createVehicle _foundPickupPos;
	};

};
[_fob, format ["FOB_%1", netId _fob]] call fnc_duws_keep;

// Keyed to the FOB so the entry dies with it. The defences and guards entries hang off the same
// FOB and cannot use this form -- an object-keyed id is that object's netId, so the three would
// evict each other; those two suffix a string instead.
[_fob, _fob_owner] remoteExec ["fnc_FOBactions", [0,-2] select isDedicated,_fob];

// Hold the FOB out of Zeus so a game master cannot delete it by accident (fnc_asset_guard). Combat
// destruction is unaffected -- that runs through fnc_fob_destroyed, not a curator delete.
[_fob] call fnc_guard_register;

_refortify = false;
[(getpos _fob), _fob, _refortify] spawn fnc_fortifyFOB;

// Held until the fortification pass has placed its objects -- it creates them before its first
// sleep, so a short wait covers the ring as well as the building. The patrols below are units
// walking in and need no cover.
if (count _fadePlayers > 0) then {
	sleep 2;
	["IN", _fadePlayers] call fnc_baseFade;
};

[localize "STR_DUWS_T_OVERLORD", format [localize "STR_DUWS_T_fobcall", _fobname]] remoteExec ["fnc_duws_dialogue", 0];

// The garrison, and the one patrol that walks the perimeter with it -- no extra taskPatrol groups:
// they scattered the FOB's infantry across 170 m of open ground on separate random routes, and the
// reguard action rebuilt none of them, so a FOB that lost them never got them back.

// Registered as a frozen site, not given a watcher thread of its own: ten FOBs would be ten
// permanent sleepers, where the shared poller covers them in one pass.
// The same key fnc_fortifyFOB files its turret ring under.
private _fobKey = format ["FOB_%1", netId _fob];
_fob setVariable ["DUWS_siteKey", _fobKey];
[_fobKey, _foundPickupPos, base_garrison_sleep_range, "freeze"] call fnc_site_register;
// Woken by players or by hostiles. A garrison that cannot be woken by an attacker is a garrison
// that loses its base while nobody is looking; the shared BLUFOR test cannot answer it, because
// its AI arm exists to notice BLUFOR arriving on OPFOR ground and at a friendly base it would
// count the garrison standing in the middle of the radius and never let it sleep.
{
	[_fobKey, _x, WEST, "base"] call fnc_site_occupant_register_profile;
} forEach ["infantry", "emplacement"];

[_foundPickupPos, _fob] spawn fnc_guardsFOB;

// No arrival trigger: it existed only to announce a friendly element reaching the FOB, and the
// hardcore reveal fnc_enterlocation still does is keyed on a zone name, which a FOB never has.

// warning trigger when an enemy approaches the camp -- the same red contact card and map mark the
// HQ raises, through fnc_enemy_contact. The FOB label is baked into the statement as a literal:
// the trigger evaluates later with no local scope, so _fobname is out of reach by then.
_trgWarning = createTrigger["EmptyDetector",_foundPickupPos];
_trgWarning setTriggerArea[450,450,0,false];
_trgWarning setTriggerActivation["EAST","PRESENT",true];
_trgWarning setTriggerStatements[
    "this",
    format["[%1, thisList] call fnc_enemy_contact;", str(format ["FOB %1", _fobname])],
    ""
];
// Filed under the rounded trigger position, which is the only key fnc_FOB_cleanup can rebuild
// from the FOB position it is handed.
missionNamespace setVariable [
    format["trigfob2%1%2",round (_foundPickupPos select 0),round (_foundPickupPos select 1)],
    _trgWarning
];

Array_of_FOBS = Array_of_FOBS + [_fob];
publicVariable "Array_of_FOBS";

Array_of_FOBname = Array_of_FOBname + [_fobname];
publicVariable "Array_of_FOBname";

// getPos _fob, not _foundPickupPos: createVehicle can nudge the building off the requested
// spot, and the removal dialog identifies a FOB by reading getPos back off Array_of_FOBS.
// Storing the request would leave the two describing positions that never quite match.
Array_of_FOBpos = Array_of_FOBpos + [getPos _fob];
publicVariable "Array_of_FOBpos";

["INFO", "SUPPORT", format ["FOB '%1' built at %2, %3 now standing",
	_fobname, _foundPickupPos, count Array_of_FOBS]] call fnc_log;

_spawnPos = [west, _fob] call BIS_fnc_addRespawnPosition;

[_fob,_markerstr, _spawnPos, _fobname, getPos _fob] spawn fnc_fob_destroyed;

