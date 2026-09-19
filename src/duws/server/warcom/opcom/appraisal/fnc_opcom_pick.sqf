// Locality: server -- the OPCOM tick's pick stage. Uniform over actions before targets, so a target-rich action does not
// crowd out the rest.
if (DUWS_opcom_aiMode isEqualTo "off" && {!DUWS_opcom_pickOnce}) exitWith {};
DUWS_opcom_pickOnce = false;

private _live = [];
// Unscheduled so every action reads one wallet and one store. The execute runs after, scheduled, because an order plans
// a route and the router may yield.
isNil {
    {
        private _targets = (call (_x select 2)) select { (_x select 1) <= WARCOM_opfor_ap };
        if (_targets isNotEqualTo []) then { _live pushBack [_x, _targets] };
    } forEach DUWS_opcom_actions;
};

(selectRandom _live) params ["_row", "_targets"];
_row params ["_id", "", "", "_execute"];
(selectRandom _targets) params ["_target", "_price", "_label"];
// Re-checked: the wallet can drop after the snapshot, and fnc_ap_adjust would clamp the overdraft to a free buy.
private _ok = WARCOM_opfor_ap >= _price && {[_target, _price] call _execute};
if (_ok && {_price > 0}) then { ["OPF", -_price, format ["opcom_%1", _id]] call fnc_ap_adjust };

private _line = format ["%1%2%3", _label, [format ["  %1 AP", _price], ""] select (_price == 0), ["  (refused)", ""] select _ok];
["INFO", "OPCOM", format ["pick (%1): %2", DUWS_opcom_aiMode, _line]] call fnc_log;
