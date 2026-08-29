// Locality: client -- inherited from client/supports/fnc_mapclickarty.sqf.
// [position,salvos, radius, interval between salvos, rounds per salvo, supportType, cost, ammoType] spawn fnc_arty
// Arty (1) and mortar (2 HE, 7 smoke) resolve their round from the faction's blufor_ARTY_X /
// blufor_MORTAR_X vehicle via DUWS_fnc_deriveShell; the ammoType passed is only the vanilla fallback.
// The air-delivered types carry a sentinel the fire switch reads: Laser / Cluster / Napalm, JDAM's Bo_Mk82.
// SUPPORT TYPE: 1 = arty, 2 = mortar, 3 = jdam, 4 = laser, 5 = cluster, 6 = napalm, 7 = mortar smoke

_position = _this select 0;
_salvos = _this select 1;
_radius = _this select 2;
_interval = _this select 3;
_rps = _this select 4;
_supportype = _this select 5;
_cost = _this select 6;
_ammotype = _this select 7;
_rpsinit = _rps;
_fireObjects = [];  // for napalm flames
_speaker = localize "STR_DUWS_T_actionteam";
_message = format [localize "STR_DUWS_T_artycall", mapGridPosition _position];
// Per-support-type metadata, indexed by _supportype (1-7): [callsign, consume-item class, ordnance
// label]. Mortar HE and smoke both crew Sledge 1-1; cluster/napalm share Reaper; laser answers Slingshot.
private _artyDesc = [
	[],                                                                        // 0 unused
	["STR_DUWS_T_redleg",      "artillery",    "STR_DUWS_T_jg5oh7nw"],         // 1 tube arty
	["STR_DUWS_T_sledge",      "mortar",       "STR_DUWS_T_9sgayeiq"],         // 2 mortar HE
	["STR_DUWS_T_slingshot_2", "jdam",         "STR_DUWS_T_sa5k8p4r"],         // 3 JDAM
	["STR_DUWS_T_slingshot",   "laser",        "STR_DUWS_T_4o24llvl"],         // 4 laser bomb
	["STR_DUWS_T_reaper",      "cluster",      "STR_DUWS_T_a31378y0"],         // 5 cluster
	["STR_DUWS_T_reaper_2",    "napalm",       "STR_DUWS_T_7sgon7jn"],         // 6 napalm
	["STR_DUWS_T_sledge",      "mortar_smoke", "STR_DUWS_T_mortar_smoke_ord"]  // 7 mortar smoke
];
private _desc = _artyDesc select _supportype;
_callsign = localize (_desc select 0);

// Swap the fallback shell for the faction's own round where a piece is named. Unset key -> "" -> keep
// the passed vanilla shell, so an undeclared faction fires exactly as before.
switch (_supportype) do {
	case 1: {
		private _r = [missionNamespace getVariable ["blufor_ARTY_X", ""], "he"] call DUWS_fnc_deriveShell;
		if (_r != "") then { _ammotype = _r };
	};
	case 2: {
		private _r = [missionNamespace getVariable ["blufor_MORTAR_X", ""], "he"] call DUWS_fnc_deriveShell;
		if (_r != "") then { _ammotype = _r };
	};
	case 7: {
		private _r = [missionNamespace getVariable ["blufor_MORTAR_X", ""], "smoke"] call DUWS_fnc_deriveShell;
		if (_r != "") then { _ammotype = _r };
	};
};

{
	if (_x distance _position < 1000 || _supportype == 4) exitWith {arty_Blufor_close = true};
} forEach call BIS_fnc_listPlayers;
	
if (isNil "arty_Blufor_close") exitWith {arty_Blufor_close = false};

// One-time use: the strike is committed here -- blufor confirmed in range, target picked -- so the
// item is spent at this point rather than at selection. A map-click the player backs out of in the
// 45 s window never reaches here, leaving the flag set for fnc_mapclickarty to hand the item back.
// Paid at purchase, so no per-fire charge.
private _consumeClass = _desc select 1;
if (_consumeClass isNotEqualTo "") then { [_consumeClass] call fnc_support_consume };

