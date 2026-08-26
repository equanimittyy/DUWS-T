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
_supportype = _this select 5; // 1 = arty, 2 = mortar, 3 = jdam, 4 = laser bomb, 5 = cluster
_cost = _this select 6;
_ammotype = _this select 7;
_rpsinit = _rps;
_fireObjects = [];  // for napalm flames
_speaker = localize "STR_DUWS_T_actionteam";
_message = format [localize "STR_DUWS_T_artycall", mapGridPosition _position];
// Each support type answers on its own callsign; mortar HE and smoke both crew Sledge 1-1, cluster/napalm shares Reaper.
_callsign = switch (_supportype) do {
	case 1: { localize "STR_DUWS_T_redleg" };		// tube arty
	case 2: { localize "STR_DUWS_T_sledge" };		// mortar HE
	case 3: { localize "STR_DUWS_T_slingshot_2" };	// JDAM
	case 5: { localize "STR_DUWS_T_reaper" };		// cluster
	case 6: { localize "STR_DUWS_T_reaper_2" };		// napalm
	case 7: { localize "STR_DUWS_T_sledge" };		// mortar smoke (same crew as HE)
	default { localize "STR_DUWS_T_slingshot" };	// laser bomb
};

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

// make sure blufor has someone in range

{
	if (_x distance _position < 1000 || _supportype == 4) exitWith {arty_Blufor_close = true};
} forEach call BIS_fnc_listPlayers;
	
if (isNil "arty_Blufor_close") exitWith {arty_Blufor_close = false};

// One-time use: the strike is committed here -- blufor confirmed in range, target picked -- so the
// item is spent at this point rather than at selection. A map-click the player backs out of in the
// 45 s window never reaches here, leaving the flag set for fnc_mapclickarty to hand the item back.
// Paid at purchase, so no per-fire charge.
private _consumeClass = switch (_supportype) do {
	case 1: {"artillery"}; case 2: {"mortar"}; case 3: {"jdam"};
	case 4: {"laser"}; case 5: {"cluster"}; case 6: {"napalm"};
		case 7: {"mortar_smoke"}; default {""};
};
if (_consumeClass isNotEqualTo "") then { [_consumeClass] call fnc_support_consume };

[_speaker, _message, "", name player] remoteExec ["fnc_duws_dialogue", 0];
[localize "STR_DUWS_T_OVERLORD", format [localize "STR_DUWS_T_artyack", _callsign]] remoteExec ["fnc_duws_dialogue", 0];

_ord = "";
if (_supportype == 1) then {_ord = localize "STR_DUWS_T_jg5oh7nw"};	//arty
if (_supportype == 2) then {_ord = localize "STR_DUWS_T_9sgayeiq"};		//mortar
if (_supportype == 3) then {_ord = localize "STR_DUWS_T_sa5k8p4r"};			//jdam
if (_supportype == 4) then {_ord = localize "STR_DUWS_T_4o24llvl"};		//laser
if (_supportype == 5) then {_ord = localize "STR_DUWS_T_a31378y0"};		//cluster
if (_supportype == 6) then {_ord = localize "STR_DUWS_T_7sgon7jn"};		//napalm
if (_supportype == 7) then {_ord = localize "STR_DUWS_T_mortar_smoke_ord"};	//mortar smoke

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

_drawRadius = "";
if (_ammotype == "Bo_Mk82") then {
	_drawRadius = 20;
} else {
	_drawRadius = _radius;
};

_markername = format["ord%1%2",_position];
_markerstr = createMarker [str(_markername), _position];
_markerstr setMarkerShape "ELLIPSE";
str(_markername) setMarkerColor "ColorGrey";
str(_markername) setMarkerSize [_drawRadius,_drawRadius]; 

