// Locality: client; the map-click bodies below run on the machine that triggers them, not here (invoked from a dialog action).
// [salvos, radius, interval between salvos(in seconds), shots per salvo, support type, CP cost, ammotype] spawn fnc_mapclickarty
// AMMO TYPES:  Arty (R_80mm_HE) / Laser (Bo_Mk82) / Mortar(grenade) / JDAM (Bo_Mk82) / Cluster(grenade)
//  SUPPORT TYPE: 1 = arty, 2 = mortar, 3 = jdam, 4 = laser, 5 = cluster, 6 = napalm, 7 = mortar smoke

_salvos = _this select 0;
_radius = _this select 1;
_interval = _this select 2;
_rps = _this select 3;
_supportype = _this select 4;
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
		case 7: {"mortar_smoke"};
		default {""};
	};
	if (_item isNotEqualTo "") then { [_item] call fnc_support_comm_add };
};

// Advisory only -- it skips a map-click window the player cannot pay for. fnc_arty makes
// the real decision, up to 45 s later.
if (commandpointsblu1 < _cost) exitWith {
	hint localize "STR_DUWS_T_e95mc4lv";
	sleep 30;
	call _fnc_restoreCommMenu;
};

// One fire mission per support type across the whole team. The unlock and the 300 s cooldown
// below are both per player, so two squad leads could otherwise walk mortars onto the map at the
// same moment and talk over each other on the net for the whole salvo. Claimed before the map
// opens, so a refusal costs the caller nothing but the hint.
if !([_supportype] call fnc_support_claim) exitWith {
	hint localize "STR_DUWS_T_SUPPORT_BUSY";
	call _fnc_restoreCommMenu;
};

// Laser skips the click flow: the jet loiters over the caller and drops on the player's own laser.
// fnc_arty owns the slot release, so this path only mirrors the click path's in-range reset and cooldown.
if (_supportype == 4) exitWith {
	[getPos player, _salvos, _radius, _interval, _rps, _supportype, _cost, _ammotype] spawn fnc_arty;
	waitUntil {sleep 0.5; !isNil "arty_Blufor_close"};
	arty_Blufor_close = nil;
	sleep 300;
	call _fnc_restoreCommMenu;
};

_pos = [];
// The handler releases before closing the map: the banner the release clears is a control on
// the map display and cannot be reached once it is gone.
if (!(["ARTY", format["[_pos,%2,%3,%4,%5,%6,%7,'%8'] spawn fnc_arty; clicked = true; ['ARTY'] call fnc_mapclick_release; openMap false",_pos,_salvos,_radius,_interval,_rps,_supportype,_cost,_ammotype]] call fnc_mapclick_claim)) exitWith {
	[_supportype] remoteExec ["fnc_support_release", 2];
	call _fnc_restoreCommMenu;
};

// Opened here rather than left to the player, so the brief can be drawn on the map like every
// other click mode: as a hint it was only ever readable in the gap before the player opened
// the map themselves, and not at all if they called this with the map already up.
openMap true;
[localize "STR_DUWS_T_4sqljq58"] call fnc_map_prompt;

// Closing the map is how the player backs out, so the wait ends there rather than holding the
// click slot for the rest of the timer. Tested after the sleep: visibleMap does not read true on
// the frame openMap is issued.
while {_timer > 0 AND !clicked} do {

	_timer = _timer - 1;
	sleep 1;
	if (!visibleMap) exitWith {};
};

["ARTY"] call fnc_mapclick_release;
openMap false;

// Each path that ends without ordnance hands the slot back. fnc_arty owns the release on the
// paths it reaches instead -- and the slot expires on its own besides, so a caller that drops
// out between the two cannot strand its support type for the rest of the campaign.
if (clicked) then {
	waitUntil {sleep 0.5;!isNil "arty_Blufor_close"};
	if !(arty_Blufor_close) exitWith {
		[_supportype] remoteExec ["fnc_support_release", 2];
		hint localize "STR_DUWS_T_7yy0wapp";
		arty_Blufor_close = nil;
	};
	arty_Blufor_close = nil;
	sleep 300;
} else {
	[_supportype] remoteExec ["fnc_support_release", 2];
	hint localize "STR_DUWS_T_346eazcm";	
};

call _fnc_restoreCommMenu;