[_speaker, _message, "", name player] remoteExec ["fnc_duws_dialogue", 0];
// Laser has no plotted grid -- the jet loiters and the caller designates later -- so Overlord names
// the bird inbound rather than claiming a target the plotted-grid types already have.
private _ackLine = if (_ammotype == "Laser") then {"STR_DUWS_T_artyack_laser"} else {"STR_DUWS_T_artyack"};
[localize "STR_DUWS_T_OVERLORD", format [localize _ackLine, _callsign]] remoteExec ["fnc_duws_dialogue", 0];

_ord = localize (_desc select 2);

sleep 8;
if (_ammotype == "Laser") then {
	[_callsign, localize "STR_DUWS_T_stmeajce"] remoteExec ["fnc_duws_dialogue", 0];
} else {
	if (_ammotype == "Bo_Mk82" || _ammotype == "Cluster" || _ammotype == "Napalm") then {
		[_callsign, localize "STR_DUWS_T_artyair_inbound"] remoteExec ["fnc_duws_dialogue", 0];
	} else {
		[_callsign, localize "STR_DUWS_T_77l9izur"] remoteExec ["fnc_duws_dialogue", 0];
	};
};

_markername = format["ord%1%2",_position];
_markername2 = format["lbl%1%2",_position];
// No target marker for the laser strike: the jet loiters on the caller, who designates by hand, so
// there is no pre-plotted grid to draw -- a circle over the player's own position is just noise. Names
// stay defined so the tail's deletemarker calls are harmless no-ops.
if (_ammotype != "Laser") then {
	private _drawRadius = if (_ammotype == "Bo_Mk82") then {20} else {_radius};
	_markerstr = createMarker [str(_markername), _position];
	_markerstr setMarkerShape "ELLIPSE";
	str(_markername) setMarkerColor "ColorGrey";
	str(_markername) setMarkerSize [_drawRadius,_drawRadius];

	_markerstr2 = createMarker [str(_markername2), _position];
	_markerstr2 setMarkerShape "ICON";
	str(_markername2) setMarkerType "hd_warning";
	str(_markername2) setMarkerColor "ColorOrange";
	str(_markername2) setMarkerSize [.8,.8];
	str(_markername2) setMarkerText " " + _ord;
};

sleep 20;

_group = "";
_vehicle = "";

_spawnPos = _position;
_vec =[random [-1,0,1], random [-1,0,1], 0];
_dist = 3000;

_spawnPos = ((vectorNormalized _vec) vectorMultiply _dist) vectorAdd _spawnPos;
onStation = false;

