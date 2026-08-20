// Locality: server -- called (not spawned) from fnc_rescue_squad_mission once the cordon is broken.
//
// Evac + completion. The cordon is dead and the squad is up; fly it out and close the mission. Squad
// and helicopter are both set captive for the pickup: the fight is already won, and a scripted bird
// taking stray fire from a passing patrol on the way out is not a failure the player earned. The bird
// lands at an LZ off the building and the squad boards on foot; a straggler stuck on geometry is moved
// into cargo on a timeout so one man cannot hang the extraction. A bird lost while the squad is still on
// foot -- on approach or on the deck -- costs the lift, not the mission: the survivors walk off the AO and
// the reward still pays. Once they are sealed aboard they are committed to it, so a crash from there
// (before the reward) is a loss; a wiped squad is a KIA fail either way. The player and allies are kept off
// the bird -- any that board while it is down are turned out before it lifts, then cargo is locked for the
// flight -- so the teardown only ever deletes the flight crew and the squad.
params ["_squad", "_bld", "_marker", "_taskId", "_tpos", "_radius", "_compKey", "_mission_name", "_cpreward", "_apreward"];
private _bpos = getPos _bld;
private _alive = _squad select {alive _x};

// Squad up and safe for the pickup: unpin them (PATH/MOVE on) so they can walk to the bird, stand them
// up, and set captive so the extraction is not lost to a stray round now the fight is won. Unpinned here
// as well as at break-out: on a cordon-wiped win the main thread can flip DUWS_rsq_relieved before the
// un-captive thread runs, so without this the squad stays pinned in the building and never boards.
{
    _x enableAI "PATH";
    _x enableAI "MOVE";
    _x setCaptive true;
    _x setUnitPos "AUTO";
} forEach _alive;
[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_squadevac"] remoteExec ["fnc_duws_dialogue", 0];

// A safe, flat spot to put down on -- anywhere clear within reach of the building, not pinned right
// beside it, so the bird gets real open ground instead of a cramped slot against the walls. Wide band
// and the taxi's gradient tolerance for a reliable find; the squad boards on foot, so it stays walkable.
private _lz = [_bpos, 40, 200, 15, 0, 0.5, 0] call BIS_fnc_findSafePos;
if (_lz isEqualTo [] || {(_lz select 0) == 0}) then { _lz = _bpos getPos [60, random 360] };

private _bearing = random 360;
private _vehpos = _bpos getPos [2500, _bearing];
// Spawn and fly the bird on the helo-taxi's shape (client/supports/taxi/fnc_helotaxi.sqf), the one
// transport pattern that lands reliably here. BIS_fnc_spawnVehicle gives a crewed, flight-ready bird in
// one call (no pilotless window); setPos z is above ground level, so 200 clears whatever terrain the far
// spawn sits on; flyInHeight sets the cruise. The invisible helipad and the pinned pilot below are what
// turn an inconsistent approach into a clean put-down.
private _veh = [_vehpos, 0, blufor_TRANS_HELI_X, WEST] call BIS_fnc_spawnVehicle;
private _heli = _veh select 0;
private _heliGrp = _veh select 2;
_heli setPos [_vehpos select 0, _vehpos select 1, 200];
[_heli, _compKey] call fnc_duws_keep;
_heli setCaptive true;
_heli flyInHeight 50;
{ _x setCaptive true } forEach crew _heli;
// The flight crew, captured before anyone boards: teardown deletes exactly these plus the squad, never a
// blanket crew _heli, so a player or ally who rode along is never caught by the delete. Cargo starts
// unlocked so the squad can board on foot; it is locked once they are aboard (below).
private _heliCrew = crew _heli;
// Without this VCOM's squad FSM seizes the WEST/AI group and ignores its scripted MOVE waypoint,
// leaving the bird idle at spawn. Every other scripted transport heli sets it for the same reason.
{ _x setVariable ["Vcm_Disable", true] } forEach units _heliGrp;
_heliGrp setBehaviour "CARELESS";
_heliGrp setCombatMode "BLUE";
_heliGrp deleteGroupWhenEmpty true;

// Pilot will not abort the run: allowFleeing 0 stops it bugging out on damage, disableAI "Target" stops
// it breaking off to engage. Straight off the taxi.
private _pilot = currentPilot _heli;
_pilot allowFleeing 0;
_pilot disableAI "Target";

// Invisible helipad on the LZ: this is what makes `land` put down on the exact spot rather than the AI
// choosing its own and hovering. Kept under the composition key so teardown sweeps it with the rest.
private _helipad = createVehicle ["Land_HelipadEmpty_F", _lz, [], 0, "NONE"];
[_helipad, _compKey] call fnc_duws_keep;

// In to the LZ, then land and let the squad board on foot. `land "GET IN"` puts the bird down and lifts
// it again on its own once everyone assigned is aboard.
private _wpIn = _heliGrp addWaypoint [_lz, 0];
_wpIn setWaypointType "MOVE";
_wpIn setWaypointSpeed "FULL";

// The player can still kill the captive squad mid-evac; if none are left there is nothing to extract,
// so abort the bird and fail rather than flying an empty LZ run to a false success. The main thread's
// squad-death fail only reaches up to the cordon breaking -- this carries it through the extraction.
private _fail = {
    [_marker] call fnc_missionMarkerClear;
    [_taskId, "FAILED"] call fnc_missionTaskEnd;
    [localize "STR_DUWS_T_OVERLORD", [localize "STR_DUWS_T_squadfail"] call fnc_cs] remoteExec ["fnc_duws_dialogue", 0];
    // No one left to lift. Send the empty bird off and delete it once it is clear of the AO, rather than
    // vanishing it in front of the player. Its LZ run is dropped for a departure leg; a detached watcher
    // deletes it when far (or on a timeout) so this fail path finishes and tears down now. mission_end
    // releases the composition but only schedules disposal, so nothing poofs the bird before it leaves.
    if (!isNil "_heli" && {alive _heli}) then {
        _heliGrp setBehaviour "CARELESS";
        _heli flyInHeight 80;
        for "_i" from (count (waypoints _heliGrp) - 1) to 1 step -1 do { deleteWaypoint [_heliGrp, _i] };
        private _wpAway = _heliGrp addWaypoint [_bpos getPos [4000, _bearing], 0];
        _wpAway setWaypointType "MOVE";
        _wpAway setWaypointSpeed "FULL";
        [_heli, _bpos, _heliCrew] spawn {
            params ["_h", "_ref", "_crew"];
            private _t = time + 120;
            waitUntil { sleep 2; !alive _h || {(_h distance2D _ref) > 2500} || {time > _t} };
            if (!isNull _h) then { { deleteVehicle _x } forEach _crew; deleteVehicle _h };
        };
    };
    if (!isNil "_helipad") then { deleteVehicle _helipad };
    [_tpos, _radius, _compKey] call fnc_mission_end;
};

// The evac bird is down, but the fight was already won and the squad is up, so losing the lift is not a
// failure the player earned: the survivors walk off the AO on foot and the mission still succeeds. Only a
// squad with no one left to walk -- wiped before this, or lost in a crash with them aboard -- falls through
// to the KIA fail. Radio tone is borrowed from the helo-taxi's own bird-down call.
private _exfilFoot = {
    // Let a crash blast finish resolving before calling this a save. If the bird went down on top of the
    // squad their deaths can land a beat after the wreck is flagged dead, so a bare survivor check would
    // pay out a squad that is about to die. Settle, then require someone actually left to walk out.
    sleep 10;
    private _out = _squad select {alive _x};
    if (_out isEqualTo []) exitWith { call _fail };
    // Cancel any boarding order, turn out anyone caught in the wreck, and stand them up to walk.
    {
        unassignVehicle _x;
        if (_x in _heli) then { _x remoteExec ["moveOut", _x] };
        _x enableAI "PATH";
        _x enableAI "MOVE";
        _x setUnitPos "AUTO";
    } forEach _out;
    // Run the group back to friendly HQ on its own legs; wipe the boarding waypoints first so it heads
    // home instead of chasing the dead bird's LZ. The despawn below still sweeps it once clear of the AO.
    private _grp = group (_out select 0);
    _grp setBehaviour "AWARE";
    for "_i" from (count (waypoints _grp) - 1) to 0 step -1 do { deleteWaypoint [_grp, _i] };
    private _wpFoot = _grp addWaypoint [getPos bluHQ_object, 0];
    _wpFoot setWaypointType "MOVE";
    _wpFoot setWaypointSpeed "FULL";
    if (!isNil "_helipad") then { deleteVehicle _helipad };
    [_marker] call fnc_missionMarkerClear;
    [_taskId, "SUCCEEDED"] call fnc_missionTaskEnd;
    [] spawn {
        [localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_squadevacfoot"] remoteExec ["fnc_duws_dialogue", 0];
        sleep 5;
        [localize "STR_DUWS_T_Signal", localize "STR_DUWS_T_squadfootout"] remoteExec ["fnc_duws_dialogue", 0];
    };
    // Survivors and the dead bird's crew are swept once the squad is clear of the AO (or on a timeout).
    [_out, _heli, _heliCrew, _bpos] spawn {
        params ["_sq", "_h", "_crew", "_ref"];
        private _t = time + 180;
        waitUntil { sleep 2; ({ alive _x && {(_x distance2D _ref) < 2500} } count _sq) == 0 || {time > _t} };
        { deleteVehicle _x } forEach _sq;
        { deleteVehicle _x } forEach _crew;
        if (!isNull _h) then { deleteVehicle _h };
    };
    [_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;
    [_tpos, _radius, _compKey] call fnc_mission_end;
};

private _tApproach = time + 150;
waitUntil { sleep 1; !alive _heli || {(_heli distance2D _lz) < 350} || {time > _tApproach} || {(_squad findIf {alive _x}) < 0} };
if ((_squad findIf {alive _x}) < 0) exitWith { call _fail };
if (!alive _heli) exitWith { call _exfilFoot };
_heli land "GET IN";
{ _x assignAsCargo _heli } forEach (_squad select {alive _x});
(_squad select {alive _x}) orderGetIn true;

// Board on foot; teleport any straggler on a timeout so a man stuck on geometry cannot hang it.
private _tBoard = time + 75;
waitUntil { sleep 1; !alive _heli || {({ alive _x && {!(_x in _heli)} } count _squad) == 0} || {time > _tBoard} };
if ((_squad findIf {alive _x}) < 0) exitWith { call _fail };
if (!alive _heli) exitWith { call _exfilFoot };
{ if (alive _x && {!(_x in _heli)}) then { _x moveInCargo _heli } } forEach _squad;
// Seal the bird for the flight out: turn out anyone who is not the squad or the flight crew -- a
// player or ally who hopped in while it was down -- then lock cargo so none board mid-air. moveOut
// runs on the machine that owns the unit.
{ if !(_x in _squad || {_x in _heliCrew}) then { _x remoteExec ["moveOut", _x] } } forEach crew _heli;
_heli lockCargo true;
_heli land "NONE";

// Off the deck and away. The win lands the moment the bird is up with the squad aboard, so pay out and
// close ~10 s after takeoff rather than blocking on the long flight home -- the empty run to the map edge
// and the despawn happen in the background below.
private _departPos = _bpos getPos [3500, _bearing];
private _wpOut = _heliGrp addWaypoint [_departPos, 0];
_wpOut setWaypointType "MOVE";
_wpOut setWaypointSpeed "FULL";

sleep 10;
// Sealed aboard and lifting: the squad is committed to the bird, so a crash here -- before the reward is
// paid -- is a loss, not an on-foot recovery. Fail rather than pay a squad that went down with the bird.
if (!alive _heli) exitWith { call _fail };

[_marker] call fnc_missionMarkerClear;
[_taskId, "SUCCEEDED"] call fnc_missionTaskEnd;

// Radio exchange, spawned so the beat between the two lines does not hold up the payout below.
[] spawn {
    [localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_squadevacout"] remoteExec ["fnc_duws_dialogue", 0];
    sleep 5;
    [localize "STR_DUWS_T_Signal", localize "STR_DUWS_T_squadthanks"] remoteExec ["fnc_duws_dialogue", 0];
};

deleteVehicle _helipad;

// The bird flies itself off and despawns in the background; the win does not wait on it. Crew and squad
// go with it once it is clear of the AO (or on a timeout). mission_end releases the composition but only
// schedules disposal, so nothing poofs the bird before it leaves.
[_heli, _heliCrew, _squad, _bpos] spawn {
    params ["_h", "_crew", "_sq", "_ref"];
    private _t = time + 180;
    waitUntil { sleep 2; !alive _h || {(_h distance2D _ref) > 2500} || {time > _t} };
    { deleteVehicle _x } forEach _crew;
    { deleteVehicle _x } forEach _sq;
    if (!isNull _h) then { deleteVehicle _h };
};

[_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;
[_tpos, _radius, _compKey] call fnc_mission_end;
