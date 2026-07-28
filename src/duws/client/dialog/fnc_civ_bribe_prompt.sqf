// Locality: the player the offer was made to -- fnc_civ_request remoteExecs it here when a roll
// comes back bribe.
//
// The amount arrives from the server and is displayed only. What goes back is a bare yes or no:
// the server holds which row was offered and what it costs, so this machine never names either.
if (!hasInterface) exitWith {};

params ["_civNetId", ["_bribe", 0]];

private _civilian = objectFromNetId _civNetId;
if (isNull _civilian) exitWith {};

DUWS_civ_target = _civilian;

// Read by the dialog's onUnload, which is what answers the offer. Set before the dialog exists
// so closing it in the same frame still sends a refusal rather than a nil.
DUWS_civ_bribe_accepted = false;

if (!createDialog "civ_bribe_dialog") exitWith {};
waitUntil { dialog };

private _coins = { _x == "Money_roll" } count (itemsWithMagazines player);
ctrlSetText [8410, format [localize "STR_DUWS_T_CIV_BRIBE_DEMAND", _bribe]];
ctrlSetText [8411, format [localize "STR_DUWS_T_CIV_MENU_COINS", _coins]];

// Advisory, like everything else the menu greys: the server reads the player's coins again
// before it deducts, because in co-op two players can spend the same ones. What greying buys is
// that an unaffordable demand reads as unaffordable instead of failing on click -- and since
// being unable to pay closes the civilian either way, the player at least sees the price first.
ctrlEnable [8420, _coins >= _bribe];
