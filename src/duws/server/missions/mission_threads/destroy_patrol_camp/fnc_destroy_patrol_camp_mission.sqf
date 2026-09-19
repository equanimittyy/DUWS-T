// Locality: server; the composition, spawns and monitor all run on the server. Callers remoteExec to 2.

params ["_MissionPos", "_mission_name"];
private _requester = remoteExecutedOwner;

private _build = {
    params ["_targetpos", "_randomPos", "_radius"];

    // Camp centres: 1-3, min-separated so the smoke columns read as distinct objectives. Each is biased
    // into forest -- a candidate seats only where enough trees stand around it (findSafePos still holds the
    // centre 8 m clear, so the camp gets a clearing ringed by trees). The tree demand relaxes late in the
    // search so a thinly wooded zone still seats every camp rather than collapsing them onto the anchor.
    private _campCount = 1 + floor random 3;
    private _campCentres = [];
    private _campTreeRadius = 60;
    private _campTreeDense  = 20;   // trees within radius to read as deep forest
    private _campTreeMin    = 8;    // relaxed floor once the deep-forest tries run out
    private _tries = 0;
    while { count _campCentres < _campCount && _tries < 80 } do {
        _tries = _tries + 1;
        private _p = [_randomPos, _radius - 120, 120, 8, 0.4, []] call fnc_safe_pos;
        if (_p isEqualTo []) then { continue };
        if (_campCentres findIf { (_x distance2D _p) < 400 } >= 0) then { continue };
        if (count (_p nearRoads 300) > 0) then { continue };
        private _trees = count nearestTerrainObjects [_p, ["TREE", "SMALL TREE"], _campTreeRadius, false, true];
        if (_trees < (if (_tries < 55) then { _campTreeDense } else { _campTreeMin })) then { continue };
        _campCentres pushBack _p;
    };
    if (_campCentres isEqualTo []) then { _campCentres = [_targetpos]; };

    private _campTeamUnits = [];
    {
        private _campPos = _x;
        private _cx = _campPos select 0;
        private _cy = _campPos select 1;

        // Camp composition (Eden-authored). Rows are [class, offX, offY, offZ, dir, isWeapon] from the camp
        // centre; offZ unused (props seat on terrain). Left simulated, not hardened: the smoke-column
        // particle on the campfire is the beacon, and a particle source needs simulation to emit.
        // --DUWS-COMPOSITION BEGIN name="Mission: Patrol Camp" schema=A--
        private _staticsArray = [
            ["Land_TentDome_F", -3.95898, 3.27539, -5.90000000000312E-05, 45, false],
            ["Land_TentDome_F", 3, 2, -5.90000000000312E-05, 315,  false],
            ["Land_TentDome_F", -0.728516, -3.83398, -5.90000000000312E-05, 180, false],
            ["Land_CampingTable_F", 5.71484, -0.441406, -0.207753, 44.8096, false],
            ["Land_BagBunker_Small_F", 4.51172, -10.6426, 0.346326, 345.614, false],
            ["Land_BagFence_Long_F", 6.11133, -0.015625, -0.199993, 44.7205, false],
            ["Land_WoodPile_F", -5.94141, -3.69336, -0.35937, 122.244, false],
            ["Land_WoodPile_large_F", 2.04102, -11.5586, -0.250585, 163.572, false],
            ["Land_CampingChair_V2_F", -6.32227, -1.58203, -0.112819, 91.7357, false],
            ["Land_BagFence_Long_F", -7.23828, 1.02148, -0.199993, 277.736, false],
            ["Land_CampingTable_F", -6.66406, 0.666016, -0.207753, 98.212, false],
            ["Land_Garbage_square5_F", -3.29297, -5.99219, -0.5798689, 0, false],
            ["Land_Garbage_square3_F", 6.37305, -2.90625, -0.5673886, 47.4125, false],
            ["Land_Garbage_line_F", 3.86328, -7.67188, -0.5691529, 0, false],
            ["Land_BarrelEmpty_F", -6.58398, 2.23828, -0.214552, 0, false],
            ["Land_Ammobox_rounds_F", 2.86328, -9.74609, -0.513942, 313.351, false],
            ["Land_Ammobox_rounds_F", 2.66016, -9.45117, -0.513942, 250.36, false],
            ["Land_BagFence_Round_F", -7.42969, -1.82031, -0.199993, 74.2054, false],
            ["Land_CratesWooden_F", 2.33398, 5.09961, 0.119695, 253.913, false],
            ["Land_BagFence_Long_F", -4.20898, 7.19922, -0.199993, 162.012, false],
            ["Land_BagFence_Long_F", -1.41602, 8.18359, -0.199993, 162.012, false],
            ["Land_Campfire_F", -0.136719, -0.171875, -0.399721, 0, false]
    ];
        // --DUWS-COMPOSITION END--
        private _props = [_staticsArray, [_cx, _cy], "mission_patrol_camp", [0, [], []]] call fnc_composition_place;

        // Wood-smoke column on the campfire as the beacon -- inflame gives only a weak low wisp. Built per
        // client (DUWS_fnc_campSmoke): the #particlesource carries no config, so its emitter is set locally
        // on each machine. JIP-tied to the fire object so a late joiner rebuilds it while the camp stands.
        private _fireIdx = _staticsArray findIf { (_x select 0) isEqualTo "Land_Campfire_F" };
        if (_fireIdx >= 0) then {
            private _fire = _props param [_fireIdx, objNull];
            if (!isNull _fire) then {
                [_fire] remoteExec ["DUWS_fnc_campSmoke", [0, -2] select isDedicated, _fire];
            };
        };

        // Intel on the table: three independent 1-in-3 rolls (0-3 items) from the shared pool. Damage off
        // throughout so stray fire cannot destroy loot or table.
        private _tableIdx = _staticsArray findIf { (_x select 0) isEqualTo "Land_CampingTable_F" };
        private _table = if (_tableIdx >= 0) then { _props param [_tableIdx, objNull] } else { objNull };
        if (!isNull _table) then {
            // Settle on the terrain, then lock as the slot anchor. enableSimulationGlobal (not local): a
            // client left simulating renders it toppling off the anchor.
            sleep 2;
            // Toppled or steep past ~18 degrees: physics gave up on this spot. Reset to the row's authored
            // transform on the terrain -- reorient AND re-pin, since a flip usually slides it off the slot too.
            // A flat table with a floating edge on a slope beats one on its back; mild tilt is left conformed.
            if (((vectorUp _table) select 2) < 0.95) then {
                private _tRow = _staticsArray select _tableIdx;
                _table setVectorUp [0, 0, 1];
                _table setPosATL [_cx + (_tRow select 1), _cy + (_tRow select 2), 0];
                _table setDir (_tRow select 4);
            };
            _table allowDamage false;
            _table enableSimulationGlobal false;

            // Each item scatters to a random spot and heading on the table top (boundingBoxReal max-corner Z),
            // inset by _edgeMargin so nothing overhangs and kept _itemSep apart so two never z-fight. Kept
            // objects are `persistent`, so fnc_repetitive_cleanup never reaps an unlooted item before mission end.
            private _bb   = boundingBoxReal _table;
            private _bMin = _bb select 0;
            private _bMax = _bb select 1;
            private _topZ = _bMax select 2;
            private _edgeMargin = 0.12;   // inset from every edge so no item overhangs the table
            private _itemSep    = 0.18;   // min gap between two items so they do not stack and z-fight
            private _minX = (_bMin select 0) + _edgeMargin;
            private _maxX = (_bMax select 0) - _edgeMargin;
            private _minY = (_bMin select 1) + _edgeMargin;
            private _maxY = (_bMax select 1) - _edgeMargin;
            private _rows = [];
            for "_i" from 0 to 2 do {
                if (random 1 < (1/3)) then {
                    // Bare inventory class for the holder's cargo: DUWS_intelDocuments lists the Item_*
                    // ground bodies, so strip that prefix (fnc_place_settled seats loot in a GroundWeaponHolder).
                    private _cls = (DUWS_intelDocuments selectRandomWeighted DUWS_intelDocumentWeights) select [5];
                    private _ox = 0;
                    private _oy = 0;
                    // Draw a spot clear of the ones already taken; keep the last draw if none comes up clear.
                    for "_try" from 0 to 7 do {
                        _ox = _minX + random (_maxX - _minX);
                        _oy = _minY + random (_maxY - _minY);
                        if (_rows findIf { [(_x select 1) - _ox, (_x select 2) - _oy] distance [0, 0] < _itemSep } < 0) exitWith {};
                    };
                    _rows pushBack [_cls, _ox, _oy, _topZ, random 360];
                };
            };
            // _asLoot: intel rides a GroundWeaponHolder so PhysX cannot fling it off the table.
            [_rows, _table, "mission_patrol_camp", true, true] call fnc_place_settled;
        };

        // The camp's guard team -- the objective; all camp teams dead wins.
        private _team = ["team", _campPos, 180, "closepatrol"] call fnc_spawn_team;
        if (!isNull _team) then {
            [_team] call fnc_mission_claim;
            _campTeamUnits append (units _team);
        };
    } forEach _campCentres;

    // No guard team stood up: with nothing to kill the win check would pass on the first poll. Bail at build
    // time rather than hand the player a mission that completes itself -- the caller aborts, which releases the
    // slot and cooldown for a fresh pick and hands the keyed composition to the sweep.
    if (_campTeamUnits isEqualTo []) exitWith {
        ["ERROR", "MISSION", "patrol camp: no camp team raised; aborting for a fresh pick"] call fnc_log;
        "ABORT"
    };

    // One roaming patrol per camp, all walking the same circuit through every camp centre (hqpatrol anchors).
    // fnc_spawn_team cannot thread the anchors, so raise each posture "none" at its camp, then order it here.
    // Ambience: not claimed against the win, but claimed for cleanup so the sweep bins them with the camps.
    {
        private _patrol = ["patrol", _x, _radius, "none", _x] call fnc_spawn_team;
        if (!isNull _patrol) then {
            [_patrol, "hqpatrol", _randomPos, _radius, _campCentres] call fnc_apply_posture;
            [_patrol] call fnc_mission_claim;
        };
    } forEach _campCentres;

    _campTeamUnits
};

