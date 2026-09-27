// Locality: server, [] call'd at load. The live ferry crossing -- a watched carry rendered as the timed six-phase
// machine plus its GetIn/GetOut board/dismount handlers. Each lift type's phases are its own table
// (fnc_opcom_ferry_rotor, fnc_opcom_ferry_boat, fnc_opcom_ferry_ground); this file holds what they share. The
// orchestrator (fnc_opcom_ferry) drives it each tick; the virtual mirror is fnc_opcom_ferry_virt
// (docs/plans/opcom/opcom_plan.md §Shipped).
if (!isServer) exitWith {};

// Lift type -> phase -> handler, filled by the lift files.
DUWS_opcom_ferryHulls = createHashMap;

// Clear a hull's ferry state so one that ferries a second rider re-arms cleanly (a stale handler skips the re-arm).
DUWS_fnc_opcom_ferryClearHull = {
    params ["_veh"];
    private _b = _veh getVariable ["DUWS_ferryBoardEH", -1];
    if (_b >= 0) then { _veh removeEventHandler ["GetIn", _b]; _veh setVariable ["DUWS_ferryBoardEH", -1] };
    private _u = _veh getVariable ["DUWS_ferryUnloadEH", -1];
    if (_u >= 0) then { _veh removeEventHandler ["GetOut", _u]; _veh setVariable ["DUWS_ferryUnloadEH", -1] };
    _veh setVariable ["DUWS_ferryRiderGrp", grpNull];
    _veh setVariable ["DUWS_ferryUnloadGrp", grpNull];
    _veh setVariable ["DUWS_ferryUnloadRider", -1];
    _veh setVariable ["DUWS_ferryUnloadQ", []];
};

// The pad hangs off the tasking, not the hull: a hull shot down on its approach can lose its group and leave its
// crew dead outside the wreck, so a pad reachable only through it outlives the ferry. netId because a tasking holds
// no object handle; the class check refuses one a reload has recycled onto another object.
DUWS_fnc_opcom_ferryClearPad = {
    params ["_t"];
    private _pad = objectFromNetId (_t getOrDefault ["ferryPad", ""]);
    if (_pad isKindOf "Land_HelipadEmpty_F") then { deleteVehicle _pad };
    _t set ["ferryPad", ""];
};

// A squad can outnumber the cabin, so the men who do not fit wait hidden and ride in as seats free.
DUWS_fnc_opcom_ferrySeatFill = {
    params ["_veh"];
    private _q = (_veh getVariable ["DUWS_ferryUnloadQ", []]) select { !isNull _x && {alive _x} };
    while {_q isNotEqualTo [] && {(_veh emptyPositions "cargo") > 0}} do {
        private _u = _q deleteAt 0;
        _u enableSimulation true;
        _u hideObjectGlobal false;
        _u moveInCargo _veh;
    };
    _veh setVariable ["DUWS_ferryUnloadQ", _q];
};

// Refill first: the men the cabin could not take wait hidden 10 km up, and a freed seat is how they reach the LZ.
DUWS_fnc_opcom_ferryUnloadNext = {
    params ["_veh"];
    [_veh] call DUWS_fnc_opcom_ferrySeatFill;
    private _grp = _veh getVariable ["DUWS_ferryUnloadGrp", grpNull];
    if (isNull _grp) exitWith {};
    private _aboard = (units _grp) select { alive _x && {vehicle _x isEqualTo _veh} };
    if (_aboard isEqualTo []) exitWith {};
    private _u = _aboard select 0;
    // moveOut, not an ordered dismount: the order left men aboard as the hull lifted. Unassign so nobody re-boards.
    moveOut _u;
    unassignVehicle _u;
};

DUWS_fnc_opcom_ferryUnloadPending = {
    params ["_veh"];
    private _q = (_veh getVariable ["DUWS_ferryUnloadQ", []]) select { !isNull _x && {alive _x} };
    private _grp = _veh getVariable ["DUWS_ferryUnloadGrp", grpNull];
    private _aboard = if (isNull _grp) then { [] } else { (units _grp) select { alive _x && {vehicle _x isEqualTo _veh} } };
    (_q + _aboard) isNotEqualTo []
};

// The step helpers from here down run inside DUWS_fnc_opcom_ferryStepLive, as the lift tables' handlers do, and read
// its locals _t, _rider, _grp, _veh, _tpos and _phase rather than taking them.
DUWS_fnc_opcom_ferrySetPhase = {
    params ["_p"];
    private _wait = _t getOrDefault ["ferryWait", 0];
    [["INFO", "WARN"] select (_wait >= OPCOM_FERRY_WAIT_MAX), "OPCOM", format ["ferry: transport %1 (%2) rider %3 %4 -> %5, wait %6/%7",
        _t get "id", _t get "moveType", _rider get "id", _phase, _p, _wait, OPCOM_FERRY_WAIT_MAX]] call fnc_log;
    _t set ["ferryPhase", _p]; _t set ["ferryWait", 0];
};