if (_ammotype == "Laser") then {
	// Loiter wide and very high, centred on the caller. The jet is cosmetic -- ammo is stripped and
	// the bomb is scripted onto the player's laser below -- so altitude and radius are purely visual.
	_spawnPos = [_spawnPos select 0, _spawnPos select 1, (_spawnPos select 2)+800];
	_grouptype = [blufor_MISC_AIR_X];
	_group = [_spawnPos, WEST, _grouptype, [], [], blufor_ai_skill] call BIS_fnc_spawnGroup;
	_group deleteGroupWhenEmpty true;
	_pilot = units _group select 0;
	_pilot allowfleeing 0;
	_pilot disableAI "Target";
	// Cosmetic bird: hold fire and don't acquire, so it flies its scripted run instead of breaking off to engage.
	_pilot disableAI "AUTOTARGET";
	_group setCombatMode "BLUE";
	_vehicle = vehicle _pilot;
	_vehicle engineOn true;
	_vehicle flyInHeight 1000;
	_vehicle setVehicleAmmo 0;
	// MOVE onto the caller first to flag on-station -- a LOITER waypoint never "completes", so its
	// statement would never run -- then circle it at a wide radius until the strike or the timeout.
	_wp1 = _group addWaypoint [_position, 200];
	_wp1 setWaypointType "MOVE";
	_wp1 setWaypointBehaviour "CARELESS";
	_wp1 setWaypointStatements ["true", "onStation = true"];
	_wp2 = _group addWaypoint [_position, 0];
	_wp2 setWaypointType "LOITER";
	_wp2 setWaypointLoiterType "CIRCLE_L";
	_wp2 setWaypointLoiterRadius 1500;
	_wp2 setWaypointBehaviour "CARELESS";
} else {
	if (_ammotype == "Bo_Mk82" || _ammotype == "Cluster" || _ammotype == "Napalm") then {
		_spawnPos = [_spawnPos select 0, _spawnPos select 1, (_spawnPos select 2)+800];
		_grouptype = [blufor_MISC_AIR_X];
		_group = [_spawnPos, WEST, _grouptype, [], [], blufor_ai_skill] call BIS_fnc_spawnGroup;
		_group deleteGroupWhenEmpty true;
		_pilot = units _group select 0;
		_pilot allowfleeing 0;
		_pilot disableAI "Target";
		// Cosmetic bird: hold fire and don't acquire, so it flies its scripted run instead of breaking off to engage.
		_pilot disableAI "AUTOTARGET";
		_group setCombatMode "BLUE";
		_vehicle = vehicle _pilot;
		_vehicle engineOn true;
		_vehicle flyInHeight 150;
		_vehicle setVehicleAmmo 0;
		_wp1 = _group addWaypoint [_position, -1];
		_wp1 setWaypointType "MOVE";
		_wp1 setWaypointBehaviour "CARELESS";
		_wp1 setWaypointStatements ["true", "onStation = true"];
		_wp2 = _group addWaypoint [[0,0], 100];
		_wp2 setWaypointType "MOVE";
		_wp2 setWaypointBehaviour "CARELESS";
	};
};

_veh_alive = true;
_laserImpact = [];
_laserLocked = false;
if (_ammotype == "Laser") then {
	// On-station over the caller, then hold for the player to designate. Slingshot needs a steady
	// spot: the laser must stay on target 5 s unbroken before it locks, and any drop restarts the
	// count. Impact tracks the live spot so the bomb lands where the laser is at lock, not entry.
	waitUntil {sleep 0.25; onStation || !alive _vehicle};
	if (alive _vehicle) then {
		[_callsign, localize "STR_DUWS_T_laser_onstation"] remoteExec ["fnc_duws_dialogue", 0];
		hint localize "STR_DUWS_T_laser_loiter";
		// Keep the orbit over the caller: the loiter was plotted where they stood at call time, but the
		// designation window runs up to 5 min and they move. Re-centred every 5 s until the window closes.
		// The loiter is waypoint index 2 (implicit 0, the on-station MOVE 1, the LOITER 2); _wp2 itself is
		// scoped to the setup block above and reads nil here, so reach it through the function-scoped _group.
		_vehicle setVariable ["DUWS_laser_recentre", true];
		[_vehicle, [_group, 2]] spawn {
			params ["_veh", "_loiterWp"];
			while { alive _veh && (_veh getVariable ["DUWS_laser_recentre", false]) } do {
				_loiterWp setWaypointPosition [getPos player, 0];
				sleep 5;
			};
		};
		private _deadline = time + 300;
		private _lockStart = -1;
		private _lastPrompt = -1000;
		private _lastFailHint = -1000;
		waitUntil {
			sleep 0.25;
			private _t = if (isNull getConnectedUAV player) then { LaserTarget player } else { LaserTarget getConnectedUAV player };
			if (isNull _t) then {
				// Dropped the spot before the lock: re-show the instruction so the caller re-lases,
				// still inside the window. Debounced so a jittery hold does not strobe the hint box.
				if (_lockStart >= 0 && (time - _lastFailHint > 5)) then {
					_lastFailHint = time;
					hint localize "STR_DUWS_T_laser_loiter";
					[_callsign, localize "STR_DUWS_T_laser_dropped"] remoteExec ["fnc_duws_dialogue", 0];
				};
				_lockStart = -1;
				_laserImpact = [];
			} else {
				private _fresh = _lockStart < 0;
				if (_fresh) then { _lockStart = time };
				// Slingshot calls the hold when the player picks up the spot. Debounced: it re-keys on a
				// genuine re-acquire but stays quiet through sub-second flicker, so a shaky lase does not
				// spam the net.
				if (_fresh && (time - _lastPrompt > 8)) then {
					_lastPrompt = time;
					[_callsign, localize "STR_DUWS_T_laser_hold"] remoteExec ["fnc_duws_dialogue", 0];
				};
				_laserImpact = getPos _t;
				if (time - _lockStart >= 5) then { _laserLocked = true };
			};
			_laserLocked || (time > _deadline) || (!alive _vehicle)
		};
		_vehicle setVariable ["DUWS_laser_recentre", false];
	};
	if (!alive _vehicle) then {_veh_alive = false};
} else {
	if (_ammotype == "Bo_Mk82" || _ammotype == "Cluster" || _ammotype == "Napalm") then {
		[_callsign, localize "STR_DUWS_T_0jegiaf4"] remoteExec ["fnc_duws_dialogue", 0];
		waitUntil {sleep 0.1;onStation||!alive _vehicle};
		sleep 2;
		if (!alive _vehicle) then {_veh_alive = false};
	} else {
		[_callsign, localize "STR_DUWS_T_hf9bhgvb"] remoteExec ["fnc_duws_dialogue", 0];
		sleep 30;
	};
};

