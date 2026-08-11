// Locality: client -- invoked from a dialog action (shared/includes/request_menu.hpp:85).

_sel = lbCurSel 2101;
if (_sel < 0) exitWith {};

// The section token rides in lbData -- "HC:<type>" -- because tier-locked squads sort to the
// bottom and the row's position no longer names it. A heading or spacer carries no data.
_data = lbData [2101, _sel];
if (_data == "") exitWith {hint localize "STR_DUWS_T_9607znvh"};
_parts = _data splitString ":";
_row = [_parts select 1] call DUWS_fnc_squadRow;
if (_row isEqualTo []) exitWith {hint localize "STR_DUWS_T_9607znvh"};
_row params ["", "_globalName", "_HCsquadtype", "", "_tier"];

_squad = missionNamespace getVariable [_globalName, []];
if (count _squad < 2) exitWith {hint localize "STR_DUWS_T_9607znvh"};
_cost = _squad select 1;
_grouptype = _squad select 0;
// AP is charged only for the vehicle-fielding sections; infantry carries a 0 here.
_apCost = _squad param [2, 0];

// Tier gate before the charge, the same lock the greyed row advertises.
if !(["BLU", _tier] call DUWS_fnc_ap_unlocked) exitWith {
	hint format [localize "STR_DUWS_T_tier_locked_hint", [_tier] call DUWS_fnc_tierName];
};

_spawnPos = getpos player;
_spawnPos = [[(_spawnPos select 0), (_spawnPos select 1)],300,400,15,0,0.3,0,[],[]] call BIS_fnc_findSafePos;

sleep 2;

// Charge before spawning: the server rules on affordability, so a refused request must
// not leave a squad standing.
// A section with a vehicle charges both pools atomically; infantry charges CP alone. One verdict
// -- both halves debit or neither -- so a refusal never leaves the player charged for half a squad.
private _bought = if (_apCost > 0) then { ["CPAP", [_cost, _apCost]] call fnc_pool_spend } else { ["CP", _cost] call fnc_pool_spend };
if !(_bought) exitWith {hint localize "STR_DUWS_T_e95mc4lv";};

// Spawn, name, register and muster all happen on the server; it hands
// hcSetGroup back here, since that needs this machine's own player.
[_spawnPos, _grouptype, _HCsquadtype, player] remoteExec ["fnc_HCsquad_spawn", 2];

hint localize "STR_DUWS_T_gu6cbc5f";
_speaker = localize "STR_DUWS_T_OVERLORD";
_message = ([localize "STR_DUWS_T_squadready"] call fnc_cs);
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
