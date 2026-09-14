// Locality: server, [] call'd at load. The live ferry crossing -- a watched carry rendered as the timed six-phase
// machine plus its GetIn/GetOut board/dismount handlers. The orchestrator (fnc_opcom_ferry) drives it each tick;
// the virtual mirror is fnc_opcom_ferry_virt (docs/plans/opcom/opcom_plan.md §Transport).
if (!isServer) exitWith {};

// Clear both ferry handlers (load GetIn, unload GetOut) so a hull that later ferries a second rider re-arms
// cleanly -- a stale handler would make the re-arm skip on the "already armed" check.
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

// Feed the next held rider into a cargo seat and order it out. Only one rider is ever in the hold (the GetOut
// handler calls this as each climbs out), so seat capacity never binds; held riders wait hidden + sim-off so
// they never show on the ground.
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

// Render a live transport's crossing for one tick as a timed phase machine shared by both lift types (topickup ->
// pickupland -> pickupboard -> carry -> dropland -> dropunload): the two transit legs are untimed, each
// land/board/unload phase is capped at OPCOM_FERRY_WAIT_MAX ticks (reset on entry) and forces through on expiry.
// A rotary lands ("GET IN"/"GET OUT") and boards/dismounts man by man; a boat cannot land, so it navigates to
// within OPCOM_FERRY_BOARD_BOAT of the shore and board-despawns / de-virtualises the whole group at once. Strength
// freezes at the board commit and thaws when the riders spawn at the drop.
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
    private _setPhase = { params ["_p"]; _t set ["ferryPhase", _p]; _t set ["ferryWait", 0] };
    // Spawn the rider at the drop, detach it from the hull, and thaw its strength -- egress losses now count.
    private _dropDeliver = {
        private _land = _rider getOrDefault ["ferryLand", _t get "target"];
        _rider set ["pos", _land]; _rider set ["route", []]; _rider set ["leg", 0];
        [_rider] call DUWS_fnc_opcom_deVirt;
        _rider set ["ridingOn", -1]; _rider set ["ferryFrozen", false];
    };
    // All riders aboard (or force-cleared): stow the rider virtual, retarget the drop, and start the carry.
    private _embark = {
        private _rg = groupFromNetId (_rider get "grp");
        if (!isNull _rg) then { { deleteVehicle _x } forEach ((units _rg) select { alive _x }); deleteGroup _rg };
        _rider set ["grp", ""]; _rider set ["status", "virtual"];
        private _drop = [_rider] call DUWS_fnc_opcom_ferryDrop; _rider set ["ferryLand", _drop];
        _t set ["target", [_t, _drop] call DUWS_fnc_opcom_ferryApproach]; _t set ["route", []];
        _t set ["embarked", true];
        if (!_boat) then { [_veh] call DUWS_fnc_opcom_ferryClearEH; _veh land "NONE" };  // release the landing hold so it lifts off
        ["carry"] call _setPhase;
    };

    switch (_phase) do {
        // Transit to the pickup (untimed): a rotary flies to a safe LZ by the rider, a boat runs to the nearest
        // navigable water off its shore; both trigger the next phase within k cells (a boat issues no land order).
        case "topickup": {
            private _lz = _t getOrDefault ["ferryLZ", []];
            if (_lz isEqualTo []) then {
                _lz = if (_boat) then { [_t, _rider get "pos"] call DUWS_fnc_opcom_ferryApproach }
                    else { private _p = [_rider get "pos", 0, 80, 8, 0, 0.3, 0] call BIS_fnc_findSafePos; _p set [2, 0]; _p };
                _t set ["ferryLZ", _lz];
            };
            if (count waypoints _grp == 0) then { [_grp, "move", _lz] call DUWS_fnc_opcom_applyOrder };
            if (([_veh, _lz] call DUWS_fnc_opcom_cellDist) <= OPCOM_FERRY_LAND_K) then {
                if (!_boat) then { _veh land "GET IN" };
                ["pickupland"] call _setPhase;
            };
        };
        // Arrive at the pickup (timed): a rotary descends to the ground, a boat closes to within a boat-length of
        // its shore point; either way expiry board-despawns the riders and skips to the carry.
        case "pickupland": {
            private _wait = (_t getOrDefault ["ferryWait", 0]) + 1; _t set ["ferryWait", _wait];
            if (_boat) then {
                private _lz = _t getOrDefault ["ferryLZ", []];
                if (count waypoints _grp == 0) then { [_grp, "move", _lz] call DUWS_fnc_opcom_applyOrder };
                if ((_veh distance2D _lz) < OPCOM_FERRY_BOARD_BOAT) exitWith { ["pickupboard"] call _setPhase };
                if (_wait >= OPCOM_FERRY_WAIT_MAX) then { _rider set ["ferryFrozen", true]; call _embark };
            } else {
                _veh land "GET IN";
                if (((getPosATL _veh) select 2) < OPCOM_FERRY_GROUND_ALT) exitWith {
                    _rider set ["ferryFrozen", true];       // board commit
                    ["pickupboard"] call _setPhase;
                };
                if (_wait >= OPCOM_FERRY_WAIT_MAX) then { _rider set ["ferryFrozen", true]; call _embark };
            };
        };
        // Board (timed): a boat waits for the shore party to close, then board-despawns the whole group at once; a
        // rotary forces the current lead into a seat one per tick. Group empty/aboard or expiry -> carry.
        case "pickupboard": {
            private _wait = (_t getOrDefault ["ferryWait", 0]) + 1; _t set ["ferryWait", _wait];
            private _rg = groupFromNetId (_rider get "grp");
            if (_boat) then {
                // Walk the shore party to the hull so the vanish reads as a board, then freeze + despawn the whole
                // group once its lead is within a boat-length (the board commit) or the wait expires.
                if (!isNull _rg && {count waypoints _rg == 0}) then { [_rg, "move", getPosASL _veh] call DUWS_fnc_opcom_applyOrder };
                private _here = !isNull _rg && {((leader _rg) distance2D _veh) < OPCOM_FERRY_BOARD_BOAT};
                if (isNull _rg || _here || {_wait >= OPCOM_FERRY_WAIT_MAX}) exitWith { _rider set ["ferryFrozen", true]; call _embark };
            } else {
                _veh land "GET IN";
                // Arm a one-shot GetIn handler that board-despawns each rider as he enters (a seat frees instantly, so
                // one hull loads any squad; the rider-group tag keeps it off the crew), and drop the shore HOLD.
                if (!isNull _rg && {(_veh getVariable ["DUWS_ferryBoardEH", -1]) < 0}) then {
                    _veh setVariable ["DUWS_ferryRiderGrp", _rg];
                    private _eh = _veh addEventHandler ["GetIn", {
                        params ["_v", "", "_u"];
                        if (group _u isEqualTo (_v getVariable ["DUWS_ferryRiderGrp", grpNull])) then { deleteVehicle _u };
                    }];
                    _veh setVariable ["DUWS_ferryBoardEH", _eh];
                    while {count waypoints _rg > 0} do { deleteWaypoint ((waypoints _rg) select 0) };
                };
                if (isNull _rg || {((units _rg) findIf {alive _x}) < 0} || {_wait >= OPCOM_FERRY_WAIT_MAX}) exitWith { call _embark };
                // Force the current lead aboard, one per tick, whatever its combat state -- the rest keep fighting.
                // moveInCargo ignores combat, range and seat waits; the GetIn handler board-despawns him, promoting the
                // next man. An ordered board would instead stall under fire (combat AI refuses it) and pull the squad off the fight.
                private _lead = leader _rg;
                if (alive _lead && {vehicle _lead isEqualTo _lead}) then { _lead moveInCargo _veh };
            };
        };
        // Transit to the drop (untimed): the rider rides bound + virtual; trigger the next phase within k cells (a
        // rotary issues the land order, a boat just closes on its shore point).
        case "carry": {
            _rider set ["pos", _tpos];
            private _nav = _t get "target";
            if (count waypoints _grp == 0) then { [_grp, "move", _nav] call DUWS_fnc_opcom_applyOrder };
            if (([_veh, _nav] call DUWS_fnc_opcom_cellDist) <= OPCOM_FERRY_LAND_K) then {
                if (!_boat) then { _veh land "GET OUT" };
                ["dropland"] call _setPhase;
            };
        };
        // Arrive at the drop (timed): a boat closes on its shore point and hands to the disembark; a rotary descends,
        // then spawns + arms the man-by-man dismount. Expiry drops the group at the destination regardless.
        case "dropland": {
            _rider set ["pos", _tpos];
            private _wait = (_t getOrDefault ["ferryWait", 0]) + 1; _t set ["ferryWait", _wait];
            if (_boat) then {
                private _nav = _t get "target";
                if (count waypoints _grp == 0) then { [_grp, "move", _nav] call DUWS_fnc_opcom_applyOrder };
                if (((_veh distance2D _nav) < OPCOM_FERRY_BOARD_BOAT) || {_wait >= OPCOM_FERRY_WAIT_MAX}) then { ["dropunload"] call _setPhase };
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
        // Disembark (timed): a boat de-virtualises the whole group ashore and releases in one tick; a rotary drains
        // the GetOut chain, ejecting any stragglers at the cap, then releases (freeing the hull, clearing unloading).
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
