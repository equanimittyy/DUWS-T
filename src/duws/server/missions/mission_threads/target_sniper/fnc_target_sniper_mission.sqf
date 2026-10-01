// Locality: server -- callers remoteExec to target 2.
params ["_MissionPos", "_mission_name"];
private _requester = remoteExecutedOwner;

#define SNIPER_FLUSH_DIST 500   // a player this close, or a hit, releases a team to move
#define SNIPER_MIN_SEP    400   // teams sited at least this far apart when the ring allows it
#define PERCH_COUNT       6
#define PERCH_SEP         150   // so a move is a real relocation, not a shuffle on one hilltop
#define PERCH_HOLD        180   // a perch is held for 1-2x this many seconds

private _build = {
    params ["_targetpos", "_randomPos", "_radius"];

    private _teamCount = 1 + floor random 3;   // 1..3 two-man teams
    private _allSnipers = [];
    private _allGroups = [];
    private _placedPerches = [];   // perch of each team already sited, to space the next one off them

    private _ring = [0, 45, 90, 135, 180, 225, 270, 315];
    private _openBearing = {
        private _eye = [_this select 0, _this select 1, (getTerrainHeightASL _this) + 0.5];
        private _bestRay = 0;
        private _bestDir = 0;
        {
            private _dir = _x;
            private _clear = 700;
            for "_d" from 70 to 700 step 70 do {
                private _tp = _this getPos [_d, _dir];
                if (terrainIntersectASL [_eye, [_tp select 0, _tp select 1, (getTerrainHeightASL _tp) + 1]]) exitWith {
                    _clear = _d - 70;
                };
            };
            if (_clear > _bestRay) then { _bestRay = _clear; _bestDir = _dir };
        } forEach _ring;
        _bestDir
    };

    // Best first. Height in the zone leads, so a perch sits on the zone's high ground, not on a bump in a
    // valley; the rise over a 60 m ring lifts a crest or a plateau rim over flat ground at the same height.
    private _samples = [];
    for "_i" from 1 to 64 do {
        private _cand = _targetpos getPos [_radius * sqrt (random 1), random 360];
        if (!(surfaceIsWater _cand)) then {
            private _z = getTerrainHeightASL _cand;
            private _ringSum = 0;
            { _ringSum = _ringSum + getTerrainHeightASL (_cand getPos [60, _x]) } forEach _ring;
            _samples pushBack [_z + (_z - _ringSum / 8), _cand];
        };
    };
    _samples sort false;
    private _vacant = [];   // [perch, facing]
    {
        private _cand = _x select 1;
        if ((_vacant findIf { _cand distance2D (_x select 0) < PERCH_SEP }) < 0) then {
            _vacant pushBack [_cand, _cand call _openBearing];
        };
        if (count _vacant == PERCH_COUNT) exitWith {};
    } forEach _samples;

    for "_t" from 1 to _teamCount do {
        private _pick = _vacant findIf { private _p = _x select 0; (_placedPerches findIf { _p distance2D _x < SNIPER_MIN_SEP }) < 0 };
        private _home = _vacant deleteAt (_pick max 0);
        _home params ["_perch", "_perchDir"];
        _placedPerches pushBack _perch;

        // The "sniper_element" token drawn from the faction pools, raised through fnc_spawn_team with
        // posture none and the perch as _spawnPos: the perch siting below (setPosATL, setDir) is the
        // circuit a posture would otherwise add, which none omits, and the spawn point overrides the band.
        private _group = ["sniper_element", _perch, 0, "none", _perch, "opfor"] call fnc_spawn_team;
        [_group] call fnc_mission_claim;
        private _target1 = units _group select 0;
        private _target2 = units _group select 1;

        // Spread the pair off the perch and face them both down the open bearing so they open the
        // mission already watching the ground the ray found clear.
        _target2 setPosATL (_perch getPos [8, _perchDir + 90]);
        _group setFormDir _perchDir;
        { _x setDir _perchDir } forEach [_target1, _target2];

        {
            _x setSkill ["aimingAccuracy", 1];
            _x setSkill ["aimingShake", 1];
            _x setSkill ["aimingSpeed", 1];
            _x setSkill ["spotDistance", 1];
            _x setSkill ["spotTime", 1];
            _x setSkill ["general", 1];
            _x setUnitPos "DOWN";
            _x disableAI "PATH";
            _x addEventHandler ["Hit", { (group (_this select 0)) setVariable ["DUWS_sniperFlushed", true] }];
        } forEach [_target1, _target2];
        _group setBehaviour "COMBAT";

        if (VERSION_X == "MODERN") then {
            if !(("OPTRE" in BLUFOR_FactionFile_X)
                or ("HL2ECR" in BLUFOR_FactionFile_X)
                or ("TIOW" in BLUFOR_FactionFile_X)) then {
                removeheadgear _target1;
                removeheadgear _target2;
                _target1 addHeadgear "H_Shemag_khk";
                _target2 addHeadgear "H_Shemag_khk";
            };
        };

        // Ends when the pair is dead too, so the loop cannot outlive the objective it watches.
        [_group, [_target1, _target2], _home, _vacant] spawn {
            params ["_grp", "_snipers", "_home", "_vacant"];
            private _flushed = {
                private _live = _snipers select { alive _x };
                (_live isEqualTo [])
                || {_grp getVariable ["DUWS_sniperFlushed", false]}
                || {_live findIf { private _s = _x; (allPlayers findIf { alive _x && {_x distance2D _s < SNIPER_FLUSH_DIST} }) >= 0 } >= 0}
            };
            while { !(call _flushed) } do {
                private _moveAt = time + PERCH_HOLD + random PERCH_HOLD;
                waitUntil { sleep 3; (call _flushed) || {time > _moveAt} };
                // _vacant is shared by every team's loop: no suspension between the check and the take.
                if (_vacant isNotEqualTo [] && {!(call _flushed)}) then {
                    private _next = _vacant deleteAt floor random count _vacant;
                    _vacant pushBack _home;
                    _home = _next;
                    _home params ["_perch", "_perchDir"];
                    { _x enableAI "PATH"; _x setUnitPos "AUTO" } forEach _snipers;
                    _grp move _perch;
                    // A pair that cannot path up to the perch settles where it stands and tries the next one.
                    private _giveUpAt = time + 600;
                    waitUntil { sleep 3; (call _flushed) || {(leader _grp) distance2D _perch < 15} || {time > _giveUpAt} };
                    if (call _flushed) exitWith {};
                    _grp setFormDir _perchDir;
                    { if (alive _x) then { _x setDir _perchDir; _x setUnitPos "DOWN"; _x disableAI "PATH" } } forEach _snipers;
                };
            };
            { if (alive _x) then { _x setUnitPos "AUTO"; _x enableAI "PATH" } } forEach _snipers;
            _grp setBehaviour "COMBAT";
            _grp setCombatMode "RED";
        };

        { [_x] call fnc_addRandomLoot } forEach units _group;

        _allGroups pushBack _group;
        _allSnipers append [_target1, _target2];
    };

    // Auto-aware, but only inside the AO: pin each team's knowledge of every in-ring player at 4 (exact
    // position). knowsAbout decays, so re-applied until the last sniper dies -- inside the ring they never
    // lose the player; past _radius the player falls off normal spotting.
    [_allGroups, _allSnipers, _targetpos, _radius] spawn {
        params ["_grps", "_snipers", "_aoCentre", "_aoRadius"];
        while { (_snipers findIf { alive _x }) >= 0 } do {
            private _inAo = allPlayers select { alive _x && {_x distance2D _aoCentre < _aoRadius} };
            { private _g = _x; { _g reveal [_x, 4] } forEach _inAo } forEach _grps;
            sleep 5;
        };
    };

    _allSnipers
};

private _done = { (_this findIf { alive _x }) < 0 };

if (!([5, _MissionPos, _mission_name, _requester] call fnc_mission_begin)) exitWith {};

private _radius = 600;
// Trust the offer: the perch search anchors on the offered near-enemy dot.
private _randomPos = _MissionPos;
private _targetpos = _MissionPos;

private _taskId = format ["sniperhunt%1%2", round (_MissionPos select 0), round (_MissionPos select 1)];
[_requester, "STR_DUWS_T_MISSION_GEN_BUILD"] call fnc_mission_notice;
private _handles = [_targetpos, _randomPos, _radius] call _build;
if (isNil "_handles") then { _handles = [] };

private _marker = [_randomPos, _radius, _taskId, localize "STR_DUWS_T_16dh939j", _mission_name, "kill",
    [["STR_DUWS_T_OVERLORD", "STR_DUWS_T_sniperletsdothis", 6], ["STR_DUWS_T_actionteam", "STR_DUWS_T_snipercopy", 0]]
] call fnc_mission_present;

[_handles, _done, _mission_name, _taskId, _targetpos, _radius, [_marker],
    ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_sniperend"]] call fnc_mission_watch;
