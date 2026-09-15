// Locality: server. The tasking phase of the perception loop, one pass per tick after the grid rebuild:
// movement, streaming, status and healing (no scoring -- Phase 4 adds what to commit). Off the isNil scoring
// block, since a route search may yield. A carrying transport owns its own streaming (DUWS_fnc_opcom_ferryTick),
// keeping the rider bound across the boundary. De-virtualisation triggers on player proximity only, and never for a
// `garrison`: it rests virtual, a combatant defending through the zone's reserve wave.
if (!isServer) exitWith {};
if (isNil "DUWS_opcom_taskings") exitWith {};

private _w = DUWS_opcom_grid_w;

private _pcells = (allPlayers select { alive _x }) apply {
    private _ci = [getPosASL _x] call DUWS_fnc_opcom_w2c;
    [_ci mod _w, floor (_ci / _w)]
};

// Least Chebyshev cell distance from a point to any player; 1e9 with no player on the map.
private _nearestPlayerCells = {
    params ["_pos"];
    if (_pcells isEqualTo []) exitWith { 1e9 };
    private _ci = [_pos] call DUWS_fnc_opcom_w2c;
    private _cx = _ci mod _w;
    private _cy = floor (_ci / _w);
    private _best = 1e9;
    { _best = _best min ((abs (_cx - (_x select 0))) max (abs (_cy - (_x select 1)))) } forEach _pcells;
    _best
};

// Settle an arrived move: re-garrison a returnZone or hold as guard. Mutates the record only; true if it garrisoned.
private _settleMove = {
    params ["_t", "_pos"];
    private _rz = _t getOrDefault ["returnZone", ""];
    if (_rz isNotEqualTo "") exitWith {
        _t set ["order", "garrison"]; _t set ["homeZone", _rz];
        _t set ["target", []]; _t set ["route", []]; _t set ["returnZone", ""];
        [_rz] call DUWS_fnc_opcom_zoneReserveSync;
        true
    };
    _t set ["order", "guard"]; _t set ["target", _pos]; _t set ["route", []];
    false
};

{
    private _t = _x;
    private _order = _t get "order";
    private _live = (_t get "grp") isNotEqualTo "";

    if ((_t getOrDefault ["carrying", -1]) >= 0) then {
        // A carrying transport streams on its own radius, binding kept across the boundary -- handled before the
        // generic branches, since it is neither a plain live group nor a plain virtual mover (fnc_opcom_ferry).
        private _k = DUWS_opcom_streamK getOrDefault [_t get "moveType", 1];
        [_t, ([_t get "pos"] call _nearestPlayerCells) <= _k] call DUWS_fnc_opcom_ferryTick;
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

                    // Supply drop arrived: delete the courier and fire its success.
                    if ((_t getOrDefault ["supplyDrop", false]) && {(_ldr distance2D (_t get "target")) < 40}) then {
                        ["INFO", "OPCOM", format ["supply delivered by tasking %1 at %2", _t get "id", _t get "target"]] call fnc_log;
                        { deleteVehicle _x } forEach (units _grp);
                        deleteGroup _grp;
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
                        if (!_arrived && {!_bound}) then {
                            private _k = DUWS_opcom_streamK getOrDefault [_t get "moveType", 1];
                            // Reset on re-entry/engagement, so the stow needs an unbroken absence (OPCOM_REVIRT_GRACE).
                            if (!_engaged && {([getPosASL _ldr] call _nearestPlayerCells) > _k}) then {
                                private _far = (_t getOrDefault ["farTicks", 0]) + 1;
                                _t set ["farTicks", _far];
                                if (_far >= OPCOM_REVIRT_GRACE) then { [_t] call DUWS_fnc_opcom_reVirt };
                            } else {
                                _t set ["farTicks", 0];
                            };
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
                private _k = DUWS_opcom_streamK getOrDefault [_t get "moveType", 1];
                if (!isNil "_tr" && {!(_tr getOrDefault ["embarked", false])} && {([_t get "pos"] call _nearestPlayerCells) <= _k}) then {
                    [_t] call DUWS_fnc_opcom_deVirt;
                };
            } else {
                switch (_order) do {
                    case "garrison": {
                        private _full = _t get "fullForce";
                        _t set ["effForce", (_full) min ((_t get "effForce") + OPCOM_GARRISON_HEAL_RATE * _full)];
                    };
                    case "guard": {
                        // Holds its point -- no march, no heal -- but still streams in to defend it on approach.
                        private _k = DUWS_opcom_streamK getOrDefault [_t get "moveType", 1];
                        if (([_t get "pos"] call _nearestPlayerCells) <= _k) then { [_t] call DUWS_fnc_opcom_deVirt };
                    };
                    default {
                        private _k = DUWS_opcom_streamK getOrDefault [_t get "moveType", 1];
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
                        // supplyDrop and returnZone are exclusive (set upstream), so supplyDrop-first cannot double-settle.
                        private _settled = false;
                        if (_adv isEqualTo "arrived" && {_order isEqualTo "move"}) then {
                            if (_t getOrDefault ["supplyDrop", false]) then {
                                // A supply run that reaches its drop with no player near still completes.
                                ["INFO", "OPCOM", format ["supply delivered (virtual) by tasking %1 at %2", _t get "id", _t get "target"]] call fnc_log;
                                _t set ["status", "done"]; _settled = true;
                            } else {
                                _settled = [_t, _t get "pos"] call _settleMove;
                            };
                        };
                        // Skip the stream-in for a settled record or a rider that just bound to a ferry.
                        if (!_settled && {(_t getOrDefault ["ridingOn", -1]) < 0} && {([_t get "pos"] call _nearestPlayerCells) <= _k}) then { [_t] call DUWS_fnc_opcom_deVirt };
                    };
                };
            };
        };
    };
// Iterate the store directly, never a +copy -- + clones the nested hashMaps, so every _t set would be lost
// (arma_engine_gotchas.md). Safe: nothing adds/removes elements in the loop.
} forEach DUWS_opcom_taskings;

DUWS_opcom_taskings = DUWS_opcom_taskings select { !((_x get "status") in ["dead", "done"]) };
