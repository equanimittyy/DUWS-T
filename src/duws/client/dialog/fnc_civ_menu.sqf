// Locality: the player who opened it. Draws the civilian panel and greys the rows the server
// would refuse anyway.
//
// Everything greyed here is advisory. The coin count is this machine's snapshot, the state flags
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

private _coins = [player] call fnc_coins_count;
ctrlSetText [8310, format [localize "STR_DUWS_T_CIV_MENU_COINS", _coins]];

private _closed = _civilian getVariable ["DUWS_civ_closed", false];

// All four rows grey together: one exchange -- served or refused -- closes the person for good,
// so there is no state where one row is still open and another is not. No range test any more:
// the action that opens this menu is itself gated to the 3 m the rows work at, so a row can no
// longer be reached from further away than it functions.
{
    ctrlEnable [_x, !_closed];
} forEach [8340, 8341, 8342, 8343];

// Arrest greys on the same flag rather than carrying a second life: one exchange is all a person
// is worth, so talking to someone and then ordering their hands up is two.
ctrlEnable [8344, !_closed && !(_civilian getVariable ["DUWS_civ_arrested", false])];
