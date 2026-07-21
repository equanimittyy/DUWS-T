
_cost = _this select 0;
_timer = 60;
_pos = [];
clicked = false;

// IF NOT ENOUGH PTS
if (commandpointsblu1 < _cost) exitWith {
	["info",[localize "STR_DUWS_T_e95mc4lv",format[localize "STR_DUWS_T_p6sb3ply",_cost]]] call bis_fnc_showNotification;
	sleep 30;
	[player,"uav_recon"] call BIS_fnc_addCommMenuItem;
};

switch (VERSION_X) do {
	case "MODERN": {
		hint localize "STR_DUWS_T_01np5zjk";
	};
};	

//_cost OnMapSingleClick "[_pos,500,_this] spawn fnc_uav_scanner;
_cost OnMapSingleClick "[_pos,500,_this] remoteExec ['fnc_uav_scanner', 2];
	clicked=true;
	onMapSingleClick ''; 
	hint localize 'STR_DUWS_T_6u8qilfh'";

// TIMER
while {_timer>0 AND !clicked} do {
	_timer = _timer-1; // remove 1 to timer
	sleep 1;
};
// TIMER ELLAPSED OR CLICKED
sleep 80;
[player,"uav_recon"] call BIS_fnc_addCommMenuItem;
OnMapSingleClick "";