// Locality: server -- an angry crowd, rolled in the Hostile band so rep has already turned the town.
//
// MOB_SIZE unarmed CIVILIANs, one group, that gather in the town and close on the nearest BLUFOR to jeer
// and stone them. Each throw is a scripted lob of a rock (fnc_throw); no weapon or magazine is involved.
//
// Deliberately NOT isHostile and left on the civilian side: the crowd itself never opens fire, so there is
// no self-defence to protect, and gunning it down is meant to stay the war crime it is (the civilian-death
// charge). This is the one Hostile-band event whose "attackers" are civilians by design, so the fire.sqf
// isHostile invariant is waived here and only here.
if (!isServer) exitWith {};
params [["_townIndex", -1], ["_player", objNull]];
if (isNull _player) exitWith {};

private _bodies = missionNamespace getVariable ["civ_array", []];
if (_bodies isEqualTo []) exitWith {};

#define MOB_SIZE 15
#define GATHER 20
#define CLOSE_RANGE 8
#define THROW_RANGE 18
#define REISSUE 15
#define LIFETIME 300
#define TICK 2

private _locs = missionNamespace getVariable ["civ_locations", []];
private _centre = if (_townIndex >= 0 && _townIndex < count _locs) then { getPos (_locs select _townIndex) } else { getPos _player };

private _grp = createGroup [CIVILIAN, true];
for "_i" from 1 to MOB_SIZE do {
	private _pos = _centre getPos [random GATHER, random 360];
	private _u = _grp createUnit [selectRandom _bodies, _pos, [], 0, "NONE"];
	if (!isNull _u) then {
		removeAllWeapons _u;
		// The war-crime trap only bites if these carry the same death charge a spawned civilian does:
		// createUnit skips fnc_civ_spawnUnit (and its unwanted recruit action / flee-on-fire), so wire
		// the Killed handler on by hand and stamp the town it charges, or the hit would fall on town -1.
		_u setVariable ["civ_locIndex", _townIndex];
		_u addEventHandler ["Killed", missionNamespace getVariable "CIV_KILLED_HANDLER"];
		_u setVariable ["DUWS_binMe", true];
		_u setVariable ["DUWS_binAt", time + LIFETIME];
	};
};
if (units _grp isEqualTo []) exitWith {};
// CARELESS so the crowd walks where ordered and ignores danger rather than scattering for cover.
_grp setBehaviour "CARELESS";
_grp setCombatMode "BLUE";
_grp setSpeedMode "LIMITED";

[_grp] spawn {
	params ["_grp"];
	private _deadline = time + LIFETIME;
	private _lastMove = [0, 0, 0];
	private _nextSay = 0;
	while { time < _deadline && { { alive _x } count units _grp > 0 } } do {
		private _live = allPlayers select { alive _x };
		if (_live isEqualTo []) exitWith {};
		private _target = [_live, leader _grp] call BIS_fnc_nearestPosition;

		// The crowd roar, re-fired every clip-length so it loops. say3D from the server carries to every
		// client on its own and rides the object, so the sound follows the crowd; spoken from a live unit
		// as the leader may have been shot.
		if (time > _nextSay) then {
			private _voice = leader _grp;
			if (!alive _voice) then { _voice = (units _grp select { alive _x }) param [0, objNull] };
			if (!isNull _voice) then { _voice say3D "DUWS_angry_mob"; _nextSay = time + 12; };
		};

		// Re-order the crowd toward the player only when they have moved, to spare the pathfinder.
		if ((getPos _target) distance _lastMove > REISSUE) then {
			_lastMove = getPos _target;
			_grp move _lastMove;
		};

		{
			if (alive _x && { (_x distance _target) < CLOSE_RANGE }) then {
				_x setDir (_x getDir _target);
				_x playMove "AmovPercMstpSnonWnonDnon_talking";
			};
		} forEach units _grp;

		private _throwers = (units _grp) select { alive _x && { (_x distance _target) < THROW_RANGE } };
		if !(_throwers isEqualTo []) then {
			private _t = selectRandom _throwers;
			_t setDir (_t getDir _target);
			[_t, getPosASL _target, "stone"] call fnc_throw;
		};
		sleep TICK;
	};
	// Units carry DUWS_binMe: the cleanup reaper disperses them once the player leaves.
};