_markername2 = format["lbl%1%2",_position];
_markerstr2 = createMarker [str(_markername2), _position];
_markerstr2 setMarkerShape "ICON";
str(_markername2) setMarkerType "hd_warning";
str(_markername2) setMarkerColor "ColorOrange";
str(_markername2) setMarkerSize [.8,.8]; 
str(_markername2) setMarkerText " " + _ord;

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
		hint localize "STR_DUWS_T_laser_loiter";
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
		// The round leaves the jet and runs in on the spot, so it reads as an air-delivered strike --
		// but the kill is scripted onto the laser point and detonated on arrival, so a stripped-ammo
		// prop still lands exactly where the player lased, regardless of the jet's line or ballistics.
		private _drop = _vehicle modelToWorld [0,0,-3];
		_bomb = "Bo_Mk82" createVehicle _drop;
		[_bomb, _laserImpact, _callsign] spawn {
			params ["_round", "_imp", "_cs"];
			// Steer the prop round onto _imp -- the point where the scripted round detonates, fixed when
			// the laser locked -- so the visible bomb lands where the real ordnance goes off rather than
			// falling short and leaving the blast to pop somewhere else. Outermost ring first below so
			// overlapping rings do not heal the inner kills back to 0.5.
			waitUntil {
				sleep 0.05;
				_round setVelocity ((vectorNormalized (_imp vectorDiff (position _round))) vectorMultiply 300);
				isNull _round || !alive _round || (_round distance _imp < 12) || ((getPosATL _round) select 2) < 2
			};
			deleteVehicle _round;
			"Bo_Mk82" createVehicle _imp;
			[_cs, localize "STR_DUWS_T_arty_splash"] remoteExec ["fnc_duws_dialogue", 0];
			private _hit = _imp nearObjects 20;
			{_x setDamage .5} forEach _hit;
			{_x setDamage 1} forEach (_hit select {_x distance _imp < 10});
			[_cs, localize "STR_DUWS_T_artyair_rtb"] remoteExec ["fnc_duws_dialogue", 0];
		};
	};
	// Break the loiter and send the jet out either way; cleanup deletes it after the tail sleeps.
	{ deleteWaypoint _x } forEach (reverse (waypoints _group));
	private _rtb = _group addWaypoint [_spawnPos, 0];
	_rtb setWaypointType "MOVE";
	_rtb setWaypointBehaviour "CARELESS";
} else {
	// Splash call as the first rounds arrive.
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
					_bomb = _ammotype createVehicle [(_position select 0)+(random _radius)-(random _radius), (_position select 1)+(random _radius)-(random _radius), 800]; //spawn shells
					_bomb setVelocity [0,0,-500];
					sleep ((random 20)/10);
				};
				case 2: {  // Mortar
					_bomb = _ammotype createVehicle [(_position select 0)+(random _radius)-(random _radius), (_position select 1)+(random _radius)-(random _radius), 800]; //spawn shells
					_bomb setVelocity [0,0,-500];
					sleep ((random 20)/10);
				};
				case 7: {  // Mortar smoke -- walk the screen line, jittered enough to read as a wall, not a ruler
					private _along = (random (2 * _radius)) - _radius;
					private _p = _position vectorAdd (_smokeAxis vectorMultiply _along);
					_bomb = _ammotype createVehicle [(_p select 0)+(random 14)-(random 14), (_p select 1)+(random 14)-(random 14), 800];
					_bomb setVelocity [0,0,-500];
					sleep ((random 20)/10);
				};
				case 3: {  // JDAM
					_bomb = _ammotype createVehicle [(_position select 0)+(random _radius)-(random _radius), (_position select 1)+(random _radius)-(random _radius), (_position select 2)]; //spawn shells
					// One query and the outermost-first ordering, as the laser strike above.
					// This branch fires once per round with no yield, so the doubled query was
					// paid for every shell in the salvo.
					private _hit = _position nearObjects 20;
					{_x setDamage .5} forEach _hit;
					{_x setDamage 1} forEach (_hit select {_x distance _position < 10});
				};
				case 5: {  // Cluster
					_bomb= "R_60mm_HE" createVehicle [(_position select 0)+(random _radius)-(random _radius), (_position select 1)+(random _radius)-(random _radius), (_position select 2)]; //spawn shells
					_bomb= "R_60mm_HE" createVehicle [(_position select 0)+(random _radius)-(random _radius), (_position select 1)+(random _radius)-(random _radius), (_position select 2)]; //spawn shells
					sleep ((random 10)/50);
				};
				case 6: {  // Napalm
					_bomb= "Bo_Mk82" createVehicle [(_position select 0)+(random _radius)-(random _radius), (_position select 1)+(random _radius)-(random _radius), (_position select 2)]; //spawn shells
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

// Slot handed back the moment the ordnance is off, not after the cleanup sleeps below: those
// spend a further 90 s deleting markers and the jet, and the battery is free long before that.
[_supportype] remoteExec ["fnc_support_release", 2];

// Laser reports its outcome over the radio (captured / abort); other types close on the firing callsign.
if (_ammotype != "Laser") then {
	sleep 2;
	// Air-delivered types (JDAM/cluster/napalm) drop ordnance, not rounds; tube and mortar keep "rounds".
	private _closeLine = if (_ammotype == "Bo_Mk82" || _ammotype == "Cluster" || _ammotype == "Napalm") then {"STR_DUWS_T_artyair_complete"} else {"STR_DUWS_T_artycomplete"};
	[_callsign, localize _closeLine] remoteExec ["fnc_duws_dialogue", 0];
};

sleep 30;

{ 
	deletevehicle _x;
	sleep 5;
} foreach _fireObjects;

deletemarker str(_markername);
deletemarker str(_markername2);

if (_ammotype == "Bo_Mk82" || _ammotype == "Laser" || _ammotype == "Cluster" || _ammotype == "Napalm") then {
	sleep 60;
	{
		deleteVehicle _x;
	} foreach units _group;

	deleteVehicle _vehicle;
};