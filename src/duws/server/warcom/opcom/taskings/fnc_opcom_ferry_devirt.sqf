// Locality: server, [] call'd at load. The live ferry crossing -- a watched carry rendered as the timed six-phase
// machine plus its GetIn/GetOut board/dismount handlers. The orchestrator (fnc_opcom_ferry) drives it each tick;
// the virtual mirror is fnc_opcom_ferry_virt (docs/plans/opcom/opcom_plan.md §Transport).
if (!isServer) exitWith {};

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
        // Assigned, not merely seated: "GET OUT" works off the assignment list, and a cabin filled by moveInCargo
        // alone reads as empty, so the hold ends the moment the skids touch.
        _u assignAsCargo _veh;
        _u moveInCargo _veh;
    };
    _veh setVariable ["DUWS_ferryUnloadQ", _q];
};

// Refill before turning anyone out: land "GET OUT" holds only while the hull has cargo to put down, so a cabin that
// empties between two men ends the hold and flies the rest away.
DUWS_fnc_opcom_ferryUnloadNext = {
    params ["_veh"];
    [_veh] call DUWS_fnc_opcom_ferrySeatFill;
    private _grp = _veh getVariable ["DUWS_ferryUnloadGrp", grpNull];
    if (isNull _grp) exitWith {};
    private _aboard = (units _grp) select { alive _x && {vehicle _x isEqualTo _veh} };
    if (_aboard isEqualTo []) exitWith {};
    private _u = _aboard select 0;
    // moveOut, the way fnc_helotaxi turns its passengers out and keeps its hull down: an ordered dismount left the
    // ferry's men aboard as the hull lifted. Unassign after he is out, so the men behind him keep the hold alive.
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

// A boat's live [shore, park]: the water-cell centre can sit ~350 m out, past any board range. The park is capped
// at that centre, which is water by construction (grid_init samples each cell centre), though not always deep.
DUWS_fnc_opcom_ferryBoatPark = {
    params ["_landPt", "_waterPt"];
    private _dir = _landPt getDir _waterPt;
    private _len = _landPt distance2D _waterPt;
    private _shore = 0;
    for "_d" from 0 to _len step 10 do {
        if !(surfaceIsWater (_landPt getPos [_d, _dir])) then { _shore = _d };
    };
    [_landPt getPos [_shore, _dir], _landPt getPos [(_shore + OPCOM_FERRY_BOAT_PARK) min _len, _dir]]
};

// One tick of the live crossing: a timed phase machine for both lift types (topickup -> pickupland -> pickupboard
// -> carry -> dropland -> dropunload). Transit legs are untimed; each land/board/unload phase caps at
// OPCOM_FERRY_WAIT_MAX ticks and forces through on expiry, so a rotor's descent and its walk-aboard hold a budget
// each. Do NOT unify the lifts' board/dismount shapes: a rotor lands on a helipad at both ends, walking the squad
// aboard with the skids down and out a man every two seconds; a boat parks off the shore and swaps the whole group
// at once, because boats are finnicky. Strength freezes at the board commit, thaws when the rider is on the ground.
DUWS_fnc_opcom_ferryStepLive = {
    params ["_t", "_rider"];
    private _grp = groupFromNetId (_t get "grp");
    if (isNull _grp) exitWith {};                       // spawn lost; ferryTick re-streams it next tick
    private _veh = vehicle (leader _grp);
    private _tpos = getPosASL (leader _grp);
    _t set ["pos", _tpos];
    _t set ["effForce", [_grp] call DUWS_fnc_opcom_effForceLive];
    private _boat = (_t get "moveType") isEqualTo "boat";

    private _phase = _t getOrDefault ["ferryPhase", "topickup"];
    private _setPhase = {
        params ["_p"];
        private _wait = _t getOrDefault ["ferryWait", 0];
        [["INFO", "WARN"] select (_wait >= OPCOM_FERRY_WAIT_MAX), "OPCOM", format ["ferry: transport %1 (%2) rider %3 %4 -> %5, wait %6/%7",
            _t get "id", _t get "moveType", _rider get "id", _phase, _p, _wait, OPCOM_FERRY_WAIT_MAX]] call fnc_log;
        _t set ["ferryPhase", _p]; _t set ["ferryWait", 0];
    };
    // A leg's move goes out once, as the leg starts: finished waypoints stay in `waypoints`, so no count gate re-fires.
    private _legTo = { params ["_pt"]; _t set ["ferryLZ", _pt]; [_grp, "move", _pt] call DUWS_fnc_opcom_applyOrder };
    // fnc_rescue_squad_success's put-down: the helipad makes `land` settle on the spot rather than hover over a pick of
    // its own, a pinned pilot neither flees nor breaks off to engage, and Vcm_Disable keeps VCOM, when loaded, off the
    // scripted waypoints. The pin follows the move, whose applyOrder resets behaviour.
    private _rotorLeg = {
        params ["_near"];
        private _p = [_near, 0, 80, 8, 0, 0.3, 0] call BIS_fnc_findSafePos; _p set [2, 0];
        [_t] call DUWS_fnc_opcom_ferryClearPad;
        _t set ["ferryPad", netId (createVehicle ["Land_HelipadEmpty_F", _p, [], 0, "NONE"])];
        [_p] call _legTo;
        _grp setBehaviour "CARELESS"; _grp setCombatMode "BLUE";
        { _x setVariable ["Vcm_Disable", true] } forEach units _grp;
        private _pilot = currentPilot _veh;
        _pilot allowFleeing 0; _pilot disableAI "Target";
    };
    private _dropLeg = {
        if (_boat) exitWith { [([_rider get "ferryLand", _t get "target"] call DUWS_fnc_opcom_ferryBoatPark) select 1] call _legTo };
        [_t get "target"] call _rotorLeg;
    };
    // Once per rider group: one streamed in mid-pickup is a new group. The GetIn handler reads the group tag live, so
    // one handler serves any rider group and stays off the crew; board-despawn frees each seat at once, so one hull
    // loads any squad.
    private _orderRiders = {
        private _rg = groupFromNetId (_rider get "grp");
        if (isNull _rg || {(_veh getVariable ["DUWS_ferryRiderGrp", grpNull]) isEqualTo _rg}) exitWith {};
        _veh setVariable ["DUWS_ferryRiderGrp", _rg];
        if (_boat) exitWith {
            private _shore = _t get "ferryShore";
            [_rg, "move", _shore] call DUWS_fnc_opcom_applyOrder;
            (_rg addWaypoint [_shore, 0]) setWaypointType "HOLD";
        };
        if ((_veh getVariable ["DUWS_ferryBoardEH", -1]) < 0) then {
            _veh setVariable ["DUWS_ferryBoardEH", _veh addEventHandler ["GetIn", {
                params ["_v", "", "_u"];
                if (group _u isEqualTo (_v getVariable ["DUWS_ferryRiderGrp", grpNull])) then { deleteVehicle _u };
            }]];
        };
        // Off the LZ, not onto it: the hull sets down where these men stand. Assignment is what the "GET IN" hold
        // waits on and it moves nobody, so the walk-aboard order waits for the skids, in pickupboard.
        private _lz = _t get "ferryLZ";
        [_rg, "move", _lz getPos [OPCOM_FERRY_STAGE, _lz getDir (leader _rg)]] call DUWS_fnc_opcom_applyOrder;
        { _x assignAsCargo _veh } forEach ((units _rg) select {alive _x});
    };
    // Seats bind once, against what was free then: a man the full cabin left over is never re-paired to a
    // seat his despawning mates freed, so the last one in -- the leader -- idles to expiry. _settle takes him.
    private _boardPush = {
        params ["_settle"];
        private _rg = groupFromNetId (_rider get "grp");
        if (isNull _rg) exitWith {};
        private _out = (units _rg) select { alive _x && {vehicle _x isEqualTo _x} };
        if (_out isEqualTo []) exitWith {};
        if (_settle) exitWith { { _x moveInCargo _veh } forEach _out };
        { _x assignAsCargo _veh } forEach _out;
        _out orderGetIn true;
    };
    // Spawns the rider still bound; ferryRelease, or a rotor's first man out, unbinds it. _alt spawns it clear
    // of the map: hideObjectGlobal lands a frame or two late, so a group raised on the pad flashes there.
    private _dropSpawn = {
        params [["_alt", 0]];
        private _p = if (_boat) then { _rider getOrDefault ["ferryLand", _t get "target"] } else { _t get "ferryLZ" };
        if (_alt > 0) then { _p = [_p select 0, _p select 1, _alt] };
        _rider set ["pos", _p];
        _rider set ["route", []]; _rider set ["leg", 0];
        [_rider] call DUWS_fnc_opcom_deVirt;
    };
    // Seat the men before calling the landing: "GET OUT" keeps the engine turning where "LAND" shuts it down, but
    // with an empty cabin its hold ends at once, so they board first and ride the descent in their seats.
    private _dropBoard = {
        [10000] call _dropSpawn;
        private _rg = groupFromNetId (_rider get "grp");
        if (isNull _rg) exitWith { [_t] call DUWS_fnc_opcom_ferryRelease };
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
        _veh land "GET OUT";
    };
    // Put whoever is left on the ground at the LZ: the held men wait 10 km above it, so showing them where they
    // stand drops them to their deaths.
    private _dropGround = {
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
    private _embark = {
        private _rg = groupFromNetId (_rider get "grp");
        if (!isNull _rg) then { { deleteVehicle _x } forEach ((units _rg) select { alive _x }); deleteGroup _rg };
        _rider set ["grp", ""]; _rider set ["status", "virtual"];
        private _drop = [_rider] call DUWS_fnc_opcom_ferryDrop; _rider set ["ferryLand", _drop];
        _t set ["target", [_t, _drop] call DUWS_fnc_opcom_ferryApproach]; _t set ["route", []];
        _t set ["embarked", true];
        if (!_boat) then { [_veh] call DUWS_fnc_opcom_ferryClearHull; _veh land "NONE" };  // release the landing hold so it lifts off
        call _dropLeg;
        ["carry"] call _setPhase;
    };

    switch (_phase) do {
        case "topickup": {
            if ((_t getOrDefault ["ferryLZ", []]) isEqualTo []) then {
                private _rpos = _rider get "pos";
                if (_boat) then {
                    ([_rpos, [_rpos] call DUWS_fnc_opcom_nearestWater] call DUWS_fnc_opcom_ferryBoatPark) params ["_shore", "_park"];
                    _t set ["ferryShore", _shore];
                    [_park] call _legTo;
                } else {
                    [_rpos] call _rotorLeg;
                };
            };
            if (_boat) then { call _orderRiders };
            if (([getPosASL _veh, _t get "ferryLZ"] call DUWS_fnc_opcom_cellDist) <= OPCOM_FERRY_LAND_K) then {
                if (!_boat) then {
                    // Seat them before the call: "GET IN" keeps the engine turning where "LAND" shuts it down, but
                    // with nobody assigned its hold completes at once and the hull lifts straight off again.
                    call _orderRiders;
                    _veh land "GET IN";
                    _rider set ["ferryFrozen", true];       // board commit
                };
                ["pickupland"] call _setPhase;
            };
        };
        // The gate above is one grid cell wide and reads no altitude, so a rotor's men are ordered in from
        // pickupboard: ordered here they walk out to a hull still hundreds of metres up, on the board's clock.
        case "pickupland": {
            private _wait = (_t getOrDefault ["ferryWait", 0]) + 1; _t set ["ferryWait", _wait];
            if (_boat) then {
                call _orderRiders;
                if ((_veh distance2D (_t get "ferryLZ")) < OPCOM_FERRY_BOARD_BOAT) exitWith { ["pickupboard"] call _setPhase };
                if (_wait >= OPCOM_FERRY_WAIT_MAX) then { _rider set ["ferryFrozen", true]; call _embark };
            } else {
                call _orderRiders;   // a group re-streamed mid-descent is a new one, and its seats died with the old
                if (((getPosATL _veh) select 2) < OPCOM_FERRY_GROUND_ALT) exitWith {
                    // A virtual rider has no one to walk in and boards on touchdown.
                    if ((_rider get "grp") isEqualTo "") then { call _embark } else { ["pickupboard"] call _setPhase };
                };
                if (_wait >= OPCOM_FERRY_WAIT_MAX) then { call _embark };
            };
        };
        case "pickupboard": {
            private _wait = (_t getOrDefault ["ferryWait", 0]) + 1; _t set ["ferryWait", _wait];
            call _orderRiders;
            if (_boat) exitWith {
                private _rg = groupFromNetId (_rider get "grp");
                private _here = !isNull _rg && {((leader _rg) distance2D (_t get "ferryShore")) < OPCOM_FERRY_BOARD_BOAT};
                if (isNull _rg || _here || {_wait >= OPCOM_FERRY_WAIT_MAX}) then { _rider set ["ferryFrozen", true]; call _embark };
            };
            [_wait >= (OPCOM_FERRY_WAIT_MAX / 2)] call _boardPush;
            // Boarders despawn on entry, so an empty group is a finished board.
            if (({alive _x} count units groupFromNetId (_rider get "grp")) == 0) exitWith { call _embark };
            if (_wait >= OPCOM_FERRY_WAIT_MAX) then { call _embark };
        };
        case "carry": {
            _rider set ["pos", _tpos];
            if ((_t getOrDefault ["ferryLZ", []]) isEqualTo []) then { call _dropLeg };   // live spell resumed mid-carry
            if (([getPosASL _veh, _t get "ferryLZ"] call DUWS_fnc_opcom_cellDist) <= OPCOM_FERRY_LAND_K) then {
                if (!_boat) then { call _dropBoard };
                ["dropland"] call _setPhase;
            };
        };
        case "dropland": {
            _rider set ["pos", _tpos];
            private _wait = (_t getOrDefault ["ferryWait", 0]) + 1; _t set ["ferryWait", _wait];
            if (_boat) then {
                // Same intentional divergence as the board: the boat spawns the whole group ashore at once.
                if (((_veh distance2D (_t get "ferryLZ")) < OPCOM_FERRY_BOARD_BOAT) || {_wait >= OPCOM_FERRY_WAIT_MAX}) then { ["dropunload"] call _setPhase };
            } else {
                if (((getPosATL _veh) select 2) < OPCOM_FERRY_GROUND_ALT) exitWith {
                    ["dropunload"] call _setPhase;
                    [_veh] spawn {
                        params ["_veh"];
                        while {alive _veh && {[_veh] call DUWS_fnc_opcom_ferryUnloadPending}} do {
                            [_veh] call DUWS_fnc_opcom_ferryUnloadNext;
                            sleep 2;
                        };
                    };
                };
                if (_wait >= OPCOM_FERRY_WAIT_MAX) exitWith { call _dropGround; [_t] call DUWS_fnc_opcom_ferryRelease };
            };
        };
        case "dropunload": {
            if (_boat) exitWith { [] call _dropSpawn; [_t] call DUWS_fnc_opcom_ferryRelease };
            private _wait = (_t getOrDefault ["ferryWait", 0]) + 1; _t set ["ferryWait", _wait];
            private _rg = groupFromNetId (_rider get "grp");
            if ((isNull _rg) || {!([_veh] call DUWS_fnc_opcom_ferryUnloadPending)} || {_wait >= OPCOM_FERRY_WAIT_MAX}) then {
                if (_wait >= OPCOM_FERRY_WAIT_MAX) then { call _dropGround };
                [_t] call DUWS_fnc_opcom_ferryRelease;
            };
        };
    };
};
