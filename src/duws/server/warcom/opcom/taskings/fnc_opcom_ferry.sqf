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

// Chebyshev distance in grid cells between two world points -- the ferry's "measure by k", decoupled from any
// streaming radius. A rotor issues its land order a fixed cell count (OPCOM_FERRY_LAND_K) from its LZ/drop.
DUWS_fnc_opcom_cellDist = {
    params ["_a", "_b"];
    private _w = DUWS_opcom_grid_w;
    private _ca = [_a] call DUWS_fnc_opcom_w2c;
    private _cb = [_b] call DUWS_fnc_opcom_w2c;
    (abs ((_ca mod _w) - (_cb mod _w))) max (abs (floor (_ca / _w) - floor (_cb / _w)))
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

// A boat's nav target for a shore point, snapped to the nearest navigable water: a water move type has no
// shore-stop in `advance` and fnc_opcom_route cannot join it to a land cell, so it beaches unless kept wet.
// A rotary/land lift takes the land point directly.
DUWS_fnc_opcom_ferryApproach = {
    params ["_t", "_landPt"];
    if ((_t get "moveType") isEqualTo "boat") then { [_landPt] call DUWS_fnc_opcom_nearestWater } else { _landPt }
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
// re-virtualises elsewhere, which is fine. A fighting hull is skipped: the phase harness forces a stalled crossing
// through, but a hull lost mid-trip still strands its bound rider with nothing to free it -- lend one likely to
// survive the trip (opcom_plan.md §Transport).
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
    _tr set ["ferryPhase", "topickup"]; _tr set ["ferryWait", 0]; _tr set ["ferryLZ", []];
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
        _t set ["target", [_t, _rider get "pos"] call DUWS_fnc_opcom_ferryApproach];
        if (((_t get "pos") distance2D (_t get "target")) <= OPCOM_GRID_CELL) then {
            // A rider still live at the near shore board-despawns as it embarks: with nobody watching the
            // virtual carry there is no boarding to render (the live path deletes them one by one instead).
            private _rg = groupFromNetId (_rider get "grp");
            if (!isNull _rg) then {
                { deleteVehicle _x } forEach units _rg; deleteGroup _rg;
                _rider set ["grp", ""]; _rider set ["status", "virtual"];
            };
            _t set ["embarked", true];
            private _drop = [_rider] call DUWS_fnc_opcom_ferryDrop;
            _rider set ["ferryLand", _drop];
            _t set ["target", [_t, _drop] call DUWS_fnc_opcom_ferryApproach];
            _t set ["route", []];
        } else {
            [_t] call DUWS_fnc_opcom_advance;
        };
    };
    // Carry: ferry to the far shore, the rider riding along, then drop it to resume its own route on foot.
    if (_t get "embarked") then {
        private _arrived = ([_t] call DUWS_fnc_opcom_advance) isEqualTo "arrived";
        _rider set ["pos", _t get "pos"];
        if (_arrived) exitWith {
            _rider set ["pos", _rider getOrDefault ["ferryLand", _t get "pos"]];
            // Off-screen drop skips ferryRelease, so thaw the freeze here (a live board may have set it before the
            // carry went virtual); the rider re-streams and tracks live from its drop.
            _rider set ["ridingOn", -1]; _rider set ["route", []]; _rider set ["ferryFrozen", false];
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

// Free a transport from a carry -- the rider is gone, or the crossing is done. Reverts it to a free staged
// guard back in the pool (a boat backs off to navigable water, unable to rest on land); if live it takes the
// guard order in place, else it just banks the reverted state.
DUWS_fnc_opcom_ferryRelease = {
    params ["_t"];
    // Crossing over: thaw the rider's strength freeze and clear its unload guard so live tracking + tasking resume.
    private _r = [_t get "carrying"] call DUWS_fnc_opcom_byId;
    if (!isNil "_r") then { _r set ["ferryFrozen", false]; _r set ["unloading", false] };
    private _grp = groupFromNetId (_t get "grp");
    private _pos = if (!isNull _grp) then { getPosASL (leader _grp) } else { _t get "pos" };
    if ((_t get "moveType") isEqualTo "boat") then { _pos = [_pos] call DUWS_fnc_opcom_nearestWater };
    _t set ["pos", _pos];
    _t set ["carrying", -1]; _t set ["embarked", false];
    _t set ["ferryWait", 0]; _t set ["ferryLZ", []]; _t set ["ferryPhase", "topickup"];
    _t set ["order", "guard"]; _t set ["target", _pos]; _t set ["route", []];
    if (!isNull _grp) then {
        [vehicle (leader _grp)] call DUWS_fnc_opcom_ferryClearEH;
        [_grp, "guard", _pos] call DUWS_fnc_opcom_applyOrder;
    };
};

// Drive a carrying transport for one tick, choosing live or virtual by the transport's OWN streaming and
// keeping the rider bound across it (docs/plans/opcom/opcom_plan.md §Transport). Far, it stows -- reVirt keeps
// carrying/embarked, so the virtual step resumes the carry; it holds live through a board/unload in progress.
DUWS_fnc_opcom_ferryTick = {
    params ["_t", "_near"];
    private _rider = [_t get "carrying"] call DUWS_fnc_opcom_byId;
    // Once embarked the transport owns the crossing and dismount to completion: the rider detaches (ridingOn -1)
    // at the drop the moment its leader spawns, so past embark only a lost or dead rider aborts, never the detach.
    if (isNil "_rider"
        || {(_rider get "status") in ["dead", "done"]}
        || {!(_t getOrDefault ["embarked", false]) && {(_rider getOrDefault ["ridingOn", -1]) != (_t get "id")}}) exitWith {
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
            // Fresh live spell: resume the phase by embarked (pickup before the board, carry after), timer reset.
            _t set ["ferryPhase", ["topickup", "carry"] select (_t getOrDefault ["embarked", false])];
            _t set ["ferryWait", 0]; _t set ["ferryLZ", []];
        };
    };
};

// Render a live transport's crossing for one tick. A rotary steps an explicit phase machine (topickup ->
// pickup-land -> pickup-board -> carry -> drop-land -> drop-unload): the two transit legs are untimed, each
// land/board/unload phase is capped at OPCOM_FERRY_WAIT_MAX ticks (reset on entry) and forces through on expiry.
// A boat is not in the timed harness -- it board-despawns the whole group on reach and respawns it whole at the
// far shore, one tick each end. Strength freezes at the board commit and thaws when the riders spawn at the drop.
DUWS_fnc_opcom_ferryStepLive = {
    params ["_t", "_rider"];
    private _grp = groupFromNetId (_t get "grp");
    if (isNull _grp) exitWith {};                       // spawn lost; ferryTick re-streams it next tick
    private _veh = vehicle (leader _grp);
    private _tpos = getPosASL (leader _grp);
    _t set ["pos", _tpos];
    _t set ["effForce", [_grp] call DUWS_fnc_opcom_effForceLive];

    // Boat: whole-group, one tick each end, no timed sub-phases (opcom_plan.md defers it from the harness).
    if ((_t get "moveType") isEqualTo "boat") exitWith {
        if (!(_t get "embarked")) then {
            private _nav = [_t, _rider get "pos"] call DUWS_fnc_opcom_ferryApproach;
            [_grp, "move", _nav] call DUWS_fnc_opcom_applyOrder;
            if ((_veh distance2D _nav) < OPCOM_FERRY_BOARD_BOAT) then {
                _rider set ["ferryFrozen", true];       // board commit
                private _rg = groupFromNetId (_rider get "grp");
                if (!isNull _rg) then { { deleteVehicle _x } forEach units _rg; deleteGroup _rg };
                _rider set ["grp", ""]; _rider set ["status", "virtual"];
                _t set ["embarked", true];
                private _drop = [_rider] call DUWS_fnc_opcom_ferryDrop;
                _rider set ["ferryLand", _drop];
                _t set ["target", [_t, _drop] call DUWS_fnc_opcom_ferryApproach]; _t set ["route", []];
            };
        } else {
            private _nav = _t get "target";
            private _land = _rider getOrDefault ["ferryLand", _nav];
            _rider set ["pos", _tpos];
            [_grp, "move", _nav] call DUWS_fnc_opcom_applyOrder;
            if ((_tpos distance2D _nav) < OPCOM_FERRY_BOARD_BOAT) then {
                _rider set ["pos", _land]; _rider set ["route", []]; _rider set ["leg", 0];
                [_rider] call DUWS_fnc_opcom_deVirt;    // whole group ashore at once
                _rider set ["ridingOn", -1];            // landed: detach (ferryRelease thaws the freeze)
                [_t] call DUWS_fnc_opcom_ferryRelease;
            };
        };
    };

    // Rotary phase machine.
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
        [_veh] call DUWS_fnc_opcom_ferryClearEH;
        _rider set ["grp", ""]; _rider set ["status", "virtual"];
        private _drop = [_rider] call DUWS_fnc_opcom_ferryDrop; _rider set ["ferryLand", _drop];
        _t set ["target", [_t, _drop] call DUWS_fnc_opcom_ferryApproach]; _t set ["route", []];
        _t set ["embarked", true];
        _veh land "NONE";                                // release the landing hold so it lifts off
        ["carry"] call _setPhase;
    };

    switch (_phase) do {
        // Transit to the LZ (untimed): fly there, issue the land order within k cells of it.
        case "topickup": {
            private _lz = _t getOrDefault ["ferryLZ", []];
            if (_lz isEqualTo []) then {
                _lz = [_rider get "pos", 0, 80, 8, 0, 0.3, 0] call BIS_fnc_findSafePos; _lz set [2, 0];
                _t set ["ferryLZ", _lz];
            };
            if (count waypoints _grp == 0) then { [_grp, "move", _lz] call DUWS_fnc_opcom_applyOrder };
            if (([_veh, _lz] call DUWS_fnc_opcom_cellDist) <= OPCOM_FERRY_LAND_K) then {
                _veh land "GET IN";
                ["pickupland"] call _setPhase;
            };
        };
        // Descent (timed): grounded -> board; expiry -> board-despawn the riders and skip to the carry.
        case "pickupland": {
            _veh land "GET IN";
            private _wait = (_t getOrDefault ["ferryWait", 0]) + 1; _t set ["ferryWait", _wait];
            if (((getPosATL _veh) select 2) < OPCOM_FERRY_GROUND_ALT) exitWith {
                _rider set ["ferryFrozen", true];       // board commit
                ["pickupboard"] call _setPhase;
            };
            if (_wait >= OPCOM_FERRY_WAIT_MAX) then { _rider set ["ferryFrozen", true]; call _embark };
        };
        // Board (timed): force the current lead into a seat one per tick; group empty or expiry -> carry.
        case "pickupboard": {
            _veh land "GET IN";
            private _wait = (_t getOrDefault ["ferryWait", 0]) + 1; _t set ["ferryWait", _wait];
            private _rg = groupFromNetId (_rider get "grp");
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
        // Transit to the drop (untimed): the rider rides bound + virtual; issue the land order within k cells.
        case "carry": {
            _rider set ["pos", _tpos];
            private _nav = _t get "target";
            if (count waypoints _grp == 0) then { [_grp, "move", _nav] call DUWS_fnc_opcom_applyOrder };
            if (([_veh, _nav] call DUWS_fnc_opcom_cellDist) <= OPCOM_FERRY_LAND_K) then {
                _veh land "GET OUT";
                ["dropland"] call _setPhase;
            };
        };
        // Descent at the drop (timed): grounded -> spawn + one-by-one dismount; expiry -> spawn and release.
        case "dropland": {
            _rider set ["pos", _tpos];
            _veh land "GET OUT";
            private _wait = (_t getOrDefault ["ferryWait", 0]) + 1; _t set ["ferryWait", _wait];
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
        // Dismount (timed): the GetOut chain drains the hold; finalise once none are queued or seated, or eject
        // the stragglers at the cap, then release (which frees the hull and clears the unloading guard).
        case "dropunload": {
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
