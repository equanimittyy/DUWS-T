// Locality: server -- callers remoteExec to target 2.
//
// Recover an aid truck OPFOR has hijacked and hand it back to the IDAP crew. The truck sits parked under
// an OPFOR guard, the same shape as the stolen supply truck (fnc_steal_supply_mission is the reference for
// the spawn and guard force); the crew wait in the nearest neutral/BLUFOR town, and the win is delivering
// the truck to within reach of them. The offer is gated on such a town existing (fnc_transport_IDAP_site);
// the thread re-derives the same town here and aborts if the war state left none between offer and start.
params ["_MissionPos", "_mission_name"];
if (!([14, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};


_radius = 600;
_deliverDist = 50;
_cpreward = DUWS_curReward select 0;
_apreward = DUWS_curReward select 1;
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

// The crew's haven: nearest neutral/BLUFOR town to the truck, matching what the site-finder vetted. A town
// in the OPFOR band (its centre in the broadcast enemy list) is no hand-over point. duws_town_circles is
// index-aligned with civ_locations, so its index is the town index fnc_town_rep_adjust takes. If the last
// non-enemy town flipped hostile in the gap, there is nowhere to deliver: release the gate and abort.
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
if (_townIdx < 0) exitWith { [14, "STR_DUWS_T_crtzxs0j", "no_delivery_town"] call fnc_mission_abort; };

// IDAP's thanks names the delivery town (the location's own name, nearest-location fallback, then a
// generic if the map left it unnamed) so the sign-off reads for the place the player just drove to.
private _townName = text ((missionNamespace getVariable ["civ_locations", []]) select _townIdx);
if (_townName == "") then { _townName = text (nearestLocation [_townPos, ""]) };
if (_townName == "") then { _townName = localize "STR_DUWS_T_idap_town_generic" };
private _message3 = format [localize "STR_DUWS_T_idapend", _townName];

private _site = [_MissionPos, _radius, 14] call fnc_mission_site;
if (_site isEqualTo []) exitWith {};
_site params ["_randomPos", "_Building", "_targetpos"];

// Marked before anything is built. The ellipse and the task are the only things telling the
// player where the objective is, and the spawn-up below runs for tens of seconds.
_markername2 = [_randomPos, _radius] call fnc_missionMarkerData;
private _VARtaskgeneratedName = format ["rescue%1%2", round(_MissionPos select 0), round(_MissionPos select 1)];
[_VARtaskgeneratedName, localize "STR_DUWS_T_transIDAP", _mission_name, _randomPos, "truck"] call fnc_missionTaskCreate;

// Brief opens the mission, before the truck/guard spawn-up below (tens of seconds): the spawn must not
// delay the opening line. Speakers and messages are fixed strings, independent of the spawned convoy.
[_speakerIDAP, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 6;
[_speaker, _message1] remoteExec ["fnc_duws_dialogue", 0];
sleep 5;
[_speakeracteam, _message2] remoteExec ["fnc_duws_dialogue", 0];

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

// Guard force, the stolen-supply shape: idle team on the prize, a close and two wide foot patrols, plus
// vehicle patrols that scale with the enemy's earned AP -- DUWS_fnc_tokenClass returns "" for a token
// gated out at the current tier, so a car joins from motorised (60 AP) and a second car-or-ifv from
// mechanised (150 AP).
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
for "_i" from 1 to 5 do { _groupUnits pushBack (selectRandom _unitClasses); };
_groupDelivery = [_targetDeliveryPos, civilian, _groupUnits, [], [], [0.5, 0.6]] call BIS_fnc_spawnGroup;

{
    private _offsetDist = 5 + random 3;
    private _offsetDir = random 360;
    _x setPos (_targetDeliveryPos getPos [_offsetDist, _offsetDir]);
    _x disableAI "MOVE";
    _x disableAI "PATH";
    _x setBehaviour "CARELESS";
    [_x] spawn {
        params ["_unit"];
        while {alive _unit} do {
            _unit switchMove "Acts_JetsShooterNavigate_loop_m";
            sleep 5;
        };
    };
} forEach units _groupDelivery;

_smokeObjects = [];
_deliverySmokeScript = [_targetDeliveryPos, _smokeObjects] spawn {
    params ["_pos", "_smokeObjects"];
    while {true} do {
        if (count _smokeObjects > 0) then {
            deleteVehicle (_smokeObjects select 0);
            _smokeObjects deleteAt 0;
        };
        private _smoke = "SmokeShellGreen" createVehicle _pos;
        _smoke setPos _pos;
        _smokeObjects pushBack _smoke;
        sleep 30;
    };
};

_cleanupDelivery = {
    if (!isNil "_deliverySmokeScript") then { terminate _deliverySmokeScript; };
    if (!isNil "_smokeObjects") then { { deleteVehicle _x } forEach _smokeObjects; };
    if (!isNil "_groupDelivery") then { { deleteVehicle _x } forEach units _groupDelivery; deleteGroup _groupDelivery; };
    deleteMarker _deliveryMarkerName;
};

sleep 5; // let the patrols finish spawning


waitUntil {
    sleep 2;
    (getDammage _truck1 > 0.95) || (_truck1 distance _targetDeliveryPos < _deliverDist) || (time > _deadline)
};

[_markername2] call fnc_missionMarkerClear;

if (getDammage _truck1 > 0.95) exitWith {
    call _cleanupDelivery;
    _truck1 setDamage 1;
    [_speaker, _messageLost] remoteExec ["fnc_duws_dialogue", 0];
    [_VARtaskgeneratedName, "FAILED"] call fnc_missionTaskEnd;
    [_townIdx, _repFail, "idap_failed"] call fnc_town_rep_adjust;
    [_targetpos, _radius, "mission_transport_idap"] call fnc_mission_end;
};

if (time > _deadline) exitWith {
    call _cleanupDelivery;
    call fnc_mission_timeout_notice;
    [_VARtaskgeneratedName, "FAILED"] call fnc_missionTaskEnd;
    [_townIdx, _repFail, "idap_deadline"] call fnc_town_rep_adjust;
    [_targetpos, _radius, "mission_transport_idap"] call fnc_mission_end;
};

deleteMarker _deliveryMarkerName;
// Forced VOICE, not the SUB-NET the speaker's distress call routed to: at hand-over the crew are in the
// room with the player, not a radio contact, so this line is in person.
[_speakerIDAP, _message3, "VOICE"] remoteExec ["fnc_duws_dialogue", 0];
sleep 6;
[_speaker, _messageClose] remoteExec ["fnc_duws_dialogue", 0];
sleep 4;
[_VARtaskgeneratedName, "SUCCEEDED"] call fnc_missionTaskEnd;
[_townIdx, _repWin, "idap_success"] call fnc_town_rep_adjust;
sleep 2;
deleteVehicle _box2;
sleep 2;
deleteVehicle _box1;
sleep 8;
deleteVehicle _truck1;
call _cleanupDelivery;

[_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;
[_targetpos, _radius, "mission_transport_idap", true] call fnc_mission_end;
