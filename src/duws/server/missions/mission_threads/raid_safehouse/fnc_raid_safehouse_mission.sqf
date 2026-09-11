// Locality: server -- callers remoteExec to target 2. The breach EHs, the ask actions and the door
// animations run on the machines they are keyed to (this thread remoteExecs them out).
//
// Raid an informant safehouse hidden in a friendly/neutral town. Several candidate houses are furnished,
// locked shut and marked "?" on the map; one holds the cache and its guards, the rest hold innocent
// locals. The player works the crowd for tips -- each ruling out a decoy or bearing toward the real house
// -- then breaches by shooting a door open. The real house's occupants wake to an elite OPFOR cell after a
// short fuse; clearing them frees the intel crate (turned in at HQ analysis). Breaching a wrong house
// costs town standing.
params ["_MissionPos", "_mission_name"];
private _requester = remoteExecutedOwner;

// TUNABLE. Total candidate houses cap, the building-search radius floor (matches the site finder; the
// live radius is the town's own, floored here), and the per-house occupant count. Groups run large, so
// the house cap is deliberately low.
#define MAX_HOUSES 8
#define MIN_RADIUS 350

// Resolve the town this offer sits on (the finder returned a town centre): the nearest registered town is
// it. civ_locations / civ_radii are server-only, and this is server-side. Needed for the wrong-raid rep
// charge and to work the town's crowd.
private _locs  = missionNamespace getVariable ["civ_locations", []];
private _radii = missionNamespace getVariable ["civ_radii", []];
if (_locs isEqualTo []) exitWith { [23, _requester, "no_towns_registered"] call fnc_mission_abort };
private _townIndex = -1;
private _bestD = 1e9;
{ private _d = (getPos _x) distance2D _MissionPos; if (_d < _bestD) then { _bestD = _d; _townIndex = _forEachIndex } } forEach _locs;
private _townPos    = getPos (_locs select _townIndex);
private _townRadius = _radii param [_townIndex, 200];

if (!([23, _MissionPos, _mission_name, _requester] call fnc_mission_begin)) exitWith {};

private _radius = MIN_RADIUS max _townRadius;

// Door-having, enterable houses only -- a house with no openable door can't be locked or breached, so it
// is no safehouse (matches the site finder's gate).
private _usable = ([_MissionPos, 3, _radius] call fnc_usableBuildings) select { (count ([_x] call fnc_house_doors)) > 0 };
if (count _usable < 4) exitWith { [23, _requester, "no_door_cluster"] call fnc_mission_abort };

private _count = (4 + floor random (MAX_HOUSES - 3)) min (count _usable);   // 4-8, capped at what exists
private _bldgs = [];
private _pool = +_usable;
for "_i" from 1 to _count do { _bldgs pushBack (_pool deleteAt (floor random (count _pool))) };
private _realBldg = selectRandom _bldgs;
private _decoys = _bldgs - [_realBldg];

private _taskId = format ["raidsafehouse%1%2", round (_MissionPos select 0), round (_MissionPos select 1)];
[_requester, "STR_DUWS_T_MISSION_GEN_BUILD"] call fnc_mission_notice;

private _civBodies = missionNamespace getVariable ["civ_array", []];
if (_civBodies isEqualTo []) then { _civBodies = ["C_man_1"] };

// Building slots nearest the interior centroid first: a perimeter slot sits against a wall, wedging
// furniture or a crate where it clips. Reused for furniture, crate and occupant placement.
private _fnc_innerSlots = {
    params ["_bldg"];
    private _positions = [_bldg] call BIS_fnc_buildingPositions;
    if (count _positions <= 1) exitWith { _positions };
    private _sx = 0; private _sy = 0;
    { _sx = _sx + (_x select 0); _sy = _sy + (_x select 1) } forEach _positions;
    private _cen = [_sx / count _positions, _sy / count _positions, 0];
    private _scored = _positions apply { [_cen distance2D _x, _x] };
    _scored sort true;
    _scored apply { _x select 1 }
};

