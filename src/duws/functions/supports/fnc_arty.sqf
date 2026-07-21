// [position,salvos, radius, interval between salvos, rounds per salvo, supportType, cost, ammoType] spawn fnc_arty
// AMMO TYPES:  Arty (Sh_120mm_HE) / Laser (Bo_Mk82) / Mortar(R_80mm_HE) / JDAM (Bo_Mk82) / Cluster(R_60mm_HE)
// SUPPORT TYPE: 1 = arty, 2 = mortar, 3 = jdam, 4 = laser, 5 = cluster, 6 = napalm

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

// make sure blufor has someone in range

{
	if (_x distance _position < 1000 || _supportype == 4) exitWith {arty_Blufor_close = true};
} forEach call BIS_fnc_listPlayers;
	
if (isNil "arty_Blufor_close") exitWith {arty_Blufor_close = false};

[_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];

_ord = "";
if (_supportype == 1) then {_ord = localize "STR_DUWS_T_jg5oh7nw"};	//arty
if (_supportype == 2) then {_ord = localize "STR_DUWS_T_9sgayeiq"};		//mortar
if (_supportype == 3) then {_ord = localize "STR_DUWS_T_sa5k8p4r"};			//jdam
if (_supportype == 4) then {_ord = localize "STR_DUWS_T_4o24llvl"};		//laser
if (_supportype == 5) then {_ord = localize "STR_DUWS_T_a31378y0"};		//cluster
if (_supportype == 6) then {_ord = localize "STR_DUWS_T_7sgon7jn"};		//napalm

_taxiName = [1] call fnc_random_name;
_random1 = round random 9;
_random2 = round random 9;

hint localize "STR_DUWS_T_fqeghaut";
//hint format["Position: %1\nSalvos:%2\nRadius:%3\nInterval:%4\nRPS:%5\nSupport type:%6\nCost:%7\nAmmo type:%8", _position, _salvos, _radius, _interval, _rps,_supportype,_cost,_ammotype];
if (_ammotype == "Bo_Mk82" || _ammotype == "Laser" || _ammotype == "Cluster" || _ammotype == "Napalm") then {
	player globalChat format[localize "STR_DUWS_T_stmeajce",_taxiName,_random1,_random2];
} else {
	player globalChat format[localize "STR_DUWS_T_77l9izur",_taxiName,_random1,_random2];
};
[] remoteExec ["fnc_broadcastRadioChatter", 0];

// CREATE A MARKER ON TARGET

_drawRadius = "";
if (_ammotype == "Bo_Mk82") then {
	_drawRadius = 20;
} else {
	_drawRadius = _radius;
};

_markername = format["ord%1%2",_position]; // Define marker name
//hint _markername;
_markerstr = createMarker [str(_markername), _position];
_markerstr setMarkerShape "ELLIPSE";
str(_markername) setMarkerColor "ColorGrey";
str(_markername) setMarkerSize [_drawRadius,_drawRadius]; 

// give marker a label
_markername2 = format["lbl%1%2",_position]; // Define marker name
//hint _markername;
_markerstr2 = createMarker [str(_markername2), _position];
_markerstr2 setMarkerShape "ICON";
str(_markername2) setMarkerType "hd_warning";
str(_markername2) setMarkerColor "ColorOrange";
str(_markername2) setMarkerSize [.8,.8]; 
str(_markername2) setMarkerText " " + _ord;

commandpointsblu1 = commandpointsblu1 - _cost;
publicVariable "commandpointsblu1";

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
	_grouptype = [blufor_PLANE_CAS_X];
	_group = [_spawnPos, WEST, _grouptype, [], [], blufor_ai_skill] call BIS_fnc_spawnGroup;
	_group deleteGroupWhenEmpty true;
	_pilot = units _group select 0;
	_pilot setcaptive true;
	_pilot allowfleeing 0;
	_pilot disableAI "Target"; 
	_vehicle = vehicle _pilot;
	_vehicle engineOn true;
	_vehicle flyInHeight 150;
	_vehicle setVehicleAmmo 0;
	_vehicle allowDamage false;
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
	player globalChat format[localize "STR_DUWS_T_0jegiaf4",_taxiName,_random1,_random2];
} else {	
	player globalChat format[localize "STR_DUWS_T_hf9bhgvb",_taxiName,_random1,_random2];
};
[] remoteExec ["fnc_broadcastRadioChatter", 0];

_veh_alive = true;
if (_ammotype == "Laser") then {
	sleep 15;
	hint localize "STR_DUWS_T_wlasdnk6";
	//sleep 15;
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
		_bomb = "Bo_Mk82" createVehicle (getPos _target);
		_destroyObj10 = nearestObjects [getPos _target, [], 10];
		_destroyObj20 = nearestObjects [getPos _target, [], 20];
		{_x setDamage 1 ;}foreach _destroyObj10;
		{_x setDamage .5 ;}foreach _destroyObj20;
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
					//_bomb = _ammotype createVehicle [(_position select 0)+(random _radius)-(random _radius), (_position select 1)+(random _radius)-(random _radius), (_position select 2)]; //spawn shells
					sleep ((random 20)/10);
				};
				case 3: {  // JDAM
					_bomb = _ammotype createVehicle [(_position select 0)+(random _radius)-(random _radius), (_position select 1)+(random _radius)-(random _radius), (_position select 2)]; //spawn shells
					_destroyObj10 = nearestObjects [_position, [], 10];
					_destroyObj20 = nearestObjects [_position, [], 20];
					{_x setDamage 1 ;}foreach _destroyObj10;
					{_x setDamage .5 ;}foreach _destroyObj20;
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

// MISSED THE LASER
if (_ammotype == "Laser" && isNull _target) then { 
	hint localize "STR_DUWS_T_b95i2b8d";
} else {
	sleep 2;
	hint localize "STR_DUWS_T_t6y8r92y";
};

//DELETE THE SMOKE & FLAMES
//if (_ammotype == "Napalm") then { [_position,_radius] remoteExec ["fnc_delete_napalm",[0,-2] select isDedicated] };
//_fireObjects = [];

//{ 
//	if (typeof _x == "#particlesource") then { 
//		_fireObjects pushBack _x;
//	};
//} foreach (_position nearObjects (_radius + 50));

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