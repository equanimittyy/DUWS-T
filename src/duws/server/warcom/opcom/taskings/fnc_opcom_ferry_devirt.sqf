// Locality: server, [] call'd at load. The live ferry crossing -- a watched carry rendered as the timed six-phase
// machine plus its GetIn/GetOut board/dismount handlers. The orchestrator (fnc_opcom_ferry) drives it each tick;
// the virtual mirror is fnc_opcom_ferry_virt (docs/plans/opcom/opcom_plan.md §Transport).
if (!isServer) exitWith {};

// Clear both ferry handlers so a hull that ferries a second rider re-arms cleanly (a stale handler skips the re-arm).
DUWS_fnc_opcom_ferryClearEH = {
    params ["_veh"];
    private _b = _veh getVariable ["DUWS_ferryBoardEH", -1];
    if (_b >= 0) then { _veh removeEventHandler ["GetIn", _b]; _veh setVariable ["DUWS_ferryBoardEH", -1] };
    private _u = _veh getVariable ["DUWS_ferryUnloadEH", -1];
    if (_u >= 0) then { _veh removeEventHandler ["GetOut", _u]; _veh setVariable ["DUWS_ferryUnloadEH", -1] };
    _veh setVariable ["DUWS_ferryRiderGrp", grpNull];
    _veh setVariable ["DUWS_ferryUnloadGrp", grpNull];
    _veh setVariable ["DUWS_ferryUnloadQ", []];
};

