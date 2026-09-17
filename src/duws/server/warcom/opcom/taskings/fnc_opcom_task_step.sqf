// Locality: server. The tasking phase of the perception loop, one pass per tick after the grid rebuild:
// movement, streaming, status and healing (no scoring -- Phase 4 adds what to commit). Off the isNil scoring
// block, since a route search may yield. Every tasking streams through _deVirtIfNear / _stowIfFar, a ferry carry
// included: fnc_opcom_ferry scripts the carry, never when it streams. A unit renders only when it has something to
// engage -- a player or a live BLUFOR group within K -- and never as a `garrison`: it rests virtual, a combatant
// defending through the zone's reserve wave.
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

private _garrisonInto = {
    params ["_t", "_zk"];
    _t set ["order", "garrison"]; _t set ["homeZone", _zk];
    _t set ["target", []]; _t set ["route", []]; _t set ["returnZone", ""]; _t set ["settleZone", ""];
    [_zk] call DUWS_fnc_opcom_zoneReserveSync;
};

// Settle an arrived move: re-garrison a returnZone or hold as guard. Mutates the record only; true if it garrisoned.
private _settleMove = {
    params ["_t", "_pos"];
    private _rz = _t getOrDefault ["returnZone", ""];
    if (_rz isNotEqualTo "") exitWith { [_t, _rz] call _garrisonInto; true };
    _t set ["order", "guard"]; _t set ["target", _pos]; _t set ["route", []];
    false
};

// -> true the tick an attacker enters its target zone's radius. A live one tracks it too, or a later stow re-reports.
private _captureEnters = {
    params ["_t", "_pos"];
    private _site = [_t get "targetZone"] call fnc_site_at;
    private _in = (_pos distance2D (_site get "pos")) <= (_site get "radius");
    private _entered = _in && {!(_t getOrDefault ["inZone", false])};
    _t set ["inZone", _in];
    _entered
};

// -> true if it garrisoned. A live attacker inside the zone guards until it stows, so it never vanishes in front of a
// player; one still on the road re-garrisons there.
private _captureEnd = {
    params ["_t", "_pos", "_grp"];
    private _zk = _t get "targetZone";
    private _site = [_zk] call fnc_site_at;
    _t set ["targetZone", ""];
    if ((_pos distance2D (_site get "pos")) > (_site get "radius")) exitWith {
        _t set ["hold", 0];
        if !([_t, "move", _site get "pos", _zk] call fnc_opcom_task) then { [_t, "guard"] call fnc_opcom_task };
        false
    };
    if (isNull _grp) exitWith { [_t, _zk] call _garrisonInto; true };
    _t set ["order", "guard"]; _t set ["target", _pos]; _t set ["route", []]; _t set ["settleZone", _zk];
    [_grp, "guard", _pos] call DUWS_fnc_opcom_applyOrder;
    ["INFO", "OPCOM", format ["capture: tasking %1 holds %2, garrisoning when it stows", _t get "id", _zk]] call fnc_log;
    false
};

// Re-plans only once the row's believed position moves past one cell: each re-plan is an A* search. A decayed row
// leaves the last position read.
private _interceptFollow = {
    params ["_t", "_live"];
    private _i = DUWS_opcom_belief_key findIf { _x isEqualTo (_t get "interceptKey") };
    if (_i < 0) exitWith {};
    private _bp = DUWS_opcom_belief_pos select _i;
    if (([_bp, _t get "target"] call DUWS_fnc_opcom_cellDist) <= 1) exitWith {};
    _t set ["target", +_bp];
    ([_t get "pos", _bp, _t get "moveType", 0] call fnc_opcom_route) params ["_pts", "_mode"];
    _t set ["route", _pts]; _t set ["routeMode", _mode]; _t set ["leg", 0];
    if (_live) then { [_t] call DUWS_fnc_opcom_reOrderLive };
};

private _interceptGuard = {
    params ["_t", "_pos", "_grp"];
    ["INFO", "OPCOM", format ["intercept: tasking %1 guards at %2 (row %3, contact %4)", _t get "id", _pos apply { round _x }, _t get "interceptKey", _t get "contact"]] call fnc_log;
    _t set ["order", "guard"]; _t set ["target", _pos]; _t set ["route", []]; _t set ["interceptKey", ""];
    if (!isNull _grp) then { [_grp, "guard", _pos] call DUWS_fnc_opcom_applyOrder };
};

