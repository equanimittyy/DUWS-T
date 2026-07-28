// Locality: server -- inherited from server/init_zones/fnc_createzone.sqf.


_name =			_this select 0;
_zonePos =		_this select 1;
_markername =	_this select 2;
_markername2 =	_this select 3;
_trigger =		_this select 4;
_firstBlu =		_trigger select 0;

["INFO", "ZONES", format ["Enter Zone: %1  POS: %2  markers: %3  %4", _name, _zonePos, _markername, _markername2]] call fnc_log;

sleep 0.5;

["location_enter",[_name,""]] remoteExec ['BIS_fnc_showNotification',[0,-2] select isDedicated,false];

// If HARDCORE and Zone entered, make Zone visible
if (hardcore_mode_enable && "Zone" in _name) then {
	["ONE",_zonePos] call fnc_zone_reveal;
};

waitUntil {
	sleep 5;
    count _trigger < 1;
}; 

["location_leave",[_name,""]] remoteExec ['BIS_fnc_showNotification',[0,-2] select isDedicated,false];

