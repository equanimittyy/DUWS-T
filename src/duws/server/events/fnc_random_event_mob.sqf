// Locality: server -- an angry crowd, rolled in the Hostile band so rep has already turned the town.
//
// MOB_SIZE unarmed CIVILIANs gather in the town square and hold there. Mob mode arms once -- the moment any
// BLUFOR (player or AI) steps inside the town radius -- and from then the crowd swarms: each rioter paths to
// its own point just off the nearest BLUFOR so they clot rather than string into a formation line, a third
// of the followers carry the roar (never the leader, whose order chatter cuts say3D short), and a rock is
// lobbed at every BLUFOR man in reach, not one chosen target (fnc_throw does the lob and its animation).
//
// Mob mode ends one of two ways: the crowd panics -- a BLUFOR shot lands near them, or one of them drops --
// and scatters; or the window closes (or they lose contact) and they melt into an aimless town stroll.
// Either way the DUWS_binMe flag hands the bodies to the map cleanup.
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
#define BUNCH 6
#define REISSUE 6
#define CHASE 250
#define LIFETIME 300
#define STROLL 90
#define TICK 2
#define ROAR_EVERY 12
#define ROAR_JITTER 1.2
#define PANIC_FIRE 40
#define ACTIVATE_TIMEOUT 300

private _locs = missionNamespace getVariable ["civ_locations", []];
private _centre = if (_townIndex >= 0 && _townIndex < count _locs) then { getPos (_locs select _townIndex) } else { getPos _player };

private _grp = createGroup [CIVILIAN, true];
_grp setVariable ["DUWS_mob_panic", false];
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
		// createUnit also skips the civ flee-on-fire handler, so this is what lets a warning shot break the
		// mob: any BLUFOR round landing near one rioter panics the whole group (read in the loop / the arm wait).
		_u addEventHandler ["FiredNear", {
			params ["_unit", "_firer", "_distance"];
			if (_distance < PANIC_FIRE && {!isNull _firer} && {side group _firer == west}) then {
				(group _unit) setVariable ["DUWS_mob_panic", true];
			};
		}];
		_u setVariable ["DUWS_binMe", true];
		_u setVariable ["DUWS_binAt", time + LIFETIME];
	};
};
private _mobbers = { alive _x } count units _grp;
if (_mobbers == 0) exitWith {};
// CARELESS so the crowd walks where ordered and ignores danger rather than scattering for cover; BLUE so it
// never opens fire even if somehow handed a weapon. Left standing until mob mode arms.
_grp setBehaviour "CARELESS";
_grp setCombatMode "BLUE";
_grp setSpeedMode "LIMITED";

