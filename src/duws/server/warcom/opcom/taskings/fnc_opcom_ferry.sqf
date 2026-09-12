// Locality: server, [] call'd at load. Movement + ferry helpers. `advance` is the shared per-tick mover, for a
// plain march and for the ferry carry. A land type cannot foot over water: its route may cross a navigable body
// (fnc_opcom_route lifts it at a penalty), and `advance` stops at the near shore so the tasking phase can borrow
// a transport there. The transport ferries the rider to the far shore, drops it, and reverts to a free staged
// guard back in the borrow pool. The rider owns its whole route; the carrier is fetched by the route, never
// commanded (docs/plans/opcom/opcom_plan.md §Transport). A bound rider takes no turn of its own -- task_step skips it.
if (!isServer) exitWith {};

// A world point sits in a navigable-water cell -- a ferry leg for a land type.
DUWS_fnc_opcom_isWaterPt = {
    params ["_pt"];
    (DUWS_opcom_grid_water select ([_pt] call DUWS_fnc_opcom_w2c)) >= 0
};

// The far shore a stopped rider faces: the first land past the next water span at or after its leg, scanning
// past any leading land so it holds whether `leg` sits on the water (a virtual rider) or on land (a live rider,
// leg not stepped). Falls back to the rider's target if the chain runs to water (an offshore target).
DUWS_fnc_opcom_ferryDrop = {
    params ["_rider"];
    private _route = _rider get "route";
    private _far = -1;
    private _seenWater = false;
    for "_i" from (_rider get "leg") to (count _route - 1) do {
        if ([_route select _i] call DUWS_fnc_opcom_isWaterPt) then {
            _seenWater = true;
        } else {
            if (_seenWater) exitWith { _far = _i };
        };
    };
    if (_far >= 0) then { _route select _far } else { _rider get "target" }
};

// A zone garrison is locked while BLUFOR stands on it -- its transports cannot be borrowed. The same presence
// test the reserve wave raises a defence by (fnc_garrisonReservePass), so lock and defence agree.
DUWS_fnc_opcom_zoneContested = {
    params ["_key"];
    if (_key isEqualTo "") exitWith { false };
    private _site = [_key] call fnc_site_at;
    private _pos = _site getOrDefault ["pos", []];
    if (_pos isEqualTo []) exitWith { false };
    [_pos, (_site getOrDefault ["radius", 0]) + DUWS_streamArrivalMargin, 1] call fnc_duws_bluforNear
};

// Shared by the borrow and the debug inspector so the two can never drift. _excludeId drops one id (a rider
// never borrows itself); -1 drops none. Idle-only by order, not by streaming: a hull on a directed order is a
// role unit off the pool, but a *live* idle hull is lendable too -- it flies off to ferry and lands or
// re-virtualises elsewhere, which is fine. Excluded only if fighting (opcom_plan.md §Transport).
DUWS_fnc_opcom_ferryPool = {
    params [["_excludeId", -1]];
    DUWS_opcom_taskings select {
        ("transport" in (_x get "flags"))
        && {(_x getOrDefault ["carrying", -1]) < 0}
        && {(_x get "id") != _excludeId}
        && {(_x get "moveType") in ["boat", "rotary"]}
        && {(_x get "order") in ["guard", "garrison"]}
        && {(_x getOrDefault ["status", ""]) isNotEqualTo "engaged"}
        && {!(((_x get "order") isEqualTo "garrison") && {[_x get "homeZone"] call DUWS_fnc_opcom_zoneContested})}
    }
};

