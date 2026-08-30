// Locality: server -- callers remoteExec to target 2.
params ["_MissionPos", "_mission_name"];
private _requester = remoteExecutedOwner;
if (!([14, _MissionPos, _mission_name, _requester] call fnc_mission_begin)) exitWith {};


_radius = 600;
_deliverDist = 50;
// Town goodwill: handing the aid back lifts the delivery town, losing the truck sours it the same amount.
// The mission's REP column mirrors the win figure for the briefing line.
_repWin = 3;
_repFail = -3;
_deadline = DUWS_curDeadlineAt;
_speakerIDAP = localize "STR_DUWS_T_IDAP";
_speaker = localize "STR_DUWS_T_OVERLORD";
_speakeracteam = localize "STR_DUWS_T_actionteam";
_message = localize "STR_DUWS_T_idapletsdothis";
_message1 = localize "STR_DUWS_T_idapcopy";
_message2 = localize "STR_DUWS_T_idapacteamgo";
_messageClose = localize "STR_DUWS_T_idapoverlordclose";
_messageLost = localize "STR_DUWS_T_idaptruckdown";

// The crew's haven: nearest neutral/BLUFOR town, matching what the site-finder vetted (a town in the OPFOR
// band is no hand-over point). duws_town_circles is index-aligned with civ_locations, so its index is what
// fnc_town_rep_adjust takes. If the last non-enemy town flipped in the gap, abort.
private _enemyTowns = missionNamespace getVariable ["DUWS_enemy_town_pos", []];
private _circles = missionNamespace getVariable ["duws_town_circles", []];
private _townIdx = -1;
private _townPos = [];
private _bestD = 1e9;
{
    _x params ["_c", ""];
    if ((_enemyTowns findIf { _x distance2D _c < 5 }) < 0) then {
        private _d = _c distance2D _MissionPos;
        if (_d < _bestD) then { _bestD = _d; _townPos = _c; _townIdx = _forEachIndex };
    };
} forEach _circles;
if (_townIdx < 0) exitWith { [14, _requester, "no_delivery_town"] call fnc_mission_abort; };

// IDAP's thanks names the delivery town (the location's own name, nearest-location fallback, then a
// generic if the map left it unnamed) so the sign-off reads for the place the player just drove to.
private _townName = text ((missionNamespace getVariable ["civ_locations", []]) select _townIdx);
if (_townName == "") then { _townName = text (nearestLocation [_townPos, ""]) };
if (_townName == "") then { _townName = localize "STR_DUWS_T_idap_town_generic" };
private _message3 = format [localize "STR_DUWS_T_idapend", _townName];

private _site = [_MissionPos, _radius, 14, _requester] call fnc_mission_site;
if (_site isEqualTo []) exitWith {};
_site params ["_randomPos", "_Building", "_targetpos"];

private _VARtaskgeneratedName = format ["rescue%1%2", round(_MissionPos select 0), round(_MissionPos select 1)];
[_requester, "STR_DUWS_T_MISSION_GEN_BUILD"] call fnc_mission_notice;

_vehPos = _targetpos;

// The objective itself: kept for the mission's duration so the abandoned-vehicle sweep cannot collect it.
_truck1 = "C_Truck_02_transport_F" createVehicle _vehPos;
[_truck1, "mission_transport_idap"] call fnc_duws_keep;

_box1 = "";
_box2 = "";
_static1 = "";
_static2 = "";
switch (VERSION_X) do {
    case "MODERN": {
        _box1 = "Land_FoodSacks_01_cargo_white_idap_F" createVehicle _vehPos;
        _box2 = "Land_FoodSacks_01_cargo_white_idap_F" createVehicle _vehPos;
        { [_x, "mission_transport_idap"] call fnc_duws_keep; } forEach [_box1, _box2];
        _box1 attachTo [_truck1, [0, -0.5, 0]];
        _box1 setDir 90;
        _box2 attachTo [_truck1, [0, -2.2, 0]];
        _box2 setDir 75;
        _static1 = "CargoNet_01_barrels_F";
        _static2 = "CamoNet_INDP_open_F";
    };
};

_obj1 = createVehicle [_static1, [(_vehPos select 0)-12, (_vehPos select 1)-10], [], 0, "CAN_COLLIDE"];
[_obj1, "mission_transport_idap"] call fnc_duws_keep;
sleep 1;
_obj2 = createVehicle [_static1, [(_vehPos select 0)-10, (_vehPos select 1)-10], [], 0, "CAN_COLLIDE"];
[_obj2, "mission_transport_idap"] call fnc_duws_keep;
sleep 1;
_obj3 = createVehicle [_static1, [(_vehPos select 0)-8, (_vehPos select 1)-10], [], 0, "CAN_COLLIDE"];
[_obj3, "mission_transport_idap"] call fnc_duws_keep;
sleep 1;
_obj4 = createVehicle [_static2, [(_vehPos select 0)-10, (_vehPos select 1)-10], [], 0, "CAN_COLLIDE"];
[_obj4, "mission_transport_idap"] call fnc_duws_keep;
sleep 1;

