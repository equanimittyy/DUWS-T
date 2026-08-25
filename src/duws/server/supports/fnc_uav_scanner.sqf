// Locality: server -- the map-click handler in client/supports/fnc_mapclickuav.sqf remoteExecs to
// target 2. The trigger bodies below run on whichever machine trips them.
_centerPos = _this select 0;
_checkedRadius = _this select 1;
// Escalation applied here: this path never reaches the purchase handshake.
_cost = [_this select 2] call fnc_escalation_cost;
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
_speaker = localize "STR_DUWS_T_actionteam";
_message = ([localize "STR_DUWS_T_requestuavscan"] call fnc_cs);
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;
_speaker = localize "STR_DUWS_T_OVERLORD";
_message = localize "STR_DUWS_T_requestuavscan1";
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
_markername = format["%1%2vc",round(_centerPos select 0),round(_centerPos select 1)];
_markerstr = createMarker [str(_markername), _centerPos];
_markerstr setMarkerShape "ELLIPSE";
str(_markername) setMarkerBrush "SolidBorder";
str(_markername) setMarkerColor "ColorWhite";
str(_markername) setMarkerSize [_checkedRadius, _checkedRadius];
str(_markername) setMarkerAlpha 0.5;


_group = "";
_vehicle = "";
_grouptype = [];

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
_vehicle engineOn true;


onStation = false;
_wp1 = _group addWaypoint [_centerPos, -1];
_wp1 setWaypointType "MOVE";
_wp1 setWaypointBehaviour "CARELESS";
// Fire onStation promptly on arrival so the scan starts right away, not after a
// 40-80 s loiter timeout; the drone then circles the target while it reports.
_wp1 setWaypointTimeout [1, 2, 3];
_wp1 setWaypointStatements ["true", "onStation = true"];
_wp2 = _group addWaypoint [_centerPos, 0];
_wp2 setWaypointType "LOITER";
_wp2 setWaypointBehaviour "CARELESS";
_wp2 setWaypointLoiterRadius 400;

switch (VERSION_X) do {
	case "MODERN": {
		[localize "STR_DUWS_T_allseer", localize "STR_DUWS_T_45np59yv"] remoteExec ["fnc_duws_dialogue", 0];
	};
};

waitUntil {sleep 0.5;onStation||!alive _vehicle};
// The UAV is now killable, so death before it reaches station is a real path:
// tell the caller and tidy the search-area marker and dead group.
if (!alive _vehicle) exitWith {
	if (!isNull _caller) then {
		["info", [localize "STR_DUWS_T_l01sbx6n"]] remoteExec ["bis_fnc_showNotification", _caller];
	};
	{ deleteVehicle _x } forEach units _group;
	deleteVehicle _vehicle;
	deleteMarker str(_markername);
};

switch (VERSION_X) do {
	case "MODERN": {
		[localize "STR_DUWS_T_allseer", localize "STR_DUWS_T_7vt59ge6"] remoteExec ["fnc_duws_dialogue", 0];
	};
};

_speaker = localize "STR_DUWS_T_OVERLORD";
_message = localize "STR_DUWS_T_uavscancall";
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 5;
[localize "STR_DUWS_T_allseer", localize "STR_DUWS_T_2ncoq1yy"] remoteExec ["fnc_duws_dialogue", 0];


// Live recon feed. Two EmptyDetector triggers keep a continuously-updated PRESENT
// list of each side in the scan area, so the position markers can be refreshed on a
// fixed cadence and follow units as they move, rather than freezing at one arrival
// snapshot. The feed runs until the drone is destroyed or its on-station time ends;
// markers are pulled the moment it stops, so a dead/departed UAV shows nothing.
_scanInterval = 5;
_scanDuration = 180;

_trg = createTrigger ["EmptyDetector", _centerPos];
_trg setTriggerArea [_checkedRadius, _checkedRadius, 0, false];
_trg setTriggerActivation ["EAST", "PRESENT", false];
_trg setTriggerStatements ["this", "", ""];
_trg setTriggerTimeout [0, 0, 0, true];

_trgwest = createTrigger ["EmptyDetector", _centerPos];
_trgwest setTriggerArea [_checkedRadius, _checkedRadius, 0, false];
_trgwest setTriggerActivation ["WEST", "PRESENT", false];
_trgwest setTriggerStatements ["this", "", ""];
_trgwest setTriggerTimeout [0, 0, 0, true];

// Let the engine evaluate the fresh triggers once so the first pass has a real
// PRESENT list; without this the arrival tick reads empty.
sleep 1;

_reconMarkers = [];
_elapsed = 0;
while {alive _vehicle && _elapsed < _scanDuration} do {
	{ deleteMarker _x } forEach _reconMarkers;
	_reconMarkers = [];
	_idx = 0;

	{
		_mk = createMarker [format ["%1_e_%2", _markername, _idx], getPos _x];
		_mk setMarkerShape "ELLIPSE";
		_mk setMarkerBrush "SolidBorder";
		_mk setMarkerColor "ColorRed";
		_mk setMarkerSize [3, 3];
		_reconMarkers pushBack _mk;
		_idx = _idx + 1;
	} forEach list _trg;

	{
		_mk = createMarker [format ["%1_w_%2", _markername, _idx], getPos _x];
		_mk setMarkerShape "ELLIPSE";
		_mk setMarkerBrush "SolidBorder";
		_mk setMarkerColor "ColorBlue";
		_mk setMarkerSize [3, 3];
		_reconMarkers pushBack _mk;
		_idx = _idx + 1;
	} forEach list _trgwest;

	sleep _scanInterval;
	_elapsed = _elapsed + _scanInterval;
};

// Feed ended (drone destroyed or station time up): clear the live markers, stand the
// drone down, then remove the search circle and triggers.
{ deleteMarker _x } forEach _reconMarkers;
[localize "STR_DUWS_T_allseer", localize "STR_DUWS_T_rfcxa2ku"] remoteExec ["fnc_duws_dialogue", 0];

{ deleteVehicle _x } forEach units _group;
deleteVehicle _vehicle;
deleteMarker str(_markername);
deleteVehicle _trg;
deleteVehicle _trgwest;
