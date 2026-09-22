// Locality: client -- invoked from a dialog action (shared/includes/request_menu.hpp).
_sel = lbCurSel 2102;
if (_sel < 0) exitWith {};

// The faction-list index is read from lbData, not lbCurSel: the list is sorted by tier, so the row's
// position no longer matches the faction list. An empty data string is a header or spacer row.
_data = lbData [2102, _sel];
if (_data == "") exitWith {hint localize "STR_DUWS_T_9607znvh"};

_vehicle = (["VEHICLE"] call fnc_faction_rqst_list) param [parseNumber _data, []];
// Refused before the spend: a row with no faction entry behind it must not charge CP, and
// `select 2` on the missing entry would otherwise throw with nothing said to the player.
if (_vehicle isEqualTo []) exitWith {hint localize "STR_DUWS_T_9607znvh"};

// The row may be visible but locked. Refuse before the spend, naming the tier it needs.
_tier = [_vehicle select 0] call DUWS_fnc_vehTier;
if !(["BLU", _tier] call DUWS_fnc_ap_unlocked) exitWith {
    hint format [localize "STR_DUWS_T_tier_locked_hint", [_tier] call DUWS_fnc_tierName];
};

if !(["CP", _vehicle select 2] call fnc_pool_spend) exitWith {hint localize "STR_DUWS_T_e95mc4lv"};

[player, _vehicle select 0, getPosATL player, true, "STR_DUWS_T_REQUEST_VEHICLE_DELIVERED"] remoteExec ["fnc_depot_carry_spawn", 2];
