// Locality: server; the composition, spawns and monitor all run on the server. Callers remoteExec to 2.
//
// A cluster of 1-3 enemy recon camps spread across a 1 km zone, each hidden in treeline and betrayed by
// its campfire smoke. Each camp holds a close-patrol team (the objective) and seeds a roaming patrol that
// circuits between all the camps. Win when every camp team is dead; the roaming patrols are ambience, not
// part of the win. Each camp's table may hold 0-3 lootable intel items.

params ["_MissionPos", "_mission_name"];

private _build = {
    params ["_targetpos", "_randomPos", "_radius", "_Building"];

    // Camp centres: 1-3, spread across the zone with a minimum separation so the smoke columns read as
    // distinct objectives rather than one blob. Each is heavily biased into forest: a candidate seats only
    // where enough trees stand around it, so camps sit deep in woods rather than open ground. findSafePos
    // still holds the centre 8 m clear of objects, so the camp gets a small clearing ringed by the trees.
    // The tree demand relaxes partway through the tries -- deep forest first, mere treeline as a fallback --
    // so a thinly wooded zone still seats every camp instead of collapsing them onto the anchor.
    private _campCount = 1 + floor random 3;
    private _campCentres = [];
    private _campTreeRadius = 60;
    private _campTreeDense  = 20;   // trees within radius to read as deep forest
    private _campTreeMin    = 8;    // relaxed floor once the deep-forest tries run out
    private _tries = 0;
    while { count _campCentres < _campCount && _tries < 80 } do {
        _tries = _tries + 1;
        private _p = [_randomPos, 120, _radius - 120, 8, 0, 0.4, 0] call BIS_fnc_findSafePos;
        if (_p isEqualTo [] || {surfaceIsWater _p}) then { continue };
        if (_campCentres findIf { (_x distance2D _p) < 250 } >= 0) then { continue };
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

        // The camp composition, authored in Eden -- tents, two tables, sandbag cover, wood piles, ammo and
        // clutter, and a campfire. Rows are [class, offX, offY, offZ, dir, isWeapon], offsets from the camp
        // centre; offZ unused (props seat on terrain). Left simulated (no hardening): the smoke-column particle
        // stood on the campfire below is the beacon, and a particle source needs simulation to emit.
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

        // Stand a medium wood-smoke column on the campfire as the beacon. inflame would light only
        // campfire-class props and gives a weak, low wisp; this reads from across the zone. Built per client
        // (DUWS_fnc_campSmoke) rather than as one global object: the taller look needs a #particlesource,
        // which carries no config and so must have its emitter set locally on each machine. Sent to every
        // present client, and JIP-tied to the fire object so a late joiner gets the column while the camp
        // stands but not after it is retired (the fire is then gone). The source self-cleans with the fire.
        private _fireIdx = _staticsArray findIf { (_x select 0) isEqualTo "Land_Campfire_F" };
        if (_fireIdx >= 0) then {
            private _fire = _props param [_fireIdx, objNull];
            if (!isNull _fire) then {
                [_fire] remoteExec ["DUWS_fnc_campSmoke", [0, -2] select isDedicated, _fire];
            };
        };

        // Intel on the table: three independent 1-in-3 rolls, so a camp holds 0-3 items, drawn from the shared
        // document pool. The table settles on the terrain, is forced upright if it toppled, then frozen as a
        // fixed anchor; the rolled items are seated on its top by fnc_place_settled, which keeps each simulated
        // (so fnc_intelAnalysis can still take it from inventory) yet velocity-pinned so it does not scatter.
        // Damage is off on all of it so stray patrol fire cannot destroy the loot or the table.
        private _tableIdx = _staticsArray findIf { (_x select 0) isEqualTo "Land_CampingTable_F" };
        private _table = if (_tableIdx >= 0) then { _props param [_tableIdx, objNull] } else { objNull };
        if (!isNull _table) then {
            private _hover = 0.02;   // seat just above the top so it does not clip; small so there is no drop

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

            // Roll the loot, then hand the chosen classes to the placer as model-space slots on the table top
            // (boundingBoxReal max-corner Z), a hair above it. Each item scatters to a random spot and heading
            // rather than a fixed row, inset from the edges by _edgeMargin so nothing overhangs, and kept
            // _itemSep off the others so two documents do not land on the same spot and z-fight. The layout
            // lives here; placement -- seat, align, kill velocity, keep under the key -- lives in
            // fnc_place_settled. The table needs no keep; fnc_composition_place already filed it. Kept objects
            // are `persistent`, so fnc_repetitive_cleanup never reaps an unlooted item before fnc_mission_end
            // releases the key.
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
                    private _cls = DUWS_intelDocuments selectRandomWeighted DUWS_intelDocumentWeights;
                    private _ox = 0;
                    private _oy = 0;
                    // Draw a spot clear of the ones already taken; keep the last draw if none comes up clear.
                    for "_try" from 0 to 7 do {
                        _ox = _minX + random (_maxX - _minX);
                        _oy = _minY + random (_maxY - _minY);
                        if (_rows findIf { [(_x select 1) - _ox, (_x select 2) - _oy] distance [0, 0] < _itemSep } < 0) exitWith {};
                    };
                    _rows pushBack [_cls, _ox, _oy, _topZ + _hover, random 360];
                };
            };
            [_rows, _table, "mission_patrol_camp"] call fnc_place_settled;
        };

        // The camp's guard team: close patrol centred on this camp. This is the objective -- all camp teams
        // dead wins the mission.
        private _team = ["team", _campPos, 180, "closepatrol"] call fnc_spawn_team;
        if (!isNull _team) then {
            [_team] call fnc_mission_claim;
            _campTeamUnits append (units _team);
        };
    } forEach _campCentres;

    // No guard team stood up: with nothing to kill the win check would pass on the first poll. Abort at build
    // time rather than hand the player a mission that completes itself -- the spine fails the task, sweeps the
    // keyed composition, and pays no reward.
    if (_campTeamUnits isEqualTo []) exitWith {
        ["ERROR", "MISSION", "patrol camp: no camp team raised; ending without reward"] call fnc_log;
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

if (!([18, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};

private _radius = 1000;
private _site = [_MissionPos, _radius, 18] call fnc_mission_site;
if (_site isEqualTo []) exitWith {};
_site params ["_randomPos", "_Building", "_targetpos"];

private _taskId = format ["patrolcamp%1%2", round (_MissionPos select 0), round (_MissionPos select 1)];
private _marker = [_randomPos, _radius, _taskId, localize "STR_DUWS_T_DESTROY_PATROL_CAMP_DESC", _mission_name, "destroy",
    [["STR_DUWS_T_OVERLORD", "STR_DUWS_T_PATROLCAMP_BRIEF", 6], ["STR_DUWS_T_actionteam", "STR_DUWS_T_PATROLCAMP_COPY", 0]]
] call fnc_mission_present;

private _handles = [_targetpos, _randomPos, _radius, _Building] call _build;
// Build-time abort: no camp team stood up (a broken-faction edge), so fail rather than let an empty
// census win on the first poll. The brief has already played, so the abort speaks nothing.
if (_handles isEqualTo "ABORT") exitWith {
    [_mission_name, _taskId, "FAILED", _targetpos, _radius, [_marker], [], false, "mission_patrol_camp", false, false] call fnc_mission_finish;
};
if (isNil "_handles") then { _handles = [] };

sleep 5; // let the camp teams finish arriving before the win poll starts

private _deadline = DUWS_curDeadlineAt;
waitUntil { sleep 2; (_handles call _done) || time > _deadline };

if (!(_handles call _done) && time > _deadline) exitWith {
    [_mission_name, _taskId, "FAILED", _targetpos, _radius, [_marker], [], false, "mission_patrol_camp"] call fnc_mission_finish;
};

[_mission_name, _taskId, "SUCCEEDED", _targetpos, _radius, [_marker], ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_patrolcampend"], true, "mission_patrol_camp"] call fnc_mission_finish;
