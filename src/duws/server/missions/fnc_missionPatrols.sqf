// Locality: server -- called by mission threads only, all server-side.
//
// _patrols scales the infantry ring: the destroy-site missions field a lighter 3, the default the full 5.
params ["_missionPos", "_radius", ["_patrols", 5]];

// Three distinct offsets; anything past the third repeats the last position.
private _offsets = [[30, 20], [30, 0], [35, 0]];

// Claimed here, not in the builders (shared with zone garrisons), so teardown collects the ring
// wherever it patrolled. Each builder runs in its own thread to read back its group. The mission token
// is captured up front and compiled into the claim -- a spawned thread does not inherit caller privates,
// and a group raised late must claim the mission that ordered it, not the next if a finish advanced it.
private _token = missionNamespace getVariable ["DUWS_mission_token", 0];
private _fnc_claimInf = compile format ["[(['patrol'] + _this) call fnc_spawn_team, %1] call fnc_mission_claim", _token];
private _fnc_claimTeam = compile format ["[(['team'] + _this) call fnc_spawn_team, %1] call fnc_mission_claim", _token];
private _fnc_claimVeh = compile format ["[_this call fnc_spawn_vehicle, %1] call fnc_mission_claim", _token];

for "_i" from 1 to _patrols do {
    sleep 1;
    private _o = _offsets select ((_i - 1) min 2);
    [[(_missionPos select 0) + (_o select 0), (_missionPos select 1) + (_o select 1)], _radius] spawn _fnc_claimInf;
};
sleep 1;
[[(_missionPos select 0), (_missionPos select 1)+35], _radius] spawn _fnc_claimTeam;
sleep 1;
// Three vehicle slots, each gated on its top rung (car/ifv/tank), so the ring thickens with Army Power
// rather than fielding all three at once. AP is monotonic, so an opened slot rolls across its pool with
// the lower token already earned -- the middle slot mixes light and medium, not always the heavier.
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
