// Locality: client; the event-handler bodies below run on the machine that triggers them,
// not here (invoked from the comm menu, shared/includes/supports_radio_modern.hpp:198).

// Team-wide single-flight + global cooldown. Refused (with a hint) if one is already on station or the
// cooldown is still running; a refused call is handed back to the player unspent.
if !(["hcCAS", "hc_CAS", "STR_DUWS_T_hcair_busy_jet", "STR_DUWS_T_hcair_cooldown_jet"] call fnc_hcair_claim_request) exitWith {};

// Claim granted -> the support is spent. Consumed here, not at menu pick, so a request the guard above
// refused (in service or on cooldown) is handed back to the player unspent.
["hc_CAS"] call fnc_support_consume;

[localize "STR_DUWS_T_actionteam", ([localize "STR_DUWS_T_hccasrequest"] call fnc_cs), "", name player] remoteExec ["fnc_duws_dialogue", 0];

private _hq = getmarkerpos str blu_hq_markername;

// Ferry in from off the map: the bearing from map centre out through HQ points at the nearest
// edge, so a fixed push past HQ puts the spawn outside the playable area.
private _brg = ((_hq select 0) - worldSize/2) atan2 ((_hq select 1) - worldSize/2);
private _offmap = [(_hq select 0) + 6000 * sin _brg, (_hq select 1) + 6000 * cos _brg, 600];

_grouptype = [blufor_MISC_AIR_X];

_group = [_offmap, WEST, _grouptype, [], [], blufor_ai_skill] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;
sleep 1;
_pilot = units _group select 0;
_vehicle = vehicle _pilot;
_vehicle engineOn true;

// store the current CAS jet in a global for event-handler sync
HC_CAS_currentVehicle = _vehicle;
HC_CAS_active = true;

// Killed handles a shoot-down; Deleted handles a despawn with the crew still alive. Both only flip the
// per-sortie flags -- the terminal tail below owns the cooldown, on every path.
_vehicle addEventHandler ["Killed", {
    params ["_killedVehicle"];
    if (!HC_CAS_active) exitWith {};
    if (_killedVehicle != HC_CAS_currentVehicle) exitWith {};
    HC_CAS_active = false;
    HC_CAS_currentVehicle = nil;
    [localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_casdownkoi"] remoteExec ["fnc_duws_dialogue", 0];
}];

_vehicle addEventHandler ["Deleted", {
    params ["_deletedVehicle"];
    if (!HC_CAS_active) exitWith {};
    if (_deletedVehicle != HC_CAS_currentVehicle) exitWith {};
    HC_CAS_active = false;
    HC_CAS_currentVehicle = nil;
}];

// Inbound: captive and CARELESS so it is not targetable, holds fire, and flies straight in. Not the
// player's asset yet -- no hcSetGroup until it reaches HQ. A LOITER waypoint over HQ both brings the jet
// in and keeps it circling once there, until the player redirects it via High Command.
{ _x setCaptive true } forEach units _group;
_vehicle setCaptive true;
_group setBehaviour "CARELESS";
private _wpIn = _group addWaypoint [_hq, 0];
_wpIn setWaypointType "LOITER";
_wpIn setWaypointLoiterRadius 800;
_wpIn setWaypointSpeed "NORMAL";

[localize "STR_DUWS_T_OVERLORD", [localize "STR_DUWS_T_hccasack"] call fnc_cs] remoteExec ["fnc_duws_dialogue", 0];

// Bounded so a jet that cannot reach HQ still funnels to the tail instead of holding the slot forever.
private _inbound = time + 300;
waitUntil { sleep 3; !alive _vehicle || {_vehicle distance _hq < 1200} || {time > _inbound} };

if (alive _vehicle && HC_CAS_active && {_vehicle distance _hq < 1200}) then {
	// On station: hand it to the player. Clear captive/CARELESS, add to High Command, name the group.
	{ _x setCaptive false } forEach units _group;
	_vehicle setCaptive false;
	_group setBehaviour "AWARE";
	_vehicle flyInHeight 150;
	player hcsetgroup [_group,""];
	DUWS_number_CAS = DUWS_number_CAS + 1;
	_group setGroupId [format[localize "STR_DUWS_T_hc_cas_squad",DUWS_number_CAS]];

	[localize "STR_DUWS_T_koipilot", [localize "STR_DUWS_T_koiin"] call fnc_cs] remoteExec ["fnc_duws_dialogue", 0];
	hint localize "STR_DUWS_T_gu6cbc5f";

	// On-station leash: the jet holds for a fixed window, then breaks off and ferries back off the map.
	// A one-time support that only ever ended by being shot down was permanent once bought; this makes it
	// a sortie. A shoot-down ends the wait early so the leash never fights its own Killed handler.
	private _leash = time + (missionNamespace getVariable ["HC_air_station_seconds", 300]);
	waitUntil { sleep 5; time > _leash || !alive _vehicle };
	if (alive _vehicle && HC_CAS_active) then {
		[localize "STR_DUWS_T_koipilot", [localize "STR_DUWS_T_hc_cas_rtb"] call fnc_cs] remoteExec ["fnc_duws_dialogue", 0];
		// Cleared before egress: it is leaving under orders, so a shoot-down now is not a "casdown".
		HC_CAS_active = false;
		{ _x setCaptive true } forEach units _group;
		_vehicle setCaptive true;
		_group setBehaviour "CARELESS";
		while { count waypoints _group > 0 } do { deleteWaypoint [_group, 0] };
		private _wpOut = _group addWaypoint [_offmap, 0];
		_wpOut setWaypointType "MOVE";
		_wpOut setWaypointSpeed "FULL";
		// Grace cap so a damaged or blocked aircraft that never clears the map still cleans up.
		private _grace = time + 180;
		waitUntil { sleep 3; !alive _vehicle || _vehicle distance _offmap < 800 || time > _grace };
	};
};

// Terminal tail, reached on every path (arrived-and-expired, shot down, or no-show): tear the sortie
// down, then start the global cooldown. The support was consumed at launch, so it is not handed back --
// the caller re-buys at an HQ or FOB, and the cooldown gates the whole team until it lapses.
HC_CAS_active = false;
HC_CAS_currentVehicle = nil;
if (alive _vehicle) then { [_vehicle, _group] call fnc_support_despawn };
["hcCAS", 600] remoteExec ["fnc_hcair_endActive", 2];
