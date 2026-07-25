// Locality: server -- the map-click handler in client/supports/fnc_mapclickuav.sqf remoteExecs to
// target 2. The trigger bodies below run on whichever machine trips them.
_centerPos = _this select 0;
_checkedRadius = _this select 1;
_cost = _this select 2;
_caller = _this param [3, objNull];

// Check and debit as adjacent statements on the server. fnc_mapclickuav read the balance
// before a map-click window of up to 60 s, so its answer cannot be trusted by now; call
// rather than remoteExec to self so the two do not land in different frames.
if (commandpointsblu1 < _cost) exitWith {
	if (!isNull _caller) then {
		["info",[localize "STR_DUWS_T_e95mc4lv",format[localize "STR_DUWS_T_p6sb3ply",_cost]]] remoteExec ["bis_fnc_showNotification", _caller];
	};
};
[-_cost, "uav_scan"] call fnc_cp_adjust;
_speaker = ([localize "STR_DUWS_T_actionteam"] call fnc_cs);
_message = ([localize "STR_DUWS_T_requestuavscan"] call fnc_cs);
[_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];
sleep 8;
_speaker = localize "STR_DUWS_T_OVERLORD";
_message = localize "STR_DUWS_T_requestuavscan1";
[_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];
// CREATE MARKER FOR CHECKED SIZE
_markername = format["%1%2vc",round(_centerPos select 0),round(_centerPos select 1)]; // Define marker name
_markerstr = createMarker [str(_markername), _centerPos];
_markerstr setMarkerShape "ELLIPSE";
str(_markername) setMarkerBrush "SolidBorder";
str(_markername) setMarkerColor "ColorWhite";
str(_markername) setMarkerSize [_checkedRadius, _checkedRadius];
str(_markername) setMarkerAlpha 0.5;


// SEND A UAV
_group = "";
_vehicle = "";
_grouptype = [];

// FIND A RANDOM LOCATION
_spawnPos = _centerPos;
switch (VERSION_X) do {
	case "MODERN": {
		_vec =[random [-1,0,1], random [-1,0,1], 0];
		_dist = 200;
		_spawnPos = ((vectorNormalized _vec) vectorMultiply _dist) vectorAdd _spawnPos;
		_spawnPos = [_spawnPos select 0, _spawnPos select 1, (_spawnPos select 2)+500];
		_grouptype = ["B_UAV_02_dynamicLoadout_F"];
	};
};
_group = [_spawnPos, WEST, _grouptype, [], [], blufor_ai_skill] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;
_pilot = units _group select 0;
_vehicle = vehicle _pilot;
_vehicle setVehicleAmmo 0;
_vehicle allowdamage false;
_vehicle engineOn true;


onStation = false;
_wp1 = _group addWaypoint [_centerPos, -1];
_wp1 setWaypointType "MOVE";
_wp1 setWaypointBehaviour "CARELESS";
_wp1 setWaypointTimeout [40, 60, 80];
_wp1 setWaypointStatements ["true", "onStation = true"]; 
_wp2 = _group addWaypoint [[0,0], 100];
_wp2 setWaypointType "MOVE";
_wp2 setWaypointBehaviour "CARELESS";

switch (VERSION_X) do {
	case "MODERN": {
		[localize "STR_DUWS_T_45np59yv"] spawn fnc_sideChat_filter;
	};
};

waitUntil {sleep 0.5;onStation||!alive _vehicle};
if (!alive _vehicle) exitWith {hint localize "STR_DUWS_T_l01sbx6n"};

switch (VERSION_X) do {
	case "MODERN": {
		[localize "STR_DUWS_T_7vt59ge6"] spawn fnc_sideChat_filter;
	};
};

_speaker = localize "STR_DUWS_T_OVERLORD";
_message = localize "STR_DUWS_T_uavscancall";
[_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];
sleep 5;
[localize "STR_DUWS_T_2ncoq1yy"] spawn fnc_sideChat_filter;


// CREATE EAST TRIGGER
_trg=createTrigger["EmptyDetector",_centerPos];
_trg setTriggerArea[_checkedRadius,_checkedRadius,0,false];
_trg setTriggerActivation["EAST","PRESENT",false];
_trg setTriggerStatements["this","", ""];
_trg setTriggerTimeout [0, 0, 0, true ];  
sleep 1;
_tlist = list _trg; 

{  
	// CREATE MARKER
	_markername2 = format["%1%2uav",round(getpos _x select 0),round(getpos _x select 1)]; // Define marker name
	_markerstr2 = createMarker [str(_markername2), getpos _x];
	_markerstr2 setMarkerShape "ELLIPSE";
	str(_markername2) setMarkerBrush "SolidBorder";
	str(_markername2) setMarkerColor "ColorRed";
	str(_markername2) setMarkerSize [3, 3];
	str(_markername2) setMarkerAlpha 1;

	// BEGIN FLASHING LOOP
	[_markername2] spawn {
		_markername2 = _this select 0;
		for [{_i=0}, {_i<=200}, {_i = _i+1}] do
		{
			sleep 0.5;
			str(_markername2) setMarkerColor "ColorPink";
			sleep 0.5;
			str(_markername2) setMarkerColor "ColorRed";
		};    
		deleteMarker str(_markername2); 
	};  
 
} forEach _tlist;

// CREATE WEST TRIGGER
_trgwest=createTrigger["EmptyDetector",_centerPos];
_trgwest setTriggerArea[_checkedRadius,_checkedRadius,0,false];
_trgwest setTriggerActivation["WEST","PRESENT",false];
_trgwest setTriggerStatements["this","", ""];
_trgwest setTriggerTimeout [0, 0, 0, true ];  
sleep 1;
_tlistwest = list _trgwest; 

{ 
	// CREATE MARKER
	_markername2 = format["%1%2uavw",round(getpos _x select 0),round(getpos _x select 1)]; // Define marker name
	_markerstr2 = createMarker [str(_markername2), getpos _x];
	_markerstr2 setMarkerShape "ELLIPSE";
	str(_markername2) setMarkerBrush "SolidBorder";
	str(_markername2) setMarkerColor "ColorBlue";
	str(_markername2) setMarkerSize [3, 3];
	str(_markername2) setMarkerAlpha 1;

	// BEGIN FLASHING LOOP
	[_markername2] spawn {
		_markername2 = _this select 0;
		for [{_i=0}, {_i<=200}, {_i = _i+1}] do {
			sleep 0.5;
			str(_markername2) setMarkerColor "ColorBlue";
			sleep 0.5;
			str(_markername2) setMarkerColor "ColorBLUFOR";
		};    
		deleteMarker str(_markername2); 
	};  
 
} forEach _tlistwest;

sleep 20; 
[localize "STR_DUWS_T_rfcxa2ku"] spawn fnc_sideChat_filter;
sleep 20;

//DELETE THE UAV
{
	deleteVehicle _x;
} foreach units _group;

deleteVehicle _vehicle;

// WAIT AND EXIT
sleep 200;
deleteMarker str(_markername);
deletevehicle _trg;
deletevehicle _trgwest;

