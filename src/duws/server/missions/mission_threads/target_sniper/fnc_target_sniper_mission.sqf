// Locality: server -- callers remoteExec to target 2.
// Kill both snipers. They are the ONLY things spawned: no garrison, no patrols, no support teams --
// the pair on the hilltop is the whole objective, so the win is unambiguous and the field is empty
// but for them. Shared spine: fnc_mission_run.
//
// Siting reuses the hardpoint terrain-ray technique (fnc_hardpoint_siting): sample ground within the
// ring, keep what stands above its surroundings (an eight-point elevation ring) AND looks down open
// terrain (rays marched out on eight bearings until the ground masks them). The pair is laid prone
// facing the most open bearing -- an overwatch, not a garrison. Prone eye height is modelled in the
// ray (z + 0.5) so the perch is chosen for the stance they actually hold.
//
// Elite by override, not by campaign difficulty: their sub-skills are forced to 1 so they are as
// accurate and quick to spot as the engine allows, whatever opfor_ai_skill is. They hold prone and
// still (PATH disabled) until a player closes within 500 m or one of them is hit, then they are
// released to move and fight -- a static overwatch that will not sit and be flanked.
params ["_MissionPos", "_mission_name"];

#define SNIPER_FLUSH_DIST 500   // a player this close, or a hit, releases the pair to move

private _build = {
    params ["_targetpos", "_randomPos", "_radius"];

    // Best prone overlook near the found ground: high above its ring and looking down open terrain.
    // Terrain-only rays, generation-time; getPos on a position array is the same relative-point form
    // the recon site-finder uses. Falls back to _targetpos if nothing within reach clears the bar.
    private _perch = _targetpos;
    private _perchDir = 0;
    private _bestScore = -1;
    private _ring = [0, 45, 90, 135, 180, 225, 270, 315];
    for "_i" from 0 to 23 do {
        private _cand = _targetpos getPos [50 + random 450, random 360];
        if (!(surfaceIsWater _cand)) then {
            private _z = getTerrainHeightASL _cand;
            private _ringSum = 0;
            { _ringSum = _ringSum + getTerrainHeightASL (_cand getPos [30, _x]) } forEach _ring;
            private _relElev = _z - _ringSum / 8;
            if (_relElev >= 2) then {
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
                private _score = _relElev * 8 + _openSum;
                if (_score > _bestScore) then { _bestScore = _score; _perch = _cand; _perchDir = _candBestDir };
            };
        };
    };

    private _group = [_perch, east, [opfor_SNIPER_SOLDIER_X, opfor_SNIPER_SOLDIER_X], [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
    _group deleteGroupWhenEmpty true;
    [_group] call fnc_mission_claim;
    private _target1 = units _group select 0;
    private _target2 = units _group select 1;

    // Spread the pair off the perch and face them both down the open bearing so they open the mission
    // already watching the ground the ray found clear.
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

    [_target1] spawn { params ["_unit"]; sleep 5; _unit forceAddUniform "U_B_FullGhillie_sard" };
    [_target2] spawn { params ["_unit"]; sleep 5; _unit forceAddUniform "U_B_FullGhillie_sard" };
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

    // Hold prone and still until threatened, then release both to move and fight. Ends when the pair
    // is dead too, so the monitor cannot outlive the objective it watches.
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

    [_target1, _target2]
};

private _spec = [
    5, 1000, "kill", "STR_DUWS_T_16dh939j", "STR_DUWS_T_c5", "sniperhunt",
    _build,
    { params ["_target1", "_target2"]; !alive _target1 && !alive _target2 },
    [["STR_DUWS_T_Viper", "STR_DUWS_T_sniperletsdothis", 8]],
    ["STR_DUWS_T_Viper", "STR_DUWS_T_sniperend"]
];
[_MissionPos, _mission_name, _spec] call fnc_mission_run;
