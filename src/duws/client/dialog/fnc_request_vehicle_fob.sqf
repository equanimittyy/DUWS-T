// Locality: client -- invoked from a dialog action (shared/includes/request_menu.hpp, the FOB form).
_sel = lbCurSel 2102;
if (_sel < 0) exitWith {};

_spawnPos = getpos player;
_spawnPos = [[(_spawnPos select 0), (_spawnPos select 1)],10,300,15,0,0.4,0,[],[]] call BIS_fnc_findSafePos;


///  10 VEHICLES MAX

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
    hint format [localize "STR_DUWS_T_tier_locked_hint", _tier];
};

if !(["CP", _vehicle select 2] call fnc_pool_spend) exitWith {hint localize "STR_DUWS_T_e95mc4lv"};

_speaker = localize "STR_DUWS_T_OVERLORD";
_message = localize "STR_DUWS_T_vehicleready";
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
_vehicle select 0 createVehicle _spawnPos;


// give vehicle a marker
_markername = format["lbl%1%2",_spawnPos]; // Define marker name
_markerstr = createMarker [str(_markername), _spawnPos];
_markerstr setMarkerShape "ICON";
str(_markername) setMarkerType "hd_objective";
str(_markername) setMarkerColor "ColorBlue";
str(_markername) setMarkerSize [.5,.5];
str(_markername) setMarkerText localize "STR_DUWS_T_uhaz94ur";
sleep 60;
deletemarker str(_markername);
