// Locality: server, [] call'd at load. The ferry orchestrator and borrow lifecycle: a land unit stopped at a water
// leg borrows the nearest free compatible transport, which carries it across and then garrisons the nearest held
// zone. `ferryTick` dispatches the bound crossing to fnc_opcom_ferry_virt (unwatched) or fnc_opcom_ferry_devirt
// (watched) by the transport's own streaming, holding the binding across the boundary. The rider owns its route;
// the carrier is fetched by it, never commanded, and a bound rider takes no turn of its own -- task_step skips it
// (docs/plans/opcom/opcom_plan.md §Transport).
if (!isServer) exitWith {};

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

// Shared by the borrow and the debug inspector so the two never drift. _excludeId drops one id (a rider never
// borrows itself), -1 none. Idle is by order, not streaming: a live idle hull is lendable too (it flies off and
// re-virtualises elsewhere). A fighting hull is skipped -- a hull lost mid-trip strands its bound rider.
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

// Borrow the nearest free compatible transport for a rider at a water leg; returns it, or nil if none is free.
// A garrisoned pick is flipped to `move` so its ferry turn runs; no reserve draw-out, since a ferry-capable
// transport is a non-combatant never in the wave.
DUWS_fnc_opcom_borrowFerry = {
    params ["_rider"];
    private _rpos = _rider get "pos";
    private _pool = [_rider get "id"] call DUWS_fnc_opcom_ferryPool;
    if (_pool isEqualTo []) exitWith { nil };
    private _cands = _pool;
    private _best = 1e12; private _pick = -1;
    { private _dd = (_x get "pos") distance2D _rpos; if (_dd < _best) then { _best = _dd; _pick = _forEachIndex } } forEach _cands;
    private _tr = _cands select _pick;
    _tr set ["order", "move"]; _tr set ["carrying", _rider get "id"]; _tr set ["embarked", false]; _tr set ["route", []];
    _tr set ["ferryPhase", "topickup"]; _tr set ["ferryWait", 0]; _tr set ["ferryLZ", []];
    _rider set ["ridingOn", _tr get "id"];
    // Live rider: pin it at the pickup on bind -- the task step skips a bound rider after, so this is the one chance.
    if ((_rider get "grp") isNotEqualTo "") then { [_rider] call DUWS_fnc_opcom_reOrderLive };
    ["INFO", "OPCOM", format ["ferry: tasking %1 borrows %2 transport %3 for a water leg", _rider get "id", _tr get "moveType", _tr get "id"]] call fnc_log;
    _tr
};

// Detach a rider from its lift and put it back on its own route: a drop spawn runs deVirt's reOrderLive while the
// rider is still bound, which pins it with a HOLD, so without the re-order it would stand at the drop.
DUWS_fnc_opcom_ferryUnbind = {
    params ["_r"];
    _r set ["ridingOn", -1]; _r set ["ferryFrozen", false];
    [_r] call DUWS_fnc_opcom_reOrderLive;
};

// Send a freed hull to garrison the nearest held, uncontested zone, else hold guard where it stands. It is off the
// pool until it settles. A boat measures to ports and skips a portless zone, which fnc_opcom_task would refuse.
DUWS_fnc_opcom_ferryHome = {
    params ["_t"];
    private _from = _t get "pos";
    private _boat = (_t get "moveType") isEqualTo "boat";
    private _best = 1e12; private _key = ""; private _zpos = [];
    {
        private _k = [_x] call fnc_zone_key;
        private _dest = _x;
        if (_boat) then {
            private _port = [_k] call DUWS_fnc_opcom_portOf;
            _dest = if (_port < 0) then { [] } else { [_port] call DUWS_fnc_opcom_c2w };
        };
        if (_dest isNotEqualTo [] && {!([_k] call DUWS_fnc_opcom_zoneContested)} && {(_dest distance2D _from) < _best}) then {
            _best = _dest distance2D _from; _key = _k; _zpos = _x;
        };
    } forEach WARCOM_zones_controled_by_OPFOR;
    _t set ["hold", 0];   // a release is no OPCOM commit: a hold left from before the borrow must not refuse it
    if (_key isEqualTo "" || {!([_t, "move", _zpos, _key] call fnc_opcom_task)}) then { [_t, "guard"] call fnc_opcom_task };
};

