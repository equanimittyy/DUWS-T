// Locality: server -- called by mission threads only, all server-side.
//
// _patrols scales the infantry ring only, an argument rather than a forked copy that could drift. No
// caller asks for a light ring today, so the default is the full ring.
params ["_missionPos", "_radius", ["_patrols", 5]];

// Three distinct offsets; anything past the third repeats the last position.
private _offsets = [[30, 20], [30, 0], [35, 0]];

// Claimed here, not in the builders (shared with zone/town garrisons), so teardown collects the ring
// wherever it patrolled. Each builder is `call`ed from inside its own thread -- the only way to read
// back the group it returns.
private _fnc_claimInf = { [(["patrol"] + _this) call fnc_spawn_team] call fnc_mission_claim };
private _fnc_claimTeam = { [(["team"] + _this) call fnc_spawn_team] call fnc_mission_claim };
private _fnc_claimVeh = { [_this call fnc_spawn_vehicle] call fnc_mission_claim };

for "_i" from 1 to _patrols do {
    sleep 1;
    private _o = _offsets select ((_i - 1) min 2);
    [[(_missionPos select 0) + (_o select 0), (_missionPos select 1) + (_o select 1)], _radius] spawn _fnc_claimInf;
};
sleep 1;
[[(_missionPos select 0), (_missionPos select 1)+35], _radius] spawn _fnc_claimTeam;
sleep 1;
// Two tokens rather than one substituted for the other. The Army Power rung gates the heavier one;
// the lighter stands whether or not the heavier is dropped, so the ladder adds armour instead of
// exchanging a car for it.
{
    private _class = [_x] call DUWS_fnc_tokenClass;
    if (_class != "") then {
        [_class, [(_missionPos select 0)+30, (_missionPos select 1)+10], _radius] spawn _fnc_claimVeh;
        sleep 1;
    };
} forEach ["tank", "car"];
[["car"] call DUWS_fnc_tokenClass, [(_missionPos select 0)+28, (_missionPos select 1)+12], _radius] spawn _fnc_claimVeh;
