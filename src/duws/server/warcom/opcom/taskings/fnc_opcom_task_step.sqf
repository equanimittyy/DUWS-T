// Locality: server. The tasking phase of the perception loop, one pass per tick after the grid rebuild:
// movement, streaming, status and healing (no scoring -- Phase 4 adds what to commit). Off the isNil scoring
// block, since a route search may yield.
//
// Per tasking: refresh -> step -> ferry -> stream. The first two come from DUWS_opcom_orders (fnc_opcom_orders.sqf);
// the stages here are the liveness-bound half, and the step context is the one place liveness is read.
// Every tasking streams through _deVirtIfNear / _stowIfFar, a ferry carry included: fnc_opcom_ferry scripts the
// carry, never when it streams. A unit renders only when it has something to engage -- a player or a live BLUFOR
// group within K -- and never as a `garrison`: it rests virtual, defending through the zone's reserve wave.
if (!isServer) exitWith {};
if (isNil "DUWS_opcom_taskings") exitWith {};

private _w = DUWS_opcom_grid_w;

// A streaming read of true positions, never belief: a player's AI squad or a headless client's group draws a fight too.
private _blufor = allPlayers select { alive _x };
{ private _l = leader _x; if (alive _l) then { _blufor pushBackUnique _l } } forEach (allGroups select { side _x == west });
private _bcells = [];
{ private _ci = [getPosASL _x] call DUWS_fnc_opcom_w2c; _bcells pushBackUnique [_ci mod _w, floor (_ci / _w)] } forEach _blufor;

// Least Chebyshev cell distance from a point to any BLUFOR; 1e9 with none on the map.
private _nearestBluforCells = {
    params ["_pos"];
    if (_bcells isEqualTo []) exitWith { 1e9 };
    private _ci = [_pos] call DUWS_fnc_opcom_w2c;
    private _cx = _ci mod _w;
    private _cy = floor (_ci / _w);
    private _best = 1e9;
    { _best = _best min ((abs (_cx - (_x select 0))) max (abs (_cy - (_x select 1)))) } forEach _bcells;
    _best
};

private _deVirtIfNear = {
    params ["_t"];
    private _k = DUWS_opcom_streamK getOrDefault [_t get "moveType", 1];
    if (([_t get "pos"] call _nearestBluforCells) > _k) exitWith { _t set ["nearTicks", 0]; false };
    private _near = (_t getOrDefault ["nearTicks", 0]) + 1;
    _t set ["nearTicks", _near];
    (_near >= OPCOM_DEVIRT_BUFFER) && {[_t] call DUWS_fnc_opcom_deVirt}
};

// A stow needs OPCOM_REVIRT_GRACE unbroken far ticks; a near or _hold tick resets the count.
private _stowIfFar = {
    params ["_t", "_ldr", "_hold"];
    private _k = DUWS_opcom_streamK getOrDefault [_t get "moveType", 1];
    if (_hold || {([getPosASL _ldr] call _nearestBluforCells) <= _k}) exitWith { _t set ["farTicks", 0]; false };
    private _far = (_t getOrDefault ["farTicks", 0]) + 1;
    _t set ["farTicks", _far];
    if (_far < OPCOM_REVIRT_GRACE) exitWith { false };
    [_t] call DUWS_fnc_opcom_reVirt;
    true
};

// [_t, _live, _grp, _adv] -> [_pos, _grp, _live, _engaged, _arrived, _adv]. Writes the live record's status too,
// beside the engagement test that decides it.
private _stepContext = {
    params ["_t", "_live", "_grp", "_adv"];
    // pos/effForce are refreshed by the bookkeep pass ahead of grid_rebuild (fnc_opcom_perception_run).
    private _pos = _t get "pos";
    private _engaged = false;
    if (_live) then {
        private _ldr = leader _grp;
        _pos = getPosASL _ldr;
        _engaged = behaviour _ldr isEqualTo "COMBAT";
        if (!_engaged && {count allPlayers > 0}) then {
            private _pl = (allPlayers select { alive _x }) apply { [_ldr distance _x, _x] };
            if (_pl isNotEqualTo []) then {
                _pl sort true;
                _engaged = _ldr knowsAbout ((_pl select 0) select 1) > 1.5;
            };
        };
        _t set ["status", ["moving", "engaged"] select _engaged];
    };
    // A live tasking is walked by its waypoints, so arrival is a distance read; a virtual one by the refresh above.
    private _arrived = if (_live) then {
        !_engaged && {(_pos distance2D (_t get "target")) < OPCOM_MOVE_ARRIVE}
    } else {
        _adv isEqualTo "arrived"
    };
    // A garrison settle must not walk men into a zone BLUFOR is still fighting over.
    if (_arrived && {[_t getOrDefault ["returnZone", ""]] call DUWS_fnc_opcom_zoneContested}) then { _arrived = false };
    [_pos, _grp, _live, _engaged, _arrived, _adv]
};

