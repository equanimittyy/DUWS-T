_index = lbCurSel 2122;

_spawnPos = getpos player;
_spawnPos = [[(_spawnPos select 0), (_spawnPos select 1)],10,300,15,0,0.4,0,[],[]] call BIS_fnc_findSafePos;
//_spawnPos = [(_spawnPos select 0)+30, _spawnPos select 1];


_setmrkr = false;

///  10 VEHICLES MAX

if (_index < 2) exitWith {hint localize "STR_DUWS_T_9607znvh"};

_var = "";
if (_index > 10) then {
	_var = "blufor_RQST_VEHICLE_" + (str (_index - 1)) + "_X"; // Parse the name of the variable as a string
} else {
	_var = "blufor_RQST_VEHICLE_0" + (str (_index - 1)) + "_X"; // Parse the name of the variable as a string
};	
_vehicle = call (compile _var); // Get the vehicle variable

if (commandpointsblu1 >= _vehicle select 2) then {
    _speaker = localize "STR_DUWS_T_dispatcher";
    _message = localize "STR_DUWS_T_vehicleready";
    [_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
    [] remoteExec ["fnc_broadcastRadioChatter", 0]; 
    commandpointsblu1 = commandpointsblu1 - (_vehicle select 2);
    ctrlSetText [1000, format["%1",commandpointsblu1]];      
    publicVariable "commandpointsblu1";
    _vehic = _vehicle select 0 createVehicle _spawnPos;
	_setmrkr = true;
} else {
	hint localize "STR_DUWS_T_e95mc4lv";
};

publicVariable "commandpointsblu1";
//hint format["index: %1",_index];

// give vehicle a marker
if (_setmrkr) then {
	_markername = format["lbl%1%2",_spawnPos]; // Define marker name
	//hint _markername;
	_markerstr = createMarker [str(_markername), _spawnPos];
	_markerstr setMarkerShape "ICON";
	str(_markername) setMarkerType "hd_objective";
	str(_markername) setMarkerColor "ColorBlue";
	str(_markername) setMarkerSize [.5,.5]; 
	str(_markername) setMarkerText localize "STR_DUWS_T_uhaz94ur";
	sleep 60;
	deletemarker str(_markername);
};
      
    publicVariable "commandpointsblu1";