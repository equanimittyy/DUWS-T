// Locality: server -- called by mission threads only, all server-side.
//
// The guard ring for a mission site. Despite the name, its bodies are not specially flagged for intel --
// they are searchable like any enemy corpse; this only spawns the ring.
params ["_missionPos", "_radius"];

// See fnc_missionPatrols for why the claim lives here and why each builder runs in its own thread.
private _fnc_claimInf = { [(["patrol"] + _this) call fnc_spawn_team] call fnc_mission_claim };
private _fnc_claimTeam = { [(["team"] + _this) call fnc_spawn_team] call fnc_mission_claim };
private _fnc_claimVeh = { [_this call fnc_spawn_vehicle] call fnc_mission_claim };

sleep 1;
[[(_missionPos select 0)+30, (_missionPos select 1)+20], _radius] spawn _fnc_claimInf;
sleep 1;
[[(_missionPos select 0)+30, (_missionPos select 1)], _radius] spawn _fnc_claimInf;
sleep 1;
[[(_missionPos select 0)+35, (_missionPos select 1)], _radius] spawn _fnc_claimInf;
sleep 1;
[[(_missionPos select 0), (_missionPos select 1)+35], _radius] spawn _fnc_claimTeam;
sleep 1;
// Three vehicle slots, each gated on its top rung (car/ifv/tank tier), so the ring thickens with Army
// Power rather than fielding all three at once. AP is monotonic, so an opened slot rolls across its pool
// with the lower token already earned -- the middle slot mixes light and medium, not always the heavier.
private _vehSlots = [
    [["car"],         "car",  [(_missionPos select 0)+30, (_missionPos select 1)+10]],
    [["car", "ifv"],  "ifv",  [(_missionPos select 0)+35, (_missionPos select 1)]],
    [["ifv", "tank"], "tank", [(_missionPos select 0)+28, (_missionPos select 1)+12]]
];
{
    _x params ["_pool", "_gate", "_pos"];
    if (([_gate] call DUWS_fnc_tokenClass) == "") then { continue };
    private _class = [selectRandom _pool] call DUWS_fnc_tokenClass;
    if (_class != "") then {
        [_class, _pos, _radius] spawn _fnc_claimVeh;
        sleep 1;
    };
} forEach _vehSlots;