{
    private _t = _x;
    private _order = _t get "order";
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
                private _ldr = leader _grp;
                // pos/effForce are refreshed by the bookkeep pass ahead of grid_rebuild (fnc_opcom_perception_run).
                if ((_t getOrDefault ["ridingOn", -1]) >= 0 || {_t getOrDefault ["ferryFrozen", false]} || {_t getOrDefault ["unloading", false]}) then {
                    // A live rider the ferry owns (awaiting pickup, frozen aboard, or dismounting): the transport
                    // drives the sequence, so it must not stow or replan out from under it.
                    _t set ["status", "moving"];
                } else {
                    private _engaged = behaviour _ldr isEqualTo "COMBAT";
                    if (!_engaged && {count allPlayers > 0}) then {
                        private _pl = (allPlayers select { alive _x }) apply { [_ldr distance _x, _x] };
                        if (_pl isNotEqualTo []) then {
                            _pl sort true;
                            _engaged = _ldr knowsAbout ((_pl select 0) select 1) > 1.5;
                        };
                    };
                    _t set ["status", ["moving", "engaged"] select _engaged];
                    if (_order isEqualTo "intercept") then {
                        [_t, true] call _interceptFollow;
                        private _near = ([getPosASL _ldr] call _nearestBluforCells) <= (DUWS_opcom_streamK getOrDefault [_t get "moveType", 1]);
                        if (_near) then { _t set ["contact", true] };
                        if (!_near && {(_t get "contact") || {([getPosASL _ldr, _t get "target"] call DUWS_fnc_opcom_cellDist) == 0}}) then {
                            [_t, getPosASL _ldr, _grp] call _interceptGuard;
                            _order = "guard";
                        };
                    };
                    if (_order isEqualTo "capture") then {
                        if ([_t get "targetZone"] call fnc_zone_bluforHeld) then {
                            [_t, getPosASL _ldr] call _captureEnters;
                        } else {
                            [_t, getPosASL _ldr, _grp] call _captureEnd;
                            _order = _t get "order";
                        };
                    };

                    if (((_t getOrDefault ["errand", []]) isNotEqualTo []) && {(_ldr distance2D (_t get "target")) < 40}) then {
                        [_t] call DUWS_fnc_opcom_deliver;
                        [_grp] call DUWS_fnc_opcom_despawn;
                        _t set ["status", "done"];
                        _t set ["grp", ""];
                    } else {
                        // Settle the same tick, not after a later stow; a guard settle re-orders the group so map and
                        // group agree. A garrison settle despawns (a combatant's token now sits in the reserve wave, so
                        // a live copy would fight twice) and so waits out combat and a contested home zone first.
                        private _arrived = _order isEqualTo "move" && {!_engaged} && {(_ldr distance2D (_t get "target")) < OPCOM_MOVE_ARRIVE}
                            && {!([_t getOrDefault ["returnZone", ""]] call DUWS_fnc_opcom_zoneContested)};
                        if (_arrived) then {
                            if ([_t, getPosASL _ldr] call _settleMove) then {
                                [_t] call DUWS_fnc_opcom_reVirt;
                            } else {
                                [_grp, "guard", getPosASL _ldr] call DUWS_fnc_opcom_applyOrder;
                            };
                        };
                        // A land unit at its near shore with a water leg ahead borrows a transport (fnc_opcom_ferry);
                        // no lift free, it waits and retries, WARNing every OPCOM_FERRY_STRAND_TICKS.
                        private _bound = false;
                        if (!_arrived && {!_engaged} && {_order isNotEqualTo "guard"}
                            && {(DUWS_opcom_moveWater getOrDefault [_t get "moveType", "land"]) isEqualTo "land"}) then {
                            ([_t, getPosASL _ldr] call DUWS_fnc_opcom_shoreStage) params ["_crosses", "_stage"];
                            if (_crosses && {(_ldr distance2D _stage) < OPCOM_FERRY_SHORE_ARRIVE}) then {
                                private _tr = [_t] call DUWS_fnc_opcom_borrowFerry;
                                if (isNil "_tr") then {
                                    private _s = (_t getOrDefault ["strandTicks", 0]) + 1;
                                    _t set ["strandTicks", _s];
                                    if ((_s mod OPCOM_FERRY_STRAND_TICKS) == 0) then {
                                        ["WARN", "OPCOM", format ["ferry: tasking %1 stranded %2 ticks at a water leg -- no lift free", _t get "id", _s]] call fnc_log;
                                    };
                                } else {
                                    _t set ["strandTicks", 0]; _bound = true;
                                };
                            };
                        };
                        // Skip the stow for a rider that just bound to a ferry this tick -- the transport owns it now.
                        if (!_arrived && {!_bound} && {[_t, _ldr, _engaged] call _stowIfFar}
                            && {(_t getOrDefault ["settleZone", ""]) isNotEqualTo ""}) then {
                            [_t, _t get "settleZone"] call _garrisonInto;
                        };
                    };
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
                switch (_order) do {
                    case "garrison": {
                        private _full = _t get "fullForce";
                        _t set ["effForce", (_full) min ((_t get "effForce") + OPCOM_GARRISON_HEAL_RATE * _full)];
                    };
                    case "guard": {
                        // Holds its point -- no march, no heal -- but still streams in to defend it on approach.
                        [_t] call _deVirtIfNear;
                    };
                    default {
                        if (_order isEqualTo "intercept") then { [_t, false] call _interceptFollow };
                        private _adv = [_t] call DUWS_fnc_opcom_advance;
                        // No lift free: hold, retry, and WARN every OPCOM_FERRY_STRAND_TICKS so an island gap is not silent.
                        if (_adv isEqualTo "water") then {
                            private _tr = [_t] call DUWS_fnc_opcom_borrowFerry;
                            if (isNil "_tr") then {
                                private _s = (_t getOrDefault ["strandTicks", 0]) + 1;
                                _t set ["strandTicks", _s];
                                if ((_s mod OPCOM_FERRY_STRAND_TICKS) == 0) then {
                                    ["WARN", "OPCOM", format ["ferry: tasking %1 stranded %2 ticks at a water leg -- no lift free", _t get "id", _s]] call fnc_log;
                                };
                            } else {
                                _t set ["strandTicks", 0];
                            };
                        } else {
                            _t set ["strandTicks", 0];
                        };
                        // errand and returnZone are exclusive (set upstream), so errand-first cannot double-settle.
                        private _settled = false;
                        if (_adv isEqualTo "arrived" && {_order isEqualTo "move"}) then {
                            if ((_t getOrDefault ["errand", []]) isNotEqualTo []) then {
                                [_t] call DUWS_fnc_opcom_deliver;
                                _t set ["status", "done"]; _settled = true;
                            } else {
                                _settled = [_t, _t get "pos"] call _settleMove;
                            };
                        };
                        // BLUFOR within K render the unit instead, so it fights them live.
                        if (_order isEqualTo "intercept" && {_adv isEqualTo "arrived"}
                            && {([_t get "pos"] call _nearestBluforCells) > (DUWS_opcom_streamK getOrDefault [_t get "moveType", 1])}) then {
                            [_t, _t get "pos", grpNull] call _interceptGuard;
                        };
                        if (_order isEqualTo "capture") then {
                            private _zk = _t get "targetZone";
                            if ([_zk] call fnc_zone_bluforHeld) then {
                                private _zpos = ([_zk] call fnc_site_at) get "pos";
                                if ([_t, _t get "pos"] call _captureEnters) then {
                                    private _ni = zone_namePOS_pairs findIf { ([_x select 1] call fnc_zone_key) isEqualTo _zk };
                                    if (_ni >= 0) then { [(zone_namePOS_pairs select _ni) select 0, []] call fnc_enemy_contact };
                                };
                                // The zone's own retake statement, so a virtual capture passes what the trigger would. No BLUFOR
                                // count: any within K would have rendered the attacker, so its stored force outnumbers nobody.
                                if ((_t get "inZone") && {(_t get "effForce") > 0}) then {
                                    private _trg = missionNamespace getVariable [format ["trigger_%1_%2", floor abs (_zpos select 0), floor abs (_zpos select 1)], objNull];
                                    if (!isNull _trg) then { call compile ((triggerStatements _trg) select 1) };
                                };
                            } else {
                                _settled = [_t, _t get "pos", grpNull] call _captureEnd;
                            };
                        };
                        // Skip the stream-in for a settled record or a rider that just bound to a ferry.
                        if (!_settled && {(_t getOrDefault ["ridingOn", -1]) < 0}) then { [_t] call _deVirtIfNear };
                    };
                };
            };
        };
    };
// Iterate the store directly, never a +copy -- + clones the nested hashMaps, so every _t set would be lost
// (arma_engine_gotchas.md). Safe: nothing adds/removes elements in the loop.
} forEach DUWS_opcom_taskings;

DUWS_opcom_taskings = DUWS_opcom_taskings select { !((_x get "status") in ["dead", "done"]) };
