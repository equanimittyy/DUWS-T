// Locality: server -- an angry crowd, rolled in the Hostile band so rep has already turned the town.
//
// MOB_SIZE unarmed CIVILIANs gather in the town square and hold there. Mob mode arms once -- the moment any
// BLUFOR (player or AI) steps inside the town radius -- and from then the crowd closes to a STANDOFF ring and
// holds there, each rioter pathing to its own point on the ring so they bunch rather than string into a
// formation line or pile onto the player. A third of the followers carry the roar (never the leader, whose
// order chatter cuts say3D short), and each tick every rioter in range may lob at the nearest BLUFOR it can
// reach -- a volley from all sides, not one rock at one man (fnc_throw does the lob and its animation).
//
// Mob mode ends one of two ways: the crowd panics -- a BLUFOR shot lands near them, or one of them drops --
// and scatters; or the window closes (or they lose contact) and they melt into an aimless town stroll.
// Either way the DUWS_binMe flag hands the bodies to the map cleanup.
//
// Escalation variant (_escalate, the angry_mob2 kind): a few of the crowd are tagged instigators but stay
// in the harass group so they blend in. After a fuse they throw molotovs, then break off into their own
// EAST group -- marked isHostile so the kill no longer charges a war crime -- and open fire, which panics
// the rest into scattering. Still civilians as they throw, so cutting them down before the break is the crime.
//
// Deliberately NOT isHostile and left on the civilian side: the crowd itself never opens fire, so there is
// no self-defence to protect, and gunning it down is meant to stay the war crime it is (the civilian-death
// charge). This is the one Hostile-band event whose "attackers" are civilians by design, so the fire.sqf
// isHostile invariant is waived here and only here.
if (!isServer) exitWith {};
params [["_townIndex", -1], ["_player", objNull], ["_escalate", false]];
if (isNull _player) exitWith {};

private _bodies = missionNamespace getVariable ["civ_array", []];
if (_bodies isEqualTo []) exitWith {};

#define MOB_SIZE 15
#define GATHER 20
#define STANDOFF 10
#define STANDOFF_SPREAD 3
#define FACE_RANGE 14
#define THROW_RANGE 18
#define THROW_COOLDOWN 3
#define THROW_JITTER 3
#define REISSUE 6
#define CHASE 250
#define LIFETIME 300
#define STROLL 90
#define TICK 2
#define ROAR_EVERY 12
#define ROAR_JITTER 1.2
#define PANIC_FIRE 40
#define ACTIVATE_TIMEOUT 300
#define INSTIGATORS 3
#define INST_FUSE 30
#define INST_FUSE_SPREAD 30
#define INST_ARM_GAP 3
#define MOLO_SPREAD 6

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

// angry_mob2: tag a few of the crowd as instigators but leave them in the harass group so they blend in and
// roar/stone with everyone. Kept counted in _mobbers on purpose -- the subplot breaks them out to EAST only
// after the fuse, so that count-drop lands on the same beat as the panic it sets, not before.
private _instigators = [];
if (_escalate) then {
	_instigators = (units _grp select { alive _x }) call BIS_fnc_arrayShuffle;
	_instigators resize (INSTIGATORS min count _instigators);
};

private _mobbers = { alive _x } count units _grp;
if (_mobbers == 0) exitWith {};
// CARELESS so the crowd walks where ordered and ignores danger rather than scattering for cover; BLUE so it
// never opens fire even if somehow handed a weapon. Left standing until mob mode arms.
_grp setBehaviour "CARELESS";
_grp setCombatMode "BLUE";
_grp setSpeedMode "LIMITED";

