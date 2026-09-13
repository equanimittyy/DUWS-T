// Locality: server. The tasking phase of the perception loop, one pass per tick after the grid rebuild --
// movement, streaming, status, healing, no scoring (Phase 4 adds what to commit). Off the isNil scoring
// block, since the route search may yield.
//
// A virtual active tasking steps along its route (replanning if a re-virtualise cleared the chain), then
// de-virtualises if a player is within its reach; a live one reads status, resolves a supply arrival, requests
// a ferry once it reaches a water leg, and stows once the player leaves with no contact; a resting garrison
// heals. A transport driving a carry owns its own streaming (DUWS_fnc_opcom_ferryTick), keeping the rider
// bound across the boundary. De-virtualisation triggers on player proximity only -- off-screen opposing-force
// contact waits on the BLUFOR virtualisation (not built).
if (!isServer) exitWith {};
if (isNil "DUWS_opcom_taskings") exitWith {};

private _w = DUWS_opcom_grid_w;

// Player cells once for the tick. No player near means nothing de-virtualises and every live group stows.
private _pcells = (allPlayers select { alive _x }) apply {
    private _ci = [getPosASL _x] call DUWS_fnc_opcom_w2c;
    [_ci mod _w, floor (_ci / _w)]
};

// Least Chebyshev cell distance from a world point to any player, 1e9 when no player is on the map.
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

// Settle an arrived move: re-garrison a returnZone (rejoining its reserve wave) or hold as guard. Mutates the
// record only -- a live caller re-orders the group itself. Returns true when it garrisoned, so the caller can
// skip a stream-in the reserve wave covers. Supply drops finish on their own path, never here.
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
        // A carrying transport streams on its own radius, rendered when watched and virtual when not, the
        // binding kept across the boundary (fnc_opcom_ferry). Handled before the generic branches -- it is
        // neither a plain live group nor a plain virtual mover.
        private _k = DUWS_opcom_streamK getOrDefault [_t get "moveType", 1];
        [_t, ([_t get "pos"] call _nearestPlayerCells) <= _k] call DUWS_fnc_opcom_ferryTick;
    } else {
        if (_live) then {
            private _grp = groupFromNetId (_t get "grp");
            // Alive-count, not count units: a wiped group keeps its corpses in `units` until the mission GC
            // clears them (when the player leaves), so a body-count gate would leave the record live and
            // depositing stale force until then.
            if (isNull _grp || {(units _grp) findIf {alive _x} < 0}) then {
                _t set ["status", "dead"];
                _t set ["grp", ""];
            } else {
                private _ldr = leader _grp;
                // pos/effForce are refreshed by the bookkeep pass ahead of grid_rebuild (fnc_opcom_perception_run).
                if ((_t getOrDefault ["ridingOn", -1]) >= 0) then {
                    // A live rider bound at the shore: its transport drives the pickup and crossing (ferryTick).
                    // It takes no order and must not stow out from under the carry.
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

                    // Supply drops on arrival: delete the courier and fire its success (logged; mission plumbing
                    // lands with the actions that consume it in Phase 4).
                    if ((_t getOrDefault ["supplyDrop", false]) && {(_ldr distance2D (_t get "target")) < 40}) then {
                        ["INFO", "OPCOM", format ["supply delivered by tasking %1 at %2", _t get "id", _t get "target"]] call fnc_log;
                        { deleteVehicle _x } forEach (units _grp);
                        deleteGroup _grp;
                        _t set ["status", "done"];
                        _t set ["grp", ""];
                    } else {
                        // Live arrival: settle in place the same tick so the OPCOM map flips MOVE->GUARD (or
                        // re-garrisons) now, not only after a later stow re-virtualises. Same settle as the
                        // virtual path below; re-order the group so map and group agree.
                        private _arrived = _order isEqualTo "move" && {!_engaged} && {(_ldr distance2D (_t get "target")) < OPCOM_MOVE_ARRIVE};
                        if (_arrived) then {
                            [_t, getPosASL _ldr] call _settleMove;
                            [_grp, "guard", getPosASL _ldr] call DUWS_fnc_opcom_applyOrder;
                        };
                        // A land unit that has reached its near shore with a water leg ahead borrows a transport,
                        // which then renders the crossing live (fnc_opcom_ferry). It binds (ridingOn) and holds;
                        // no lift free, it waits and retries, WARNing every OPCOM_FERRY_STRAND_TICKS -- the same
                        // stranded path as a virtual rider.
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
                            // Reset on re-entry/engagement below, so the stow needs an unbroken absence, not one
                            // far sample (OPCOM_REVIRT_GRACE).
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
                // A bound rider is driven by its transport, but while it still awaits pickup it streams in like
                // any tasking, so a player at the shore sees the squad standing and its board rendered. Once the
                // transport has it (embarked) it stays virtual: its pos then tracks the hull, out on the water.
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
                        // No lift free strands the rider at the shore: it holds, retries, and WARNs every
                        // OPCOM_FERRY_STRAND_TICKS so a true island gap (no transport recruited) is not silent.
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
                        // supplyDrop / returnZone are exclusive, set upstream in fnc_opcom_task, so checking
                        // supplyDrop first cannot double-settle.
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
                        // Skip the stream-in for a completed supply / fresh garrison (defends via the reserve wave) and a rider that bound to a ferry this tick.
                        if (!_settled && {(_t getOrDefault ["ridingOn", -1]) < 0} && {([_t get "pos"] call _nearestPlayerCells) <= _k}) then { [_t] call DUWS_fnc_opcom_deVirt };
                    };
                };
            };
        };
    };
// Iterate the store directly, never a +copy -- + clones the nested hashMaps, so every _t set above would
// be lost and nothing would move (arma_engine_gotchas.md). Safe: nothing adds/removes elements in the loop.
} forEach DUWS_opcom_taskings;

// Retire finished and dead records in one sweep.
DUWS_opcom_taskings = DUWS_opcom_taskings select { !((_x get "status") in ["dead", "done"]) };
