// Locality: server -- callers remoteExec to target 2; the watcher threads spawned here inherit it.
//
// A broken-down enemy MBT sits abandoned in the field. Its crew is inbound by road convoy to get it
// running again: three crew (one an engineer) riding one or two unarmed transports, an escort scaled to
// what OPFOR can field (a car, an IFV or a tank), and a rifle team along for security. The convoy enters
// ~1 km out from the nearest OPFOR-held zone and drives to the tank; an orange arrow on the map marks
// where it comes from and which way it heads. The player either ambushes the crew at the tank or
// intercepts the convoy on the road.
//
// Win = the tank denied to the enemy: every crewman dead, or the tank destroyed (blowing the derelict
// before they reach it counts). Fail = the crew reach it, repair it to operational, and drive it clear
// of the site, or the deadline. The tank is protected from cleanup only while the mission runs, and is
// never claimed on a win, so a player who clears the crew can drive it home -- a claim is a deletion
// order, and this one may end up the player's.
//
// Not on the fnc_mission_run spine: that spine wins-or-times-out on a one-shot predicate, and this has
// a distinct scripted fail (the repair race) the spine has no hook for. Shares the same helpers a spine
// thread does -- fnc_mission_begin/site/reward/end, the marker and task calls -- just not its loop.
params ["_MissionPos", "_mission_name"];
if (!([18, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};

#define DA_RADIUS      300      // objective ring drawn and searched within
#define DA_CONVOY_DIST 1000     // how far out the convoy enters, from the enemy zone's side
#define DA_DISEMBARK   140      // troops dismount once their transport is this close to the tank
#define DA_ARRIVE      15       // a live crewman this close to the tank is working on it (AI halts at the hull)
#define DA_REPAIR_TIME 45       // seconds of uninterrupted work to bring it back to operational
#define DA_ESCAPE      300      // a repaired tank driven this far from the site has got away

private _compKey = "mission_destroy_armour";
private _cpreward = DUWS_curReward select 0;
private _apreward = DUWS_curReward select 1;
private _deadline = DUWS_curDeadlineAt;

private _site = [_MissionPos, DA_RADIUS, 18] call fnc_mission_site;
if (_site isEqualTo []) exitWith {};
_site params ["_randomPos", "_Building", "_targetpos"];

// The tank's exact ground: a flat, vehicle-clear spot by the site so it reads as a derelict on open
// ground rather than wedged in a stub, and so the crew can drive it out once repaired.
private _vehpos = [_targetpos, 5, 25, 8, 0, 0.2, 0] call BIS_fnc_findSafePos;
if (_vehpos isEqualTo [] || {(_vehpos select 0) == 0}) then { _vehpos = _targetpos };

// Marked before anything is built: the ellipse and the task are the only things pointing the player at
// the objective while the convoy is still forming up off-screen.
private _marker = [_randomPos, DA_RADIUS] call fnc_missionMarkerData;
private _taskId = format ["destroyarmour%1%2", round (_MissionPos select 0), round (_MissionPos select 1)];
[_taskId, localize "STR_DUWS_T_destroyarmour_desc", _mission_name, _randomPos, "destroy"] call fnc_missionTaskCreate;
[localize "STR_DUWS_T_c18", {hint _this}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated];

// The broken-down tank: empty (createVehicle raises no crew, unlike BIS_fnc_spawnVehicle), pre-damaged
// and low on fuel so it reads as a wreck-in-waiting and the repair below is a real state change. Marked
// persistent so the abandoned-vehicle sweep (fnc_repetitive_cleanup) cannot reap the empty hull before
// the convoy or the player reaches it. Deliberately neither claimed nor kept: a claim is a delete order,
// and a player who wins by clearing the crew is meant to be able to drive this home.
private _tank = createVehicle [opfor_MBT_TANK1_X, _vehpos, [], 0, "CAN_COLLIDE"];
_tank setDir (random 360);
_tank setDamage 0.7;
_tank setFuel 0.15;
_tank setVariable ["persistent", true];

// Convoy origin: 1 km out on the bearing of the nearest OPFOR-held zone, so it enters from friendly
// ground and heads in. WARCOM_zones_controled_by_OPFOR is a list of zone positions; empty (every zone
// still OPFOR at hour zero, or none created) falls back to a random bearing so the convoy still forms up.
private _opforZones = missionNamespace getVariable ["WARCOM_zones_controled_by_OPFOR", []];
private _bearing = if (_opforZones isEqualTo []) then { random 360 } else {
    private _nearest = [_opforZones, [_targetpos], {_input0 distance2D _x}, "ASCEND"] call BIS_fnc_sortBy select 0;
    _targetpos getDir _nearest
};
private _convoyStart = [_targetpos getPos [DA_CONVOY_DIST, _bearing], 0, 80, 8, 0, 0.4, 0] call BIS_fnc_findSafePos;
if (_convoyStart isEqualTo [] || {(_convoyStart select 0) == 0}) then { _convoyStart = _targetpos getPos [DA_CONVOY_DIST, _bearing] };

// Orange arrow at the convoy's entry point, pointing the way it drives. Approach direction only -- the
// ellipse already marks the tank -- so it stays static and is cleared once the convoy is in and engaged.
private _arrow = format ["da_arrow_%1%2", round (_targetpos select 0), round (_targetpos select 1)];
deleteMarker _arrow;   // a rounded-position name can collide with a prior mission's leftover
createMarker [_arrow, _convoyStart];
_arrow setMarkerType "mil_arrow";
_arrow setMarkerColor "ColorOrange";
_arrow setMarkerDir (_convoyStart getDir _targetpos);
_arrow setMarkerSize [1.1, 1.1];
_arrow setMarkerAlpha 0.8;
_arrow setMarkerText localize "STR_DUWS_T_destroyarmour_arrow";

// The tank crew: two crewmen and the engineer who does the repairing, their own group so the win test
// reads exactly these three.
private _crewGrp = [_convoyStart, EAST, [opfor_CREW_X, opfor_CREW_X, opfor_ENG_SOLDIER_X], [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
_crewGrp deleteGroupWhenEmpty true;
private _crewUnits = units _crewGrp;

// The escort rifle team, placed on the exact convoy point (posture "none" overrides the band). A team,
// not a vehicle token, so it is faction-safe on a pack that never named this role.
private _teamGrp = ["team", _convoyStart, DA_RADIUS, "none", _convoyStart] call fnc_spawn_team;
private _teamUnits = if (isNull _teamGrp) then { [] } else { units _teamGrp };

// Unarmed transport for the crew and the team. One truck if they fit; a second is raised only when the
// riders overflow its cargo, so a small-cargo faction truck still carries everyone rather than stranding
// the overflow to walk in from 1 km. Crew load first, so the mission-critical three always ride.
private _riders = _crewUnits + _teamUnits;
private _truckSpawn = [_convoyStart, _bearing + 180, opfor_TRANS_TRUCK_X, EAST] call BIS_fnc_spawnVehicle;
private _truck = _truckSpawn select 0;                 // lead truck, watched for the disembark trigger
private _trucks = [_truck];
private _truckGrps = [_truckSpawn select 2];
{
    private _cur = _trucks select (count _trucks - 1);
    if (_cur emptyPositions "cargo" == 0) then {
        private _extra = [_convoyStart getPos [20 * count _trucks, _bearing + 90], _bearing + 180, opfor_TRANS_TRUCK_X, EAST] call BIS_fnc_spawnVehicle;
        _cur = _extra select 0;
        _trucks pushBack _cur;
        _truckGrps pushBack (_extra select 2);
    };
    _x moveInCargo _cur;
} forEach _riders;

// One armed escort, scaled to what OPFOR can currently field: a car, an IFV, or a tank, drawn at random
// from those the enemy's earned AP tier (and the HeavyArmor toggle) actually allow -- DUWS_fnc_tokenClass
// answers "" for a token above the tier, so the pool widens as the campaign does. Falls back to the armed
// car global when the enemy has not yet earned even a car, so the convoy is never unescorted.
private _escortPool = ["car", "ifv", "tank"] select { ([_x] call DUWS_fnc_tokenClass) != "" };
private _escortClass = if (_escortPool isEqualTo []) then { opfor_ARMED_CAR1_X } else { [selectRandom _escortPool] call DUWS_fnc_tokenClass };
private _escortSpawn = [_convoyStart getPos [25, _bearing - 90], _bearing + 180, _escortClass, EAST] call BIS_fnc_spawnVehicle;
private _escortGrp = _escortSpawn select 2;

{ [_x] call fnc_mission_claim } forEach ([_crewGrp, _teamGrp, _escortGrp] + _truckGrps);

// Drive to the tank at a road pace the player can race: LIMITED speed, AWARE so they still fight if
// jumped en route. Loose completionRadius so a truck halts near the tank rather than shouldering it.
{
    _x setBehaviour "AWARE";
    _x setCombatMode "YELLOW";
    _x setSpeedMode "LIMITED";
    private _wp = _x addWaypoint [_vehpos, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointCompletionRadius 40;
} forEach ([_escortGrp] + _truckGrps);

private _place = [_randomPos] call fnc_place_name;
[localize "STR_DUWS_T_OVERLORD", format [localize "STR_DUWS_T_destroyarmour_start", _place]] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;
[localize "STR_DUWS_T_allseer", localize "STR_DUWS_T_destroyarmour_convoy"] remoteExec ["fnc_duws_dialogue", 0];

// Teardown shared by both outcomes: clear both markers and end the task, then hand the objective to the
// map cleanup. mission_end flags claimed units on a ~5-minute far-clock rather than poofing them, so a
// convoy the player is still fighting does not blink out.
private _finish = {
    params ["_status"];
    // Drop the mission-only protection: a tank the player took is now theirs and lives under the ordinary
    // cleanup rules (spared while crewed or near base, reaped once abandoned in the field), and a claimed
    // one that got away must not be spared by the persistent flag when cleanup comes for it.
    _tank setVariable ["persistent", false];
    deleteMarker _arrow;
    [_marker] call fnc_missionMarkerClear;
    [_taskId, _status] call fnc_missionTaskEnd;
    [_targetpos, DA_RADIUS, _compKey] call fnc_mission_end;
};

// The repair race. WIN the moment the tank is denied -- every crewman dead, or the tank destroyed.
// FAIL when a live crew drives the repaired tank clear of the site, or on the deadline. In between: once
// the transport is near the tank (or destroyed, so the crew bail), the crew and escort dismount and the
// crew work on the tank; the clock only advances while a crewman stands at it and no player has taken it.
private _dismounted = false;
private _repairAt = -1;
private _repaired = false;

while { true } do {
    sleep 2;

    private _liveCrew = _crewUnits select { alive _x };
    private _tankDead = !alive _tank || {(damage _tank) >= 1};

    if (_liveCrew isEqualTo [] || _tankDead) exitWith {
        [localize "STR_DUWS_T_OVERLORD", [localize "STR_DUWS_T_destroyarmour_end"] call fnc_cs] remoteExec ["fnc_duws_dialogue", 0];
        [_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;
        ["SUCCEEDED"] call _finish;
    };

    if (time > _deadline) exitWith {
        ["FAILED"] call _finish;
        [localize "STR_DUWS_T_OVERLORD", [localize "STR_DUWS_T_destroyarmour_fail_time"] call fnc_cs] remoteExec ["fnc_duws_dialogue", 0];
    };

    if (!_dismounted) then {
        // Dismount when a transport reaches the tank, or once none is left alive (survivors bail and finish
        // on foot). The crew make for the tank; the escort team holds around it as an ambush to break.
        private _aliveTrucks = _trucks select { alive _x };
        if (_aliveTrucks isEqualTo [] || {(_aliveTrucks findIf { (_x distance2D _tank) < DA_DISEMBARK }) >= 0}) then {
            _dismounted = true;
            deleteMarker _arrow;
            {
                if (alive _x) then { moveOut _x; unassignVehicle _x; _x doMove _vehpos };
            } forEach _crewUnits;
            {
                if (alive _x) then { moveOut _x; unassignVehicle _x };
            } forEach _teamUnits;
            if (!isNull _teamGrp) then {
                _teamGrp setBehaviour "COMBAT";
                _teamGrp setCombatMode "RED";
                private _gwp = _teamGrp addWaypoint [_vehpos, 0];
                _gwp setWaypointType "GUARD";
            };
        };
    } else {
        if (!_repaired) then {
            // The tank cannot be worked on while a player is aboard it: a stolen tank must not be handed a
            // free repair, and its crew, blocked, become targets the player finishes for the win.
            private _playerInTank = (crew _tank findIf { isPlayer _x }) >= 0;
            private _atTank = (_liveCrew findIf { (_x distance2D _tank) < DA_ARRIVE }) >= 0;
            if (_atTank && !_playerInTank) then {
                if (_repairAt < 0) then { _repairAt = time };
                if (time - _repairAt >= DA_REPAIR_TIME) then {
                    _repaired = true;
                    _tank setDamage 0;
                    _tank setFuel 1;
                    // Seat the survivors and drive it home. Reuse the crew group so it moves as one; fill
                    // driver first so a crew short a man still rolls, then head back down the entry bearing.
                    private _seats = [{ _this moveInDriver _tank }, { _this moveInCommander _tank }, { _this moveInGunner _tank }];
                    { _x call (_seats param [_forEachIndex, {}]) } forEach _liveCrew;
                    _crewGrp setBehaviour "AWARE";
                    _crewGrp setCombatMode "YELLOW";
                    private _home = _targetpos getPos [DA_CONVOY_DIST + DA_ESCAPE, _bearing];
                    private _twp = _crewGrp addWaypoint [_home, 0];
                    _twp setWaypointType "MOVE";
                    _twp setWaypointSpeed "FULL";
                    [localize "STR_DUWS_T_allseer", localize "STR_DUWS_T_destroyarmour_repaired"] remoteExec ["fnc_duws_dialogue", 0];
                };
            } else {
                _repairAt = -1;   // pushed off the tank -- the work does not carry over
            };
        } else {
            // Repaired and pulling out: fail once it is clear of the site with a live enemy crew aboard.
            // A tank destroyed or a crew wiped after this still hits the win check at the top of the loop.
            if ((_tank distance2D _targetpos) > DA_ESCAPE && {(crew _tank findIf { alive _x && !isPlayer _x }) >= 0}) exitWith {
                // Claimed only now: an escaping tank is the enemy's again, so let cleanup collect it with the
                // crew once the player is clear, rather than leaving an unowned MBT on the map (_finish drops
                // its persistent flag, without which the sweep would spare the still-alive hull).
                [_tank] call fnc_mission_claim;
                ["FAILED"] call _finish;
                [localize "STR_DUWS_T_OVERLORD", [localize "STR_DUWS_T_destroyarmour_fail"] call fnc_cs] remoteExec ["fnc_duws_dialogue", 0];
            };
        };
    };
};
