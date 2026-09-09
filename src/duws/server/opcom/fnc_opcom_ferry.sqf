// Locality: server, [] call'd at load. Movement + ferry helpers. `advance` is the shared per-tick mover (used
// by a plain march and by the ferry). `ferryStep` runs the boarding order (docs/plans/opcom/opcom_plan.md): a
// transport OPCOM binds to a rider rendezvous with it, embarks it, ferries it to the rider's own objective,
// and drops it to resume. The rider is driven entirely by the transport while bound -- task_step skips its turn.
if (!isServer) exitWith {};

// Step a tasking stepMetres along its route this tick; returns true if it reached the end. Replans from the
// current position when the chain is empty (a fresh order, or a re-virtualise cleared it).
DUWS_fnc_opcom_advance = {
    params ["_t"];
    if ((_t get "route") isEqualTo [] && {(_t get "target") isNotEqualTo []}) then {
        ([_t get "pos", _t get "target", _t get "moveType", 0] call fnc_opcom_route) params ["_pts", "_mode"];
        _t set ["route", _pts]; _t set ["routeMode", _mode]; _t set ["leg", 0];
    };
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
    _leg >= count _route
};

// Advance a transport's carry one tick. Returns the bound rider record while the carry stands, else nil (the
// rider is gone, or the ferry completed). The transport moves on its own type, the rider's position following
// it while aboard.
DUWS_fnc_opcom_ferryStep = {
    params ["_t"];
    private _rider = [_t get "carrying"] call DUWS_fnc_opcom_byId;
    if (isNil "_rider" || {((_rider get "status") in ["dead", "done"]) || {(_rider get "ridingOn") != (_t get "id")}}) exitWith {
        _t set ["carrying", -1]; _t set ["embarked", false]; nil
    };
    // Rendezvous: steer to the waiting rider; embark once within a cell, then retarget to the rider's objective.
    if (!(_t get "embarked")) then {
        _t set ["target", _rider get "pos"];
        if (((_t get "pos") distance2D (_rider get "pos")) <= OPCOM_GRID_CELL) then {
            _t set ["embarked", true];
            _t set ["target", _rider get "target"];
            _t set ["route", []];
        } else {
            [_t] call DUWS_fnc_opcom_advance;
        };
    };
    // Carry: ferry to the objective, the rider riding along, then drop it to resume its own tasking.
    if (_t get "embarked") then {
        private _arrived = [_t] call DUWS_fnc_opcom_advance;
        _rider set ["pos", _t get "pos"];
        if (_arrived) exitWith {
            _rider set ["ridingOn", -1]; _rider set ["route", []];
            _t set ["carrying", -1]; _t set ["embarked", false]; _t set ["status", "done"];
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
