// Locality: server, [] call'd at load. The ferry orchestrator and borrow lifecycle: a land unit stopped at a water
// leg borrows the nearest free compatible transport, which carries it across and reverts to a staged guard in the
// pool. `ferryTick` dispatches the bound crossing to fnc_opcom_ferry_virt (unwatched) or fnc_opcom_ferry_devirt
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