// Borrow the nearest free compatible transport for a rider stopped at a water leg; returns the bound transport,
// or nil if none is free (the rider holds at the shore and retries next tick). Boats are preferred, a rotary is
// the fallback lift. A garrisoned pick is flipped off `garrison` to `move` so its ferry turn runs; no reserve
// draw-out -- a ferry-capable transport is a non-combatant, never enrolled in the reserve wave.
DUWS_fnc_opcom_borrowFerry = {
    params ["_rider"];
    private _rpos = _rider get "pos";
    private _pool = [_rider get "id"] call DUWS_fnc_opcom_ferryPool;
    if (_pool isEqualTo []) exitWith { nil };
    private _boats = _pool select { (_x get "moveType") isEqualTo "boat" };
    private _cands = [_boats, _pool] select (_boats isEqualTo []);   // boats first; rotary only when no boat is free
    private _best = 1e12; private _pick = -1;
    { private _dd = (_x get "pos") distance2D _rpos; if (_dd < _best) then { _best = _dd; _pick = _forEachIndex } } forEach _cands;
    private _tr = _cands select _pick;
    _tr set ["order", "move"]; _tr set ["carrying", _rider get "id"]; _tr set ["embarked", false]; _tr set ["route", []];
    _rider set ["ridingOn", _tr get "id"];
    ["INFO", "OPCOM", format ["ferry: tasking %1 borrows transport %2 for a water leg", _rider get "id", _tr get "id"]] call fnc_log;
    _tr
};

// Step a tasking one tick along its route. Returns "arrived" (route end reached), "water" (a land type stopped
// at the near shore of a ferry leg), or "moving". Replans from the current position when the chain is empty (a
// fresh order, or a re-virtualise cleared it).
DUWS_fnc_opcom_advance = {
    params ["_t"];
    if ((_t get "route") isEqualTo [] && {(_t get "target") isNotEqualTo []}) then {
        ([_t get "pos", _t get "target", _t get "moveType", 0] call fnc_opcom_route) params ["_pts", "_mode"];
        _t set ["route", _pts]; _t set ["routeMode", _mode]; _t set ["leg", 0];
    };
    private _route = _t get "route";
    private _leg = _t get "leg";
    private _pos = _t get "pos";
    private _landRule = (DUWS_opcom_moveWater getOrDefault [_t get "moveType", "land"]) isEqualTo "land";
    private _remain = OPCOM_GRID_CELL / (DUWS_opcom_speed getOrDefault [_t get "moveType", 30]);
    private _water = false;
    while {_remain > 0 && {_leg < count _route} && {!_water}} do {
        private _wp = _route select _leg;
        if (_landRule && {[_wp] call DUWS_fnc_opcom_isWaterPt}) then {
            _water = true;                          // near shore: a land type cannot foot on, task_step fetches a ferry
        } else {
            private _d = _pos distance2D _wp;
            if (_d <= _remain) then {
                _pos = +_wp; _leg = _leg + 1; _remain = _remain - _d;
            } else {
                private _dir = [(_wp select 0) - (_pos select 0), (_wp select 1) - (_pos select 1)];
                private _len = sqrt ((_dir select 0) ^ 2 + (_dir select 1) ^ 2);
                _pos = [(_pos select 0) + (_dir select 0) / _len * _remain, (_pos select 1) + (_dir select 1) / _len * _remain, 0];
                _remain = 0;
            };
        };
    };
    _t set ["pos", _pos];
    _t set ["leg", _leg];
    switch (true) do {
        case (_water): { "water" };
        case (_leg >= count _route): { "arrived" };
        default { "moving" };
    }
};

