// Locality: server. The tasking phase of the perception loop, one pass per tick after the grid rebuild --
// movement, streaming, status, healing, no scoring (Phase 4 adds what to commit). Off the isNil scoring
// block, since the route search may yield.
//
// A virtual active tasking steps along its route (replanning if a re-virtualise cleared the chain), then
// de-virtualises if a player is within its reach; a live one reads status, resolves a supply arrival, and
// stows once the player leaves with no contact; a resting garrison heals. De-virtualisation triggers on
// player proximity only -- off-screen opposing-force contact waits on the BLUFOR virtualisation (not built).
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

{
    private _t = _x;
    private _order = _t get "order";
    private _live = (_t get "grp") isNotEqualTo "";

    if (_live) then {
        private _grp = groupFromNetId (_t get "grp");
        if (isNull _grp || {count units _grp == 0}) then {
            _t set ["status", "dead"];
            _t set ["grp", ""];
        } else {
            private _ldr = leader _grp;
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
            if (_order isEqualTo "supply" && {(_ldr distance2D (_t get "target")) < 40}) then {
                ["INFO", "OPCOM", format ["supply delivered by tasking %1 at %2", _t get "id", _t get "target"]] call fnc_log;
                { deleteVehicle _x } forEach (units _grp);
                deleteGroup _grp;
                _t set ["status", "done"];
                _t set ["grp", ""];
            } else {
                private _k = DUWS_opcom_streamK getOrDefault [_t get "moveType", 1];
                if (!_engaged && {([_ldr] call _nearestPlayerCells) > (_k + 1)}) then { [_t] call DUWS_fnc_opcom_reVirt };
            };
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
                // Active mover. Replan if the chain was cleared (e.g. after a re-virtualise).
                if ((_t get "route") isEqualTo [] && {(_t get "target") isNotEqualTo []}) then {
                    ([_t get "pos", _t get "target", _t get "moveType", 0] call fnc_opcom_route) params ["_pts", "_mode"];
                    _t set ["route", _pts]; _t set ["routeMode", _mode]; _t set ["leg", 0];
                };

                // Walk stepMetres along the polyline this tick, crossing as many short legs as it spans.
                private _route = _t get "route";
                private _leg = _t get "leg";
                private _pos = _t get "pos";
                private _remain = OPCOM_GRID_CELL / (DUWS_opcom_speed getOrDefault [_t get "moveType", 30]);
                while {_remain > 0 && {_leg < count _route}} do {
                    private _wp = _route select _leg;
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
                _t set ["pos", _pos];
                _t set ["leg", _leg];

                if (_leg >= count _route && {_order isEqualTo "supply"}) then {
                    // A supply run that reaches its drop with no player near still completes -- fire and retire.
                    ["INFO", "OPCOM", format ["supply delivered (virtual) by tasking %1 at %2", _t get "id", _t get "target"]] call fnc_log;
                    _t set ["status", "done"];
                } else {
                    // De-virtualise when a player has closed within reach.
                    private _k = DUWS_opcom_streamK getOrDefault [_t get "moveType", 1];
                    if (([_pos] call _nearestPlayerCells) <= _k) then { [_t] call DUWS_fnc_opcom_deVirt };
                };
            };
        };
    };
} forEach (+DUWS_opcom_taskings);

// Retire finished and dead records in one sweep.
DUWS_opcom_taskings = DUWS_opcom_taskings select { !((_x get "status") in ["dead", "done"]) };
