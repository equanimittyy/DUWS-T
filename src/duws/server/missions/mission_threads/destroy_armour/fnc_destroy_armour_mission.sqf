// Locality: server -- callers remoteExec to target 2.
// STUB, not yet wired. The genuine "destroy the armour" mission: a live, crewed MBT the player must
// actually destroy (win = tank dead), as opposed to fnc_target_armor_mission, which is an
// elimination of the crew standing down around a wrecked tank. Dormant until a mission_types.hpp row
// and its stringtable keys exist -- fnc_stratmap offers every row in that table, so adding the row is
// the on-switch and nothing here can be rolled before it. Shared spine: fnc_mission_run.
//
// Open before wiring:
//   - mission_types.hpp row (the next free index) with reward/deadline, objective "sabotage", and the
//     four string keys below; the spec's _index must match that row.
//   - the string keys referenced here (English first; DE/ES/ZH lag per project convention).
//   - how the player is expected to kill armour with no guaranteed AT -- an AT loadout at HQ, a
//     support call, or a launcher pre-placed near the site. This is the core design question the
//     elimination variant sidesteps by making the target a man, not the tank.
//   - crew/tank posture: static overwatch vs a short patrol, and whether the crew bails and fights.
params ["_MissionPos", "_mission_name"];

private _build = {
    params ["_targetpos", "_randomPos", "_radius"];

    private _vehpos = [_targetpos, 10, 30, 10, 0, 0.15, 0, [], [[0,0],[0,0]]] call BIS_fnc_findSafePos;
    [_targetpos, _radius] spawn fnc_missionPatrolswithintel;

    // Full-health crewed MBT, kept under the composition key so the abandoned-vehicle collector
    // cannot delete the objective before the player reaches it. Released on end with the composition.
    private _spawn = [_vehpos, random 360, opfor_MBT_TANK1_X, EAST] call BIS_fnc_spawnVehicle;
    private _veh = _spawn select 0;
    private _grp = _spawn select 2;
    [_veh, "mission_destroy_armour"] call fnc_duws_keep;
    _grp deleteGroupWhenEmpty true;
    [_grp] call fnc_mission_claim;

    [[_targetpos, _radius] call fnc_garrisonBuildings] call fnc_mission_claim;

    [_veh]
};

private _spec = [
    18, 250, "destroy", "STR_DUWS_T_destroyarmour_desc", "STR_DUWS_T_destroyarmour_name", "destroyarmour",
    _build,
    { params ["_veh"]; !alive _veh || {(damage _veh) >= 1} },
    [["STR_DUWS_T_OVERLORD", "STR_DUWS_T_destroyarmour_start", 8]],
    ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_destroyarmour_end"],
    "mission_destroy_armour"
];
[_MissionPos, _mission_name, _spec] call fnc_mission_run;
