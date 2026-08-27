// Locality: client -- invoked from the comm menu (shared/includes/supports_radio_modern.hpp), which
// defers the consume so a cancelled pick hands the item back.
//
// Vehicle drop requisition. The player buys a motorised-or-lower faction hull from the same
// list the request menu prices and it is para-dropped empty on their position. The support unlock
// already charged the delivery fee, so the drop itself costs only the vehicle's own CP.
if (!hasInterface) exitWith {};
params ["_caller"];
private _location = getpos _caller;

// A light transport and nothing heavier: cars and armed cars, no APC/tank/air/UAV/truck. Kind is the
// request-menu classifier, so a modded faction's hulls sort here exactly as they do in its request list.
// Tier-locked hulls are dropped from the list here so the player only sees what the ladder has unlocked;
// the post-pick tier check below still guards a co-op AP drop mid-dialog.
private _list = (["VEHICLE"] call fnc_faction_rqst_list) select {
    (([_x select 0] call DUWS_fnc_vehKind) in ["lightUnarmed", "armedCar"])
    && {["BLU", [_x select 0] call DUWS_fnc_vehTier] call DUWS_fnc_ap_unlocked}
};
if (_list isEqualTo []) exitWith {
    hint localize "STR_DUWS_T_veh_drop_none";
    ["veh_drop"] call fnc_support_comm_add;
};

DUWS_vehdrop_pick = "";
DUWS_vehdrop_confirmed = false;
if (!createDialog "veh_drop_dialog") exitWith { ["veh_drop"] call fnc_support_comm_add };
waitUntil { dialog };

lbClear 8510;
{
    private _i = lbAdd [8510, _x select 1];
    lbSetData [8510, _i, _x select 0];
} forEach _list;
lbSetCurSel [8510, 0];

waitUntil { !dialog };

// Escaped or Closed: no charge, no consume, the one-use item comes back.
if (!DUWS_vehdrop_confirmed || {DUWS_vehdrop_pick == ""}) exitWith {
    ["veh_drop"] call fnc_support_comm_add;
};

private _class = DUWS_vehdrop_pick;

// Visible but tier-locked: refuse before the spend, name the tier, hand the item back so the pick
// can be retried once the ladder allows it.
private _tier = [_class] call DUWS_fnc_vehTier;
if !(["BLU", _tier] call DUWS_fnc_ap_unlocked) exitWith {
    hint format [localize "STR_DUWS_T_tier_locked_hint", [_tier] call DUWS_fnc_tierName];
    ["veh_drop"] call fnc_support_comm_add;
};

// Priced through the shared classifier, not the list label, so the charge is authoritative.
private _cost = [_class] call DUWS_fnc_vehPrice;
if !(["CP", _cost] call fnc_pool_spend) exitWith {
    ["info", [localize "STR_DUWS_T_e95mc4lv", format [localize "STR_DUWS_T_p6sb3ply", _cost]]] call bis_fnc_showNotification;
    ["veh_drop"] call fnc_support_comm_add;
};

// Paid and committed past every abort above: spend the one-use item now.
ctrlSetText [1000, format ["%1", commandpointsblu1]];
["veh_drop"] call fnc_support_consume;

_speaker = localize "STR_DUWS_T_actionteam";
_speaker1 = localize "STR_DUWS_T_courier2";
_message = localize "STR_DUWS_T_vehdropcall";
_message1 = localize "STR_DUWS_T_vehdropcallend";
[_speaker, _message, "", name player] remoteExec ["fnc_duws_dialogue", 0];
[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_vehdropack"] remoteExec ["fnc_duws_dialogue", 0];

// SEND A PLANE -- offset the spawn 1200 m off a random bearing so it flies in rather than appearing overhead.
private _vec = [random [-1,0,1], random [-1,0,1], 0];
private _spawnPos = ((vectorNormalized _vec) vectorMultiply 1200) vectorAdd _location;
_spawnPos = [_spawnPos select 0, _spawnPos select 1, (_spawnPos select 2) + 400];
missionNamespace setVariable ["VEHDROP_onStation", false];

private _group = [_spawnPos, WEST, [blufor_TRANS_HELI_X], [], [], blufor_ai_skill] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;
private _pilot = units _group select 0;
private _vehicle = vehicle _pilot;
_vehicle setVehicleAmmo 0;
_vehicle allowdamage false;
// Cosmetic transport: crew hold fire and don't acquire, so it flies the drop run instead of engaging.
_pilot disableAI "Target";
_pilot disableAI "AUTOTARGET";
_group setCombatMode "BLUE";
_vehicle engineOn true;

private _wp1 = _group addWaypoint [_location, -1];
_wp1 setWaypointType "MOVE";
_wp1 setWaypointBehaviour "CARELESS";
_wp1 setWaypointStatements ["true", "missionNamespace setVariable ['VEHDROP_onStation', true]"];
private _wp2 = _group addWaypoint [[0,0], 100];
_wp2 setWaypointType "MOVE";
_wp2 setWaypointBehaviour "CARELESS";

sleep 8;
[_speaker1, _message1] remoteExec ["fnc_duws_dialogue", 0];
waitUntil { sleep 0.5; (missionNamespace getVariable "VEHDROP_onStation") || !alive _vehicle };

if (!alive _vehicle) exitWith {
    [localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_vehdropdown"] remoteExec ["fnc_duws_dialogue", 0];
    missionNamespace setVariable ["VEHDROP_onStation", nil];
    { deleteVehicle _x } forEach units _group;
    deleteVehicle _vehicle;
};

private _parachute = "Steerable_Parachute_F" CreateVehicle _location;
_parachute setPos [_location select 0, _location select 1, (_location select 2) + 100];
private _cargo = CreateVehicle [_class, [_location select 0, _location select 1, (_location select 2) + 50], [], 0, "CAN_COLLIDE"];
_cargo attachTo [_parachute, [0,0,0]];

[localize "STR_DUWS_T_courier2", localize "STR_DUWS_T_vehdroponstation"] remoteExec ["fnc_duws_dialogue", 0];
hint localize "STR_DUWS_T_iv3s5xlc";
sleep 30;
deleteVehicle _parachute;
sleep 7;
"SmokeShellGreen" CreateVehicle (getpos _cargo);
_cargo setVehicleArmor 1;

sleep 60;
{ deleteVehicle _x } forEach units _group;
deleteVehicle _vehicle;
missionNamespace setVariable ["VEHDROP_onStation", nil];
