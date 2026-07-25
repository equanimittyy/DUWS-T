// Locality: client; the map-click bodies below run on the machine that triggers them, not here (inherited from client/dialog/fnc_HQ_manual_place.sqf).
// Draw a prompt banner on the open map (findDisplay 12).
// The engine's hint box renders *beneath* the map, so any prompt issued while
// the map is open (forceMap/openMap) is invisible. A static structured-text
// control on the map display renders on top and is click-transparent, so the
// map's onMapSingleClick still fires under it. Pass "" to clear the banner.
params ["_text"];
disableSerialization;

private _disp = findDisplay 12;
if (isNull _disp) exitWith {};          // map not open -> nothing to draw on

private _idc = 91334;
private _ctrl = _disp displayCtrl _idc;

if (_text isEqualTo "") exitWith {
    if (!isNull _ctrl) then { ctrlDelete _ctrl };
};

private _x = safezoneX + safezoneW * 0.15;
private _y = safezoneY + safezoneH * 0.045;
private _w = safezoneW * 0.7;

if (isNull _ctrl) then {
    _ctrl = _disp ctrlCreate ["RscStructuredText", _idc];
    _ctrl ctrlSetBackgroundColor [0, 0, 0, 0.75];
};

// Fit the box to its content. Callers range from a two-line generation counter to a
// multi-line AO briefing, and RscStructuredText clips rather than grows: one fixed height
// either truncates the long prompt or leaves a slab of black over the map for the short one.
// Width has to be committed before measuring, because ctrlTextHeight depends on wrapping.
_ctrl ctrlSetPosition [_x, _y, _w, safezoneH * 0.2];
_ctrl ctrlCommit 0;
_ctrl ctrlSetStructuredText parseText format ["<t align='center'>%1</t>", _text];
_ctrl ctrlSetPosition [_x, _y, _w, (ctrlTextHeight _ctrl) + (safezoneH * 0.012)];
_ctrl ctrlCommit 0;
