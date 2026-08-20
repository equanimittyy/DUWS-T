// Locality: server -- callers remoteExec to target 2; the watcher threads spawned here inherit it.
//
// A broken-down enemy MBT sits abandoned in the field. Its crew is inbound by road convoy to get it
// running again: three crew (one an engineer) riding one or two unarmed transports, an escort scaled to
// what OPFOR can field (a car, an IFV or a tank), and a rifle team along for security. The convoy forms up
// partway between the nearest OPFOR-held zone and the tank and drives in as one column; an orange arrow on
// the map marks where it comes from and which way it heads. The player either ambushes the crew at the tank or
// intercepts the convoy on the road.
//
// Win = the tank denied to the enemy: every crewman dead, or the tank destroyed (blowing the derelict
// before they reach it counts). Fail = the crew reach it, repair it to operational, and drive it back to
// their nearest zone, or the deadline. The tank is protected from cleanup only while the mission runs, and is
// never claimed on a win, so a player who clears the crew can drive it home -- a claim is a deletion
// order, and this one may end up the player's.
//
// Not on the fnc_mission_run spine: that spine wins-or-times-out on a one-shot predicate, and this has
// a distinct scripted fail (the repair race) the spine has no hook for. Shares the same helpers a spine
// thread does -- fnc_mission_begin/site/reward/end, the marker and task calls -- just not its loop.
params ["_MissionPos", "_mission_name", ["_destZone", []]];
if (!([18, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};

#define DA_RADIUS      300      // objective ring drawn and searched within
#define DA_CONVOY_DIST 1000     // fallback convoy entry distance when no OPFOR zone is known
#define DA_DISEMBARK   140      // troops dismount once their transport is this close to the tank
#define DA_ARRIVE      15       // a live crewman this close to the tank is working on it (AI halts at the hull)
#define DA_ARRIVE_ZONE 150      // a repaired tank this close to its home zone has got away (fail)

// Repair time scales inversely with how far the nearest OPFOR zone is: a zone at or inside NEARDIST gives
// the long NEAR window, one at or past FARDIST the short FAR one, linear between. A repaired tank near its
// own lines is the harder denial, so the player is given the longer window to break the repair there.
#define DA_REPAIR_NEAR      300    // repair seconds at/inside DA_REPAIR_NEARDIST
#define DA_REPAIR_FAR       30     // repair seconds at/beyond DA_REPAIR_FARDIST
#define DA_REPAIR_NEARDIST  1000
#define DA_REPAIR_FARDIST   4000

private _compKey = "mission_deny_armor";
private _cpreward = DUWS_curReward select 0;
private _apreward = DUWS_curReward select 1;
private _deadline = DUWS_curDeadlineAt;

private _site = [_MissionPos, DA_RADIUS, 18] call fnc_mission_site;
if (_site isEqualTo []) exitWith {};
_site params ["_randomPos", "_Building", "_targetpos"];

// The tank's exact ground: flat, hull-clear, and within ~100 m of a road so the inbound convoy can ride
// the network to within fnc_convoy_watch's final-hop of the hull rather than road-locking short of an
// off-network spot, and so the repaired tank starts its run home on that same network. Still set off the
// carriageway so it reads as a derelict abandoned in the field. No road near the objective (a remote
// site) falls back to the plain safe-pos by the target, accepting the longer off-road approach.
private _vehpos = [];
private _tankRoads = _targetpos nearRoads 100;
if !(_tankRoads isEqualTo []) then {
    _vehpos = [getPosATL (selectRandom _tankRoads), 8, 30, 12, 0, 0.2, 0] call BIS_fnc_findSafePos;
};
if (_vehpos isEqualTo [] || {(_vehpos select 0) == 0}) then {
    _vehpos = [_targetpos, 5, 25, 12, 0, 0.2, 0] call BIS_fnc_findSafePos;
};
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

// Convoy origin: midway between the tank and the nearest OPFOR-held zone, on that bearing, both distance
// and heading jittered so the entry point moves run to run. WARCOM_zones_controled_by_OPFOR lists zone
// positions; empty (every zone still OPFOR at hour zero, or none created) falls back to the fixed distance
// on a random bearing. Floored clear of the objective ring so the convoy never starts on top of the tank.
private _opforZones = missionNamespace getVariable ["WARCOM_zones_controled_by_OPFOR", []];
private _bearing = random 360;
private _convoyDist = DA_CONVOY_DIST;
private _zoneDist = DA_REPAIR_NEARDIST;   // no zone known -> treat as the near case, the full repair window
private _zonePos = [];                     // the tank's home once repaired: the zone it drives back to
// Prefer the home zone the siting pass vetted (corridor clear of BLUFOR), while it is still OPFOR-held;
// else the nearest held zone to the tank. Neither -> the synthetic exfil below stands in.
private _nearest = [];
if (!(_destZone isEqualTo []) && {(_opforZones findIf { _x distance2D _destZone < 50 }) >= 0}) then {
    _nearest = _destZone;
} else {
    if !(_opforZones isEqualTo []) then {
        _nearest = [_opforZones, [_targetpos], {_input0 distance2D _x}, "ASCEND"] call BIS_fnc_sortBy select 0;
    };
};
if !(_nearest isEqualTo []) then {
    _zonePos = _nearest;
    _zoneDist = _targetpos distance2D _nearest;
    _bearing = (_targetpos getDir _nearest) + (random 30 - 15);
    _convoyDist = ((_zoneDist / 2) * (0.85 + random 0.3)) max (DA_RADIUS + 100);
};
// No zone to reach (all still OPFOR, or none created): a synthetic exfil point out past the convoy's entry
// on its bearing stands in, so the escape is still a real drive rather than an unreachable target.
if (_zonePos isEqualTo []) then { _zonePos = _targetpos getPos [_convoyDist + 500, _bearing] };
// Longer window near the enemy's lines, shorter far out (see the DA_REPAIR_* defines).
private _repairTime = linearConversion [DA_REPAIR_NEARDIST, DA_REPAIR_FARDIST, _zoneDist, DA_REPAIR_NEAR, DA_REPAIR_FAR, true];
// Spawn the convoy on the road network where possible: an off-road start makes the column fight the
// pathfinder from the first metre. Nearest road to the jittered entry point (nearRoads is distance
// sorted), falling back to a safe-pos when the entry lands off the network.
private _entry = _targetpos getPos [_convoyDist, _bearing];
private _entryRoads = _entry nearRoads 300;
private _convoyStart = if !(_entryRoads isEqualTo []) then { getPosATL (_entryRoads select 0) } else {
    private _sp = [_entry, 0, 80, 8, 0, 0.4, 0] call BIS_fnc_findSafePos;
    if (_sp isEqualTo [] || {(_sp select 0) == 0}) then { _entry } else { _sp }
};

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

// One convoy group so the vehicles road-march together in column instead of each pathing on its own and
// arriving strung out: fold the escort and any second truck into the lead truck's group, dropping the now
// empty source groups. The riding crew and rifle team stay their own groups -- they are cargo, not drivers.
private _convoyGrp = _truckGrps select 0;
{
    if (_x != _convoyGrp) then { (units _x) joinSilent _convoyGrp; deleteGroup _x };
} forEach (_truckGrps + [_escortGrp]);

// The convoy's vehicles, snapshotted here for the reliability layer and the under-attack test below.
// _trucks is final (a second truck, raised only on cargo overflow, was pushed during loading above).
private _convoyVeh = _trucks + [_escortSpawn select 0];

{ [_x] call fnc_mission_claim } forEach [_crewGrp, _teamGrp, _convoyGrp];

// Drive to the tank at a road pace the player can race: LIMITED speed, AWARE so they still fight if jumped
// en route, COLUMN so they hold convoy order. Loose completionRadius so the lead halts near the tank
// rather than shouldering it.
_convoyGrp setBehaviour "AWARE";
_convoyGrp setCombatMode "YELLOW";
_convoyGrp setSpeedMode "LIMITED";
_convoyGrp setFormation "COLUMN";
private _wp = _convoyGrp addWaypoint [_vehpos, 0];
_wp setWaypointType "MOVE";
_wp setWaypointCompletionRadius 40;

// Reliability layer: road-lock + spacing + keep-crew-aboard, then the stuck watchdog. Arma's vehicle
// route calculation stalls convoys on open ground and geometry; the watchdog nudges any hull that jams
// and lifts the road-lock for the final hop to the tank. It reads the group's current waypoint live, so
// it carries over when the repaired tank folds in and the column is re-tasked home. Ended in _finish.
[_convoyGrp, _convoyVeh] call fnc_convoy_setup;
[_convoyGrp, _convoyVeh] spawn fnc_convoy_watch;

private _place = [_randomPos] call fnc_place_name;
[localize "STR_DUWS_T_OVERLORD", format [localize "STR_DUWS_T_destroyarmour_start", _place]] remoteExec ["fnc_duws_dialogue", 0];

// Hold the convoy intel a beat: neither the approach arrow nor the eyes-on report is handed over the
// instant the mission opens. Overlord's brief lands first; 10s on, the arrow drops and Allseer calls it.
sleep 10;
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
    _convoyGrp setVariable ["DUWS_convoy_stop", true];
    deleteMarker _arrow;
    [_marker] call fnc_missionMarkerClear;
    [_taskId, _status] call fnc_missionTaskEnd;
    [_targetpos, DA_RADIUS, _compKey] call fnc_mission_end;
};

// The repair race. WIN the moment the tank is denied -- every crewman dead, or the tank destroyed.
// FAIL when a live crew drives the repaired tank back to its home zone, or on the deadline. In between: the
// tank crew dismount once their transport reaches the tank (or is destroyed) and work on the hull; the
// security team stays mounted and only pours out if the convoy is hit; the clock advances only while a
// crewman stands at the tank and no player has taken it.
private _convoyCrew = units _convoyGrp;
// Under attack = a convoy vehicle damaged or destroyed, or any man down. Keeps the security team riding on
// an untouched run so it rides back out with the tank, and pours it out to fight the moment the column is hit.
private _underAttack = {
    (_convoyVeh findIf { !alive _x || {damage _x > 0.1} }) >= 0
    || {(_convoyCrew findIf { !alive _x }) >= 0}
    || {((_crewUnits + _teamUnits) findIf { !alive _x }) >= 0}
};
private _dismounted = false;
private _teamOut = false;
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

    // Terminal fail: the repaired tank reaches its home zone with a live enemy crew still aboard. Kept a
    // direct exitWith at the loop's top level so it fires once and stops -- nested inside the repair branch
    // below, exitWith broke only that block's scope, so the fail line spammed every tick and a later tank
    // kill still reached the win check above and scored a bogus success.
    if (_repaired
        && {(_tank distance2D _zonePos) < DA_ARRIVE_ZONE}
        && {(crew _tank findIf { alive _x && !isPlayer _x }) >= 0}) exitWith {
        // Claimed only now: an escaping tank is the enemy's again, so cleanup collects it with the crew
        // once the player is clear (_finish drops its persistent flag, without which the sweep would spare
        // the still-alive hull).
        [_tank] call fnc_mission_claim;
        ["FAILED"] call _finish;
        [localize "STR_DUWS_T_OVERLORD", [localize "STR_DUWS_T_destroyarmour_fail"] call fnc_cs] remoteExec ["fnc_duws_dialogue", 0];
    };

    // The security team pours out only once the convoy is actually hit, and fights where it stands -- at the
    // tank if the ambush lands there, on the road if the player jumped the column en route.
    if (!_teamOut && {call _underAttack}) then {
        _teamOut = true;
        deleteMarker _arrow;
        {
            if (alive _x) then { moveOut _x; unassignVehicle _x };
        } forEach _teamUnits;
        if (!isNull _teamGrp) then {
            _teamGrp setBehaviour "COMBAT";
            _teamGrp setCombatMode "RED";
            private _anchor = position (_teamUnits select { alive _x } param [0, _tank]);
            private _gwp = _teamGrp addWaypoint [_anchor, 0];
            _gwp setWaypointType "GUARD";
        };
    };

    if (!_dismounted) then {
        // The tank crew dismount when a transport reaches the tank, or once none is left alive (survivors
        // bail and finish on foot), and make for the hull to work on it.
        private _aliveTrucks = _trucks select { alive _x };
        if (_aliveTrucks isEqualTo [] || {(_aliveTrucks findIf { (_x distance2D _tank) < DA_DISEMBARK }) >= 0}) then {
            _dismounted = true;
            deleteMarker _arrow;
            {
                if (alive _x) then { moveOut _x; unassignVehicle _x; _x doMove _vehpos };
            } forEach _crewUnits;
        };
    } else {
        if (!_repaired) then {
            // The tank cannot be worked on while a player is aboard it: a stolen tank must not be handed a
            // free repair, and its crew, blocked, become targets the player finishes for the win.
            private _playerInTank = (crew _tank findIf { isPlayer _x }) >= 0;
            private _atTank = (_liveCrew findIf { (_x distance2D _tank) < DA_ARRIVE }) >= 0;
            if (_atTank && !_playerInTank) then {
                if (_repairAt < 0) then { _repairAt = time };
                if (time - _repairAt >= _repairTime) then {
                    _repaired = true;
                    _tank setDamage 0;
                    _tank setFuel 1;
                    // Seat the survivors -- driver first, so a crew short a man still rolls -- then fold the
                    // tank into the convoy: the crew join the convoy group so the tank road-marches home with
                    // the trucks and escort as one column to the zone itself, the real distance to their lines,
                    // rather than driving off alone. The mounted security team rides back in the trucks; a team
                    // already pulled out by an ambush is turned for home too.
                    private _seats = [{ _this moveInDriver _tank }, { _this moveInCommander _tank }, { _this moveInGunner _tank }];
                    { _x call (_seats param [_forEachIndex, {}]) } forEach _liveCrew;
                    (units _crewGrp) joinSilent _convoyGrp;
                    // Home at a road pace unless the convoy was hit: a crew that reached the tank unopposed
                    // drives back unhurried on LIMITED, one ambushed en route or at the hull races for its
                    // lines on FULL. Same casualty/damage test that pours the security team out.
                    private _homeSpeed = ["LIMITED", "FULL"] select (call _underAttack);
                    _convoyGrp setBehaviour "AWARE";
                    _convoyGrp setCombatMode "YELLOW";
                    _convoyGrp setSpeedMode _homeSpeed;
                    _convoyGrp setFormation "COLUMN";
                    private _twp = _convoyGrp addWaypoint [_zonePos, 0];
                    _twp setWaypointType "MOVE";
                    _twp setWaypointSpeed _homeSpeed;
                    // Fold the tank into the convoy's reliability layer for the run home: forceFollowRoad
                    // and a stuck watchdog on the hull too, so the escape is a real drive the player must
                    // intercept rather than one the AI hands back by wedging. A watchdog of its own covers
                    // just the tank -- the one spawned at the start still holds the trucks and escort -- and
                    // both read this group's live home waypoint and end together in _finish.
                    [_convoyGrp, [_tank]] call fnc_convoy_setup;
                    [_convoyGrp, [_tank]] spawn fnc_convoy_watch;
                    if (!isNull _teamGrp && {_teamOut}) then {
                        _teamGrp setBehaviour "AWARE";
                        private _rtb = _teamGrp addWaypoint [_zonePos, 0];
                        _rtb setWaypointType "MOVE";
                    };
                    [localize "STR_DUWS_T_allseer", localize "STR_DUWS_T_destroyarmour_repaired"] remoteExec ["fnc_duws_dialogue", 0];
                };
            } else {
                _repairAt = -1;   // pushed off the tank -- the work does not carry over
            };
        };
    };
};
