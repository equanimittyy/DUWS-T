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
_message = localize "STR_DUWS_T_artycall";

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

[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];

_ord = "";
if (_supportype == 1) then {_ord = localize "STR_DUWS_T_jg5oh7nw"};	//arty
if (_supportype == 2) then {_ord = localize "STR_DUWS_T_9sgayeiq"};		//mortar
if (_supportype == 3) then {_ord = localize "STR_DUWS_T_sa5k8p4r"};			//jdam
if (_supportype == 4) then {_ord = localize "STR_DUWS_T_4o24llvl"};		//laser
if (_supportype == 5) then {_ord = localize "STR_DUWS_T_a31378y0"};		//cluster
if (_supportype == 6) then {_ord = localize "STR_DUWS_T_7sgon7jn"};		//napalm
if (_supportype == 7) then {_ord = localize "STR_DUWS_T_mortar_smoke_ord"};	//mortar smoke

hint localize "STR_DUWS_T_fqeghaut";
if (_ammotype == "Bo_Mk82" || _ammotype == "Laser" || _ammotype == "Cluster" || _ammotype == "Napalm") then {
	[localize "STR_DUWS_T_slingshot", localize "STR_DUWS_T_stmeajce"] remoteExec ["fnc_duws_dialogue", 0];
} else {
	[localize "STR_DUWS_T_slingshot", localize "STR_DUWS_T_77l9izur"] remoteExec ["fnc_duws_dialogue", 0];
};

// CREATE A MARKER ON TARGET

_drawRadius = "";
if (_ammotype == "Bo_Mk82") then {
	_drawRadius = 20;
} else {
	_drawRadius = _radius;
};

_markername = format["ord%1%2",_position]; // Define marker name
_markerstr = createMarker [str(_markername), _position];
_markerstr setMarkerShape "ELLIPSE";
str(_markername) setMarkerColor "ColorGrey";
str(_markername) setMarkerSize [_drawRadius,_drawRadius]; 

// give marker a label
_markername2 = format["lbl%1%2",_position]; // Define marker name
_markerstr2 = createMarker [str(_markername2), _position];
_markerstr2 setMarkerShape "ICON";
str(_markername2) setMarkerType "hd_warning";
str(_markername2) setMarkerColor "ColorOrange";
str(_markername2) setMarkerSize [.8,.8]; 
str(_markername2) setMarkerText " " + _ord;

sleep 20;

// IF JDAM, LASER or CLUSTER, SEND A JET or PLANE
_group = "";
_vehicle = "";

// FIND A RANDOM LOCATION
_spawnPos = _position;
_vec =[random [-1,0,1], random [-1,0,1], 0];
_dist = 3000;

_spawnPos = ((vectorNormalized _vec) vectorMultiply _dist) vectorAdd _spawnPos;
onStation = false;

if (_ammotype == "Bo_Mk82" || _ammotype == "Laser" || _ammotype == "Cluster" || _ammotype == "Napalm") then {
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

hint localize "STR_DUWS_T_moassj3z";
if (_ammotype == "Bo_Mk82" || _ammotype == "Laser" || _ammotype == "Cluster" || _ammotype == "Napalm") then {
	[localize "STR_DUWS_T_slingshot", localize "STR_DUWS_T_0jegiaf4"] remoteExec ["fnc_duws_dialogue", 0];
} else {	
	[localize "STR_DUWS_T_slingshot", localize "STR_DUWS_T_hf9bhgvb"] remoteExec ["fnc_duws_dialogue", 0];
};

_veh_alive = true;
if (_ammotype == "Laser") then {
	sleep 15;
	hint localize "STR_DUWS_T_wlasdnk6";
	waitUntil {sleep 0.1;onStation||!alive _vehicle};
	sleep 2;
	if (!alive _vehicle) then {_veh_alive = false};
} else {
	if (_ammotype == "Cluster" || _ammotype == "Bo_Mk82" || _ammotype == "Napalm") then {
		waitUntil {sleep 0.1;onStation||!alive _vehicle};
		sleep 2;
		if (!alive _vehicle) then {_veh_alive = false};
	} else {
		sleep 30;
	};	
};

if (!_veh_alive) exitWith {
	[_supportype] remoteExec ["fnc_support_release", 2];
	hint localize "STR_DUWS_T_9wu0cgea";
};

// WAIT UNTIL THE LAST SECOND TO CHECK FOR LASER
_target = "";
if (isNull getConnectedUAV player) then {
	_target = LaserTarget player;
} else {
	_target = LaserTarget getConnectedUAV player;
};

// NUMBER OF SALVOS
if (_ammotype == "Laser") then {
		if (isNull _target) then { hint localize "STR_DUWS_T_l6wdrhei"; sleep 10 };
		private _impact = getPos _target;
		_bomb = "Bo_Mk82" createVehicle _impact;
		// One unsorted query at the outer radius, split by distance. nearestObjects with an empty
		// class filter returns every object in range and sorts the lot by distance, and the inner
		// ring is a subset of the outer one, so asking twice paid for the same objects twice.
		// Outermost first, because the rings overlap: damaging the inner ring first left
		// everything inside 10 m on 0.5, healing what the strike had just destroyed.
		private _hit = _impact nearObjects 20;
		{_x setDamage .5} forEach _hit;
		{_x setDamage 1} forEach (_hit select {_x distance _impact < 10});
} else {
	while {_salvos > 0} do {
		_rps = _rpsinit; 		// reset number of remaining rounds for next salvo
		while {_rps > 0} do { 	// FIRE SALVO
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
				case 7: {  // Mortar smoke -- same delivery, a smoke round instead of HE
					_bomb = _ammotype createVehicle [(_position select 0)+(random _radius)-(random _radius), (_position select 1)+(random _radius)-(random _radius), 800];
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
					{
						_burnthefuckers = "test_EmptyObjectForFireBig" createVehicle [(_position select 0)+(random _radius)-(random _radius), (_position select 1)+(random _radius)-(random _radius), (_position select 2)];
						_fireObjects pushBack _burnthefuckers;
						[_bomb] joinSilent createGroup WEST;
					} foreach [1,2,3,4];
					sleep ((random 1)/50);
				};
			};
			_rps = _rps - 1; 		// REMOVE 1 ROUND TO SALVO
		};
		_salvos = _salvos - 1; 		// remove 1 salvo to counter
		sleep _interval;
	};
};	

// Slot handed back the moment the ordnance is off, not after the cleanup sleeps below: those
// spend a further 90 s deleting markers and the jet, and the battery is free long before that.
[_supportype] remoteExec ["fnc_support_release", 2];

// MISSED THE LASER
if (_ammotype == "Laser" && isNull _target) then { 
	hint localize "STR_DUWS_T_b95i2b8d";
} else {
	sleep 2;
	hint localize "STR_DUWS_T_t6y8r92y";
};

sleep 30;

{ 
	deletevehicle _x;
	sleep 5;
} foreach _fireObjects;

deletemarker str(_markername);
deletemarker str(_markername2);

//DELETE THE JET
if (_ammotype == "Bo_Mk82" || _ammotype == "Laser" || _ammotype == "Cluster" || _ammotype == "Napalm") then {
	sleep 60;
	{
		deleteVehicle _x;
	} foreach units _group;

	deleteVehicle _vehicle;
};