// Guard force, the stolen-supply shape: idle team, close + two wide foot patrols, plus vehicle patrols
// that scale with earned AP -- tokenClass returns "" for a gated token, so a car joins at 60 AP and a
// second car-or-ifv at 150 AP.
private _claim = { [_this] call fnc_mission_claim };
(["team", _targetpos, _radius, "none", _targetpos] call fnc_spawn_team) call _claim;   // idle, on the objective
(["team", _targetpos, _radius, "closepatrol"] call fnc_spawn_team) call _claim;
for "_i" from 1 to 2 do { (["patrol", _targetpos, _radius, "widepatrol"] call fnc_spawn_team) call _claim; };
private _car = ["car"] call DUWS_fnc_tokenClass;
if (_car != "") then { ([_car, _targetpos, _radius, "widepatrol"] call fnc_spawn_vehicle) call _claim; };
if ((["ifv"] call DUWS_fnc_tokenClass) != "") then {
    private _cls = [selectRandom ["car", "ifv"]] call DUWS_fnc_tokenClass;
    if (_cls != "") then { ([_cls, _targetpos, _radius, "widepatrol"] call fnc_spawn_vehicle) call _claim; };
};

// Delivery point: a safe spot in the crew's town. The crew, their green smoke and the map marker all sit here.
private _targetDeliveryPos = [_townPos, 0, 80, 5, 0, 0.5, 0] call BIS_fnc_findSafePos;
if (_targetDeliveryPos isEqualTo [] || {(_targetDeliveryPos select 0) == 0 && {(_targetDeliveryPos select 1) == 0}}) then {
    _targetDeliveryPos = _townPos;
};

private _deliveryMarkerName = format ["idap_delivery_%1", DUWS_mission_token];
createMarker [_deliveryMarkerName, _targetDeliveryPos];
_deliveryMarkerName setMarkerShape "ICON";
_deliveryMarkerName setMarkerType "o_unknown";
_deliveryMarkerName setMarkerColor "ColorGreen";
_deliveryMarkerName setMarkerText "IDAP";
_deliveryMarkerName setMarkerSize [1, 1];

_unitClasses = [
    "C_IDAP_Man_Aidworker_01_F",
    "C_IDAP_Man_Aidworker_02_F",
    "C_IDAP_Man_Aidworker_03_F",
    "C_IDAP_Man_Aidworker_04_F",
    "C_IDAP_Man_Aidworker_05_F",
    "C_IDAP_Man_Aidworker_06_F"
];
_groupUnits = [];
for "_i" from 1 to 3 do { _groupUnits pushBack (selectRandom _unitClasses); };
_groupDelivery = [_targetDeliveryPos, civilian, _groupUnits, [], [], [0.5, 0.6]] call BIS_fnc_spawnGroup;

{
    private _offsetDist = 5 + random 3;
    private _offsetDir = random 360;
    _x setPos (_targetDeliveryPos getPos [_offsetDist, _offsetDir]);
    _x disableAI "MOVE";
    _x disableAI "PATH";
    _x setBehaviour "CARELESS";
    // One man marshals; the rest just stand. The act loops, so a single switchMove holds.
    if (_forEachIndex == 0) then { _x switchMove "Acts_JetsShooterNavigate_loop_m" };
} forEach units _groupDelivery;

_cleanupDelivery = {
    if (!isNil "_groupDelivery") then { { deleteVehicle _x } forEach units _groupDelivery; deleteGroup _groupDelivery; };
    deleteMarker _deliveryMarkerName;
};

// Brief stays manual: fixed-speaker strings, not fnc_mission_present's callsign substitution.
_markername2 = [_randomPos, _radius, _VARtaskgeneratedName, localize "STR_DUWS_T_transIDAP", _mission_name, "truck"] call fnc_mission_present;
[_speakerIDAP, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 6;
[_speaker, _message1] remoteExec ["fnc_duws_dialogue", 0];
sleep 5;
[_speakeracteam, _message2] remoteExec ["fnc_duws_dialogue", 0];

sleep 5; // let the patrols finish spawning


waitUntil {
    sleep 2;
    (getDammage _truck1 > 0.95) || (_truck1 distance _targetDeliveryPos < _deliverDist) || (time > _deadline)
};

if (getDammage _truck1 > 0.95) exitWith {
    call _cleanupDelivery;
    _truck1 setDamage 1;
    [_speaker, _messageLost] remoteExec ["fnc_duws_dialogue", 0];
    [_townIdx, _repFail, "idap_failed"] call fnc_town_rep_adjust;
    [_mission_name, _VARtaskgeneratedName, "FAILED", _targetpos, _radius, [_markername2], [], false, "mission_transport_idap", false, false] call fnc_mission_finish;
};

if (time > _deadline) exitWith {
    call _cleanupDelivery;
    [_townIdx, _repFail, "idap_deadline"] call fnc_town_rep_adjust;
    [_mission_name, _VARtaskgeneratedName, "FAILED", _targetpos, _radius, [_markername2], [], false, "mission_transport_idap", false, true] call fnc_mission_finish;
};

deleteMarker _deliveryMarkerName;
// Forced VOICE, not the SUB-NET the speaker's distress call routed to: at hand-over the crew are in the
// room with the player, not a radio contact, so this line is in person.
[_speakerIDAP, _message3, "VOICE"] remoteExec ["fnc_duws_dialogue", 0];
sleep 6;
[_speaker, _messageClose] remoteExec ["fnc_duws_dialogue", 0];
sleep 4;
// The handover theatre keeps its own order; the task ticks complete at the end, through finish.
[_townIdx, _repWin, "idap_success"] call fnc_town_rep_adjust;
sleep 2;
deleteVehicle _box2;
sleep 2;
deleteVehicle _box1;
sleep 8;
deleteVehicle _truck1;
call _cleanupDelivery;

[_mission_name, _VARtaskgeneratedName, "SUCCEEDED", _targetpos, _radius, [_markername2], [], true, "mission_transport_idap", true, false] call fnc_mission_finish;