// Advance a transport's carry one tick. Returns the bound rider record while the carry stands, else nil (the
// rider is gone, or the ferry completed). Rendezvous to the waiting rider, embark within a cell, carry to the
// far shore, drop, and revert to a free staged `guard` back in the pool.
DUWS_fnc_opcom_ferryStep = {
    params ["_t"];
    private _rider = [_t get "carrying"] call DUWS_fnc_opcom_byId;
    if (isNil "_rider" || {((_rider get "status") in ["dead", "done"]) || {(_rider get "ridingOn") != (_t get "id")}}) exitWith {
        _t set ["carrying", -1]; _t set ["embarked", false]; nil
    };
    // Rendezvous: steer to the waiting rider; embark once within a cell, then retarget to the far shore.
    if (!(_t get "embarked")) then {
        _t set ["target", _rider get "pos"];
        if (((_t get "pos") distance2D (_rider get "pos")) <= OPCOM_GRID_CELL) then {
            // A rider still live at the near shore board-despawns as it embarks: with nobody watching the
            // virtual carry there is no boarding to render (the live path deletes them one by one instead).
            private _rg = groupFromNetId (_rider get "grp");
            if (!isNull _rg) then {
                { deleteVehicle _x } forEach units _rg; deleteGroup _rg;
                _rider set ["grp", ""]; _rider set ["status", "virtual"];
            };
            _t set ["embarked", true];
            _t set ["target", [_rider] call DUWS_fnc_opcom_ferryDrop];
            _t set ["route", []];
        } else {
            [_t] call DUWS_fnc_opcom_advance;
        };
    };
    // Carry: ferry to the far shore, the rider riding along, then drop it to resume its own route on foot.
    if (_t get "embarked") then {
        private _arrived = ([_t] call DUWS_fnc_opcom_advance) isEqualTo "arrived";
        _rider set ["pos", _t get "pos"];        // rider rides along; dropped on the far shore (land) to foot on
        if (_arrived) exitWith {
            _rider set ["ridingOn", -1]; _rider set ["route", []];
            // A boat backs off to navigable water so a reverted guard never rests (or de-virt spawns) on land.
            private _tpos = _t get "pos";
            if ((_t get "moveType") isEqualTo "boat") then { _tpos = [_tpos] call DUWS_fnc_opcom_nearestWater };
            _t set ["pos", _tpos]; _t set ["carrying", -1]; _t set ["embarked", false];
            _t set ["order", "guard"]; _t set ["target", _tpos]; _t set ["route", []];
            nil
        };
    };
    _rider
};

// Take down the one-shot board handler and its rider tag once boarding is done (or abandoned), so a hull that
// later ferries a second rider re-arms cleanly rather than skip on a stale flag.
DUWS_fnc_opcom_ferryClearBoardEH = {
    params ["_veh"];
    private _eh = _veh getVariable ["DUWS_ferryBoardEH", -1];
    if (_eh >= 0) then {
        _veh removeEventHandler ["GetIn", _eh];
        _veh setVariable ["DUWS_ferryBoardEH", -1];
        _veh setVariable ["DUWS_ferryRiderGrp", grpNull];
    };
};

// Free a transport from a carry -- the rider is gone, or the crossing is done. Reverts it to a free staged
// guard back in the pool (a boat backs off to navigable water, unable to rest on land); if live it takes the
// guard order in place, else it just banks the reverted state.
DUWS_fnc_opcom_ferryRelease = {
    params ["_t"];
    private _grp = groupFromNetId (_t get "grp");
    private _pos = if (!isNull _grp) then { getPosASL (leader _grp) } else { _t get "pos" };
    if ((_t get "moveType") isEqualTo "boat") then { _pos = [_pos] call DUWS_fnc_opcom_nearestWater };
    _t set ["pos", _pos];
    _t set ["carrying", -1]; _t set ["embarked", false];
    _t set ["ferryWait", 0]; _t set ["ferryLZ", []];
    _t set ["order", "guard"]; _t set ["target", _pos]; _t set ["route", []];
    if (!isNull _grp) then {
        [vehicle (leader _grp)] call DUWS_fnc_opcom_ferryClearBoardEH;
        [_grp, "guard", _pos] call DUWS_fnc_opcom_applyOrder;
    };
};