[_grp, _townIndex, _centre, _mobbers, _escalate, _instigators] spawn {
	params ["_grp", "_townIndex", "_centre", "_mobbers", "_escalate", "_instigators"];

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
		{ _x setVariable ["DUWS_binAt", time + LIFETIME + STROLL]; _x setVariable ["DUWS_nextThrow", time + random THROW_COOLDOWN] } forEach units _grp;
		_grp setVariable ["DUWS_mob_roaring", true];

		// Escalation subplot on its own fuse. The instigators harass with the crowd until the fuse expires or the
		// mob ends for any reason (mob_over), then break out to EAST. When the fuse wins that race the break's
		// count-drop and panic flag scatter the rest on the same beat as the first shot.
		if (_escalate && { count _instigators > 0 }) then {
			[_instigators, _grp] spawn {
				params ["_instigators", "_grp"];
				// Turn on the fuse, or at once if the mob ends first for any reason (a shot panics it, a rioter drops,
				// it times out or loses the players) -- an early end does not let the instigators off.
				private _fuse = time + INST_FUSE + random INST_FUSE_SPREAD;
				waitUntil { sleep 1; (time >= _fuse) || { _grp getVariable ["DUWS_mob_over", false] } || { ({ alive _x } count _instigators) == 0 } };
				private _live = _instigators select { alive _x };
				if (_live isEqualTo []) exitWith {};
				// Molotovs are the aggressive opener: throw only if the fuse ran out with the mob still up, or the mob
				// ended in violence (DUWS_mob_hostileEnd -- a shot, or a downed rioter). A peaceful end -- timed out or
				// lost the players -- still draws the pistols below, but skips the firebombs: no one left to answer.
				if ((time >= _fuse) || { _grp getVariable ["DUWS_mob_hostileEnd", false] }) then {
					// Aim scattered a random offset -- provocateurs, not marksmen -- and each staggered a beat so the
					// bottles do not land as one salvo. Still blended and still civilian as they throw.
					private _throwers = (_live call BIS_fnc_arrayShuffle) select [0, 1 + floor random INSTIGATORS];
					{
						[_x] spawn {
							params ["_r"];
							sleep (random 1.5);
							private _b = allUnits select { alive _x && {_x isKindOf "CAManBase"} && {side group _x == west} };
							if (!alive _r || { _b isEqualTo [] }) exitWith {};
							private _t = [_b, _r] call BIS_fnc_nearestPosition;
							_r setDir (_r getDir _t);
							[_r, (getPosASL _t) getPos [random MOLO_SPREAD, random 360], "molotov"] call fnc_throw;
						};
					} forEach _throwers;
					sleep INST_ARM_GAP;
				};
				// Break out to EAST and open fire. isHostile so the kill no longer bills a civilian death:
				// fnc_civ_handler exempts only isHostile / resistance, so a bare EAST civ body still charges.
				// Chambered via addWeaponItem so a pocketless civ body still fights.
				private _east = createGroup [EAST, true];
				{
					_x setVariable ["isHostile", true];
					_x setCaptive false;
					[_x] joinSilent _east;
					_x addWeapon "hgun_Rook40_F";
					_x addWeaponItem ["hgun_Rook40_F", "16Rnd_9x21_Mag", true];
					_x addMagazines ["16Rnd_9x21_Mag", 2];
					// Elite, mirroring the eliminate-snipers cell (fnc_target_sniper_mission): max the aim and spotting skills.
					_x setSkill ["aimingAccuracy", 1];
					_x setSkill ["aimingShake", 1];
					_x setSkill ["aimingSpeed", 1];
					_x setSkill ["spotDistance", 1];
					_x setSkill ["spotTime", 1];
					_x setSkill ["general", 1];
					_x setUnitPos "UP";
				} forEach (_instigators select { alive _x });
				_east setBehaviour "COMBAT";
				_east setCombatMode "RED";
				_east setSpeedMode "NORMAL";
				// A fresh EAST group starts blind and would mill until it stumbled into contact -- reveal the players and
				// send it hunting so the cell engages the moment it turns, not whenever it happens to detect them.
				private _blu = allUnits select { alive _x && {_x isKindOf "CAManBase"} && {side group _x == west} };
				if !(_blu isEqualTo []) then {
					{ _east reveal [_x, 4] } forEach _blu;
					private _wp = _east addWaypoint [getPosATL ([_blu, leader _east] call BIS_fnc_nearestPosition), 0];
					_wp setWaypointType "SAD";
					_wp setWaypointBehaviour "COMBAT";
					_wp setWaypointCombatMode "RED";
					_wp setWaypointSpeed "NORMAL";
				};
				_grp setVariable ["DUWS_mob_panic", true];
			};
		};
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
						[_v] spawn { params ["_v"]; sleep (random ROAR_JITTER); if (alive _v && { group _v getVariable ["DUWS_mob_roaring", false] }) then { _v say3D "DUWS_angry_mob" }; };
					};
				};
			};

			// Hold a ring a short way off the nearest BLUFOR: each rioter paths to its own point on it, re-issued
			// only when he has moved, so they bunch at range instead of a group move stringing them into a line.
			if ((getPos _target) distance _lastMove > REISSUE) then {
				_lastMove = getPos _target;
				{ if (alive _x) then { _x doMove (_target getPos [STANDOFF + random STANDOFF_SPREAD, random 360]) } } forEach units _grp;
			};

			// Up close, turn on the nearest BLUFOR and jeer; guarded on animationState so the gesture is not
			// restarted every tick (which reads as a stutter).
			{
				if (alive _x && { (_x distance _target) < FACE_RANGE }) then {
					_x setDir (_x getDir _target);
					if (animationState _x != "amovpercmstpsnonwnondnon_talking") then { _x playMove "AmovPercMstpSnonWnonDnon_talking" };
				};
			} forEach units _grp;

			// A staggered volley: each rioter throws on its own cooldown, and the lob itself is delayed a random
			// fraction of the tick, so even rioters that come off cooldown together do not launch as one salvo.
			{
				private _r = _x;
				if (alive _r && { time > (_r getVariable ["DUWS_nextThrow", 0]) }) then {
					private _reach = _blu select { (_r distance2D _x) < THROW_RANGE };
					if !(_reach isEqualTo []) then {
						_r setVariable ["DUWS_nextThrow", time + THROW_COOLDOWN + random THROW_JITTER];
						[_r, _reach] spawn {
							params ["_r", "_reach"];
							sleep (random TICK);
							_reach = _reach select { !isNull _x && { alive _x } };
							if (!alive _r || { _reach isEqualTo [] }) exitWith {};
							private _b = [_reach, _r] call BIS_fnc_nearestPosition;
							_r setDir (_r getDir _b);
							[_r, getPosASL _b, "stone"] call fnc_throw;
						};
					};
				};
			} forEach units _grp;

			sleep TICK;
		};
	};

	// The mob is over: stop roaring, and raise mob_over so a still-waiting instigator turns now instead of
	// sleeping out its fuse (see the subplot). say3D cannot be cut (a fresh one queues rather than replaces),
	// so a clip already playing just tails off; the roaring flag keeps a late roar-spawn from starting a new one.
	_grp setVariable ["DUWS_mob_roaring", false];
	// Aggressive end (a shot, or a downed rioter) vs peaceful (timed out / lost the players): the instigator
	// subplot throws molotovs only on the former. Set before mob_over so a waiting subplot sees both together.
	_grp setVariable ["DUWS_mob_hostileEnd", _scatter];
	_grp setVariable ["DUWS_mob_over", true];

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
