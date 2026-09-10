// Locality: client; the event-handler bodies below run on the machine that triggers them,
// not here. Shared body for the High Command air sorties (CAS jet, attack gunship): the two
// only differ in strings, group type, flight heights, and the inbound waypoint shape, so those
// arrive as _cfg and the flow stays single-sourced.

params ["_cfg"];
_cfg params [
    "_claimType", "_commItem", "_busyKey", "_cdKey",
    "_reqLine", "_ackLine",
    "_offmapAlt", "_grouptype", "_statePrefix", "_downLine",
    "_spinUp", "_ferryH", "_stationH", "_egressH",
    "_wpInType", "_loiterRadius", "_arriveDist",
    "_squadCounterVar", "_squadIdKey", "_onStaSpeaker", "_onStaLine", "_onStaHint", "_rtbLine",
    ["_cooldown", 600]
];

private _activeVar = _statePrefix + "_active";
private _curVehVar = _statePrefix + "_currentVehicle";

// Team-wide single-flight + global cooldown. Refused (with a hint) if one is already on station or the
// cooldown is still running; a refused call is handed back to the player unspent.
if !([_claimType, _commItem, _busyKey, _cdKey] call fnc_hcair_claim_request) exitWith {};

// Claim granted -> the support is spent. Consumed here, not at menu pick, so a request the guard above
// refused (in service or on cooldown) is handed back to the player unspent.
[_commItem] call fnc_support_consume;

[localize "STR_DUWS_T_actionteam", localize _reqLine, "", name player] remoteExec ["fnc_duws_dialogue", 0];

private _hq = getmarkerpos str blu_hq_markername;

// Ferry in from off the map: the bearing from map centre out through HQ points at the nearest
// edge, so a fixed push past HQ puts the spawn outside the playable area.
private _brg = ((_hq select 0) - worldSize/2) atan2 ((_hq select 1) - worldSize/2);
private _offmap = [(_hq select 0) + 6000 * sin _brg, (_hq select 1) + 6000 * cos _brg, _offmapAlt];

_group = [_offmap, WEST, _grouptype, [], [], blufor_ai_skill] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;
if (_spinUp) then { sleep 1 };
_vehicle = vehicle (leader _group);
if (_spinUp) then { _vehicle engineOn true };
// Ferry in high; dropped on-station at handover, raised again on egress below.
if (_ferryH > 0) then { _vehicle flyInHeight _ferryH };

missionNamespace setVariable [_curVehVar, _vehicle];
missionNamespace setVariable [_activeVar, true];