// Drive a carrying transport for one tick, choosing live or virtual by the transport's OWN streaming and
// keeping the rider bound across it (docs/plans/opcom/opcom_plan.md §Transport). Far, it stows -- reVirt keeps
// carrying/embarked, so the virtual step resumes the carry; it holds live through a board/unload in progress.
DUWS_fnc_opcom_ferryTick = {
    params ["_t", "_near"];
    private _rider = [_t get "carrying"] call DUWS_fnc_opcom_byId;
    if (isNil "_rider" || {((_rider get "status") in ["dead", "done"]) || {(_rider getOrDefault ["ridingOn", -1]) != (_t get "id")}}) exitWith {
        [_t] call DUWS_fnc_opcom_ferryRelease;
    };
    if ((_t get "grp") isNotEqualTo "") then {
        if (_near || {(_rider get "grp") isNotEqualTo ""}) then {
            _t set ["farTicks", 0];
            [_t, _rider] call DUWS_fnc_opcom_ferryStepLive;
        } else {
            private _far = (_t getOrDefault ["farTicks", 0]) + 1;
            _t set ["farTicks", _far];
            if (_far >= OPCOM_REVIRT_GRACE) then { [_t] call DUWS_fnc_opcom_reVirt };
        };
    } else {
        [_t] call DUWS_fnc_opcom_ferryStep;
        if ((_t getOrDefault ["carrying", -1]) >= 0 && _near) then {
            [_t] call DUWS_fnc_opcom_deVirt;
            _t set ["ferryWait", 0]; _t set ["ferryLZ", []];   // fresh live spell: no stale board/land debounce
        };
    };
};