// Spawns one blended safehouse guard: a raw CIVILIAN-side body, captive and unarmed while it hides among
// the house's occupants until the breach flips it. Kept off fnc_civ_spawnUnit so it carries no town billing
// (it is an enemy, not a local) -- only the rating-cancel below, in case it is shot before it turns.
private _fnc_spawnGuard = {
    params ["_pos"];
    private _g = createGroup [CIVILIAN, true];
    private _u = _g createUnit [selectRandom _civBodies, _pos, [], 0, "NONE"];
    if (isNull _u) exitWith { objNull };
    removeAllWeapons _u;
    _u setCaptive true;
    _u setDir (random 360);
    _u setPosATL _pos;
    _u setBehaviour "SAFE";
    _u setVariable ["DUWS_safehouse_occupant", true];
    // Cancel only the engine's global civ-kill rating tank if shot before the flip; once EAST, a kill is
    // a plain enemy kill and carries no penalty to undo.
    _u addEventHandler ["Killed", {
        params ["_unit", "_killer", "_instigator"];
        if (side _unit == CIVILIAN) then {
            private _who = _instigator; if (isNull _who) then { _who = _killer };
            if (!isNull _who) then { _who addRating 500 };
        };
    }];
    _u
};

private _guards = [];
private _allUnits = [];
private _marks = [];

{
    private _bldg = _x;
    private _isReal = _bldg isEqualTo _realBldg;

    // "?" marker at the house itself: the player sees every possible safehouse but not which is real.
    private _cpos = getPosATL _bldg;
    private _mk = format ["raidsh_%1_%2_%3", round (_cpos select 0), round (_cpos select 1), _forEachIndex];
    createMarker [_mk, _cpos];
    _mk setMarkerType "hd_unknown_noShadow";
    _mk setMarkerColor "ColorYellow";
    _mk setMarkerText "";
    _marks pushBack _mk;
    _bldg setVariable ["DUWS_safehouse_marker", _mk];
    _bldg setVariable ["DUWS_safehouse_real", _isReal];
    _bldg setVariable ["DUWS_safehouse_townIndex", _townIndex];
} forEach _bldgs;

// The intel crate, in an inner slot of the real house. Cleared of its default cargo, then stuffed with
// documents (bare classes the analysis terminal reads -- strip the Item_ ground-holder prefix), one
// guaranteed FilesSecret for a certain reveal. Turned in at HQ, not paid here.
private _realSlots = [_realBldg] call _fnc_innerSlots;
private _cratePos = _realSlots select ((count _realSlots) - 1);   // a back slot, away from the door
private _crate = createVehicle ["Land_PlasticCase_01_medium_F", _cratePos, [], 0, "CAN_COLLIDE"];   // TUNABLE class
clearItemCargoGlobal _crate; clearMagazineCargoGlobal _crate; clearWeaponCargoGlobal _crate; clearBackpackCargoGlobal _crate;
_crate setPosATL _cratePos;
_crate setVelocity [0, 0, 0];
_crate allowDamage false;
[_crate, "mission_raid_safehouse"] call fnc_duws_keep;
_crate addItemCargoGlobal [("Item_FilesSecret" select [5]), 1];
for "_i" from 1 to (6 + floor random 5) do {
    private _pick = DUWS_intelDocuments selectRandomWeighted DUWS_intelDocumentWeights;
    _crate addItemCargoGlobal [_pick select [5], 1];
};

// active is broadcast (the client ask action tests it); real/decoys are server-only reads. guards points at
// the _guards array the background build fills, so breach reads the same reference and sees them once spawned.
missionNamespace setVariable ["DUWS_safehouse_real", _realBldg];
missionNamespace setVariable ["DUWS_safehouse_decoys", _decoys];
missionNamespace setVariable ["DUWS_safehouse_guards", _guards];
DUWS_safehouse_active = true;
publicVariable "DUWS_safehouse_active";

