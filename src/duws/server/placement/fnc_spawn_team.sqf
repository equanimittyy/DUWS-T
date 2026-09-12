// Locality: server -- called from the zone spawn band, the town garrison and the mission patrol
// builders, all server-side.
// radius: 50 for a patrol inside a base, 500 for medium, 1300 for island.
//
// Raises a team -- a row on DUWS_teamRosters, ordered under fnc_apply_posture -- for either army.
//
// _side ("opfor"/"blufor") drives all three of the engine side, the skill range and the roster
// prefix, and defaults to opfor so the callers that name no side (zone band, town garrison) spawn
// exactly as before. The roster table is shared and holds bare role names; the side is prepended when
// the men are drawn (DUWS_fnc_teamRoster). Not a full side: only the two armies have a role vocabulary
// and skill globals -- CIVILIAN has neither, so a civilian caller stays a direct BIS_fnc_spawnGroup.
//
// Returned rather than only spawned, for the callers that `call` it: the zone band flags what it
// raised so the capture test can tell this zone's garrison from passers-by, and the town garrison
// needs the handle to count its strength and to order it out.

// _posture defaults to the close patrol every team walked when orders were a column on its roster
// row, so the side-mission callers that name only a team still get what they always got. A token may
// carry its own ("garrison:garrison_element"), which is what DUWS_fnc_zoneSpawnOne passes.
//
// _spawnPos is the reserve path's alone: a reinforcement is placed on a point the reserve pass chose
// on the zone's far side, not in the posture's own radius band. Empty means the ordinary team, which
// spawns in its band off the centre.
// _anchors passes straight through to fnc_apply_posture: the fixed points an hqpatrol walks. Defaults
// empty, so a caller that names none gets the same team it always did.
params ["_team", "_center", "_radius", ["_posture", "closepatrol"], ["_spawnPos", []], ["_side", "opfor"], ["_anchors", []]];

// grpNull rather than an empty group: DUWS_fnc_raiseGarrison already drops nulls, and a group with
// no men would sit on the zone roster forever holding the capture test open.
private _row = [_team] call DUWS_fnc_teamRow;
if (_row isEqualTo []) exitWith {
    ["WARN", "ZONES", format ["no team named %1; nothing raised", _team]] call fnc_log;
    grpNull
};

// Not named _roster: callers one frame up use that name for the zone's unit roster.
private _men = [_team, _side] call DUWS_fnc_teamRoster;
// Spawn distance follows the posture: a wide patrol starts on the outer ring, a close one near the
// objective, from DUWS_postureBands so the spawn and the circuit agree. A posture the table does not
// name keeps the old 50..radius band. A caller-supplied point overrides the band outright -- a
// reserve is placed where the pass put it, and its hunt orders carry no band anyway.
private _position = if (_spawnPos isNotEqualTo []) then { _spawnPos } else {
    private _band = DUWS_postureBands getOrDefault [_posture, []];
    private _minR = 50;
    private _maxR = _radius;
    if (_band isNotEqualTo []) then {
        _minR = (_band select 0) * _radius;
        _maxR = (_band select 1) * _radius;
    };
    [_center, _minR, _maxR, 5, 0, 0.5, 0, [], []] call BIS_fnc_findSafePos
};
private _army = [EAST, WEST] select (_side isEqualTo "blufor");
private _skill = missionNamespace getVariable [format ["%1_ai_skill", _side], opfor_ai_skill];
private _group = [_position, _army, _men, [], [], _skill] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;

// Random loot is OPFOR's alone: an enemy team is the player's to search, a friendly one the player
// fights alongside should not drop lootable gear on death.
if (_side isEqualTo "opfor") then { { [_x] call fnc_addRandomLoot } forEach units _group; };

[_group, _posture, _center, _radius, _anchors] call fnc_apply_posture;

_group
