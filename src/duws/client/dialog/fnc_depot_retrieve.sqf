// Locality: client -- Retrieve dispatcher on whoever opens the depot. Sends the stored index and pad
// netId to the server; the player positions the vehicle by hand via the R3F carry (fnc_depot_place_r3f).
if (!hasInterface) exitWith {};

private _g = uiNamespace getVariable ["DUWS_depotMenu_activeGarage", -1];
if (_g < 0) exitWith { hint localize "STR_DUWS_T_GARAGE_NONE_SELECTED"; };
private _sel = lbCurSel _g;
if (_sel < 0) exitWith { hint localize "STR_DUWS_T_GARAGE_NONE_SELECTED"; };
private _index = parseNumber (lbData [_g, _sel]);
private _padNet = uiNamespace getVariable ["DUWS_depotMenu_ctx", ""];

closeDialog 0;

[player, _index, _padNet] remoteExec ["fnc_garage_retrieve", 2];
