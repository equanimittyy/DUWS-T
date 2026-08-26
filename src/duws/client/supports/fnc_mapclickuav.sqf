// Locality: client; the map-click body below runs on the machine that triggers it, not
// here (invoked from the comm menu, shared/includes/supports_radio_modern.hpp:137).

_cost = _this select 0;
_timer = 60;
_pos = [];
clicked = false;

// Advisory only -- it skips a map-click window the player cannot pay for. fnc_uav_scanner
// makes the real decision on the server, up to 60 s later.
if (commandpointsblu1 < _cost) exitWith {
	["info",[localize "STR_DUWS_T_e95mc4lv",format[localize "STR_DUWS_T_p6sb3ply",_cost]]] call bis_fnc_showNotification;
	sleep 30;
	["uav_recon"] call fnc_support_comm_add;
};

// _cost rides the binary form so the handler can read the price out of _this. It releases
// before closing the map, because the banner the release clears lives on the map display. The
// request/copy/tasking exchange all run server-side in fnc_uav_scanner once this hands off.
if (!(["UAV", "[_pos,500,_this,player] remoteExec ['fnc_uav_scanner', 2];
	clicked=true;
	['UAV'] call fnc_mapclick_release;
	openMap false", _cost] call fnc_mapclick_claim)) exitWith {
	// The comm-menu entry is consumed on selection, so a refusal has to hand it back.
	["uav_recon"] call fnc_support_comm_add;
};

// Opened here rather than left to the player, so the brief can be drawn on the map like every
// other click mode: as a hint it was only ever readable in the gap before the player opened
// the map themselves, and not at all if they called this with the map already up.
openMap true;
// A future gamemode adds its own case above the default. The brief sits in the default rather
// than in a "MODERN" case so that mode inherits one: now that this forces the map open, a
// version with no line of its own would strand the player on a map saying nothing.
switch (VERSION_X) do {
	default { [localize "STR_DUWS_T_01np5zjk"] call fnc_map_prompt; };
};

// Closing the map is how the player backs out now that this opens it, so the wait ends there
// too rather than holding the click slot for the rest of the timer. Tested after the sleep:
// visibleMap does not read true on the frame openMap is issued.
while {_timer>0 AND !clicked} do {
	_timer = _timer-1;
	sleep 1;
	if (!visibleMap) exitWith {};
};
["UAV"] call fnc_mapclick_release;
openMap false;
// One-time use: a dispatched UAV is spent; a backed-out click (map closed, timer out) leaves the
// flag set and hands the item back instead.
if (clicked) then {
	["uav_recon"] call fnc_support_consume;
} else {
	["uav_recon"] call fnc_support_comm_add;
};