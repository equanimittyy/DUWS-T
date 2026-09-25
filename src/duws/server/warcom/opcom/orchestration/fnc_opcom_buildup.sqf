// Locality: server, [] call'd at load. Buildup: an Attack's units stage short of the target and launch together once
// they are enough, since no-retreat turns a force dribbled into contact into defeat in detail (opcom_plan.md
// §Commitment). A bound unit that settles at its rally rests, so only its binding keeps the next pick off it.
if (!isServer) exitWith {};

// -> the point _dist from _pos toward _dir, pulled in toward _edge until it is dry; [] when all of it is water.
DUWS_fnc_opcom_rallyAt = {
    params ["_pos", "_dir", "_dist", "_edge"];
    private _out = [];
    for "_d" from _dist to _edge step -(OPCOM_GRID_CELL / 2) do {
        private _p = _pos getPos [_d, _dir];
        if !(surfaceIsWater _p) exitWith { _out = [_p select 0, _p select 1, 0] };
    };
    _out
};

// The force an intent binds over the believed BLUFOR force at its target, both as the 3x3 block reads them.
DUWS_fnc_opcom_musterRatio = {
    params ["_intent"];
    private _force = 0;
    {
        private _t = [_intent, _x] call DUWS_fnc_opcom_roleUnit;
        if (!isNil "_t") then { _force = _force + (_t get "effForce") };
    } forEach (_intent get "roles");
    ([_intent get "pos"] call DUWS_fnc_opcom_blockForce) params ["", "_ene"];
    _force * (call DUWS_fnc_opcom_blockGain) / (_ene + 1)
};

// Every bound unit takes the capture order at once, so the attack arrives as one wave; a slot still open is dropped.
DUWS_fnc_opcom_launch = {
    params ["_intent", "_r"];
    private _roles = [];
    {
        private _t = [_intent, _x] call DUWS_fnc_opcom_roleUnit;
        if (!isNil "_t") then {
            _t set ["hold", 0];
            if ([_t, "capture", _intent get "pos"] call fnc_opcom_task) then { _roles pushBack _x } else { _t set ["boundTo", -1] };
        };
    } forEach (_intent get "roles");
    _intent set ["roles", _roles];
    if (_roles isEqualTo []) exitWith { [_intent, "dropped: no unit could launch"] call DUWS_fnc_opcom_intentClose };
    _intent set ["state", "execution"];
    ["INFO", "OPCOM", format ["intent %1 (%2 %3) launches %4 unit(s) at %5:1", _intent get "id", _intent get "action",
        _intent get "label", count _roles, _r toFixed 2]] call fnc_log;
};

DUWS_fnc_opcom_buildupStep = {
    params ["_intent"];
    if !([_intent get "target"] call DUWS_fnc_opcom_captureHolds) exitWith {
        [_intent, "dropped: the target is no longer BLUFOR's"] call DUWS_fnc_opcom_intentClose;
    };
    private _units = [];
    private _lost = false;
    {
        if ((_x get "unit") >= 0) then {
            private _t = [_intent, _x] call DUWS_fnc_opcom_roleUnit;
            if (isNil "_t") then { _lost = true } else { _units pushBack _t };
        };
    } forEach (_intent get "roles");
    // A loss while staging means BLUFOR found the rally: the survivors go free rather than wait there for the next.
    if (_lost) exitWith { [_intent, "aborted: a staging unit was lost"] call DUWS_fnc_opcom_intentClose };
    private _r = [_intent] call DUWS_fnc_opcom_musterRatio;
    private _ready = ((_intent get "roles") findIf { (_x get "required") && {(_x get "unit") < 0} }) < 0
        && {(_units findIf { [_x] call DUWS_fnc_opcom_marching }) < 0};
    if (_ready && {_r >= OPCOM_MUSTER_IDEAL}) exitWith { [_intent, _r] call DUWS_fnc_opcom_launch };
    if (DUWS_opcom_tick - (_intent get "since") < OPCOM_MUSTER_EXPIRY) exitWith {};
    if (_r >= OPCOM_MUSTER_MIN) exitWith { [_intent, _r] call DUWS_fnc_opcom_launch };
    [_intent, format ["abandoned at %1:1, short of the minimum", _r toFixed 2]] call DUWS_fnc_opcom_intentClose;
};
