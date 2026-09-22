// Locality: server -- a hostile OPFOR sniper team on the best overlook within 1 km of the picked player,
// given a standing bead on that player. Rolled in the Hostile band; the
// runner holds it off a player inside BLUFOR territory.
//
// Perch scoring mirrors the eliminate-sniper mission (fnc_target_sniper_mission), but the sight test adds
// objects and foliage: a perch that only clears terrain often has no shot at all.
// The order is static -- reveal once, hold the perch prone -- so the team does not chase a player who
// breaks contact.
if (!isServer) exitWith {};
params [["_townIndex", -1], ["_player", objNull]];
if (isNull _player) exitWith {};

if ((call DUWS_fnc_opforGroupCount) >= DUWS_zoneGroupCeiling) exitWith {};

#define SNIPER_RANGE 1000
#define BLU_STANDOFF 500
#define LIFETIME 900
#define PRONE_EYE 0.4

private _tpos = getPos _player;
private _tEye = eyePos _player;

// Anchors the perch must clear by BLU_STANDOFF, so the team never stands up on a FOB or a held zone edge.
private _bluAnchors = +WARCOM_zones_controled_by_BLUFOR;
_bluAnchors append Array_of_FOBpos;
if !(PosOfBLUHQ isEqualTo []) then { _bluAnchors pushBack PosOfBLUHQ };

// Highest ring sample that sees the target and clears the friendly standoff: LOS gates, elevation ranks.
private _ring = [0, 45, 90, 135, 180, 225, 270, 315];
private _perch = [];
private _perchDir = 0;
private _best = -1e9;
for "_i" from 0 to 47 do {
	private _cand = _tpos getPos [200 + random (SNIPER_RANGE - 200), random 360];
	if (surfaceIsWater _cand) then { continue };
	if ((_bluAnchors findIf { _cand distance2D _x < BLU_STANDOFF }) >= 0) then { continue };
	private _z = getTerrainHeightASL _cand;
	private _eye = [_cand select 0, _cand select 1, _z + PRONE_EYE];
	if !([_eye, _tEye, _player, vehicle _player, true] call fnc_sightline_clear) then { continue };
	private _ringSum = 0;
	{ _ringSum = _ringSum + getTerrainHeightASL (_cand getPos [60, _x]) } forEach _ring;
	private _relElev = _z - _ringSum / 8;
	if (_relElev > _best) then { _best = _relElev; _perch = _cand; _perchDir = _cand getDir _tpos };
};
if (_perch isEqualTo []) exitWith {};

private _grp = ["sniper_element", _perch, 0, "none", _perch, "opfor"] call fnc_spawn_team;
if (isNull _grp) exitWith {};

{
	_x setDir _perchDir;
	_x setUnitPos "DOWN";
	_x disableAI "PATH";   // hold the perch, no chase
	_x setVariable ["DUWS_binMe", true];
	_x setVariable ["DUWS_binAt", time + LIFETIME];
} forEach units _grp;
_grp setFormDir _perchDir;
_grp setBehaviour "COMBAT";
_grp setCombatMode "RED";

// One exact-position reveal, not a re-scan: it does not update, so a player who relocates unseen leaves
// the team watching the ground it was given.
_grp reveal [_player, 4];
