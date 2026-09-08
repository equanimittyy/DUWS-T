// Locality: client -- the "Retrieve (Map)" handler, spawned so it can hold the map open and wait on a
// click. The marked position and flat stored index go to the server, which re-derives and re-validates
// the ring rather than trusting this client's point.
//
// The bound is DUWS_base_keep_radius, not cosmetic: a vehicle outside it is collected by the base
// cleanup sweep (server/misc/fnc_repetitive_cleanup.sqf), so the click loop re-prompts instead of
// accepting a spot that would hand the player a vehicle that later vanishes.
if (!hasInterface) exitWith {};

private _g = uiNamespace getVariable ["DUWS_depotMenu_activeGarage", -1];
if (_g < 0) exitWith { hint localize "STR_DUWS_T_GARAGE_NONE_SELECTED"; };
private _sel = lbCurSel _g;
if (_sel < 0) exitWith { hint localize "STR_DUWS_T_GARAGE_NONE_SELECTED"; };
private _index = parseNumber (lbData [_g, _sel]);

closeDialog 0;

if (isNil "PosOfBLUHQ" || {PosOfBLUHQ isEqualTo []}) exitWith { hint localize "STR_DUWS_T_DEPOT_MAP_OUTSIDE"; };
// Fallback matches the server constant so a JIP client that missed the broadcast still bounds the same.
private _radius = missionNamespace getVariable ["DUWS_base_keep_radius", 250];

DUWS_depotMapClicked = false;
DUWS_depotMapPos = [];

openMap [true, false];
waitUntil { !isNull (findDisplay 12) };
// Banner not hint: the hint box draws beneath the open map (client/dialog/fnc_map_prompt.sqf).
private _prompt = format ["<t size='2' color='#00ffff'>%1 </t><br/>%2",
    localize "STR_DUWS_T_DEPOT_MAP_PLACE", localize "STR_DUWS_T_DEPOT_MAP_HINT"];
[_prompt] call fnc_map_prompt;
onMapSingleClick "DUWS_depotMapPos = _pos; DUWS_depotMapClicked = true; onMapSingleClick ''; true";

private _done = false;
while {visibleMap && {!_done}} do {
    waitUntil { DUWS_depotMapClicked || {!visibleMap} };
    if (DUWS_depotMapClicked) then {
        if ((DUWS_depotMapPos distance2D PosOfBLUHQ) <= _radius) then {
            _done = true;
        } else {
            // The handler self-clears after firing, so a rejected click must re-arm it.
            DUWS_depotMapClicked = false;
            [format ["%1<br/><t color='#ff1111'>%2</t>", _prompt, localize "STR_DUWS_T_DEPOT_MAP_OUTSIDE"]] call fnc_map_prompt;
            onMapSingleClick "DUWS_depotMapPos = _pos; DUWS_depotMapClicked = true; onMapSingleClick ''; true";
        };
    };
};

onMapSingleClick "";
[""] call fnc_map_prompt;
if (!_done) exitWith {};  // player closed the map to cancel
openMap [false, false];

[player, _index, DUWS_depotMapPos] remoteExec ["fnc_garage_retrieve_map", 2];