// Build and furnish off the critical path so the ask mechanic and the task reach players now, not after the
// slow furniture settle. Lock and breach-arm ride here too: a breach flips the live DUWS_safehouse_guards, so
// no breach vector may go live before the guards spawn.
[_bldgs, _realBldg, _townIndex, _civBodies, _fnc_innerSlots, _fnc_spawnGuard, _guards, _allUnits] spawn {
    params ["_bldgs", "_realBldg", "_townIndex", "_civBodies", "_fnc_innerSlots", "_fnc_spawnGuard", "_guards", "_allUnits"];

    // Decoy locals spawn as town civilians, so killing one bills the town. Both sides garrison via
    // fnc_holdBuildingPost, whose loop keys off the unit: it survives a guard's flip to EAST, so the same men
    // fight from the house rather than charge the street.
    {
        private _bldg = _x;
        private _isReal = _bldg isEqualTo _realBldg;
        private _slots = [_bldg] call _fnc_innerSlots;
        if (_slots isEqualTo []) then { _slots = [getPosATL _bldg] };

        private _n = (3 + floor random 3) min count _slots;
        private _occupants = [];
        for "_i" from 0 to (_n - 1) do {
            private _spos = _slots select (_i mod count _slots);
            private _u = if (_isReal) then {
                [_spos] call _fnc_spawnGuard
            } else {
                private _c = [_townIndex, _spos, selectRandom _civBodies, false] call fnc_civ_spawnUnit;
                if (!isNull _c) then {
                    _c setVariable ["DUWS_safehouse_occupant", true];   // keep the ask poll off the shut-in locals
                    _c setPosATL _spos;
                };
                _c
            };
            if (!isNull _u) then {
                _occupants pushBack _u; _allUnits pushBack _u;
                [_u, _bldg, _slots, "AUTO"] spawn fnc_holdBuildingPost;
            };
        };
        _bldg setVariable ["DUWS_safehouse_occupants", _occupants];
        if (_isReal) then { _guards append _occupants };

        // bis_disabled_Door_N kills the open action; the animate shuts the leaf so no house shows an open door.
        // The furnish pass below reopens doors to scan, but server-side only, so these client leaves stay shut.
        for "_i" from 1 to 10 do { _bldg setVariable [format ["bis_disabled_Door_%1", _i], 1, true] };
        [[_bldg], { params ["_h"]; for "_i" from 1 to 10 do { _h animateDoor [format ["Door_%1_rot", _i], 0] } }] remoteExec ["BIS_fnc_call", 0];
    } forEach _bldgs;

    // Guards exist now, so a breach can wake them: arm the door shot, then poll for an entry breach too (a
    // raider inside through a gap or blown wall, no door shot).
    { [_x] remoteExec ["fnc_raid_safehouse_arm", 0, _x] } forEach _bldgs;
    [_bldgs] spawn {
        params ["_bldgs"];
        while { missionNamespace getVariable ["DUWS_safehouse_active", false] } do {
            {
                private _h = _x;
                if (!(_h getVariable ["DUWS_safehouse_breached", false])) then {
                    // Inside a reconstructed room, not just within the footprint: the furnish grid's floor cells
                    // stop at the walls, so a player in an L-shaped notch or against an outside wall has none near.
                    private _cells = _h getVariable ["DUWS_furnishGrid", []];
                    if ((allPlayers findIf {
                        private _pa = getPosASL _x;
                        (_cells findIf { _pa distance (_x select 0) < 0.6 }) >= 0
                    }) >= 0) then {
                        [_h, "ALL"] call fnc_raid_safehouse_breach;
                    };
                };
            } forEach _bldgs;
            sleep 2;   // TUNABLE
        };
    };

    // Furniture last (slow settle), held a full cell clear of every doorway, so no piece is sealed behind a
    // leaf and it is safe to run after the lock.
    { [_x, "mission_raid_safehouse", 0] call fnc_furnish_building } forEach _bldgs;
};

// Thicken the street crowd so there is always someone to ask, and re-open every local already in town (a
// survivor of an earlier event still reads asked). Occupants are flagged out -- only the street answers.
private _crowd = [];
{ _x setVariable ["DUWS_safehouse_asked", false, true] } forEach
    (allUnits select { (_x getVariable ["civ_locIndex", -1]) == _townIndex && !(_x getVariable ["DUWS_safehouse_occupant", false]) });
private _spawnRadius = (_townRadius * 0.5) max 100;
private _crowdGroups = [];
for "_i" from 1 to 6 do {
    private _anchor = [_townPos, 0, _spawnRadius, 2, 0, 0.35, 0] call BIS_fnc_findSafePos;
    if (_anchor isEqualTo [0,0,0]) then { _anchor = _townPos };
    private _grp = grpNull;
    for "_j" from 0 to 2 do {
        private _cpos = _anchor getPos [_j * 3, random 360];
        private _c = [_townIndex, _cpos, selectRandom _civBodies, false] call fnc_civ_spawnUnit;
        if (!isNull _c) then {
            _crowd pushBack _c; _allUnits pushBack _c;
            if (isNull _grp) then { _grp = group _c } else { [_c] joinSilent _grp };
        };
    };
    if (!isNull _grp) then { _crowdGroups pushBack _grp };
};
private _townBuildings = (missionNamespace getVariable [format ["civ_buildings_%1", _townIndex], []]) select { !isNull _x };
[_crowdGroups, _townBuildings] spawn fnc_civ_wp_Tomata;

