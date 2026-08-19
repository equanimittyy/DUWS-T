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

// Squad up and safe for the pickup: PATH on so they can walk to the bird, captive so the extraction is
// not lost to a stray round now the fight is won.
{ _x enableAI "PATH"; _x enableAI "MOVE"; _x setCaptive true } forEach _alive;
[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_squadevac"] remoteExec ["fnc_duws_dialogue", 0];

// A clear spot just off the building to put down on.
private _lz = [_bpos, 25, 70, 10, 0, 0.35, 0] call BIS_fnc_findSafePos;
if (_lz isEqualTo [] || {(_lz select 0) == 0}) then { _lz = _bpos getPos [45, random 360] };

private _bearing = random 360;
private _spawnPos = _bpos getPos [2500, _bearing];
_spawnPos set [2, 120];
private _heli = createVehicle [blufor_TRANS_HELI_X, _spawnPos, [], 0, "FLY"];
[_heli, _compKey] call fnc_duws_keep;
_heli setCaptive true;
_heli lockedCargo true;
_heli flyInHeight 40;
createVehicleCrew _heli;
{ _x setCaptive true } forEach crew _heli;
private _heliGrp = group (driver _heli);
_heliGrp setBehaviour "CARELESS";
_heliGrp setCombatMode "BLUE";
_heliGrp deleteGroupWhenEmpty true;

// In to the LZ, then land and let the squad board on foot. `land "GET IN"` puts the bird down and
// lifts it again on its own once everyone assigned is aboard.
private _wpIn = _heliGrp addWaypoint [_lz, 0];
_wpIn setWaypointType "MOVE";
_wpIn setWaypointSpeed "FULL";

private _tApproach = time + 150;
waitUntil { sleep 1; !alive _heli || {(_heli distance2D _lz) < 120} || {time > _tApproach} };
if (alive _heli) then {
    _heli move _lz;
    _heli land "GET IN";
    { _x assignAsCargo _heli } forEach (_squad select {alive _x});
    (_squad select {alive _x}) orderGetIn true;
};

// Board on foot; teleport any straggler on a timeout so a man stuck on geometry cannot hang it.
private _tBoard = time + 75;
waitUntil { sleep 1; !alive _heli || {({ alive _x && {!(_x in _heli)} } count _squad) == 0} || {time > _tBoard} };
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
