// Locality: server -- callers remoteExec to target 2; watcher threads spawned here inherit it.
params ["_MissionPos", "_mission_name", ["_destZone", []]];
private _requester = remoteExecutedOwner;
if (!([11, _MissionPos, _mission_name, _requester] call fnc_mission_begin)) exitWith {};

#define DA_RADIUS      300      // objective ring drawn and searched within
#define DA_CONVOY_DIST 1000     // fallback convoy entry distance when no OPFOR zone is known
#define DA_DISEMBARK   140      // troops dismount once their transport is this close to the tank
#define DA_ARRIVE      15       // a live crewman this close to the tank is working on it (AI halts at the hull)
#define DA_ARRIVE_ZONE 150      // a repaired tank this close to its home zone has got away (fail)
#define DA_REQUISITION_DMG 0.65  // mean part damage, not getDammage (field repair never moves it); toolkit repair floors the parts at ~0.6, so this is thin headroom over that floor

// Repair time scales inversely with the nearest OPFOR zone's distance (NEAR at/inside NEARDIST, FAR
// at/beyond FARDIST, linear between): a tank repaired near its own lines is the harder denial.
#define DA_REPAIR_NEAR      300    // repair seconds at/inside DA_REPAIR_NEARDIST
#define DA_REPAIR_FAR       30     // repair seconds at/beyond DA_REPAIR_FARDIST
#define DA_REPAIR_NEARDIST  1000
#define DA_REPAIR_FARDIST   4000

private _compKey = "mission_deny_armor";
private _cpreward = DUWS_curReward select 0;
private _apreward = DUWS_curReward select 1;
private _deadline = DUWS_curDeadlineAt;

// Trust the offer: the finder vetted a road within reach; the tank snaps onto it below.
private _randomPos = _MissionPos;
private _targetpos = _MissionPos;

// Within ~100 m of a road so the convoy rides the network in and the repaired tank drives home on it, yet
// off the carriageway so it reads as a derelict.
private _vehpos = [];
private _tankRoads = _targetpos nearRoads 100;
if !(_tankRoads isEqualTo []) then {
    _vehpos = [getPosATL (selectRandom _tankRoads), 30, 8, 12, 0.2, []] call fnc_safe_pos;
};
if (_vehpos isEqualTo []) then { _vehpos = [_targetpos, 25, 5, 12, 0.2] call fnc_safe_pos };

private _taskId = format ["destroyarmour%1%2", round (_MissionPos select 0), round (_MissionPos select 1)];

// The broken-down tank: empty (createVehicle raises no crew), pre-damaged with part fuel and ammo so it
// reads as a derelict, the enemy repair is a real state change, and a requisitioned hull can still RTB and
// fight. Persistent so the abandoned-vehicle sweep cannot reap it before anyone arrives. Neither claimed
// nor kept: a claim deletes, and a winner drives this home.
[_requester, "STR_DUWS_T_MISSION_GEN_BUILD"] call fnc_mission_notice;
private _tank = createVehicle [opfor_MBT_TANK1_X, _vehpos, [], 0, "CAN_COLLIDE"];
_tank setDir (random 360);
[_tank, 0.8] call fnc_veh_set_comp_damage;
_tank setFuel 0.5;
_tank setVehicleAmmo 0.1;
[_tank] call fnc_veh_disable_engine;
_tank setVariable ["persistent", true];

