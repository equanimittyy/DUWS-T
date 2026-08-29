// Locality: server -- callers remoteExec to target 2.
params ["_MissionPos", "_mission_name"];
private _requester = remoteExecutedOwner;

#define SNIPER_FLUSH_DIST 500   // a player this close, or a hit, releases a team to move
#define SNIPER_MIN_SEP    400   // teams sited at least this far apart when the ring allows it

private _build = {
    params ["_targetpos", "_randomPos", "_radius"];

    private _teamCount = 1 + floor random 3;   // 1..3 two-man teams
    private _allSnipers = [];
    private _allGroups = [];
    private _placedPerches = [];   // perch of each team already sited, to space the next one off them

    for "_t" from 1 to _teamCount do {
        // Best prone overlook in the ring: score each land sample on height over its 60 m surroundings and
        // how far it sees down eight bearings (terrain-only rays, generation-time). Track two bests -- the
        // best clearing SNIPER_MIN_SEP from placed teams (preferred, so they spread), and the best
        // regardless (used only when the ring is too tight). Elevation is scored, not gated, so a flat AO
        // does not collapse every team onto _targetpos.
        private _ring = [0, 45, 90, 135, 180, 225, 270, 315];
        private _perchAny = _targetpos;  private _dirAny = 0;  private _scoreAny = -1000000;
        private _perchSep = _targetpos;  private _dirSep = 0;  private _scoreSep = -1000000;
        for "_i" from 0 to 23 do {
            private _cand = _targetpos getPos [50 + random (_radius - 50), random 360];
            if (!(surfaceIsWater _cand)) then {
                private _z = getTerrainHeightASL _cand;
                private _ringSum = 0;
                { _ringSum = _ringSum + getTerrainHeightASL (_cand getPos [60, _x]) } forEach _ring;
                private _relElev = _z - _ringSum / 8;
                private _eye = [_cand select 0, _cand select 1, _z + 0.5];
                private _openSum = 0;
                private _candBestRay = 0;
                private _candBestDir = 0;
                {
                    private _dir = _x;
                    private _clear = 700;
                    for "_d" from 70 to 700 step 70 do {
                        private _tp = _cand getPos [_d, _dir];
                        if (terrainIntersectASL [_eye, [_tp select 0, _tp select 1, (getTerrainHeightASL _tp) + 1]]) exitWith {
                            _clear = _d - 70;
                        };
                    };
                    _openSum = _openSum + _clear;
                    if (_clear > _candBestRay) then { _candBestRay = _clear; _candBestDir = _dir };
                } forEach _ring;
                // Elevation leads; openness is a bounded tie-breaker. Rays cap at 700 m, so a flat plain
                // reads as open as a hill and raw-weighted out-scored it, putting teams low. Normalise
                // openness to 0..5 m-equivalent so height decides the perch, openness only breaks ties.
                private _score = _relElev + 5 * (_openSum / 5600);
                if (_score > _scoreAny) then { _scoreAny = _score; _perchAny = _cand; _dirAny = _candBestDir };
                if ((_placedPerches findIf { _cand distance2D _x < SNIPER_MIN_SEP }) < 0) then {
                    if (_score > _scoreSep) then { _scoreSep = _score; _perchSep = _cand; _dirSep = _candBestDir };
                };
            };
        };
        private _perch = _perchAny;
        private _perchDir = _dirAny;
        if (_scoreSep > -1000000) then { _perch = _perchSep; _perchDir = _dirSep };
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

        [_target1] spawn { params ["_unit"]; sleep 5; _unit addMagazineGlobal "FileTopSecret" };
        [_target2] spawn { params ["_unit"]; sleep 5; _unit addMagazineGlobal "FileTopSecret" };

        if (hardcore_mode_enable) then {
            [[_target1, _target2], "objective"] call fnc_search_flag_group;
        };

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

        // Hold this team prone and still until threatened, then release both to move and fight. Ends
        // when the pair is dead too, so the monitor cannot outlive the objective it watches.
        [_group, [_target1, _target2]] spawn {
            params ["_grp", "_snipers"];
            waitUntil {
                sleep 3;
                private _live = _snipers select { alive _x };
                (_live isEqualTo [])
                || {_grp getVariable ["DUWS_sniperFlushed", false]}
                || {_live findIf { private _s = _x; (allPlayers findIf { alive _x && {_x distance2D _s < SNIPER_FLUSH_DIST} }) >= 0 } >= 0}
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

private _radius = 1000;
private _site = [_MissionPos, _radius, 5, _requester] call fnc_mission_site;
if (_site isEqualTo []) exitWith {};
_site params ["_randomPos", "_Building", "_targetpos"];

private _taskId = format ["sniperhunt%1%2", round (_MissionPos select 0), round (_MissionPos select 1)];
[_requester, "STR_DUWS_T_MISSION_GEN_BUILD"] call fnc_mission_notice;
private _handles = [_targetpos, _randomPos, _radius, _Building] call _build;
if (isNil "_handles") then { _handles = [] };

private _marker = [_randomPos, _radius, _taskId, localize "STR_DUWS_T_16dh939j", _mission_name, "kill",
    [["STR_DUWS_T_OVERLORD", "STR_DUWS_T_sniperletsdothis", 8], ["STR_DUWS_T_actionteam", "STR_DUWS_T_snipercopy", 0]]
] call fnc_mission_present;

sleep 5; // let the teams finish arriving before the win poll starts

private _deadline = DUWS_curDeadlineAt;
waitUntil { sleep 2; (_handles call _done) || time > _deadline };

if (!(_handles call _done) && time > _deadline) exitWith {
    [_mission_name, _taskId, "FAILED", _targetpos, _radius, [_marker]] call fnc_mission_finish;
};

[_mission_name, _taskId, "SUCCEEDED", _targetpos, _radius, [_marker], ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_sniperend"], true] call fnc_mission_finish;