// Render a live transport's crossing for one tick -- load (board-despawn), carry (rider bound + virtual), unload
// (re-spawn at stored strength). Boat and rotary only. Mirrors the virtual DUWS_fnc_opcom_ferryStep phase for
// phase so a mid-crossing stream cycle is seamless; a board/landing that never settles forces through at the cap.
DUWS_fnc_opcom_ferryStepLive = {
    params ["_t", "_rider"];
    private _grp = groupFromNetId (_t get "grp");
    if (isNull _grp) exitWith {};                       // spawn lost; ferryTick re-streams it next tick
    private _veh = vehicle (leader _grp);
    private _tpos = getPosASL (leader _grp);
    _t set ["pos", _tpos];
    _t set ["effForce", [_grp] call DUWS_fnc_opcom_effForceLive];
    private _rotary = (_t get "moveType") isEqualTo "rotary";
    private _boat = (_t get "moveType") isEqualTo "boat";
    private _reachDist = [OPCOM_FERRY_BOARD_LAND, OPCOM_FERRY_BOARD_BOAT] select _boat;
    private _wait = _t getOrDefault ["ferryWait", 0];
    private _force = _wait >= OPCOM_FERRY_WAIT_MAX;

    if (!(_t get "embarked")) then {
        // Load: close on the rider by hull type, then board-despawn it. `_close` gates the stall clock and the
        // forced board to the settling phase (a rotary landing), so a long flight in never times out mid-air.
        private _rpos = _rider get "pos";
        private _reach = false;
        private _close = false;
        if (_rotary) then {
            private _lz = _t getOrDefault ["ferryLZ", []];
            if (_lz isEqualTo []) then {
                _lz = [_rpos, 0, 80, 8, 0, 0.3, 0] call BIS_fnc_findSafePos; _lz set [2, 0];
                _t set ["ferryLZ", _lz];
            };
            _close = (_veh distance2D _lz) < 150;
            if (_close) then { _veh land "GET IN" } else {
                if (count waypoints _grp == 0) then { [_grp, "move", _lz] call DUWS_fnc_opcom_applyOrder };
            };
            _reach = ((getPosATL _veh) select 2) < OPCOM_FERRY_GROUND_ALT;
        } else {
            [_grp, "move", _rpos] call DUWS_fnc_opcom_applyOrder;
            _reach = (_veh distance2D _rpos) < _reachDist;
            _close = (_veh distance2D _rpos) < (_reachDist * 2);   // nosing in: run the stall clock so it never sticks
        };
        _t set ["ferryWait", [0, _wait + 1] select (_close && !_reach)];
        if (_reach || {_force && _close}) then {
            private _rg = groupFromNetId (_rider get "grp");
            if (!isNull _rg) then {
                if (_boat || _force) then {
                    // Boat is whole-group (seating a boat is finnicky), and a stalled board (_force) clears
                    // whatever is left rather than hang on a rider that cannot reach the hull.
                    { deleteVehicle _x } forEach ((units _rg) select { alive _x });
                } else {
                    // Real one-by-one, tick-independent: a one-shot GetIn handler board-despawns each rider as it
                    // actually enters, so a seat frees instantly and one hull loads a whole squad. The rider-group
                    // tag keeps it off the transport's own crew.
                    if ((_veh getVariable ["DUWS_ferryBoardEH", -1]) < 0) then {
                        _veh setVariable ["DUWS_ferryRiderGrp", _rg];
                        private _eh = _veh addEventHandler ["GetIn", {
                            params ["_v", "", "_u"];
                            if (group _u isEqualTo (_v getVariable ["DUWS_ferryRiderGrp", grpNull])) then { deleteVehicle _u };
                        }];
                        _veh setVariable ["DUWS_ferryBoardEH", _eh];
                        _rg orderGetIn true;
                        { _x assignAsCargo _veh } forEach units _rg;
                    };
                };
            };
            _rg = groupFromNetId (_rider get "grp");
            if (isNull _rg || {((units _rg) findIf {alive _x}) < 0}) then {
                if (!isNull _rg) then { deleteGroup _rg };
                [_veh] call DUWS_fnc_opcom_ferryClearBoardEH;
                _rider set ["grp", ""]; _rider set ["status", "virtual"];
                _t set ["embarked", true]; _t set ["ferryWait", 0]; _t set ["ferryLZ", []];
                _t set ["target", [_rider] call DUWS_fnc_opcom_ferryDrop]; _t set ["route", []];
                if (_rotary) then { _veh land "NONE" };            // release the landing hold so it lifts off
                [_grp, "move", _t get "target"] call DUWS_fnc_opcom_applyOrder;
            };
        };
    } else {
        // Carry to the far shore, then unload. The rider rides bound and virtual -- no rider object exists.
        private _drop = _t get "target";
        _rider set ["pos", _tpos];
        private _atDrop = false;
        private _close = false;
        if (_rotary) then {
            _close = (_veh distance2D _drop) < 150;
            if (_close) then { _veh land "GET OUT" } else {
                if (count waypoints _grp == 0) then { [_grp, "move", _drop] call DUWS_fnc_opcom_applyOrder };
            };
            _atDrop = (((getPosATL _veh) select 2) < OPCOM_FERRY_GROUND_ALT) && _close;
        } else {
            if (count waypoints _grp == 0) then { [_grp, "move", _drop] call DUWS_fnc_opcom_applyOrder };
            _atDrop = (_tpos distance2D _drop) < _reachDist;
            _close = (_tpos distance2D _drop) < (_reachDist * 2);
        };
        _t set ["ferryWait", [0, _wait + 1] select (_close && !_atDrop)];
        if (_atDrop || {_force && _close}) then {
            // Re-spawn the rider disembarking at stored strength, then free the hull. deVirt shore-stages the
            // onward leg; the cleared route makes a later stow replan from the drop.
            _rider set ["pos", _drop]; _rider set ["route", []]; _rider set ["leg", 0];
            [_rider] call DUWS_fnc_opcom_deVirt;
            _rider set ["ridingOn", -1];
            if (!_boat && _atDrop) then {
                // Spawn into the hold and let the onward order turn them out (the getOut disembark); a boat has no
                // hold, its group is snapped to the shore by the spawn point. Skipped on a forced (airborne) drop.
                private _rg = groupFromNetId (_rider get "grp");
                if (!isNull _rg) then { { _x moveInCargo _veh } forEach (units _rg) };
            };
            [_t] call DUWS_fnc_opcom_ferryRelease;
        };
    };
};
