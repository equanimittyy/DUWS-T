// Locality: server -- inherited from server/init_zones/fnc_createzone.sqf.
// The zone presence trigger's only remaining job is the hardcore reveal. It used to announce every
// arrival and departure to every player, which on a map of this many zones is noise rather than
// information -- a zone the player is standing in does not need naming to them. Removing the
// departure line is what retires the wait this function used to hold open for the trigger list.


_name =			_this select 0;
_zonePos =		_this select 1;
_markername =	_this select 2;
_markername2 =	_this select 3;

["INFO", "ZONES", format ["Enter Zone: %1  POS: %2  markers: %3  %4", _name, _zonePos, _markername, _markername2]] call fnc_log;

// If HARDCORE and Zone entered, make Zone visible
if (hardcore_mode_enable && "Zone" in _name) then {
	["ONE",_zonePos] call fnc_zone_reveal;
};