DUWS_fnc_opcom_ferryWaitTick = {
    private _wait = (_t getOrDefault ["ferryWait", 0]) + 1;
    _t set ["ferryWait", _wait];
    _wait
};

// A leg's move goes out once, as the leg starts: finished waypoints stay in `waypoints`, so no count gate re-fires.
DUWS_fnc_opcom_ferryLegTo = {
    params ["_pt"];
    _t set ["ferryLZ", _pt];
    [_grp, "move", _pt] call DUWS_fnc_opcom_applyOrder;
};

// Once per rider group: one streamed in mid-pickup is a new group. -> that group, or grpNull once this hull has it.
DUWS_fnc_opcom_ferryNewRiders = {
    private _rg = groupFromNetId (_rider get "grp");
    if (isNull _rg || {(_veh getVariable ["DUWS_ferryRiderGrp", grpNull]) isEqualTo _rg}) exitWith { grpNull };
    _veh setVariable ["DUWS_ferryRiderGrp", _rg];
    _rg
};

// The GetIn handler reads the group tag live, so one handler serves any rider group and stays off the crew;
// board-despawn frees each seat at once, so one hull loads any squad.
DUWS_fnc_opcom_ferryWalkAboard = {
    params ["_rg", "_meet"];
    if ((_veh getVariable ["DUWS_ferryBoardEH", -1]) < 0) then {
        _veh setVariable ["DUWS_ferryBoardEH", _veh addEventHandler ["GetIn", {
            params ["_v", "", "_u"];
            if (group _u isEqualTo (_v getVariable ["DUWS_ferryRiderGrp", grpNull])) then { deleteVehicle _u };
        }]];
    };
    [_rg, "move", _meet] call DUWS_fnc_opcom_applyOrder;
    { _x assignAsCargo _veh } forEach ((units _rg) select {alive _x});
};

// Seats bind once, against what was free then: a man the full cabin left over is never re-paired to a
// seat his despawning mates freed, so the last one in -- the leader -- idles to expiry. _settle takes him.
DUWS_fnc_opcom_ferryBoardPush = {
    params ["_settle"];
    private _rg = groupFromNetId (_rider get "grp");
    if (isNull _rg) exitWith {};
    private _out = (units _rg) select { alive _x && {vehicle _x isEqualTo _x} };
    if (_out isEqualTo []) exitWith {};
    if (_settle) exitWith { { _x moveInCargo _veh } forEach _out };
    { _x assignAsCargo _veh } forEach _out;
    _out orderGetIn true;
};

DUWS_fnc_opcom_ferryWalkBoard = {
    params ["_orderRiders", "_embark"];
    private _wait = call DUWS_fnc_opcom_ferryWaitTick;
    call _orderRiders;
    [_wait >= (OPCOM_FERRY_WAIT_MAX / 2)] call DUWS_fnc_opcom_ferryBoardPush;
    // Boarders despawn on entry, so an empty group is a finished board.
    if (({alive _x} count units groupFromNetId (_rider get "grp")) == 0) exitWith { call _embark };
    if (_wait >= OPCOM_FERRY_WAIT_MAX) then { call _embark };
};

DUWS_fnc_opcom_ferryEmbarkRider = {
    private _rg = groupFromNetId (_rider get "grp");
    if (!isNull _rg) then { { deleteVehicle _x } forEach ((units _rg) select { alive _x }); deleteGroup _rg };
    _rider set ["grp", ""]; _rider set ["status", "virtual"];
    private _drop = [_rider] call DUWS_fnc_opcom_ferryDrop; _rider set ["ferryLand", _drop];
    _t set ["target", [_t, _drop] call DUWS_fnc_opcom_ferryApproach]; _t set ["route", []];
    _t set ["embarked", true];
};

// Spawns the rider still bound; ferryRelease, or a rotor's first man out, unbinds it. _alt spawns it clear
// of the map: hideObjectGlobal lands a frame or two late, so a group raised on the pad flashes there.
DUWS_fnc_opcom_ferryDropSpawn = {
    params ["_p", ["_alt", 0]];
    if (_alt > 0) then { _p = [_p select 0, _p select 1, _alt] };
    _rider set ["pos", _p];
    _rider set ["route", []]; _rider set ["leg", 0];
    [_rider, false] call DUWS_fnc_opcom_deVirt;
};

