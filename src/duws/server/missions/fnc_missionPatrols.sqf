// Locality: server -- called by mission threads only, all server-side.
//
// _patrols scales the infantry ring only. A lighter variant of this function was kept as a
// separate copy and drifted from it; an argument cannot drift. No caller asks for a light ring
// today, so the default is the ring every mission thread has always spawned.
params ["_missionPos", "_radius", ["_patrols", 5]];

// Three distinct offsets: the ring was written as five spawns of which the last three shared a
// position, so anything past the third repeats it.
private _offsets = [[30, 20], [30, 0], [35, 0]];

// Claimed for the mission that ordered the ring, so its teardown collects it wherever it patrolled
// to. The claim lives here, not in the builders, which are shared with zone and town garrisons.
//
// Each builder is `call`ed from inside its own thread -- the only way to read back the group it
// returns.
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
