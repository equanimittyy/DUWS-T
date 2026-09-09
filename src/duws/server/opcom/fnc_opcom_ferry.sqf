// Locality: server, [] call'd at load. Movement + ferry helpers. `advance` is the shared per-tick mover, for a
// plain march and for the ferry carry. A land type cannot foot over water: its route may cross a navigable body
// (fnc_opcom_route lifts it at a penalty), and `advance` stops at the near shore so the tasking phase can borrow
// a transport there. The transport ferries the rider to the far shore, drops it, and reverts to a free staged
// guard back in the borrow pool. The rider owns its whole route; the carrier is fetched by the route, never
// commanded (docs/plans/opcom/transport_ferry.md). A bound rider takes no turn of its own -- task_step skips it.
if (!isServer) exitWith {};

// A world point sits in a navigable-water cell -- a ferry leg for a land type.
DUWS_fnc_opcom_isWaterPt = {
    params ["_pt"];
    (DUWS_opcom_grid_water select ([_pt] call DUWS_fnc_opcom_w2c)) >= 0
};

// The far shore a stopped rider faces: the first non-water point at or after its current leg. Falls back to the
// rider's target if the chain runs to water (an offshore target -- not expected).
DUWS_fnc_opcom_ferryDrop = {
    params ["_rider"];
    private _route = _rider get "route";
    private _far = -1;
    for "_i" from (_rider get "leg") to (count _route - 1) do {
        if (!([_route select _i] call DUWS_fnc_opcom_isWaterPt)) exitWith { _far = _i };
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
// never borrows itself); -1 drops none. Idle-only: a hull on a directed order is a role unit off the pool, so
// a ferry never breaks a standing order (transport_ferry.md).
DUWS_fnc_opcom_ferryPool = {
    params [["_excludeId", -1]];
    DUWS_opcom_taskings select {
        (_x get "grp") isEqualTo ""
        && {"transport" in (_x get "flags")}
        && {(_x getOrDefault ["carrying", -1]) < 0}
        && {(_x get "id") != _excludeId}
        && {(_x get "moveType") in ["boat", "rotary"]}
        && {(_x get "order") in ["guard", "garrison"]}
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

// De-virtualise a carrying pair together near a player: spawn the transport, spawn the rider at the same
// point, and seat the rider best-effort (moveInCargo silently drops any that do not fit -- the plan's tied
// abort is not modelled). Both go live and independent; the carry is unbound.
DUWS_fnc_opcom_deVirtFerry = {
    params ["_t", "_rider"];
    if !([_t] call DUWS_fnc_opcom_deVirt) exitWith { false };
    _rider set ["pos", _t get "pos"];
    [_rider] call DUWS_fnc_opcom_deVirt;
    private _tg = groupFromNetId (_t get "grp");
    private _rg = groupFromNetId (_rider get "grp");
    if (!isNull _tg && {!isNull _rg}) then {
        private _veh = vehicle (leader _tg);
        if (_veh isNotEqualTo (leader _tg)) then { { _x moveInCargo _veh } forEach (units _rg) };
    };
    _t set ["carrying", -1]; _t set ["embarked", false];
    _rider set ["ridingOn", -1];
    true
};