// Free a transport from a carry -- the rider is gone, or the crossing is done -- and send it home. A boat backs off
// to navigable water first, unable to rest or route from land.
DUWS_fnc_opcom_ferryRelease = {
    params ["_t"];
    // Crossing over: thaw the rider's strength freeze and clear its unload guard so live tracking + tasking resume;
    // a rider still bound here (a boat drop, or a rotor drop nobody got out of) unbinds now.
    private _r = [_t get "carrying"] call DUWS_fnc_opcom_byId;
    if (!isNil "_r") then {
        _r set ["ferryFrozen", false]; _r set ["unloading", false];
        if ((_r getOrDefault ["ridingOn", -1]) == (_t get "id")) then { [_r] call DUWS_fnc_opcom_ferryUnbind };
    };
    private _status = if (isNil "_r") then { "gone" } else { _r get "status" };
    private _wait = _t getOrDefault ["ferryWait", 0];
    [["INFO", "WARN"] select (_wait >= OPCOM_FERRY_WAIT_MAX), "OPCOM", format ["ferry: transport %1 (%2) releases rider %3 (%4) at %5, wait %6/%7",
        _t get "id", _t get "moveType", _t get "carrying", _status, _t getOrDefault ["ferryPhase", "topickup"], _wait, OPCOM_FERRY_WAIT_MAX]] call fnc_log;
    private _grp = groupFromNetId (_t get "grp");
    private _pos = if (!isNull _grp) then { getPosASL (leader _grp) } else { _t get "pos" };
    if ((_t get "moveType") isEqualTo "boat") then { _pos = [_pos] call DUWS_fnc_opcom_nearestWater };
    _t set ["pos", _pos];
    _t set ["carrying", -1]; _t set ["embarked", false];
    _t set ["ferryWait", 0]; _t set ["ferryLZ", []]; _t set ["ferryPhase", "topickup"];
    [_t] call DUWS_fnc_opcom_ferryClearPad;
    if (!isNull _grp) then {
        private _veh = vehicle (leader _grp);
        [_veh] call DUWS_fnc_opcom_ferryClearHull;
        private _pilot = currentPilot _veh;
        _pilot enableAI "Target";                            // undo the pickup pin
        if (_veh isKindOf "Air") then {
            _veh flyInHeight OPCOM_AIR_SPAWN_ALT;            // undo the dismount pin, at the spawner's own value
            _veh land "NONE";                                // LAND is sticky: it would sit on the pad
        };
    };
    [_t] call DUWS_fnc_opcom_ferryHome;
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
        private _tg = groupFromNetId (_t get "grp");
        // A downed transport is driven only here and never reaches the generic dead-sweep, so clear it here or it
        // lingers carrying forever. An embarked rider (no group) dies with the hull; one still ashore keeps its
        // group and is cut loose to re-ferry.
        if (isNull _tg || {(units _tg) findIf {alive _x} < 0}) exitWith {
            private _rg = groupFromNetId (_rider get "grp");
            // Men still hidden in a rotor drop's unload queue go down with the hull: a loss, not frozen ghosts at the pad.
            private _lost = (units _rg) select { isObjectHidden _x };
            { deleteVehicle _x } forEach _lost;
            ["WARN", "OPCOM", format ["ferry: transport %1 (%2) down at %3 -- rider %4 %5, %6 lost unrevealed", _t get "id", _t get "moveType",
                _t getOrDefault ["ferryPhase", "topickup"], _rider get "id", ["cut loose", "lost aboard"] select ((_rider get "grp") isEqualTo ""),
                count _lost]] call fnc_log;
            if ((_rider get "grp") isEqualTo "") then { _rider set ["status", "dead"] };
            _rider set ["ridingOn", -1]; _rider set ["ferryFrozen", false]; _rider set ["unloading", false];
            // Its ferry orders outlive the hull (a shore HOLD, a seat on the wreck, a pin at the drop pad); re-order it.
            if (!isNull _rg) then { { unassignVehicle _x } forEach units _rg; [_rider] call DUWS_fnc_opcom_reOrderLive };
            if (!isNull _tg) then { [vehicle (leader _tg)] call DUWS_fnc_opcom_ferryClearHull };
            [_t] call DUWS_fnc_opcom_ferryClearPad;
            _t set ["status", "dead"]; _t set ["grp", ""]; _t set ["carrying", -1]; _t set ["embarked", false];
        };
        if (_near || {(_rider get "grp") isNotEqualTo ""}) then {
            _t set ["farTicks", 0];
            if (duws_log_level >= 4) then {
                private _veh = vehicle (leader _tg);
                private _ph = _t getOrDefault ["ferryPhase", "topickup"];
                private _nav = _t getOrDefault ["ferryLZ", []];
                private _navM = if (_nav isEqualTo []) then { -1 } else { round (_veh distance2D _nav) };
                ["DEBUG", "OPCOM", format ["ferry: transport %1 (%2) %3 wait %4 nav %5 m alt %6 m %7 km/h wps %8, rider %9 men %10 queue %11",
                    _t get "id", _t get "moveType", _ph, _t getOrDefault ["ferryWait", 0], _navM,
                    round ((getPosATL _veh) select 2), round (speed _veh), count waypoints _tg,
                    _rider get "id", {alive _x} count units groupFromNetId (_rider get "grp"),
                    count (_veh getVariable ["DUWS_ferryUnloadQ", []])]] call fnc_log;
            };
            [_t, _rider] call DUWS_fnc_opcom_ferryStepLive;
        } else {
            private _far = (_t getOrDefault ["farTicks", 0]) + 1;
            _t set ["farTicks", _far];
            if (_far >= OPCOM_REVIRT_GRACE) then {
                ["INFO", "OPCOM", format ["ferry: transport %1 (%2) stows at %3, embarked %4", _t get "id", _t get "moveType",
                    _t getOrDefault ["ferryPhase", "topickup"], _t getOrDefault ["embarked", false]]] call fnc_log;
                [vehicle (leader _tg)] call DUWS_fnc_opcom_ferryClearHull;
                [_t] call DUWS_fnc_opcom_ferryClearPad;
                [_t] call DUWS_fnc_opcom_reVirt;
            };
        };
    } else {
        [_t] call DUWS_fnc_opcom_ferryStep;
        if ((_t getOrDefault ["carrying", -1]) >= 0 && _near && {[_t] call DUWS_fnc_opcom_deVirt}) then {
            // Fresh live spell: resume the phase by embarked (pickup before the board, carry after), timer reset.
            _t set ["ferryPhase", ["topickup", "carry"] select (_t getOrDefault ["embarked", false])];
            _t set ["ferryWait", 0]; _t set ["ferryLZ", []];
            ["INFO", "OPCOM", format ["ferry: transport %1 (%2) streams live at %3", _t get "id", _t get "moveType", _t get "ferryPhase"]] call fnc_log;
        };
    };
};
