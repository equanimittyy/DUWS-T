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
		[localize "STR_DUWS_T_e95mc4lv"] remoteExec ["hint", _caller];
	};
};
[-_cost, "uav_scan"] call fnc_cp_adjust;
// Opening exchange in the fire-support cadence: the caller's request and Overlord's copy key up
// together the instant the grid is marked, then Allseer answers a beat later. name resolved from
// the caller unit, not `player`: this fn is server-side.
_speaker = localize "STR_DUWS_T_actionteam";
_message = localize "STR_DUWS_T_requestuavscan";
[_speaker, _message, "", (if (isNull _caller) then {""} else {name _caller})] remoteExec ["fnc_duws_dialogue", 0];
[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_requestuavscan1"] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;
[localize "STR_DUWS_T_allseer", localize "STR_DUWS_T_uav_coords"] remoteExec ["fnc_duws_dialogue", 0];
// Unique per scan so two scans on the same point never share a marker namespace
// (which would stomp each other's circle and dots, and delete them early). Server-
// only fn; this read+increment has no suspension point, so scheduled calls cannot
// interleave and hand out a duplicate sequence.
if (isNil "DUWS_uav_scan_seq") then { DUWS_uav_scan_seq = 0 };
DUWS_uav_scan_seq = DUWS_uav_scan_seq + 1;
_markername = format["%1%2vc%3",round(_centerPos select 0),round(_centerPos select 1),DUWS_uav_scan_seq];
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
		_spawnPos = [_spawnPos select 0, _spawnPos select 1, (_spawnPos select 2)+750];
		_grouptype = ["B_UAV_02_dynamicLoadout_F"];
	};
};
_group = [_spawnPos, WEST, _grouptype, [], [], blufor_ai_skill] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;
_pilot = units _group select 0;
_vehicle = vehicle _pilot;
_vehicle setVehicleAmmo 0;
// Cosmetic drone: hold fire and don't acquire, so it just flies the scan orbit.
_pilot disableAI "Target";
_pilot disableAI "AUTOTARGET";
_group setCombatMode "BLUE";
_vehicle engineOn true;
_vehicle flyInHeight 750;


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
_wp2 setWaypointLoiterRadius 600;

sleep 8;
switch (VERSION_X) do {
	case "MODERN": {
		[localize "STR_DUWS_T_allseer", localize "STR_DUWS_T_45np59yv"] remoteExec ["fnc_duws_dialogue", 0];
	};
};

waitUntil {sleep 0.5;onStation||!alive _vehicle};
if (!alive _vehicle) exitWith {
	[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_uavscandown"] remoteExec ["fnc_duws_dialogue", 0];
	{ deleteVehicle _x } forEach units _group;
	deleteVehicle _vehicle;
	deleteMarker str(_markername);
};

_speaker = localize "STR_DUWS_T_allseer";
_message = localize "STR_DUWS_T_uavscancall";
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 5;


// Live recon feed. Three EmptyDetector triggers keep a continuously-updated PRESENT
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

_trgguer = createTrigger ["EmptyDetector", _centerPos];
_trgguer setTriggerArea [_checkedRadius, _checkedRadius, 0, false];
_trgguer setTriggerActivation ["GUER", "PRESENT", false];
_trgguer setTriggerStatements ["this", "", ""];
_trgguer setTriggerTimeout [0, 0, 0, true];

// Let the engine evaluate the fresh triggers once so the first pass has a real
// PRESENT list; without this the arrival tick reads empty.
sleep 1;

// Keyed by side and unit, so a contact still in view moves its marker instead of deleting and recreating
// it -- every marker command is a network message.
_reconMarkers = createHashMap;
_elapsed = 0;
while {alive _vehicle && _elapsed < _scanDuration} do {
	private _seen = [];
	{
		_x params ["_units", "_tag", "_colour"];
		{
			private _mk = format ["%1_%2_%3", _markername, _tag, netId _x];
			if (_mk in _reconMarkers) then {
				_mk setMarkerPos (getPos _x);
			} else {
				createMarker [_mk, getPos _x];
				_mk setMarkerShape "ELLIPSE";
				_mk setMarkerBrush "SolidBorder";
				_mk setMarkerColor _colour;
				_mk setMarkerSize [3, 3];
				_reconMarkers set [_mk, true];
			};
			_seen pushBack _mk;
		} forEach _units;
	} forEach [[list _trg, "e", "ColorRed"], [list _trgwest, "w", "ColorBlue"], [list _trgguer, "i", "ColorGUER"]];
	{
		if !(_x in _seen) then { deleteMarker _x; _reconMarkers deleteAt _x };
	} forEach keys _reconMarkers;

	sleep _scanInterval;
	_elapsed = _elapsed + _scanInterval;
};

{ deleteMarker _x } forEach keys _reconMarkers;
deleteMarker str(_markername);
deleteVehicle _trg;
deleteVehicle _trgwest;
deleteVehicle _trgguer;

if (!alive _vehicle) exitWith {
	[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_uavscandown"] remoteExec ["fnc_duws_dialogue", 0];
	{ deleteVehicle _x } forEach units _group;
	deleteVehicle _vehicle;
};

// Station time up with the drone intact: Allseer signs the recon off, then the UAV breaks
// the loiter and egresses, deleted only once it has cleared the area -- so it flies out like
// the laser bird rather than blinking off the map overhead.
[localize "STR_DUWS_T_allseer", localize "STR_DUWS_T_rfcxa2ku"] remoteExec ["fnc_duws_dialogue", 0];
{ deleteWaypoint _x } forEach (reverse (waypoints _group));
private _egress = _centerPos getPos [3500, random 360];
private _rtb = _group addWaypoint [_egress, 0];
_rtb setWaypointType "MOVE";
_rtb setWaypointBehaviour "CARELESS";
[_group, _vehicle, _centerPos] spawn {
	params ["_g", "_v", "_pos"];
	// Grace cap so a blocked or damaged drone that cannot make distance still cleans up.
	private _grace = time + 120;
	waitUntil { sleep 3; !alive _v || _v distance _pos > 2500 || time > _grace };
	{ deleteVehicle _x } forEach units _g;
	deleteVehicle _v;
};