// A land unit at its near shore with a water leg ahead borrows a transport (fnc_opcom_ferry); no lift free, it
// waits and retries, WARNing every OPCOM_FERRY_STRAND_TICKS. -> true if it bound to a lift this tick.
// Reads the order off the record, never a copy taken before the step: an intercept that gave up is a guard now.
private _ferryStage = {
    params ["_t", "_ctx"];
    _ctx params ["_pos", "", "_live", "_engaged", "_arrived", "_adv"];
    private _need = if (!_live) then { _adv isEqualTo "water" } else {
        private _n = false;
        if (!_arrived && {!_engaged} && {(_t get "order") isNotEqualTo "guard"}
            && {(DUWS_opcom_moveWater getOrDefault [_t get "moveType", "land"]) isEqualTo "land"}) then {
            ([_t, _pos] call DUWS_fnc_opcom_shoreStage) params ["_crosses", "_stage"];
            _n = _crosses && {(_pos distance2D _stage) < OPCOM_FERRY_SHORE_ARRIVE};
        };
        _n
    };
    if (!_need) exitWith { _t set ["strandTicks", 0]; false };
    private _tr = [_t] call DUWS_fnc_opcom_borrowFerry;
    if (!isNil "_tr") exitWith { _t set ["strandTicks", 0]; true };
    private _s = (_t getOrDefault ["strandTicks", 0]) + 1;
    _t set ["strandTicks", _s];
    if ((_s mod OPCOM_FERRY_STRAND_TICKS) == 0) then {
        ["WARN", "OPCOM", format ["ferry: tasking %1 stranded %2 ticks at a water leg -- no lift free", _t get "id", _s]] call fnc_log;
    };
    false
};

private _streamStage = {
    params ["_t", "_ctx", "_bound"];
    _ctx params ["", "_grp", "_live", "_engaged"];
    if (!_live) exitWith {
        // Skip the stream-in for a rider that just bound to a ferry -- the transport owns it now.
        if ((_t getOrDefault ["ridingOn", -1]) < 0) then { [_t] call _deVirtIfNear };
    };
    if (_bound) exitWith {};
    if (([_t, leader _grp, _engaged] call _stowIfFar) && {(_t getOrDefault ["settleZone", ""]) isNotEqualTo ""}) then {
        [_t, _t get "settleZone"] call DUWS_fnc_opcom_garrisonInto;
    };
};

private _stepOne = {
    params ["_t", "_grp", "_live"];
    private _row = DUWS_opcom_orders getOrDefault [_t get "order", DUWS_opcom_orderHold];
    private _adv = [_t, _live] call (_row select 0);
    private _ctx = [_t, _live, _grp, _adv] call _stepContext;
    if ([_t, _ctx] call (_row select 1)) exitWith {};
    private _bound = [_t, _ctx] call _ferryStage;
    [_t, _ctx, _bound] call _streamStage;
};

{
    private _t = _x;
    private _live = (_t get "grp") isNotEqualTo "";

    if ((_t getOrDefault ["carrying", -1]) >= 0) then {
        [_t] call DUWS_fnc_opcom_ferryTick;
        if ((_t get "grp") isNotEqualTo "") then {
            // Stowing the hull while its rider's men stand live would strand them: at the shore, or hidden mid-drop.
            private _rider = [_t get "carrying"] call DUWS_fnc_opcom_byId;
            private _hold = !isNil "_rider" && {(_rider get "grp") isNotEqualTo ""};
            if ([_t, leader groupFromNetId (_t get "grp"), _hold] call _stowIfFar) then { [_t] call DUWS_fnc_opcom_ferryStowed };
        } else {
            if ((_t getOrDefault ["carrying", -1]) >= 0 && {[_t] call _deVirtIfNear}) then { [_t] call DUWS_fnc_opcom_ferryResume };
        };
    } else {
        if (_live) then {
            private _grp = groupFromNetId (_t get "grp");
            // Alive-count, not count units: a wiped group keeps its corpses in `units` until the mission GC clears
            // them, so a body-count gate would leave the record live and depositing stale force. Never on a frozen
            // rider -- an empty group there is a board/dismount the transport owns, not a casualty.
            if ((isNull _grp || {(units _grp) findIf {alive _x} < 0}) && {!(_t getOrDefault ["ferryFrozen", false])}) then {
                _t set ["status", "dead"];
                _t set ["grp", ""];
            } else {
                if ((_t getOrDefault ["ridingOn", -1]) >= 0 || {_t getOrDefault ["ferryFrozen", false]} || {_t getOrDefault ["unloading", false]}) then {
                    // A live rider the ferry owns (awaiting pickup, frozen aboard, or dismounting): the transport
                    // drives the sequence, so it must not stow or replan out from under it.
                    _t set ["status", "moving"];
                } else {
                    [_t, _grp, true] call _stepOne;
                };
            };
        } else {
            private _riding = _t getOrDefault ["ridingOn", -1];
            if (_riding >= 0) then {
                // A bound rider still awaiting pickup streams in like any tasking (a player at the shore sees it
                // board). Once embarked it stays virtual, its pos tracking the hull out on the water.
                private _tr = [_riding] call DUWS_fnc_opcom_byId;
                if (!isNil "_tr" && {!(_tr getOrDefault ["embarked", false])}) then { [_t] call _deVirtIfNear };
            } else {
                [_t, grpNull, false] call _stepOne;
            };
        };
    };
// Iterate the store directly, never a +copy -- + clones the nested hashMaps, so every _t set would be lost
// (arma_engine_gotchas.md). Safe: nothing adds/removes elements in the loop.
} forEach DUWS_opcom_taskings;

DUWS_opcom_taskings = DUWS_opcom_taskings select { !((_x get "status") in ["dead", "done"]) };
