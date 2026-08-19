// Locality: server -- called (not spawned) from fnc_rescue_squad_mission once the cordon is broken.
//
// Evac + completion. The cordon is dead and the squad is up; fly it out and close the mission. Squad
// and helicopter are both set captive for the pickup: the fight is already won, and a scripted bird
// taking stray fire from a passing patrol on the way out is not a failure the player earned. The bird
// lands at an LZ off the building and the squad boards on foot; a straggler stuck on geometry is moved
// into cargo on a timeout so one man cannot hang the extraction. Player and allies cannot board
// (lockedCargo).
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

// A clear spot just off the building to put down on.
private _lz = [_bpos, 25, 70, 10, 0, 0.35, 0] call BIS_fnc_findSafePos;
if (_lz isEqualTo [] || {(_lz select 0) == 0}) then { _lz = _bpos getPos [45, random 360] };

private _bearing = random 360;
private _vehpos = _bpos getPos [2500, _bearing];
// Spawn crewed and flight-ready in one call, then lift to altitude (setPos z is above ground level, so
// it clears whatever terrain the far spawn point sits on) and set the cruise height -- the helo-taxi's
// pattern (client/supports/taxi/fnc_helotaxi.sqf). createVehicle "FLY" with a later createVehicleCrew
// left the bird airborne with no pilot for a moment -- long enough to nose into the ground -- and its
// height came only from the position z, never an explicit setPos.
private _veh = [_vehpos, 0, blufor_TRANS_HELI_X, WEST] call BIS_fnc_spawnVehicle;
private _heli = _veh select 0;
private _heliGrp = _veh select 2;
_heli setPos [_vehpos select 0, _vehpos select 1, 120];
[_heli, _compKey] call fnc_duws_keep;
_heli setCaptive true;
_heli lockedCargo true;
_heli flyInHeight 40;
{ _x setCaptive true } forEach crew _heli;
_heliGrp setBehaviour "CARELESS";
_heliGrp setCombatMode "BLUE";
_heliGrp deleteGroupWhenEmpty true;

// In to the LZ, then land and let the squad board on foot. `land "GET IN"` puts the bird down and
// lifts it again on its own once everyone assigned is aboard.
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
    if (!isNil "_heli" && {alive _heli}) then { { deleteVehicle _x } forEach crew _heli; deleteVehicle _heli };
    [_tpos, _radius, _compKey] call fnc_mission_end;
};

private _tApproach = time + 150;
waitUntil { sleep 1; !alive _heli || {(_heli distance2D _lz) < 120} || {time > _tApproach} || {(_squad findIf {alive _x}) < 0} };
if ((_squad findIf {alive _x}) < 0) exitWith { call _fail };
if (alive _heli) then {
    _heli move _lz;
    _heli land "GET IN";
    { _x assignAsCargo _heli } forEach (_squad select {alive _x});
    (_squad select {alive _x}) orderGetIn true;
};

// Board on foot; teleport any straggler on a timeout so a man stuck on geometry cannot hang it.
private _tBoard = time + 75;
waitUntil { sleep 1; !alive _heli || {({ alive _x && {!(_x in _heli)} } count _squad) == 0} || {time > _tBoard} };
if ((_squad findIf {alive _x}) < 0) exitWith { call _fail };
if (alive _heli) then {
    { if (alive _x && {!(_x in _heli)}) then { _x moveInCargo _heli } } forEach _squad;
    _heli land "NONE";
};

// Out the far side and off the map.
private _departPos = _bpos getPos [3500, _bearing];
private _wpOut = _heliGrp addWaypoint [_departPos, 0];
_wpOut setWaypointType "MOVE";
_wpOut setWaypointSpeed "FULL";

private _tOut = time + 180;
waitUntil { sleep 2; !alive _heli || {(_heli distance2D _bpos) > 2500} || {time > _tOut} };
if ((_squad findIf {alive _x}) < 0) exitWith { call _fail };

[_marker] call fnc_missionMarkerClear;
[_taskId, "SUCCEEDED"] call fnc_missionTaskEnd;
[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_squadevacout"] remoteExec ["fnc_duws_dialogue", 0];

{ deleteVehicle _x } forEach crew _heli;
deleteVehicle _heli;
{ deleteVehicle _x } forEach _squad;

[_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;
[_tpos, _radius, _compKey] call fnc_mission_end;

// If HARDCORE, Rescue pays intel. Called rather than spawned into a client function: the shape this
// replaced ran from a server thread through one that began `if (!hasInterface) exitWith {}`, so on a
// dedicated server the reward evaporated. The mission site stands in for the earner's position.
if (hardcore_mode_enable) then { [_tpos] call fnc_intel_payout };
