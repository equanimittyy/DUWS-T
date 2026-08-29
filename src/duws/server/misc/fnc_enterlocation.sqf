// Locality: server -- inherited from server/init_zones/fnc_createzone.sqf.
// The zone presence trigger's only job is the hardcore reveal. It does not announce arrivals or
// departures: on a map of this many zones that is noise rather than information -- a zone the
// player is standing in does not need naming. With no departure line, nothing holds a wait open
// for the trigger list.


_name =			_this select 0;
_zonePos =		_this select 1;
_markername =	_this select 2;
_markername2 =	_this select 3;

["INFO", "ZONES", format ["Enter Zone: %1  POS: %2  markers: %3  %4", _name, _zonePos, _markername, _markername2]] call fnc_log;

if (hardcore_mode_enable && "Zone" in _name) then {
	["ONE",_zonePos] call fnc_zone_reveal;
};
