// Locality: server (callers remoteExec to target 2). It attaches no entries itself: the deploy and
// undeploy entries come from fnc_MHQ_addActions and the crate's from fnc_field_box_actions plus
// fnc_addQuickChangeActions, both broadcast to every machine and run there.

_empty = (count (crew MHQ1)) == 0;
if (!_empty) exitWith {
	["info",[localize "STR_DUWS_T_ywl7naen",localize "STR_DUWS_T_bnw9muay"]] remoteExec ['BIS_fnc_showNotification',[0,-2] select isDedicated,false];
	["deploy"] remoteExec ["fnc_MHQ_addActions", [0,-2] select isDedicated,"duws_mhq_actions"];
};

_mhqDir = getDir MHQ1;

// A supply crate and a camo net appear on top of whoever is stood beside the vehicle, so the deploy
// gets the same cover a FOB build does. Read before anything is created; handed back at the end.
private _fadePlayers = ["OUT", getPos MHQ1] call fnc_baseFade;

_groupMHQ = [[0,0], WEST, ["C_Soldier_VR_F"], [], [], blufor_ai_skill] call BIS_fnc_spawnGroup; 
_groupMHQ deleteGroupWhenEmpty true;
_MHQdriver = units _groupMHQ select 0;

hideObjectGlobal _MHQdriver;
_MHQdriver disableAI "ALL";
_MHQdriver setBehaviour "CARELESS";
_MHQdriver setCombatMode "BLUE";
_MHQdriver allowFleeing 0;
_MHQdriver enableSimulationGlobal false;
_MHQdriver forceSpeed 0;
_MHQdriver setVariable ["Vcm_Disable", true];   // disable VCOM AI if that mod is loaded
_MHQdriver setVariable ["lambs_danger_disableAI", true]; // disable LAMBS if that mod is loaded

_MHQdriver moveInDriver MHQ1;

_ammoPOS = MHQ1 getRelPos [6,120];
MHQ_ammobox = objNull;

switch (VERSION_X) do {
	case "MODERN": {
		MHQ_ammobox = createVehicle ["O_supplyCrate_F", _ammoPOS, [], 0, "CAN_COLLIDE"];
		[MHQ_ammobox, "MHQ"] call fnc_duws_keep;
	};
};	

MHQ_ammobox setDir _mhqDir;

// A field loadout station, not a loot crate: strip whatever cargo the class ships with so the box is
// empty and its only gear comes through the Arsenal.
clearWeaponCargoGlobal MHQ_ammobox;
clearMagazineCargoGlobal MHQ_ammobox;
clearItemCargoGlobal MHQ_ammobox;
clearBackpackCargoGlobal MHQ_ammobox;

// Two broadcasts, two JIP ids: the Arsenal/rearm pair keys on the box (its queue entry dies with the
// crate), and Quick Kits takes a distinct string id -- a second broadcast against the same id would
// evict the first and leave late joiners with only one of the two.
[MHQ_ammobox] remoteExec ["fnc_field_box_actions", [0,-2] select isDedicated, MHQ_ammobox];
[MHQ_ammobox] remoteExec ["fnc_addQuickChangeActions", 0, format ["mhq_quickchange_%1", netId MHQ_ammobox]];

sleep 0.2;

MHQ_tent = objNull;
MHQ_tent = createVehicle ["CamoNet_INDP_big_F", getPos MHQ1, [], 0, "CAN_COLLIDE"];
MHQ_tent setDir _mhqDir;

// Both objects are placed, so the screens can come back. Everything below this is markers, respawn
// registration and flags -- nothing anyone can see appearing.
["IN", _fadePlayers] call fnc_baseFade;

_markerType = "b_motor_inf";
if (MHQ1 isKindof "tank") then {_markerType = "b_armor"};

[MHQ1] remoteExec ["kndr_removeMarker", [0,-2] select isDedicated,false];
sleep 0.2;
[MHQ1, _markerType, "ColorYellow", 1, 1, localize "STR_DUWS_T_cmbq8ut7"] remoteExec ["kndr_assignMarker", [0,-2] select isDedicated,false];

_respawn_location = MHQ1 getRelPos [4,270];
MHQ_respawn = [west, _respawn_location] call BIS_fnc_addRespawnPosition;
publicVariable "MHQ_respawn";

MHQ_deployed = true;
publicVariable "MHQ_deployed";

["INFO", "SUPPORT", format ["MHQ deployed at %1", getPos MHQ1]] call fnc_log;

["undeploy"] remoteExec ["fnc_MHQ_addActions", [0,-2] select isDedicated,"duws_mhq_actions"];

MHQ1 setVehicleLock "LOCKED";

