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

// The menu opens at arrest range so a standoff can still order hands up, which leaves the four
// conversational rows reachable from further than they work. Read once, deliberately: walking in
// and reopening is what a conversation costs.
private _inRange = (player distance _civilian) <= 3;

// All four rows grey together: one exchange -- served or refused -- closes the person for good,
// so there is no state where one row is still open and another is not.
{
    ctrlEnable [_x, !_closed && _inRange];
} forEach [8340, 8341, 8342, 8343];

// Arrest survives the closed flag: a town's opinion does not change whether a person raises
// their hands, and refusing to talk is not protection from being detained. Its one-shot is its
// own, spent on the attempt rather than on the outcome.
ctrlEnable [8344, !(_civilian getVariable ["DUWS_civ_arrested", false])];
