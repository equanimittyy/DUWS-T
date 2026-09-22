// Locality: client; the server's disguise monitor remoteExecs it whenever a bar segment changes, and
// with no arguments when the disguise ends, which hides the bar.
// A HUD layer, not the hint box: the bar stays up for the whole disguise, and in the hint box it would
// hide every other hint for that long.
params [["_meter", -1], ["_floor", 0], ["_civ", true]];

private _layer = "DUWS_DisguiseMeter" call BIS_fnc_rscLayer;
if (_meter < 0) exitWith { _layer cutText ["", "PLAIN"] };

private _bar = {
    params ["_n", "_colour"];
    private _s = "";
    for "_i" from 1 to _n do { _s = _s + "|" };
    format ["<t color='%1'>%2</t>", _colour, _s]
};
private _floorSeg = round (_floor / 5);
private _meterSeg = (round (_meter / 5)) max _floorSeg;
DUWS_disguiseMeterText = format [
    "%1<br/>%2<br/><t size='1.6'>%3%4%5</t>",
    localize (["STR_DUWS_T_DISGUISE_MENU_STATUS_ENEMY", "STR_DUWS_T_DISGUISE_MENU_STATUS_CIV"] select _civ),
    localize "STR_DUWS_T_DISGUISE_METER",
    [_floorSeg, "#b0b0b0"] call _bar,
    [_meterSeg - _floorSeg, "#ff4040"] call _bar,
    [20 - _meterSeg, "#404040"] call _bar
];

private _disp = uiNamespace getVariable ["DUWS_disguiseMeterDisplay", displayNull];
if (isNull _disp) exitWith { _layer cutRsc ["DUWS_DisguiseMeter", "PLAIN", 0, false] };
(_disp displayCtrl 8814) ctrlSetStructuredText parseText DUWS_disguiseMeterText;