[_grp, _townIndex, _centre, _mobbers] spawn {
	params ["_grp", "_townIndex", "_centre", "_mobbers"];

	private _radii = missionNamespace getVariable ["civ_radii", []];
	private _townRadius = _radii param [_townIndex, 0];
	if (_townRadius <= 0) then { _townRadius = 120 };

	// Arm once a BLUFOR steps inside the town; give up if a shot scares the crowd first, or nobody comes.
	private _giveUp = time + ACTIVATE_TIMEOUT;
	waitUntil {
		sleep 2;
		(({ alive _x } count units _grp) == 0)
		|| { _grp getVariable ["DUWS_mob_panic", false] }
		|| { time > _giveUp }
		|| { (allUnits findIf { alive _x && {_x isKindOf "CAManBase"} && {side group _x == west} && {(_x distance2D _centre) < _townRadius} }) >= 0 }
	};

	private _activated = ({ alive _x } count units _grp > 0)
		&& !(_grp getVariable ["DUWS_mob_panic", false])
		&& { (allUnits findIf { alive _x && {_x isKindOf "CAManBase"} && {side group _x == west} && {(_x distance2D _centre) < _townRadius} }) >= 0 };

	// Scatter only on a real panic; a timeout or a died-out crowd just strolls off below.
	private _scatter = _grp getVariable ["DUWS_mob_panic", false];

	if (_activated) then {
		// Window starts on contact, not at spawn, so a mob that forms late still gets its full run; the
		// stroll margin lets it mill a while before the reaper may take it.
		{ _x setVariable ["DUWS_binAt", time + LIFETIME + STROLL] } forEach units _grp;
		private _deadline = time + LIFETIME;
		private _lastMove = [0, 0, 0];
		private _nextRoar = 0;

		while { { alive _x } count units _grp > 0 } do {
			if (time >= _deadline) exitWith {};
			if ((_grp getVariable ["DUWS_mob_panic", false]) || { ({ alive _x } count units _grp) < _mobbers }) exitWith { _scatter = true };

			// Every BLUFOR man still in reach of the crowd -- players and AI alike, not one chosen target.
			private _blu = (allUnits select { alive _x && {_x isKindOf "CAManBase"} && {side group _x == west} }) select { (_x distance2D (leader _grp)) < CHASE };
			if (_blu isEqualTo []) exitWith {};   // broke contact: fall through to the stroll

			private _target = [_blu, leader _grp] call BIS_fnc_nearestPosition;

			// Roar carried by a third of the followers, each staggered a beat so the copies do not phase into
			// one flat tone. Never the leader: its command chatter cuts a say3D short.
			if (time > _nextRoar) then {
				_nextRoar = time + ROAR_EVERY;
				private _crowd = ((units _grp) - [leader _grp]) call BIS_fnc_arrayShuffle;
				for "_i" from 0 to (round (count _crowd / 3) - 1) do {
					private _v = _crowd param [_i, objNull];
					if (!isNull _v && { alive _v }) then {
						[_v] spawn { params ["_v"]; sleep (random ROAR_JITTER); if (alive _v) then { _v say3D "DUWS_angry_mob" }; };
					};
				};
			};

			// Bunch, do not deploy: each rioter paths to its own point just off the nearest BLUFOR, re-issued
			// only when he has moved, so they clot on him instead of a group move stringing them into a line.
			if ((getPos _target) distance _lastMove > REISSUE) then {
				_lastMove = getPos _target;
				{ if (alive _x) then { _x doMove (_target getPos [random BUNCH, random 360]) } } forEach units _grp;
			};

			// Up close, turn on the nearest BLUFOR and jeer; guarded on animationState so the gesture is not
			// restarted every tick (which reads as a stutter).
			{
				if (alive _x && { (_x distance _target) < CLOSE_RANGE }) then {
					_x setDir (_x getDir _target);
					if (animationState _x != "amovpercmstpsnonwnondnon_talking") then { _x playMove "AmovPercMstpSnonWnonDnon_talking" };
				};
			} forEach units _grp;

			// One rock at every BLUFOR with a rioter within range, so the whole squad gets pelted, not just
			// the nearest man.
			{
				private _b = _x;
				private _shooters = (units _grp) select { alive _x && { (_x distance _b) < THROW_RANGE } };
				if !(_shooters isEqualTo []) then {
					private _t = selectRandom _shooters;
					_t setDir (_t getDir _b);
					[_t, getPosASL _b, "stone"] call fnc_throw;
				};
			} forEach _blu;

			sleep TICK;
		};
	};

	// Terminal. Panic scatters, fast and upright; anything else (never armed, broke contact, window closed)
	// melts into an aimless town stroll. DUWS_binMe hands the bodies to cleanup either way.
	if (_scatter) then {
		_grp setSpeedMode "FULL";
		{ if (alive _x) then { _x setUnitPos "UP"; _x doMove (_x getPos [150 + random 100, random 360]) } } forEach units _grp;
	} else {
		_grp setBehaviour "SAFE";
		_grp setSpeedMode "LIMITED";
		{ if (alive _x) then { _x doMove (_centre getPos [20 + random 60, random 360]) } } forEach units _grp;
	};
};
