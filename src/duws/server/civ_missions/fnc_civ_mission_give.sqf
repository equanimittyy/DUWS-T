// Locality: server, by remoteExecCall from civ_give_dialog. Unscheduled, so two players giving at once cannot
// both read the same shortfall and overpay it. Money given is spent: a cancel or the giver's death refunds none.
params ["_civ", "_caller", ["_amount", 0]];
if (isNull _civ || {isNull _caller} || {!alive _civ} || {_caller distance _civ > 3}) exitWith {};
private _id = _civ getVariable ["DUWS_civMission_id", -1];
private _e = DUWS_civMissions getOrDefault [_id, createHashMap];
if ((_e getOrDefault ["state", ""]) != "active" || {(_e getOrDefault ["target", 0]) == 0}) exitWith {};

private _target = _e get "target";
_amount = (floor _amount) min (_target - (_e get "raised"));
if (_amount < 1) exitWith {};
if !([_caller, _amount] call fnc_money_spend) exitWith {};

private _raised = (_e get "raised") + _amount;
_e set ["raised", _raised];
_civ setVariable ["DUWS_civMission_funds", [_raised, _target], true];
["INFO", "CIV", format ["civilian mission %1: %2 gave %3 (%4/%5)", _id, name _caller, _amount, _raised, _target]] call fnc_log;
if (_raised >= _target) exitWith {
    _e set ["by", _caller];
    _e set ["state", "reported"];
};
[localize "STR_DUWS_T_civ", format [localize "STR_DUWS_T_CIVMISSION_FUNDS_GIVEN", _raised, _target]] remoteExec ["fnc_duws_dialogue", _caller];
