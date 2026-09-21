// Locality: the player who opened it. Draws the civilian panel and greys the rows the server
// would refuse anyway.
//
// Everything greyed here is advisory. The money count is this machine's snapshot, the state flags
// are a broadcast copy, and the range is read once rather than polled -- the server re-tests all
// three when a row is actually picked. Greying spares the player a click that would fail; it
// decides nothing.
if (!hasInterface) exitWith {};

params ["_civilian"];
if (isNull _civilian) exitWith {};

// The dialog's action strings run outside this scope and have no access to the addAction's
// _target, so the civilian is handed over through a global.
DUWS_civ_target = _civilian;

if (!createDialog "civ_dialog") exitWith {};
waitUntil { dialog };

private _money = [player] call fnc_money_count;
ctrlSetText [8310, format [localize "STR_DUWS_T_CIV_MENU_MONEY", _money]];

private _closed = _civilian getVariable ["DUWS_civ_closed", false];

// These three grey together: one exchange -- served or refused -- closes the person for good, so
// there is no state where one of them is still open and another is not. No range test any more:
// the action that opens this menu is itself gated to the 3 m the rows work at, so a row can no
// longer be reached from further away than it functions.
{
    ctrlEnable [_x, !_closed];
} forEach [8341, 8342, 8343];

// Intel carries a second gate the others do not: one ask per player per 30-minute economy tick,
// spent on the attempt whatever the local answers. Read off the player because that is where the
// tick clears it. Advisory like the rest of this file -- fnc_civ_request re-reads the flag, so a
// dialog left open across a tick boundary cannot spend an ask the server has not granted.
ctrlEnable [8340, !_closed && !(player getVariable ["DUWS_civ_intel_asked", false])];

// Arrest greys on the same flag rather than carrying a second life: one exchange is all a person
// is worth, so talking to someone and then ordering their hands up is two.
ctrlEnable [8344, !_closed && !(_civilian getVariable ["DUWS_civ_arrested", false])];

private _mission = _civilian getVariable ["DUWS_civMission_state", ""];
private _giver = _mission != "";
private _funds = _civilian getVariable ["DUWS_civMission_funds", []];
if (_giver) then {
    ctrlSetText [8325, localize "STR_DUWS_T_CIVMISSION_ROW_REPORT"];
    ctrlSetText [8335, localize "STR_DUWS_T_CIVMISSION_ROW_REPORT_DESC"];
    ctrlSetText [8345, localize "STR_DUWS_T_CIVMISSION_REPORT"];
};
// A Raise Funds giver takes money instead of a report: the gift that meets the target ends the job.
if (_funds isNotEqualTo []) then {
    ctrlSetText [8325, localize "STR_DUWS_T_CIVMISSION_ROW_GIVE"];
    ctrlSetText [8345, localize "STR_DUWS_T_CIVMISSION_GIVE"];
    buttonSetAction [8345, "closeDialog 0; [DUWS_civ_target] spawn fnc_civ_give_menu;"];
};
ctrlEnable [8345, [[!_closed, _mission == "ready"] select _giver, _money > 0] select (_funds isNotEqualTo [])];
ctrlShow [8346, _giver];
