// Locality: the player giving, from the civilian menu's first row on a Raise Funds giver. The slider is capped at
// what the player carries and what the giver still needs; the server re-reads both before it takes the money.
if (!hasInterface) exitWith {};

params ["_civilian"];
(_civilian getVariable ["DUWS_civMission_funds", [0, 0]]) params ["_raised", "_target"];
private _max = ([player] call fnc_money_count) min (_target - _raised);

if (!createDialog "civ_give_dialog") exitWith {};
waitUntil { dialog };

ctrlSetText [8432, format [localize "STR_DUWS_T_CIVMISSION_FUNDS_RAISED", _raised, _target]];
sliderSetRange [8434, 0, _max];
sliderSetSpeed [8434, 1, 1];
sliderSetPosition [8434, _max];
ctrlSetText [8433, format [localize "STR_DUWS_T_CIVMISSION_GIVE_AMOUNT", _max]];