if (!_veh_alive) exitWith {
	[_supportype] remoteExec ["fnc_support_release", 2];
	// This early-out skips the tail cleanup, so wipe the target markers and the downed aircraft here
	// or they leak: script markers are never GC'd and would orphan for the rest of the mission, and the
	// wreck and its group would linger 3 km out.
	deletemarker str(_markername);
	deletemarker str(_markername2);
	{ deleteVehicle _x } forEach units _group;
	deleteVehicle _vehicle;
	[localize "STR_DUWS_T_OVERLORD", format [localize "STR_DUWS_T_jet_down", _callsign]] remoteExec ["fnc_duws_dialogue", 0];
};

if (_ammotype == "Laser") then {
	if (!_laserLocked) then {
		// Window closed without a steady lock: no ordnance, the jet just goes home.
		[_callsign, localize "STR_DUWS_T_laser_abort"] remoteExec ["fnc_duws_dialogue", 0];
	} else {
		[_callsign, localize "STR_DUWS_T_laser_locked"] remoteExec ["fnc_duws_dialogue", 0];
		// Laser guidance, physically simulated: the round runs in under gravity and momentum, pulling a
		// capped steering correction toward the lit spot each tick -- so only sustained, early designation
		// walks it onto the mark, a short or dropped lase falls wide, and it detonates where it lands. The
		// miss is one the player sees, not one radioed in.
		private _drop = _vehicle modelToWorld [0,0,-3];
		_bomb = "Bo_Mk82" createVehicle _drop;
		[_bomb, _laserImpact, _callsign] spawn {
			params ["_round", "_lockPos", "_cs"];
			private _dt = 0.05;
			private _g = 9.8;             // gravity, always pulling the round down and short of an un-steered aim
			private _maxDV = 140 * _dt;   // steering authority: the most the fins can bend the velocity per tick
			private _lastPos = getPos _round;
			private _flightEnd = time + 25; // safety cap so a round that never resolves cannot hang the thread
			// Released running in on the locked point at a bomb's run-in speed; guidance and gravity take it
			// from here. Speed kept moderate on purpose: turn radius grows with the square of speed, so a
			// slower run-in lets the capped steering below actually walk a late correction onto the mark.
			private _vel = (vectorNormalized (_lockPos vectorDiff _lastPos)) vectorMultiply 150;
			waitUntil {
				sleep _dt;
				if (!isNull _round) then { _lastPos = getPos _round };
				_vel set [2, (_vel select 2) - _g * _dt];
				private _t = if (isNull getConnectedUAV player) then { LaserTarget player } else { LaserTarget getConnectedUAV player };
				if (!isNull _t) then {
					// Steer toward the live spot, capped: the round cannot snap onto a late or offset mark, it can
					// only bend so hard per tick, so the designation window has to be long enough to earn the hit.
					private _want = (vectorNormalized ((getPos _t) vectorDiff _lastPos)) vectorMultiply (vectorMagnitude _vel);
					private _dv = _want vectorDiff _vel;
					if (vectorMagnitude _dv > _maxDV) then { _dv = (vectorNormalized _dv) vectorMultiply _maxDV };
					_vel = _vel vectorAdd _dv;
				};
				_round setVelocity _vel;
				isNull _round || !alive _round || ((getPosATL _round) select 2) < 2 || time > _flightEnd
			};
			private _imp = _lastPos;
			if (!isNull _round) then { deleteVehicle _round };
			"Bo_Mk82" createVehicle _imp;
			[_cs, localize "STR_DUWS_T_arty_splash"] remoteExec ["fnc_duws_dialogue", 0];
			// Hold before the sign-off so the splash reads first, matching the air-delivered close.
			sleep 6;
			[_cs, localize "STR_DUWS_T_artyair_rtb"] remoteExec ["fnc_duws_dialogue", 0];
		};
	};
	// Break the loiter and send the jet home, then delete it only once it reaches the ferry-in point, so
	// it flies off rather than vanishing over the caller. Detached so the slot frees below without waiting.
	// Two traps. reverse sorts in place and returns Nothing, so inlining it as forEach (reverse (waypoints
	// _group)) iterates over Nothing and deletes no waypoint -- bind the list, reverse it, then delete
	// (highest index first). And the loiter sits at index 2 (the MOVE at index 1 flags on-station), so
	// deleting it does not move the group's current-waypoint pointer off that index onto the new egress
	// MOVE; setCurrentWaypoint forces it, or the jet keeps orbiting even with the loiter gone. The
	// single-waypoint hcCAS/hcATTchop RTBs skip this only because their loiter IS index 1, the index the
	// replacement MOVE re-takes.
	private _wps = waypoints _group;
	reverse _wps;
	{ deleteWaypoint _x } forEach _wps;
	private _rtb = _group addWaypoint [_spawnPos, 0];
	_rtb setWaypointType "MOVE";
	_rtb setWaypointBehaviour "CARELESS";
	_group setCurrentWaypoint _rtb;
	[_group, _vehicle, _spawnPos] spawn {
		params ["_g", "_v", "_home"];
		// Grace cap so a damaged jet that cannot reach home still cleans up.
		private _grace = time + 60;
		waitUntil { sleep 3; !alive _v || _v distance _home < 800 || time > _grace };
		{ deleteVehicle _x } forEach units _g;
		deleteVehicle _v;
	};
} else {
	[_callsign, localize "STR_DUWS_T_arty_splash"] remoteExec ["fnc_duws_dialogue", 0];
	// Smoke screen: rounds walk a line perpendicular to the caller's bearing to the target, so the
	// wall sits across the enemy's line of sight instead of blobbing on the point. Axis is fixed here
	// at commit time from the local player (the caller); +90 turns the sightline into the screen line.
	private _smokeAxis = [0,0,0];
	if (_supportype == 7) then {
		private _brg = (player getDir _position) + 90;
		_smokeAxis = [sin _brg, cos _brg, 0];
	};
	while {_salvos > 0} do {
		_rps = _rpsinit;
		while {_rps > 0} do {
			switch (_supportype) do {
				case 1: {  // Arty
					_bomb = _ammotype createVehicle [(_position select 0)+(random _radius)-(random _radius), (_position select 1)+(random _radius)-(random _radius), 800];
					_bomb setVelocity [0,0,-500];
					sleep ((random 20)/10);
				};
				case 2: {  // Mortar
					_bomb = _ammotype createVehicle [(_position select 0)+(random _radius)-(random _radius), (_position select 1)+(random _radius)-(random _radius), 800];
					_bomb setVelocity [0,0,-500];
					sleep ((random 20)/10);
				};
				case 7: {  // Mortar smoke -- walk the screen line, jittered enough to read as a wall, not a ruler
					private _along = (random (2 * _radius)) - _radius;
					private _p = _position vectorAdd (_smokeAxis vectorMultiply _along);
					_bomb = _ammotype createVehicle [(_p select 0)+(random 15)-(random 15), (_p select 1)+(random 15)-(random 15), 800];
					_bomb setVelocity [0,0,-500];
					sleep ((random 20)/10);
				};
				case 3: {  // JDAM
					_bomb = _ammotype createVehicle [(_position select 0)+(random _radius)-(random _radius), (_position select 1)+(random _radius)-(random _radius), (_position select 2)];
				};
				case 5: {  // Cluster
					_bomb= "R_60mm_HE" createVehicle [(_position select 0)+(random _radius)-(random _radius), (_position select 1)+(random _radius)-(random _radius), (_position select 2)];
					_bomb= "R_60mm_HE" createVehicle [(_position select 0)+(random _radius)-(random _radius), (_position select 1)+(random _radius)-(random _radius), (_position select 2)];
					sleep ((random 10)/50);
				};
				case 6: {  // Napalm
					_bomb= "Bo_Mk82" createVehicle [(_position select 0)+(random _radius)-(random _radius), (_position select 1)+(random _radius)-(random _radius), (_position select 2)];
					// A carpet of fire across the radius. Count kept low on purpose: the fire object is a
					// heavy particle-and-light emitter, and this multiplies by rounds-per-salvo, so every
					// extra one here lands eight on the ground at once.
					{
						_fire = "test_EmptyObjectForFireBig" createVehicle [(_position select 0)+(random _radius)-(random _radius), (_position select 1)+(random _radius)-(random _radius), (_position select 2)];
						_fireObjects pushBack _fire;
					} foreach [1,2,3];
					sleep ((random 1)/50);
				};
			};
			_rps = _rps - 1;
		};
		_salvos = _salvos - 1;
		sleep _interval;
	};
};	