private _marker = [_randomPos, DA_RADIUS, _taskId, localize "STR_DUWS_T_destroyarmour_desc", _mission_name, "destroy"] call fnc_mission_present;
private _place = [_randomPos] call fnc_place_name;
[localize "STR_DUWS_T_OVERLORD", format [localize "STR_DUWS_T_destroyarmour_start", _place]] remoteExec ["fnc_duws_dialogue", 0];
sleep 6;
[localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_destroyarmour_copy"] remoteExec ["fnc_duws_dialogue", 0];

private _opforZones = missionNamespace getVariable ["WARCOM_zones_controled_by_OPFOR", []];
private _bearing = random 360;
private _convoyDist = DA_CONVOY_DIST;
private _zoneDist = DA_REPAIR_NEARDIST;   // no zone known -> treat as the near case, the full repair window
private _zonePos = [];
// Prefer the siting pass's vetted home zone (corridor clear of BLUFOR) while still OPFOR-held.
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
private _repairTime = linearConversion [DA_REPAIR_NEARDIST, DA_REPAIR_FARDIST, _zoneDist, DA_REPAIR_NEAR, DA_REPAIR_FAR, true];

// Convoy start: MUST snap to a road, drive in crossing no water -- an off-network start fights the
// pathfinder, one across an inlet never arrives. Past the cap any road is taken (road is the hard
// requirement, dry corridor a preference).
private _baseBearing = _bearing;
private _convoyStart = [];
private _roadR = 300;
private _spin = 0;
while { _convoyStart isEqualTo [] } do {
    _spin = _spin + 1;
    private _spread = 15 + (_spin * 5);
    _bearing = _baseBearing + (random (2 * _spread) - _spread);
    private _entry = _targetpos getPos [_convoyDist, _bearing];
    // The snap reaches _roadR from the probe, so it re-applies the probe's floor: a start inside it seats
    // the lead truck at the tank.
    private _roads = (_entry nearRoads _roadR) select { (_x distance2D _vehpos) >= DA_RADIUS + 100 };
    if !(_roads isEqualTo []) then {
        private _cand = getPosATL (_roads select 0);
        // Never seat the column inside BLUFOR's area of influence: a convoy forming up in the player's
        // bubble is cut down on spawn and auto-wins the mission with the player nowhere near. Hard
        // constraint, ANDed so the spin cap that waives the dry-route preference never waives this.
        if (!([_cand] call fnc_aoi_blufor_covers)
            && {_spin > 60 || {!([_cand, _targetpos] call fnc_route_has_water)}}) then { _convoyStart = _cand };
    };
    if (_spin % 6 == 0) then { _roadR = _roadR + 200 };
};

// No OPFOR zone left: a synthetic exfil past the convoy start stands in, so the escape is a real drive
// rather than an unreachable target.
if (_zonePos isEqualTo []) then { _zonePos = _targetpos getPos [_convoyDist + 500, _bearing] };

// Their own group so the win test reads exactly these three.
private _crewGrp = [_convoyStart, EAST, [opfor_CREW_X, opfor_CREW_X, opfor_ENG_SOLDIER_X], [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
_crewGrp deleteGroupWhenEmpty true;
private _crewUnits = units _crewGrp;

// A team, not a vehicle token, so it is faction-safe on a pack that never named this role.
private _teamGrp = ["team", _convoyStart, DA_RADIUS, "none", _convoyStart] call fnc_spawn_team;
private _teamUnits = if (isNull _teamGrp) then { [] } else { units _teamGrp };

// Route the run (convoy start -> tank) and seat the column ON it, so the trucks and escort are born on
// the drive path, spaced and road-facing, not shoulder to shoulder. Six slots: up to five trucks (a
// tiny-cargo faction truck needs several) plus the tail escort at slot 5; unused slots are ignored. The
// route is handed to the driver (DUWS_convoy_route0) below so it reuses it without teleport-reordering.
private _route0 = [_convoyStart, _vehpos] call fnc_convoy_path;
private _laid = [_route0, 6, 22] call fnc_convoy_slots;

// Unarmed transport for the crew and team, lead-first. One truck if they fit; a second/third only when
// riders overflow its cargo, so a small-cargo faction truck still carries everyone rather than
// stranding the overflow to walk in from 1 km. Crew load first, so the mission-critical three ride.
private _riders = _crewUnits + _teamUnits;
(_laid select 0) params ["_t0p", "_t0d"];
_t0p = [_t0p, opfor_TRANS_TRUCK_X] call fnc_convoy_fit;
private _truckSpawn = [_t0p, _t0d, opfor_TRANS_TRUCK_X, EAST] call BIS_fnc_spawnVehicle;
private _truck = _truckSpawn select 0;
_truck setDir _t0d;
private _trucks = [_truck];
private _truckGrps = [_truckSpawn select 2];
{
    private _cur = _trucks select (count _trucks - 1);
    if (_cur emptyPositions "cargo" == 0) then {
        (_laid select (count _trucks min 4)) params ["_tp", "_td"];   // next free slot; cap at 4 so the escort keeps the tail
        _tp = [_tp, opfor_TRANS_TRUCK_X] call fnc_convoy_fit;
        private _extra = [_tp, _td, opfor_TRANS_TRUCK_X, EAST] call BIS_fnc_spawnVehicle;
        _cur = _extra select 0;
        _cur setDir _td;
        _trucks pushBack _cur;
        _truckGrps pushBack (_extra select 2);
    };
    _x moveInCargo _cur;
} forEach _riders;

// One armed escort at the tail slot, scaled to what OPFOR can field (car/IFV/tank): DUWS_fnc_tokenClass
// answers "" for a token above the earned AP tier (and behind the HeavyArmor toggle), so the pool
// widens with the campaign. Armed-car global if not even a car is earned, so it is never unescorted.
private _escortPool = ["car", "ifv", "tank"] select { ([_x] call DUWS_fnc_tokenClass) != "" };
private _escortClass = if (_escortPool isEqualTo []) then { opfor_ARMED_CAR1_X } else { [selectRandom _escortPool] call DUWS_fnc_tokenClass };
(_laid select 5) params ["_ep", "_ed"];
_ep = [_ep, _escortClass] call fnc_convoy_fit;
private _escortSpawn = [_ep, _ed, _escortClass, EAST] call BIS_fnc_spawnVehicle;
(_escortSpawn select 0) setDir _ed;
private _escortGrp = _escortSpawn select 2;

// One convoy group so the vehicles road-march in column instead of pathing apart and arriving strung
// out: fold the escort and any second truck into the lead truck's group, dropping the emptied source
// groups. The riding crew and rifle team stay their own groups -- they are cargo, not drivers.
private _convoyGrp = _truckGrps select 0;
{
    if (_x != _convoyGrp) then { (units _x) joinSilent _convoyGrp; deleteGroup _x };
} forEach (_truckGrps + [_escortGrp]);

// The convoy's vehicles and crews, snapshotted for the under-attack test below. Taken now, before the
// repaired tank's crew is folded into the group on the way home, so this stays the convoy that set out;
// the unit objects hold wherever they are later regrouped, so a driver shot out of any hull is still dead.
private _convoyVeh = _trucks + [_escortSpawn select 0];
private _convoyCrew = units _convoyGrp;

// Contact flag for the under-attack test below, backing up the SAFE->COMBAT promotion the test also reads.
// HandleDamage is the earliest "taking fire" signal -- it fires on a round landing even from an unspotted
// shooter, and the instigator tells enemy fire from a terrain scrape (null instigator). Returns the damage
// unchanged so it never alters durability.
{
    _x setVariable ["DA_underFire", false];
    _x addEventHandler ["HandleDamage", {
        params ["_unit", "", "_damage", "", "", "", "_instigator"];
        if (!isNull _instigator && {side _instigator == west}) then { _unit setVariable ["DA_underFire", true] };
        _damage
    }];
} forEach _convoyVeh;

{ [_x] call fnc_mission_claim } forEach [_crewGrp, _teamGrp, _convoyGrp];

// Drive to the tank at a pace the player can race: LIMITED, COLUMN, SAFE so it cruises relaxed rather than
// pre-empting spotted enemies -- the engine promotes it to COMBAT on real contact, which the under-attack
// test reads. Loose completionRadius so the lead halts near the tank rather than shouldering it.
_convoyGrp setBehaviour "SAFE";
_convoyGrp setCombatMode "YELLOW";
_convoyGrp setSpeedMode "LIMITED";
_convoyGrp setFormation "COLUMN";
private _wp = _convoyGrp addWaypoint [_vehpos, 0];
_wp setWaypointType "MOVE";
_wp setWaypointCompletionRadius 40;

// Self-routing driver: every hull drives the road route holding spacing, so Arma's bad off-road routing
// cannot wedge a follower. It reads the group's hulls live, so when the repaired tank joins and the column
// re-tasks home the same driver drives it in column. Reuses the seated route (DUWS_convoy_route0).
_convoyGrp setVariable ["DUWS_convoy_route0", _route0];
[_convoyGrp] spawn fnc_convoy_drive;

// The convoy intel is never handed the instant the mission opens.
sleep 10;
// Approach direction only (the ellipse marks the tank), so it clears once the convoy arrives or is engaged.
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

private _finish = {
    params ["_status"];
    // Drop the mission-only protection: a tank the player took is now theirs under ordinary cleanup
    // (spared while crewed or near base, reaped once abandoned in the field), and a claimed one that
    // got away must not be spared by the persistent flag when cleanup comes.
    _tank setVariable ["persistent", false];
    _convoyGrp setVariable ["DUWS_convoy_stop", true];
    deleteMarker _arrow;
    // The branches keep their own outcome line, reward and timeout notice, so finish speaks and pays nothing.
    [_mission_name, _taskId, _status, _targetpos, DA_RADIUS, [_marker], [], false, _compKey, false, false] call fnc_mission_finish;
};

// Tripping this releases the convoy driver (below), whose exit re-enables the drivers' FSM so the escort
// manoeuvres natively rather than staying force-marched.
private _underAttack = {
    (!isNull _convoyGrp && {behaviour (leader _convoyGrp) == "COMBAT"})
    || {(_convoyVeh findIf { !alive _x || {_x getVariable ["DA_underFire", false]} }) >= 0}
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

    // Before the deny win, so a healthy crewed hull plays the requisition line even if the last enemy crewman
    // fell the same tick; the hull may be the player's own repair or an enemy-fixed one boarded before it got home.
    if (((crew _tank) findIf { isPlayer _x }) >= 0 && {([_tank] call fnc_veh_comp_damage) <= DA_REQUISITION_DMG}) exitWith {
        [localize "STR_DUWS_T_OVERLORD", [localize "STR_DUWS_T_destroyarmour_taken"] call fnc_cs] remoteExec ["fnc_duws_dialogue", 0];
        [_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;
        ["SUCCEEDED"] call _finish;
    };

    if (_liveCrew isEqualTo [] || _tankDead) exitWith {
        // Tank takes precedence: a destroyed hull plays the destroyed line even when the crew died with
        // it. Crew wiped but hull intact gets its own line -- the tank is denied by having no one left
        // to recover it, not by being wrecked.
        private _endStr = if (_tankDead) then { "STR_DUWS_T_destroyarmour_end" } else { "STR_DUWS_T_destroyarmour_end_crew" };
        [localize "STR_DUWS_T_OVERLORD", [localize _endStr] call fnc_cs] remoteExec ["fnc_duws_dialogue", 0];
        [_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;
        ["SUCCEEDED"] call _finish;
    };

    if ([_deadline] call fnc_time_expired) exitWith {
        ["FAILED"] call _finish;
        call fnc_mission_timeout_notice;
    };

    // Terminal fail: the repaired tank reaches its home zone with a live enemy crew aboard. Kept a
    // direct exitWith at the loop's top level so it fires once -- nested in the repair branch, exitWith
    // broke only that block, so the fail line spammed every tick and a later tank kill scored a bogus win.
    if (_repaired
        && {(_tank distance2D _zonePos) < DA_ARRIVE_ZONE}
        && {(crew _tank findIf { alive _x && !isPlayer _x }) >= 0}) exitWith {
        // Claimed only now: an escaping tank is the enemy's again, so cleanup collects it once the
        // player is clear (_finish drops its persistent flag, without which the sweep would spare the
        // live hull).
        [_tank] call fnc_mission_claim;
        ["FAILED"] call _finish;
        [localize "STR_DUWS_T_OVERLORD", [localize "STR_DUWS_T_destroyarmour_fail"] call fnc_cs] remoteExec ["fnc_duws_dialogue", 0];
    };

    // First contact drops the convoy mechanic: release the path-replay driver so every vehicle fights
    // natively -- the escort engages instead of being force-marched, the trucks halt rather than driving
    // rigidly through the ambush. The security team pours out and fights where it stands: at the tank if
    // the ambush lands there, on the road if the player jumped the column en route.
    if (!_teamOut && {call _underAttack}) then {
        _teamOut = true;
        deleteMarker _arrow;
        _convoyGrp setVariable ["DUWS_convoy_release", true];
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
            // The tank cannot be worked while a player is aboard: a stolen tank must not get a free
            // repair, and its blocked crew become targets the player finishes for the win.
            private _playerInTank = (crew _tank findIf { isPlayer _x }) >= 0;
            private _atTank = (_liveCrew findIf { (_x distance2D _tank) < DA_ARRIVE }) >= 0;
            if (_atTank && !_playerInTank) then {
                if (_repairAt < 0) then { _repairAt = time };
                if (time - _repairAt >= _repairTime) then {
                    _repaired = true;
                    _tank setDamage 0;
                    _tank setFuel 1;
                    // Seat the survivors driver-first so a crew short a man still rolls, then fold the tank
                    // into the convoy group: it road-marches home in one column to the zone rather than alone.
                    // The mounted security team rides back in the trucks; an ambush-pulled team is turned home too.
                    private _seats = [{ _this moveInDriver _tank }, { _this moveInCommander _tank }, { _this moveInGunner _tank }];
                    { _x call (_seats param [_forEachIndex, {}]) } forEach _liveCrew;
                    (units _crewGrp) joinSilent _convoyGrp;
                    private _homeSpeed = ["LIMITED", "FULL"] select (call _underAttack);
                    _convoyGrp setBehaviour "SAFE";
                    _convoyGrp setCombatMode "YELLOW";
                    _convoyGrp setSpeedMode _homeSpeed;
                    _convoyGrp setFormation "COLUMN";
                    private _twp = _convoyGrp addWaypoint [_zonePos, 0];
                    _twp setWaypointType "MOVE";
                    _twp setWaypointSpeed _homeSpeed;
                    // No new driver for the tank. Unopposed, the spawn-time convoy driver is still alive and
                    // picks up the freshly-joined tank. Ambushed, that driver was released at first contact,
                    // so native AI drives the group home at FULL -- the race the _homeSpeed split intends.
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