// Feed the next held rider into a seat and order it out. One at a time (the GetOut handler re-calls this), so seat
// capacity never binds; the rest wait hidden + sim-off so none shows on the ground.
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
// pickupboard -> carry -> dropland -> dropunload). The two transit legs are untimed; each land/board/unload phase
// caps at OPCOM_FERRY_WAIT_MAX ticks and forces through on expiry. The lifts board and dismount on purpose
// different shapes -- do NOT unify them: a rotor lands and the squad walks aboard man by man (assigned and
// orderGetIn'd with the landing order, so the landing hold has boarders to wait on; the leader forced past
// engagement), while a boat parks off the shore and the whole group vanishes into it and later spawns ashore at
// once, because boats are finnicky and never walk men seat by seat. Strength freezes at the board commit and thaws
// when the riders spawn at the drop.
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
    private _dropLeg = {
        private _nav = _t get "target";
        if (_boat) then { _nav = ([_rider get "ferryLand", _nav] call DUWS_fnc_opcom_ferryBoatPark) select 1 };
        [_nav] call _legTo;
    };
    // Once per rider group: one streamed in mid-pickup is a new group. Board-despawn on GetIn frees each seat at
    // once, so one hull loads any squad; the group tag keeps the handler off the crew.
    private _orderRiders = {
        private _rg = groupFromNetId (_rider get "grp");
        if (isNull _rg || {(_veh getVariable ["DUWS_ferryRiderGrp", grpNull]) isEqualTo _rg}) exitWith {};
        [_veh] call DUWS_fnc_opcom_ferryClearEH;
        _veh setVariable ["DUWS_ferryRiderGrp", _rg];
        if (_boat) exitWith {
            private _shore = _t get "ferryShore";
            [_rg, "move", _shore] call DUWS_fnc_opcom_applyOrder;
            (_rg addWaypoint [_shore, 0]) setWaypointType "HOLD";
        };
        private _eh = _veh addEventHandler ["GetIn", {
            params ["_v", "", "_u"];
            if (group _u isEqualTo (_v getVariable ["DUWS_ferryRiderGrp", grpNull])) then { deleteVehicle _u };
        }];
        _veh setVariable ["DUWS_ferryBoardEH", _eh];
        while {count waypoints _rg > 0} do { deleteWaypoint ((waypoints _rg) select 0) };
        private _men = (units _rg) select {alive _x};
        { _x assignAsCargo _veh } forEach _men;
        _men orderGetIn true;
    };
    // Spawn the rider at the drop, detach it, thaw its strength -- egress losses now count.
    private _dropDeliver = {
        private _land = _rider getOrDefault ["ferryLand", _t get "target"];
        _rider set ["pos", _land]; _rider set ["route", []]; _rider set ["leg", 0];
        [_rider] call DUWS_fnc_opcom_deVirt;
        _rider set ["ridingOn", -1]; _rider set ["ferryFrozen", false];
    };
    private _embark = {
        private _rg = groupFromNetId (_rider get "grp");
        if (!isNull _rg) then { { deleteVehicle _x } forEach ((units _rg) select { alive _x }); deleteGroup _rg };
        _rider set ["grp", ""]; _rider set ["status", "virtual"];
        private _drop = [_rider] call DUWS_fnc_opcom_ferryDrop; _rider set ["ferryLand", _drop];
        _t set ["target", [_t, _drop] call DUWS_fnc_opcom_ferryApproach]; _t set ["route", []];
        _t set ["embarked", true];
        if (!_boat) then { [_veh] call DUWS_fnc_opcom_ferryClearEH; _veh land "NONE" };  // release the landing hold so it lifts off
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
                    private _p = [_rpos, 0, 80, 8, 0, 0.3, 0] call BIS_fnc_findSafePos; _p set [2, 0];
                    [_p] call _legTo;
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
                _veh land "GET IN";
                // All aboard before a tick caught the touchdown: the hold is spent and the hull lifts, so go.
                if ((_rider get "grp") isNotEqualTo "" && {((units groupFromNetId (_rider get "grp")) findIf {alive _x}) < 0}) exitWith { call _embark };
                if (((getPosATL _veh) select 2) < OPCOM_FERRY_GROUND_ALT) exitWith { ["pickupboard"] call _setPhase };
                if (_wait >= OPCOM_FERRY_WAIT_MAX) then { call _embark };
            };
        };
        case "pickupboard": {
            private _wait = (_t getOrDefault ["ferryWait", 0]) + 1; _t set ["ferryWait", _wait];
            call _orderRiders;
            private _rg = groupFromNetId (_rider get "grp");
            if (_boat) then {
                // Intentional divergence from the rotor (see the step comment): the boat never boards men in, the
                // whole group vanishes at once from the shore it walked to; freeze + despawn on arrival or expiry.
                private _here = !isNull _rg && {((leader _rg) distance2D (_t get "ferryShore")) < OPCOM_FERRY_BOARD_BOAT};
                if (isNull _rg || _here || {_wait >= OPCOM_FERRY_WAIT_MAX}) exitWith { _rider set ["ferryFrozen", true]; call _embark };
            } else {
                _veh land "GET IN";
                if (isNull _rg || {((units _rg) findIf {alive _x}) < 0} || {_wait >= OPCOM_FERRY_WAIT_MAX}) exitWith { call _embark };
                // Force the current lead aboard, one per tick, whatever its combat state -- a man in COMBAT refuses the
                // boarding order, so without this the engaged case never drains. moveInCargo ignores combat, range and
                // seat waits; the GetIn handler board-despawns him, promoting the next man.
                private _lead = leader _rg;
                if (alive _lead && {vehicle _lead isEqualTo _lead}) then { _lead moveInCargo _veh };
            };
        };
        case "carry": {
            _rider set ["pos", _tpos];
            if ((_t getOrDefault ["ferryLZ", []]) isEqualTo []) then { call _dropLeg };   // live spell resumed mid-carry
            if (([getPosASL _veh, _t get "ferryLZ"] call DUWS_fnc_opcom_cellDist) <= OPCOM_FERRY_LAND_K) then {
                if (!_boat) then { _veh land "GET OUT" };
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
                _veh land "GET OUT";
                if (((getPosATL _veh) select 2) < OPCOM_FERRY_GROUND_ALT) exitWith {
                    call _dropDeliver;
                    private _rg = groupFromNetId (_rider get "grp");
                    if (isNull _rg) exitWith { [_t] call DUWS_fnc_opcom_ferryRelease };
                    // Hold the group hidden and feed one man at a time into a seat a GetOut handler refills as each climbs
                    // out. `unloading` keeps task_step from stowing or re-tasking the now-detached rider mid-dismount.
                    { _x hideObjectGlobal true; _x enableSimulation false } forEach units _rg;
                    _veh setVariable ["DUWS_ferryUnloadGrp", _rg];
                    _veh setVariable ["DUWS_ferryUnloadQ", units _rg];
                    private _eh = _veh addEventHandler ["GetOut", {
                        params ["_v", "", "_u"];
                        if (group _u isEqualTo (_v getVariable ["DUWS_ferryUnloadGrp", grpNull])) then {
                            [_v] call DUWS_fnc_opcom_ferryUnloadNext;
                        };
                    }];
                    _veh setVariable ["DUWS_ferryUnloadEH", _eh];
                    _rider set ["unloading", true];
                    ["dropunload"] call _setPhase;
                    [_veh] call DUWS_fnc_opcom_ferryUnloadNext;
                };
                if (_wait >= OPCOM_FERRY_WAIT_MAX) exitWith { call _dropDeliver; [_t] call DUWS_fnc_opcom_ferryRelease };
            };
        };
        case "dropunload": {
            if (_boat) exitWith { call _dropDeliver; [_t] call DUWS_fnc_opcom_ferryRelease };
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
