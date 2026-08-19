// Locality: server -- callers remoteExec to target 2.
// Kill every sniper. 1-3 two-man teams are the ONLY things spawned: no garrison, no patrols, no
// support teams -- the teams on their perches are the whole objective, so the win is unambiguous and
// the field is empty but for them. Shared spine: fnc_mission_run.
//
// Each team is sited independently across the full objective ring by the hardpoint terrain-ray
// technique (fnc_hardpoint_siting): sample ground anywhere in the ring and score each on how high it
// stands over its surroundings (an eight-point elevation ring) and how far it looks down open terrain
// (rays marched out on eight bearings until the ground masks them) -- best score wins, and teams are
// held at least SNIPER_MIN_SEP apart so the pairs do not stack. The pair is laid prone facing the most
// open bearing -- an overwatch, not a garrison. Prone eye height is modelled in the ray (z + 0.5) so
// the perch is chosen for the stance they actually hold.
//
// Elite by override, not by campaign difficulty: their sub-skills are forced to 1 so they are as
// accurate and quick to spot as the engine allows, whatever opfor_ai_skill is. A reveal loop pins
// every team's knowledge of every in-AO player at max, so inside the ring they never lose the
// player's position. Each team holds prone and still (PATH disabled) until a player closes within
// 500 m or one of its pair is hit, then that team is released to move and fight -- a static overwatch
// that will not sit and be flanked.
params ["_MissionPos", "_mission_name"];

#define SNIPER_FLUSH_DIST 500   // a player this close, or a hit, releases a team to move
#define SNIPER_MIN_SEP    400   // teams sited at least this far apart when the ring allows it

private _build = {
    params ["_targetpos", "_randomPos", "_radius"];

    private _teamCount = 1 + floor random 3;   // 1..3 two-man teams
    private _allSnipers = [];
    private _allGroups = [];
    private _placedPerches = [];   // perch of each team already sited, to space the next one off them

    for "_t" from 1 to _teamCount do {
        // Best prone overlook anywhere in the ring: score every land sample on how high it stands over
        // its 60 m surroundings and how far it sees down eight bearings, and keep the best. Terrain-only
        // rays, generation-time; getPos on a position array is the same relative-point form the recon
        // site-finder uses. Two bests are tracked: the best that also clears SNIPER_MIN_SEP from every
        // team already placed (preferred, so the teams spread), and the best regardless (used only when
        // the ring is too tight to honour the separation). Elevation is scored, not gated, so a flat AO
        // no longer collapses every team onto _targetpos.
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
                // Elevation leads, openness is a bounded tie-breaker. Rays cap at 700 m/bearing, so a
                // flat open plain reads as "sees far" as a hill and, weighted raw, out-scored it -- that
                // put teams down low. Normalise openness to a 0..5 m-equivalent so height (metres)
                // decides the perch and openness only spreads teams / breaks near-ties.
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

        // Roster from the "sniper_element" token, not a class literal, so the composition tool owns the
        // pair and faction pools resolve it. Spawned here rather than via fnc_spawn_team: the perch
        // siting above replaces the token's own findSafePos/posture.
        private _men = ["sniper_element", "opfor"] call DUWS_fnc_teamRoster;
        private _group = [_perch, east, _men, [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
        _group deleteGroupWhenEmpty true;
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

    // Auto-aware, but only inside the AO: pin every team's knowledge of each live player within the
    // objective ring at 4 (fully identified, exact position). knowsAbout decays, so it is re-applied
    // until the last sniper is dead -- inside the ring the teams never lose the player's position,
    // whatever the terrain or line of sight; a player who breaks contact past _radius falls off normal
    // spotting. One loop covers every team.
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

private _spec = [
    5, 1000, "kill", "STR_DUWS_T_16dh939j", "STR_DUWS_T_c5", "sniperhunt",
    _build,
    { (_this findIf { alive _x }) < 0 },
    [["STR_DUWS_T_OVERLORD", "STR_DUWS_T_sniperletsdothis", 8]],
    ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_sniperend"]
];
[_MissionPos, _mission_name, _spec] call fnc_mission_run;
