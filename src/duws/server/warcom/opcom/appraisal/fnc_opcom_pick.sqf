// Locality: server -- the OPCOM tick's pick stage (opcom_plan.md §The pick). `random` is kept as the unscored
// control: uniform over actions before targets, so a target-rich action does not crowd out the rest.
private _mode = DUWS_opcom_aiMode;
if (DUWS_opcom_pickOnce isNotEqualTo "") then {
    _mode = DUWS_opcom_pickOnce;
    DUWS_opcom_pickOnce = "";
};
if (_mode isEqualTo "off") exitWith {};

// Random mode sites on one band cell, so the control stays an unscored draw.
[[OPCOM_SITE_SAMPLES, 1] select (_mode isNotEqualTo "weighted")] call DUWS_fnc_opcom_siteAll;

private _live = [];
// Unscheduled so every action reads one wallet and one store. The execute runs after, scheduled, because an order
// plans a route and the router may yield. The weighted pick scores what it cannot yet afford, so it can save for it.
isNil {
    {
        private _row = _x;
        private _targets = (_row param [3, []]) call (_row select 1);
        if (_mode isNotEqualTo "weighted") then { _targets = _targets select { (_x select 1) <= WARCOM_opfor_ap } };
        if (_targets isNotEqualTo []) then { _live pushBack [_row, _targets] };
    } forEach DUWS_opcom_actions;
};
if (_live isEqualTo []) exitWith {};

private _row = [];
private _cand = [];
private _score = -1;
if (_mode isEqualTo "weighted") then {
    private _weights = ["actionWeight"] call DUWS_fnc_opcom_archetypeTable;
    private _all = [];
    {
        _x params ["_r", "_ts"];
        private _w = _weights getOrDefault [_r param [4, _r select 0], 1];
        {
            private _price = _x select 1;
            private _s = [_x param [3, _price], _x param [4, 1], _x param [5, _price]] call DUWS_fnc_opcom_score;
            _all pushBack [_w * _s, _r, _x];
        } forEach _ts;
    } forEach _live;

    // Rank an index list, never the candidates: a tie would fall through to comparing rows, and a row holds code.
    private _rank = [];
    { _rank pushBack [_x select 0, _forEachIndex] } forEach _all;
    _rank sort false;

    // Without a goal, cheap actions spend every refill and a dearer, better one never becomes affordable.
    private _goal = [];
    if (_rank isNotEqualTo []) then {
        (_all select ((_rank select 0) select 1)) params ["_s", "", "_c"];
        private _short = (_c select 1) - WARCOM_opfor_ap;
        private _rate = WARCOM_opfor_lastIncome * OPCOM_TICK_PERIOD / DUWS_econ_period;
        if (_s > 0 && {_short > 0} && {_rate > 0} && {_short / _rate <= OPCOM_SAVE_HORIZON}) then {
            _goal = [_s, _c, _short, _short / _rate];
        };
    };
    if (_goal isNotEqualTo []) exitWith {
        _goal params ["_s", "_c", "_short", "_eta"];
        _score = _s;
        _row = DUWS_opcom_actions select (DUWS_opcom_actions findIf { (_x select 0) isEqualTo "bank" });
        _cand = [[], 0, format ["Bank, saving for %1 (%2 AP short, ~%3 min)", _c select 2, ceil _short, ceil (_eta * OPCOM_TICK_PERIOD / 60)]];
    };

    private _draw = [];
    {
        _x params ["_s", "_i"];
        if (_s <= 0 || {count _draw >= OPCOM_PICK_TOP * 2}) then { break };
        private _c = (_all select _i) select 2;
        if ((_c select 1) > WARCOM_opfor_ap) then { continue };
        _draw pushBack (_all select _i);
        _draw pushBack (_s ^ OPCOM_PICK_SHARPNESS);
    } forEach _rank;
    if (_draw isEqualTo []) exitWith {};

    (selectRandomWeighted _draw) params ["_s", "_r", "_c"];
    _score = _s;
    _row = _r;
    _cand = _c;
} else {
    (selectRandom _live) params ["_r", "_ts"];
    _row = _r;
    _cand = selectRandom _ts;
};
if (_row isEqualTo []) exitWith {};

_row params ["_id", "", "_execute"];
_cand params ["_target", "_price", "_label"];
// Re-checked: the wallet can drop after the snapshot, and fnc_ap_adjust would clamp the overdraft to a free buy.
private _ok = WARCOM_opfor_ap >= _price && {[_target, _price] call _execute};
if (_ok && {_price > 0}) then { ["OPF", -_price, format ["opcom_%1", _id]] call fnc_ap_adjust };

private _line = format ["%1%2%3%4", _label,
    [format ["  %1 AP", _price], ""] select (_price == 0),
    ["", format ["  score %1", _score toFixed 2]] select (_score >= 0),
    ["  (refused)", ""] select _ok];
["INFO", "OPCOM", format ["pick (%1): %2", _mode, _line]] call fnc_log;
[_line] call DUWS_fnc_opcom_aiEvent;