// Slot handed back the moment the ordnance is off, not after the cleanup below: that still clears the
// markers and flies the jet home before deleting it, and the battery is free long before that.
[_supportype] remoteExec ["fnc_support_release", 2];

// Laser reports its outcome over the radio (captured / abort); other types close on the firing callsign.
if (_ammotype != "Laser") then {
	// Air-delivered types (JDAM/cluster/napalm) drop ordnance, not rounds; tube and mortar keep "rounds".
	private _airDelivered = _ammotype == "Bo_Mk82" || _ammotype == "Cluster" || _ammotype == "Napalm";
	// A single air-delivered round makes the fire loop near-instant, so the splash lands only a beat
	// before this: hold longer so the impact call is read before the sign-off. A tube/mortar salvo
	// walks over several seconds and already spaces the two.
	sleep (if (_airDelivered) then {6} else {2});
	private _closeLine = if (_airDelivered) then {"STR_DUWS_T_artyair_complete"} else {"STR_DUWS_T_artycomplete"};
	[_callsign, localize _closeLine] remoteExec ["fnc_duws_dialogue", 0];
};

sleep 30;

{ 
	deletevehicle _x;
	sleep 5;
} foreach _fireObjects;

deletemarker str(_markername);
deletemarker str(_markername2);

if (_ammotype == "Bo_Mk82" || _ammotype == "Cluster" || _ammotype == "Napalm") then {
	// Low run-in is done above; now climb out of the deck, break for the ferry-in point, and delete on
	// arrival -- same egress as the laser and HC sorties, in place of a blind timed despawn over the
	// target. Detached so the tail returns without waiting on the jet to clear.
	_vehicle flyInHeight 1000;
	while { count waypoints _group > 0 } do { deleteWaypoint [_group, 0] };
	private _rtb = _group addWaypoint [_spawnPos, 0];
	_rtb setWaypointType "MOVE";
	_rtb setWaypointSpeed "FULL";
	_rtb setWaypointBehaviour "CARELESS";
	_group setCurrentWaypoint _rtb;
	[_group, _vehicle, _spawnPos] spawn {
		params ["_g", "_v", "_home"];
		// Grace cap so a damaged jet that cannot reach home still cleans up.
		private _grace = time + 60;
		waitUntil { sleep 3; !alive _v || _v distance _home < 800 || time > _grace };
		{ deleteVehicle _x } forEach units _g;
		deleteVehicle _v;
	};
};