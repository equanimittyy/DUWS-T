// Locality: client; the map-click bodies below run on the machine that triggers them, not here (invoked from a dialog action).
// [salvos, radius, interval between salvos(in seconds), shots per salvo, support type, CP cost, ammotype] spawn fnc_mapclickarty
// AMMO TYPES:  Arty (R_80mm_HE) / Laser (Bo_Mk82) / Mortar(grenade) / JDAM (Bo_Mk82) / Cluster(grenade)
//  SUPPORT TYPE: 1 = arty, 2 = mortar, 3 = jdam, 4 = laser, 5 = cluster, 6 = napalm

_salvos = _this select 0;
_radius = _this select 1;
_interval = _this select 2;
_rps = _this select 3;
_supportype = _this select 4; // 1 = arty, 2 = mortar, 3 = jdam, 4 = laser, 5 = cluster, 6 = napalm
_cost = _this select 5; 
_ammotype = _this select 6;

_timer = 45;
clicked = false;

// The engine consumes the comm-menu entry when the player picks it, so every path that ends
// without firing has to hand it back or the support is gone for the rest of the mission.
_fnc_restoreCommMenu = {
	private _item = switch (_supportype) do {
		case 1: {"artillery"};
		case 2: {"mortar"};
		case 3: {"JDAM"};
		case 4: {"laser"};
		case 5: {"cluster"};
		case 6: {"napalm"};
		default {""};
	};
	if (_item isNotEqualTo "") then { [player, _item] call BIS_fnc_addCommMenuItem };
};

// IF NOT ENOUGH PTS
// Advisory only -- it skips a map-click window the player cannot pay for. fnc_arty makes
// the real decision, up to 45 s later.
if (commandpointsblu1 < _cost) exitWith {
	["info",[localize "STR_DUWS_T_e95mc4lv",format[localize "STR_DUWS_T_p6sb3ply",_cost]]] call bis_fnc_showNotification;
	sleep 30;
	call _fnc_restoreCommMenu;
};

_pos = [];
if (!(["ARTY", format["[_pos,%2,%3,%4,%5,%6,%7,'%8'] spawn fnc_arty; clicked = true; ['ARTY'] call fnc_mapclick_release",_pos,_salvos,_radius,_interval,_rps,_supportype,_cost,_ammotype]] call fnc_mapclick_claim)) exitWith {
	call _fnc_restoreCommMenu;
};
hint localize "STR_DUWS_T_4sqljq58";
//hint format["Position: %1\nSalvos:%2\nRadius:%3\nInterval:%4\nRPS:%5\nSupport type:%6\nCost:%7\nAmmo type:'%8'", _position, _salvos, _radius, _interval, _rps, _supportype, _cost, _ammotype];

// TIMER
while {_timer > 0 AND !clicked} do {

	_timer = _timer - 1; // remove 1 to timer
	sleep 1;
};

// TIMER ELLAPSED OR CLICKED

["ARTY"] call fnc_mapclick_release;

if (clicked) then {
	// make sure blufor has someone in range
	waitUntil {sleep 0.5;!isNil "arty_Blufor_close"};
	if !(arty_Blufor_close) exitWith {hint localize "STR_DUWS_T_7yy0wapp";arty_Blufor_close = nil};
	arty_Blufor_close = nil;
	// 5 min until next request
	sleep 300;
} else {
	hint localize "STR_DUWS_T_346eazcm";	
};

call _fnc_restoreCommMenu;
