// Locality: server -- the OPCOM tick's pick stage (opcom_plan.md §The pick). `random` is kept as the unscored
// control: uniform over actions before targets, so a target-rich action does not crowd out the rest.
private _mode = DUWS_opcom_aiMode;
if (DUWS_opcom_pickOnce isNotEqualTo "") then {
    _mode = DUWS_opcom_pickOnce;
    DUWS_opcom_pickOnce = "";
};
if (_mode isEqualTo "off") exitWith {};

private _live = [];
// Unscheduled so every action reads one wallet and one store. The execute runs after, scheduled, because an order
// plans a route and the router may yield.
isNil {
    {
        private _row = _x;
        private _targets = ((_row param [4, []]) call (_row select 2)) select { (_x select 1) <= WARCOM_opfor_ap };
        if (_targets isNotEqualTo []) then { _live pushBack [_row, _targets] };
    } forEach DUWS_opcom_actions;
};
if (_live isEqualTo []) exitWith {};

private _row = [];
private _cand = [];
private _score = -1;
if (_mode isEqualTo "weighted") then {
    // Cost floors at 1: a free action would divide by zero, and its Value is already its score.
    private _all = [];
    {
        _x params ["_r", "_ts"];
        {
            private _price = _x select 1;
            _all pushBack [(_x param [4, 1]) * (_x param [3, _price]) / (_price max 1), _r, _x];
        } forEach _ts;
    } forEach _live;

    // Rank an index list, never the candidates: a tie would fall through to comparing rows, and a row holds code.
    private _rank = [];
    { _rank pushBack [_x select 0, _forEachIndex] } forEach _all;
    _rank sort false;

    private _draw = [];
    {
        _x params ["_s", "_i"];
        if (_s <= 0 || {count _draw >= OPCOM_PICK_TOP * 2}) then { break };
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

_row params ["_id", "", "", "_execute"];
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
