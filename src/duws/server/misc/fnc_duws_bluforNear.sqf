// One player, or _minAI friendly AI, within _radius of _pos. Shared by zone streaming and the
// town garrison so the two decide "BLUFOR have arrived" the same way.
// nearEntities rather than a filter over allUnits: the engine's spatial index answers this
// directly, so the cost tracks nearby units instead of every unit in the mission. Vehicles are
// queried alongside men and their crew resolved, because a CAManBase-only query does not report
// units riding in something.
// The AI threshold is a parameter because raising a position and holding one differ: two AI to
// bring it up, one to keep it there. That hysteresis stops a zone flickering off around the
// edges of the force that just took it.
if (!isServer) exitWith { false };
params ["_pos", "_radius", ["_minAI", 2]];

// Nobody flying raises a site: a jet crosses several rings a minute and a helicopter orbits them,
// each one a full composition placed for someone who never landed. What is being carried decides it
// rather than any height, because a helicopter on the deck is still nobody arriving. A parachute is
// the exception: a man under canopy is committed to the ground below him.
private _arrived = {
	private _veh = vehicle _this;
	!(_veh isKindOf "Air") || {_veh isKindOf "ParachuteBase"}
};

private _men = [];
{
	if (_x call _arrived) then {
		if (_x isKindOf "CAManBase") then {
			if (side _x == WEST) then { _men pushBackUnique _x };
		} else {
			{ if (side _x == WEST) then { _men pushBackUnique _x } } forEach crew _x;
		};
	};
} forEach (_pos nearEntities [["CAManBase", "LandVehicle", "Air"], _radius]);
if (count _men >= _minAI) exitWith { true };
((call BIS_fnc_ListPlayers) findIf { (_pos distance _x) < _radius && {_x call _arrived} }) >= 0
