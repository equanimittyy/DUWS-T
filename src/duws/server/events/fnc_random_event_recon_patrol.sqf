// Locality: server -- a hostile OPFOR recon team on a wide 500 m circuit, sited 300 m+ off any road near
// the picked player. Rolled in the Hostile band; the runner holds it off
// a player inside BLUFOR territory.
if (!isServer) exitWith {};
params [["_townIndex", -1], ["_player", objNull]];
if (isNull _player) exitWith {};

// These raise groups outside the garrison ledger but still count against the engine's OPFOR group wall.
if ((["OPF"] call DUWS_fnc_sideGroupCount) >= DUWS_zoneGroupCeiling) exitWith {};

#define RECON_RADIUS 500
#define OFFROAD 300
#define LIFETIME 900

// A patrol centre near the player, OFFROAD clear of any road. A few tries, then drop rather than force it.
private _centre = [];
private _anchor = getPos _player;
for "_i" from 1 to 12 do {
	private _cand = [_anchor, 600, 200, 5, 0.5, []] call fnc_safe_pos;
	if (_cand isNotEqualTo [] && {(_cand nearRoads OFFROAD) isEqualTo []}) exitWith { _centre = _cand };
};
if (_centre isEqualTo []) exitWith {};

// _centre passed as the spawn point too, so the team stands up on the off-road centre rather than on the
// widepatrol band's outer ring, which could sit it back on a road.
private _grp = ["recon", _centre, RECON_RADIUS, "widepatrol", _centre] call fnc_spawn_team;
if (isNull _grp) exitWith {};

{
	_x setVariable ["DUWS_binMe", true];
	_x setVariable ["DUWS_binAt", time + LIFETIME];
} forEach units _grp;
