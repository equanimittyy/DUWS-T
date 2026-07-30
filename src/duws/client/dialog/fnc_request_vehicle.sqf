// Locality: client -- invoked from a dialog action (shared/includes/request_menu.hpp:97).
_index = lbCurSel 2102;

_spawnPos = getpos bluHQ_object;
_spawnPos = [[(_spawnPos select 0), (_spawnPos select 1)],10,300,15,0,0.4,0,[],[]] call BIS_fnc_findSafePos;

///  50 VEHICLES MAX

if (_index < 2) exitWith {hint localize "STR_DUWS_T_9607znvh"};

if (_index > 10) then {
	_var = "blufor_RQST_VEHICLE_" + (str (_index - 1)) + "_X"; // Parse the name of the variable as a string
} else {
	_var = "blufor_RQST_VEHICLE_0" + (str (_index - 1)) + "_X"; // Parse the name of the variable as a string
};	
_vehicle = missionNamespace getVariable [_var, []];
// Refused before the spend: a row with no faction entry behind it must not charge CP, and
// `select 2` on the missing entry would otherwise throw with nothing said to the player.
if (_vehicle isEqualTo []) exitWith {hint localize "STR_DUWS_T_9607znvh"};

if !(["CP", _vehicle select 2] call fnc_pool_spend) exitWith {hint localize "STR_DUWS_T_e95mc4lv"};

_speaker = localize "STR_DUWS_T_OVERLORD";
_message = localize "STR_DUWS_T_vehicleready";
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
ctrlSetText [1000, format["%1",commandpointsblu1]];
_vehic = _vehicle select 0 createVehicle _spawnPos;


// give vehicle a marker
_markername = format["lbl%1",_spawnPos]; // Define marker name
createMarker [_markername, _spawnPos];
_markername setMarkerShape "ICON";
_markername setMarkerType "hd_objective";
_markername setMarkerColor "ColorBlue";
_markername setMarkerSize [.5,.5];
_markername setMarkerText localize "STR_DUWS_T_uhaz94ur";
sleep 60;
deletemarker _markername;