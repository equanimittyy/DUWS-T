// Locality: server -- called from the destroy-cache / destroy-radar threads.
//
// Crews two already-placed bunker guns with one OPFOR rifleman each, seats them, thaws the placement
// freeze fnc_static_place left on the guns, and merges the pair into one group so the objective has a
// single garrison to command. Returns that merged group; the caller owns the rest (attach the
// objective vehicle, or track the men for manual teardown), which is the only thing that differs
// between the two missions.
params ["_gun1", "_gun2", "_frozen"];

private _groupBunker1 = [getpos _gun1, EAST, [opfor_SOLDIER_X], [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
_groupBunker1 deleteGroupWhenEmpty true;
private _groupBunker2 = [getpos _gun2, EAST, [opfor_SOLDIER_X], [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
_groupBunker2 deleteGroupWhenEmpty true;
[[_groupBunker1, _groupBunker2]] call fnc_mission_claim;

private _guard1 = units _groupBunker1 select 0;
private _guard2 = units _groupBunker2 select 0;
_guard1 moveinGunner _gun1;
_guard2 moveinGunner _gun2;
// Thaw fnc_static_place's placement freeze now the gunners are seated.
{ _x enableSimulationGlobal true } forEach _frozen;

[_guard2] joinSilent _groupBunker1;
{ [_x] call fnc_addRandomLoot } forEach units _groupBunker1;

_groupBunker1