// Win when every camp team is dead; the roaming patrols are ambience, not part of the census.
private _done = { ({alive _x} count _this) == 0 };

if (!([18, _MissionPos, _mission_name, _requester] call fnc_mission_begin)) exitWith {};

private _radius = 1000;
// Offer only fires where the mission radius (1000 m) holds forest; each camp finds its own treed seat in it.
private _randomPos = _MissionPos;
private _targetpos = _MissionPos;

private _taskId = format ["patrolcamp%1%2", round (_MissionPos select 0), round (_MissionPos select 1)];
[_requester, "STR_DUWS_T_MISSION_GEN_BUILD"] call fnc_mission_notice;
private _handles = [_targetpos, _randomPos, _radius] call _build;
// Build-time abort: no camp team stood up (a broken-faction edge), so nothing could be killed to win.
// Caught before the mission is presented, so release the slot and cooldown for a fresh pick and hand the
// placed camp composition to the sweep -- better than fielding a task that would win on the first poll.
if (_handles isEqualTo "ABORT") exitWith {
    [18, _requester, "no_camp_team", "mission_patrol_camp"] call fnc_mission_abort;
};
if (isNil "_handles") then { _handles = [] };

private _marker = [_randomPos, _radius, _taskId, localize "STR_DUWS_T_DESTROY_PATROL_CAMP_DESC", _mission_name, "destroy",
    [["STR_DUWS_T_OVERLORD", "STR_DUWS_T_PATROLCAMP_BRIEF", 6], ["STR_DUWS_T_actionteam", "STR_DUWS_T_PATROLCAMP_COPY", 0]]
] call fnc_mission_present;

[_handles, _done, _mission_name, _taskId, _targetpos, _radius, [_marker],
    ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_patrolcampend"], "mission_patrol_camp"] call fnc_mission_watch;
