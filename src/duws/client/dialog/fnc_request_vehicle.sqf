// Locality: client -- invoked from a dialog action (shared/includes/request_menu.hpp:97).
_index = lbCurSel 2102;

_spawnPos = getpos bluHQ_object;
_spawnPos = [[(_spawnPos select 0), (_spawnPos select 1)],10,300,15,0,0.4,0,[],[]] call BIS_fnc_findSafePos;
//_spawnPos = [(_spawnPos select 0)+30, _spawnPos select 1];

///  50 VEHICLES MAX

if (_index < 2) exitWith {hint localize "STR_DUWS_T_9607znvh"};

_var = "";
if (_index > 10) then {
	_var = "blufor_RQST_VEHICLE_" + (str (_index - 1)) + "_X"; // Parse the name of the variable as a string
} else {
	_var = "blufor_RQST_VEHICLE_0" + (str (_index - 1)) + "_X"; // Parse the name of the variable as a string
};	
_vehicle = call (compile _var); // Get the vehicle variable

if !(["CP", _vehicle select 2] call fnc_pool_spend) exitWith {hint localize "STR_DUWS_T_e95mc4lv"};

_speaker = localize "STR_DUWS_T_OVERLORD";
_message = localize "STR_DUWS_T_vehicleready";
[_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];
ctrlSetText [1000, format["%1",commandpointsblu1]];
_vehic = _vehicle select 0 createVehicle _spawnPos;

//hint format["index: %1",_index];

// give vehicle a marker
_markername = format["lbl%1",_spawnPos]; // Define marker name
//hint _markername;
createMarker [_markername, _spawnPos];
_markername setMarkerShape "ICON";
_markername setMarkerType "hd_objective";
_markername setMarkerColor "ColorBlue";
_markername setMarkerSize [.5,.5];
_markername setMarkerText localize "STR_DUWS_T_uhaz94ur";
sleep 60;
deletemarker _markername;