// Poll the ask action onto every street local -- not a one-off sweep, since the crowd is not all present
// at start. Askable flags the one-time add; the loop ends with the raid and the action self-hides.
[_townIndex] spawn {
    params ["_ti"];
    while { missionNamespace getVariable ["DUWS_safehouse_active", false] } do {
        {
            if !(_x getVariable ["DUWS_safehouse_askable", false]) then {
                _x setVariable ["DUWS_safehouse_askable", true];
                [_x] remoteExec ["fnc_raid_safehouse_ask_addAction", 0, _x];
            };
        } forEach (allUnits select { (_x getVariable ["civ_locIndex", -1]) == _ti && !(_x getVariable ["DUWS_safehouse_occupant", false]) });
        sleep 5;
    };
};

// Marker + task now the raid stands. Brief formats with the nearest place name (fnc_mission_present).
private _markername2 = [_MissionPos, _radius, _taskId, localize "STR_DUWS_T_RAID_SAFEHOUSE_DESC", _mission_name, "search",
    [["STR_DUWS_T_OVERLORD", "STR_DUWS_T_RAID_SAFEHOUSE_BRIEF", 6], ["STR_DUWS_T_actionteam", "STR_DUWS_T_RAID_SAFEHOUSE_COPY"]]] call fnc_mission_present;

// Win/fail watcher. Win when the real house is breached and its guards are all down; fail on the deadline.
// Sole finisher (no addAction success path here), so it also unlocks the surviving houses and clears the
// crowd it spawned -- the town must not be left with permanently locked doors.
[_realBldg, _guards, _bldgs, _taskId, _markername2, _MissionPos, _radius, _mission_name, _marks, _allUnits] spawn {
    params ["_realBldg", "_guards", "_bldgs", "_taskId", "_marker", "_tpos", "_radius", "_mission_name", "_marks", "_allUnits"];
    private _token = DUWS_mission_token;
    private _deadline = DUWS_curDeadlineAt;
    private _outcome = "";
    waitUntil {
        sleep 3;
        if (Mission_available || DUWS_mission_token != _token) exitWith { _outcome = "GONE"; true };
        if (time > _deadline) exitWith { _outcome = "TIMEOUT"; true };
        // count _guards > 0 guards the build window: an empty list would read as "all guards down" and win on
        // the first breach.
        if ((_realBldg getVariable ["DUWS_safehouse_breached", false]) && {count _guards > 0} && {({ alive _x } count _guards) == 0}) exitWith { _outcome = "WIN"; true };
        false
    };

    DUWS_safehouse_active = false;
    publicVariable "DUWS_safehouse_active";
    // Lift the lock off every candidate so the town returns to normal; a breached house is already open.
    { private _h = _x; for "_i" from 1 to 10 do { _h setVariable [format ["bis_disabled_Door_%1", _i], 0, true] } } forEach _bldgs;

    if (_outcome isEqualTo "GONE") exitWith {};   // slot already recycled elsewhere; do not double-finish

    // Ownership teardown: claim every unit this raid spawned (enemy guards + decoy/crowd civilians) so the
    // finish below releases them to the map sweep (keep-radius). A dead guard's searchable corpse rides the
    // same sweep -- held while a player is near, taken once they leave.
    [_allUnits] call fnc_mission_claim;

    { deleteMarker _x } forEach _marks;
    if (_outcome isEqualTo "WIN") then {
        [_mission_name, _taskId, "SUCCEEDED", _tpos, _radius, [_marker], ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_RAID_SAFEHOUSE_DONE"], true, "mission_raid_safehouse", false, false] call fnc_mission_finish;
    } else {
        [_mission_name, _taskId, "FAILED", _tpos, _radius, [_marker], [], false, "mission_raid_safehouse", false, true] call fnc_mission_finish;
    };

    // No manual delete: the units were claimed above, so the finish calls released them to the map sweep.
};