// Seat the men before a rotor calls its landing: "GET OUT" keeps the engine turning where "LAND" shuts it down, but
// with an empty cabin its hold ends at once, so they board first and ride the descent in their seats.
// -> false when the rider had no group to seat, and the ferry is released.
DUWS_fnc_opcom_ferryDropBoard = {
    [_t get "ferryLZ", 10000] call DUWS_fnc_opcom_ferryDropSpawn;
    private _rg = groupFromNetId (_rider get "grp");
    if (isNull _rg) exitWith { [_t] call DUWS_fnc_opcom_ferryRelease; false };
    { _x hideObjectGlobal true; _x enableSimulation false } forEach units _rg;
    _veh setVariable ["DUWS_ferryUnloadGrp", _rg];
    _veh setVariable ["DUWS_ferryUnloadRider", _rider get "id"];
    _veh setVariable ["DUWS_ferryUnloadQ", [leader _rg] + ((units _rg) - [leader _rg])];
    // `unloading` keeps task_step from stowing or re-tasking the rider mid-drop; the first man out unbinds it.
    _veh setVariable ["DUWS_ferryUnloadEH", _veh addEventHandler ["GetOut", {
        params ["_v", "", "_u"];
        if (group _u isNotEqualTo (_v getVariable ["DUWS_ferryUnloadGrp", grpNull])) exitWith {};
        private _r = [_v getVariable ["DUWS_ferryUnloadRider", -1]] call DUWS_fnc_opcom_byId;
        if (!isNil "_r" && {(_r getOrDefault ["ridingOn", -1]) >= 0}) then { [_r] call DUWS_fnc_opcom_ferryUnbind };
    }]];
    _rider set ["unloading", true];
    [_veh] call DUWS_fnc_opcom_ferrySeatFill;
    true
};

// Put whoever is left on the ground at the LZ: the held men wait 10 km above it, so showing them where they
// stand drops them to their deaths.
DUWS_fnc_opcom_ferryDropGround = {
    private _rg = groupFromNetId (_rider get "grp");
    if (isNull _rg) exitWith {};
    (_t get "ferryLZ") params ["_lx", "_ly"];
    {
        moveOut _x;
        _x enableSimulation true;
        _x hideObjectGlobal false;
        _x setPosATL [_lx, _ly, 0];
    } forEach ((units _rg) select {alive _x});
    _veh setVariable ["DUWS_ferryUnloadQ", []];
};

DUWS_fnc_opcom_ferryUnloadPaced = {
    params ["_rotor"];
    [_veh, _rotor] spawn {
        params ["_veh", "_rotor"];
        // A rotor off the deck must not be turning men out: the tick puts the rest down instead.
        while {alive _veh && {!_rotor || {((getPosATL _veh) select 2) < OPCOM_FERRY_GROUND_ALT}}
               && {[_veh] call DUWS_fnc_opcom_ferryUnloadPending}} do {
            [_veh] call DUWS_fnc_opcom_ferryUnloadNext;
            sleep 2;
        };
    };
};

DUWS_fnc_opcom_ferryUnloadEnd = {
    params ["_wait"];
    private _rg = groupFromNetId (_rider get "grp");
    if ((isNull _rg) || {!([_veh] call DUWS_fnc_opcom_ferryUnloadPending)} || {_wait >= OPCOM_FERRY_WAIT_MAX}) then {
        if (_wait >= OPCOM_FERRY_WAIT_MAX) then { call DUWS_fnc_opcom_ferryDropGround };
        [_t] call DUWS_fnc_opcom_ferryRelease;
    };
};

// One tick of the live crossing: a timed phase machine for all three lift types (topickup -> pickupland ->
// pickupboard -> carry -> dropland -> dropunload). Transit legs are untimed; each land/board/unload phase caps at
// OPCOM_FERRY_WAIT_MAX ticks and forces through on expiry, so a rotor's descent and its walk-aboard hold a budget
// each. Do NOT unify the lifts' board/dismount shapes, which is why each lift type keeps its own phase table; a phase
// it has no row for does nothing. Strength freezes at the board commit, thaws when the rider is on the ground.
DUWS_fnc_opcom_ferryStepLive = {
    params ["_t", "_rider"];
    private _grp = groupFromNetId (_t get "grp");
    if (isNull _grp) exitWith {};                       // spawn lost; ferryTick re-streams it next tick
    private _veh = vehicle (leader _grp);
    private _tpos = getPosASL (leader _grp);
    _t set ["pos", _tpos];
    _t set ["effForce", [_grp] call DUWS_fnc_opcom_effForceLive];
    private _phase = _t getOrDefault ["ferryPhase", "topickup"];
    private _kind = switch (_t get "moveType") do {
        case "boat": { "boat" };
        case "wheeled";
        case "tracked": { "ground" };
        default { "rotor" };
    };
    call ((DUWS_opcom_ferryHulls get _kind) getOrDefault [_phase, {}]);
};