// Killed handles a shoot-down; Deleted handles a despawn with the crew still alive. Both only flip the
// per-sortie flags -- the terminal tail below owns the cooldown, on every path. Names are baked in here
// because an event-handler body cannot read the enclosing scope's locals when it fires.
_vehicle addEventHandler ["Killed", compile format ["
    params ['_killedVehicle'];
    if (!(missionNamespace getVariable ['%1', false])) exitWith {};
    if (_killedVehicle != (missionNamespace getVariable ['%2', objNull])) exitWith {};
    missionNamespace setVariable ['%1', false];
    missionNamespace setVariable ['%2', nil];
    [localize 'STR_DUWS_T_OVERLORD', localize '%3'] remoteExec ['fnc_duws_dialogue', 0];
", _activeVar, _curVehVar, _downLine]];

_vehicle addEventHandler ["Deleted", compile format ["
    params ['_deletedVehicle'];
    if (!(missionNamespace getVariable ['%1', false])) exitWith {};
    if (_deletedVehicle != (missionNamespace getVariable ['%2', objNull])) exitWith {};
    missionNamespace setVariable ['%1', false];
    missionNamespace setVariable ['%2', nil];
", _activeVar, _curVehVar]];

// Inbound: captive and CARELESS so it is not targetable, holds fire, and flies straight in. Not the
// player's asset yet -- no hcSetGroup until it reaches HQ. LOITER over HQ both brings it in and keeps it
// circling once there, until the player redirects it via High Command; MOVE just flies it to HQ.
{ _x setCaptive true } forEach units _group;
_vehicle setCaptive true;
_group setBehaviour "CARELESS";
private _wpIn = _group addWaypoint [_hq, 0];
_wpIn setWaypointType _wpInType;
if (_wpInType == "LOITER") then { _wpIn setWaypointLoiterRadius _loiterRadius };
_wpIn setWaypointSpeed "NORMAL";

[localize "STR_DUWS_T_OVERLORD", localize _ackLine] remoteExec ["fnc_duws_dialogue", 0];

// Bounded so an aircraft that cannot reach HQ still funnels to the tail instead of holding the slot forever.
private _inbound = time + 300;
waitUntil { sleep 3; !alive _vehicle || {_vehicle distance _hq < _arriveDist} || {time > _inbound} };

if (alive _vehicle && (missionNamespace getVariable [_activeVar, false]) && {_vehicle distance _hq < _arriveDist}) then {
	// On station: hand it to the player -- no longer captive, now a High Command asset.
	{ _x setCaptive false } forEach units _group;
	_vehicle setCaptive false;
	_group setBehaviour "AWARE";
	if (_stationH > 0) then { _vehicle flyInHeight _stationH };
	player hcsetgroup [_group,""];
	private _n = (missionNamespace getVariable [_squadCounterVar, 0]) + 1;
	missionNamespace setVariable [_squadCounterVar, _n];
	_group setGroupId [format[localize _squadIdKey, _n]];

	[localize _onStaSpeaker, localize _onStaLine] remoteExec ["fnc_duws_dialogue", 0];
	hint localize _onStaHint;

	// On-station leash: the aircraft holds for a fixed window, then breaks off and ferries back off the
	// map. A one-time support that only ever ended by being shot down was permanent once bought; this
	// makes it a sortie. A shoot-down ends the wait early so the leash never fights its own Killed handler.
	private _leash = time + (missionNamespace getVariable ["HC_air_station_seconds", 300]);
	waitUntil { sleep 5; time > _leash || !alive _vehicle };
	if (alive _vehicle && (missionNamespace getVariable [_activeVar, false])) then {
		[localize _onStaSpeaker, localize _rtbLine] remoteExec ["fnc_duws_dialogue", 0];
		// Cleared before egress: it is leaving under orders, so a shoot-down now is not a "casdown".
		missionNamespace setVariable [_activeVar, false];
		{ _x setCaptive true } forEach units _group;
		_vehicle setCaptive true;
		_group setBehaviour "CARELESS";
		if (_egressH > 0) then { _vehicle flyInHeight _egressH };
		while { count waypoints _group > 0 } do { deleteWaypoint [_group, 0] };
		private _wpOut = _group addWaypoint [_offmap, 0];
		_wpOut setWaypointType "MOVE";
		_wpOut setWaypointSpeed "FULL";
		// Grace cap so a damaged or blocked aircraft that never clears the map still cleans up.
		private _grace = time + 60;
		waitUntil { sleep 3; !alive _vehicle || _vehicle distance _offmap < 800 || time > _grace };
	};
};

// Terminal tail, reached on every path (arrived-and-expired, shot down, or no-show): tear the sortie
// down, then start the global cooldown. The support was consumed at launch, so it is not handed back --
// the caller re-buys at an HQ or FOB, and the cooldown gates the whole team until it lapses.
missionNamespace setVariable [_activeVar, false];
missionNamespace setVariable [_curVehVar, nil];
// Alive: normal stand-down. Dead: it was shot down, and an AI crew bails out of a critically damaged
// aircraft before it blows -- so live crew are left drifting under chutes in the player's group. Delete
// the group's surviving units so no stray friendly is stranded on the map.
if (alive _vehicle) then { [_vehicle, _group] call fnc_support_despawn }
else { { deleteVehicle _x } forEach units _group };
[_claimType, _cooldown] remoteExec ["fnc_hcair_endActive", 2];
