// Locality: server -- a stranded civilian beside a broken-down car on a roadside verge near the picked
// player (docs/plans/random_events_plan.md). Ambient event, no rep gate. He asks players in earshot to repair the
// car; once it is, he drops a cash reward, the town's regard rises, and he boards and drives off. Car placed by fnc_civ_spawnCar so it settles
// on the shoulder instead of detonating; driver a full civilian, so harming him costs reputation.
if (!isServer) exitWith {};
params [["_townIndex", -1], ["_player", objNull]];
if (isNull _player) exitWith {};

private _pool = missionNamespace getVariable ["civ_veh_array", []];
if (_pool isEqualTo []) exitWith {};

// Roads out of the player's sight where possible, so the broken-down car is come upon, not seen popping in.
private _roads = [getPos _player] call fnc_civ_pickHiddenRoad;
if (_roads isEqualTo []) exitWith {};

// A verge point 3 m off the carriageway and clear of walls: the car reads as pulled over, and a shoulder
// point embedded in a roadside structure would detonate when the setDamage below lands on the clip. Up to
// a handful of road points, then the last road's centre if every shoulder was blocked.
private _road = objNull;
private _dir = 0;
private _spawnPos = [];
for "_i" from 1 to 6 do {
	_road = selectRandom _roads;
	_dir = [_road] call fnc_civ_roadDir;
	private _p = (getPosATL _road) getPos [3, _dir + 90];
	if ((nearestTerrainObjects [_p, ["WALL", "FENCE", "ROCK", "TREE"], 4]) isEqualTo []) exitWith { _spawnPos = _p };
};
if (_spawnPos isEqualTo []) then { _spawnPos = getPosATL _road };

private _veh = [selectRandom _pool, _spawnPos, _dir] call fnc_civ_spawnCar;
// 80% damaged: reads as broken down, and short of 1.0 so it is repairable rather than a wreck. A field
// toolkit caps repair at ~50% integrity on a hull this far gone (full repair needs a repair vehicle), so
// the win test below is met at that cap, not at 0.
_veh setDamage 0.8;

private _civ = [_townIndex, _veh getPos [3, _dir + 90], selectRandom civ_array, false] call fnc_civ_spawnUnit;
if (isNull _civ) exitWith { deleteVehicle _veh };
(group _civ) setBehaviour "SAFE";
// Hold him by the car with PATH off, not doStop: doStop outlives the drive-off waypoint below
// (docs/info/architecture/arma_engine_gotchas.md), which would leave the repaired car parked.
_civ disableAI "PATH";

// Onto the cleanup sweep from the start: if no player ever comes, the map cleanup reaps car and civ once
// none is near. Both flagged -- a civ out of the car is not crew for the vehicle sweep to take with it.
_veh setVariable ["DUWS_binMe", true];
_civ setVariable ["DUWS_binMe", true];

// HEAR_RADIUS: earshot for his lines. REPAIRED_DMG: the car spawns at 0.8, so a drop to this or better is a
// genuine repair, not a jostle; set at the toolkit's ~50% cap so an on-foot repair actually reaches it.
// STRANDED_TIMEOUT: backstop so the watch thread ends if a player lingers near an unfixed car forever; the
// cleanup flags above own the actual teardown.
#define HEAR_RADIUS 30
#define REPAIRED_DMG 0.5
#define STRANDED_TIMEOUT 1500

[_civ, _veh, _townIndex] spawn {
	params ["_civ", "_veh", "_townIndex"];
	private _pleaded = false;
	private _deadline = time + STRANDED_TIMEOUT;
	while { alive _civ && {!isNull _veh} && {time < _deadline} } do {
		private _heard = (call BIS_fnc_listPlayers) select { _x distance _civ < HEAR_RADIUS };

		// His plea: set off by a player on foot -- a driver passing does not trigger it -- but heard by
		// everyone in earshot, vehicle or not, as a subtitle in the room (VOICE). Fired once: a latecomer
		// is not re-plead to; the money still drops for any.
		if (!_pleaded && {_heard findIf { vehicle _x == _x } >= 0}) then {
			_pleaded = true;
			[localize "STR_DUWS_T_civ", localize "STR_DUWS_T_RANDOM_STRANDED_ASK"] remoteExec ["fnc_duws_dialogue", _heard];
		};

		if (alive _veh && {damage _veh <= REPAIRED_DMG}) exitWith {
			// Whoever repaired it is in earshot; the thanks and the reward hint go to everyone there
			// rather than singling out one player, and the cash drops on the ground for any to grab.
			private _amt = 1 + floor random 3;
			[[["Money_roll", _amt]], getPosATL _civ] call fnc_money_drop;
			// Roadside help lifts the town: +1 rep, surfaced by fnc_town_rep_announce's own card.
			[_townIndex, 1, "roadside_help"] call fnc_town_rep_adjust;
			if !(_heard isEqualTo []) then {
				[localize "STR_DUWS_T_civ", localize "STR_DUWS_T_RANDOM_STRANDED_THANKS"] remoteExec ["fnc_duws_dialogue", _heard];
				[format [localize "STR_DUWS_T_RANDOM_STRANDED_REWARD", _amt]] remoteExec ["hint", _heard];
			};

			// He walks to the door and boards (assignAsDriver + orderGetIn) rather than snapping into the
			// seat, then drives off toward town; the binMe flags reap the car once it is away and no player
			// is near, same as the driving-traffic teardown. PATH back on so he can reach the door and move.
			private _grp = group _civ;
			_grp setBehaviour "CARELESS";
			_grp setSpeedMode "LIMITED";
			_veh limitSpeed 50;
			_civ enableAI "PATH";
			_civ assignAsDriver _veh;
			[_civ] orderGetIn true;
			// Ambling loop mirrors the driving traffic (fnc_civ_traffic); first leg is his own town so
			// the repaired car heads home before joining the town-to-town cycle.
			private _centres = (missionNamespace getVariable ["civ_locations", []]) apply { getPos _x };
			private _ownCentre = _centres param [_townIndex, getPos _civ];
			private _dest = if (count _centres > 1) then { selectRandom (_centres - [_ownCentre]) } else { _ownCentre };
			private _legs = [[_ownCentre, 30], [_dest, 30]];
			{
				_x params ["_wpPos", "_cr"];
				private _wp = _grp addWaypoint [_wpPos, 0];
				_wp setWaypointType "MOVE";
				_wp setWaypointSpeed "LIMITED";
				_wp setWaypointBehaviour "CARELESS";
				_wp setWaypointCompletionRadius _cr;
				_wp setWaypointTimeout [20, 30, 45];
			} forEach _legs;
			private _cyc = _grp addWaypoint [_ownCentre, 0];
			_cyc setWaypointType "CYCLE";
			_cyc setWaypointCompletionRadius 30;
		};
		sleep 1;
	};
};
