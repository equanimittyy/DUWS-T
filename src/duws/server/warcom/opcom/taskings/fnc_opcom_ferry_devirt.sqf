// Locality: server, [] call'd at load. The live ferry crossing -- a watched carry rendered as the timed six-phase
// machine plus its GetIn/GetOut board/dismount handlers. The orchestrator (fnc_opcom_ferry) drives it each tick;
// the virtual mirror is fnc_opcom_ferry_virt (docs/plans/opcom/opcom_plan.md §Transport).
if (!isServer) exitWith {};

// Clear a hull's ferry state so one that ferries a second rider re-arms cleanly (a stale handler skips the re-arm)
// and no helipad outlives its landing.
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
    deleteVehicle (_veh getVariable ["DUWS_ferryPad", objNull]);
    _veh setVariable ["DUWS_ferryPad", objNull];
};

// Feed the next held rider into a seat and order it out; the rotor drop's paced loop calls this every two seconds. A man
// who finds no free seat just shows beside the hull, at the helipad he spawned on.
DUWS_fnc_opcom_ferryUnloadNext = {
    params ["_veh"];
    private _q = (_veh getVariable ["DUWS_ferryUnloadQ", []]) select { !isNull _x && {alive _x} };
    _veh setVariable ["DUWS_ferryUnloadQ", _q];
    if (_q isEqualTo []) exitWith {};
    private _u = _q deleteAt 0;
    _veh setVariable ["DUWS_ferryUnloadQ", _q];
    _u enableSimulation true;
    _u hideObjectGlobal false;
    _u moveInCargo _veh;
    unassignVehicle _u;
    _u action ["GetOut", _veh];
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

// One tick of the live crossing, a timed phase machine shared by both lift types (topickup -> pickupland ->
// pickupboard -> carry -> dropland -> dropunload; a rotor boards inside pickupland and skips pickupboard). The two
// transit legs are untimed; each land/board/unload phase caps at OPCOM_FERRY_WAIT_MAX ticks and forces through on
// expiry. The lifts board and dismount on purpose different shapes -- do NOT unify them: a rotor lands on a helipad
// at both ends, the squad walking aboard (the fnc_rescue_squad_success shape: all assigned and orderGetIn'd with the
// land call, so the landing hold has boarders to wait on) and out a man every two seconds, while a boat parks off the shore
// and the whole group vanishes into it and later spawns ashore at once, because boats are finnicky and never walk men
// seat by seat. Strength freezes at the board commit and thaws when the rider is back on the ground.
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
        _veh setVariable ["DUWS_ferryPad", createVehicle ["Land_HelipadEmpty_F", _p, [], 0, "NONE"]];
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
        while {count waypoints _rg > 0} do { deleteWaypoint ((waypoints _rg) select 0) };
        private _men = (units _rg) select {alive _x};
        { _x assignAsCargo _veh } forEach _men;
        _men orderGetIn true;
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
                    _veh land "GET IN";
                    _rider set ["ferryFrozen", true];       // board commit
                    call _orderRiders;
                };
                ["pickupland"] call _setPhase;
            };
        };
        case "pickupland": {
            private _wait = (_t getOrDefault ["ferryWait", 0]) + 1; _t set ["ferryWait", _wait];
            call _orderRiders;
            if (_boat) then {
                if ((_veh distance2D (_t get "ferryLZ")) < OPCOM_FERRY_BOARD_BOAT) exitWith { ["pickupboard"] call _setPhase };
                if (_wait >= OPCOM_FERRY_WAIT_MAX) then { _rider set ["ferryFrozen", true]; call _embark };
            } else {
                [_wait >= (OPCOM_FERRY_WAIT_MAX / 2)] call _boardPush;
                // Boarders despawn on entry, so an empty group is a finished board. A virtual rider has no one to walk
                // in and boards on touchdown; at the cap the men still ashore despawn with the embark.
                if ((({alive _x} count units groupFromNetId (_rider get "grp")) == 0)
                    && {(_rider get "grp") isNotEqualTo "" || {((getPosATL _veh) select 2) < OPCOM_FERRY_GROUND_ALT}}) exitWith { call _embark };
                if (_wait >= OPCOM_FERRY_WAIT_MAX) then { call _embark };
            };
        };
        case "pickupboard": {
            // Boat only, the intentional divergence from the rotor (see the step comment): the boat never boards men
            // in, the whole group vanishes at once from the shore it walked to; freeze + despawn on arrival or expiry.
            private _wait = (_t getOrDefault ["ferryWait", 0]) + 1; _t set ["ferryWait", _wait];
            call _orderRiders;
            private _rg = groupFromNetId (_rider get "grp");
            private _here = !isNull _rg && {((leader _rg) distance2D (_t get "ferryShore")) < OPCOM_FERRY_BOARD_BOAT};
            if (isNull _rg || _here || {_wait >= OPCOM_FERRY_WAIT_MAX}) exitWith { _rider set ["ferryFrozen", true]; call _embark };
        };
        case "carry": {
            _rider set ["pos", _tpos];
            if ((_t getOrDefault ["ferryLZ", []]) isEqualTo []) then { call _dropLeg };   // live spell resumed mid-carry
            if (([getPosASL _veh, _t get "ferryLZ"] call DUWS_fnc_opcom_cellDist) <= OPCOM_FERRY_LAND_K) then {
                // LAND sets down and holds until cancelled; GET OUT only hovers low for someone to get out.
                if (!_boat) then { _veh land "LAND" };
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
                    [10000] call _dropSpawn;
                    private _rg = groupFromNetId (_rider get "grp");
                    if (isNull _rg) exitWith { [_t] call DUWS_fnc_opcom_ferryRelease };
                    // Leader first so the rest follow him off. `unloading` keeps task_step from stowing or re-tasking
                    // the rider mid-dismount; the first man out thaws and unbinds it.
                    { _x hideObjectGlobal true; _x enableSimulation false } forEach units _rg;
                    _veh setVariable ["DUWS_ferryUnloadGrp", _rg];
                    _veh setVariable ["DUWS_ferryUnloadRider", _rider get "id"];
                    _veh setVariable ["DUWS_ferryUnloadQ", [leader _rg] + ((units _rg) - [leader _rg])];
                    _veh setVariable ["DUWS_ferryUnloadEH", _veh addEventHandler ["GetOut", {
                        params ["_v", "", "_u"];
                        if (group _u isNotEqualTo (_v getVariable ["DUWS_ferryUnloadGrp", grpNull])) exitWith {};
                        private _r = [_v getVariable ["DUWS_ferryUnloadRider", -1]] call DUWS_fnc_opcom_byId;
                        if (!isNil "_r" && {(_r getOrDefault ["ridingOn", -1]) >= 0}) then { [_r] call DUWS_fnc_opcom_ferryUnbind };
                    }]];
                    _rider set ["unloading", true];
                    ["dropunload"] call _setPhase;
                    [_veh] spawn {
                        params ["_veh"];
                        while {alive _veh && {(_veh getVariable ["DUWS_ferryUnloadQ", []]) isNotEqualTo []}} do {
                            [_veh] call DUWS_fnc_opcom_ferryUnloadNext;
                            sleep 2;
                        };
                    };
                };
                if (_wait >= OPCOM_FERRY_WAIT_MAX) exitWith { [] call _dropSpawn; [_t] call DUWS_fnc_opcom_ferryRelease };
            };
        };
        case "dropunload": {
            if (_boat) exitWith { [] call _dropSpawn; [_t] call DUWS_fnc_opcom_ferryRelease };
            private _wait = (_t getOrDefault ["ferryWait", 0]) + 1; _t set ["ferryWait", _wait];
            private _rg = groupFromNetId (_rider get "grp");
            private _q = (_veh getVariable ["DUWS_ferryUnloadQ", []]) select { !isNull _x && {alive _x} };
            private _seated = if (isNull _rg) then { [] } else { (units _rg) select { alive _x && {vehicle _x isEqualTo _veh} } };
            if ((isNull _rg) || {(_q + _seated) isEqualTo []} || {_wait >= OPCOM_FERRY_WAIT_MAX}) then {
                if (_wait >= OPCOM_FERRY_WAIT_MAX) then {
                    { _x enableSimulation true; _x hideObjectGlobal false; unassignVehicle _x; _x action ["GetOut", _veh] } forEach (_q + _seated);
                };
                [_t] call DUWS_fnc_opcom_ferryRelease;
            };
        };
    };
};
