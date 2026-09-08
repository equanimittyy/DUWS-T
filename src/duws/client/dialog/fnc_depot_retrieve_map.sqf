// Locality: client -- the "Retrieve (Map)" handler, spawned so it can hold the map open and wait on a
// click (fnc_map_pick_pos). The marked position and flat stored index go to the server, which re-derives
// and re-validates the ring rather than trusting this client's point.
//
// The bound is DUWS_base_keep_radius, not cosmetic: a vehicle outside it is collected by the base
// cleanup sweep (server/misc/fnc_repetitive_cleanup.sqf), so the pick re-prompts instead of accepting a
// spot that would hand the player a vehicle that later vanishes.
if (!hasInterface) exitWith {};

private _g = uiNamespace getVariable ["DUWS_depotMenu_activeGarage", -1];
if (_g < 0) exitWith { hint localize "STR_DUWS_T_GARAGE_NONE_SELECTED"; };
private _sel = lbCurSel _g;
if (_sel < 0) exitWith { hint localize "STR_DUWS_T_GARAGE_NONE_SELECTED"; };
private _index = parseNumber (lbData [_g, _sel]);

closeDialog 0;

if (isNil "PosOfBLUHQ" || {PosOfBLUHQ isEqualTo []}) exitWith { hint localize "STR_DUWS_T_DEPOT_MAP_OUTSIDE"; };

private _prompt = format ["<t size='2' color='#00ffff'>%1 </t><br/>%2",
    localize "STR_DUWS_T_DEPOT_MAP_PLACE", localize "STR_DUWS_T_DEPOT_MAP_HINT"];
// fnc_in_base_keep reads globals only, as the predicate must (see fnc_map_pick_pos), and the server
// re-runs it on the reported point.
private _pos = [
    _prompt,
    { [_this] call fnc_in_base_keep },
    localize "STR_DUWS_T_DEPOT_MAP_OUTSIDE"
] call fnc_map_pick_pos;
if (_pos isEqualTo []) exitWith {};

[player, _index, _pos] remoteExec ["fnc_garage_retrieve_map", 2];
