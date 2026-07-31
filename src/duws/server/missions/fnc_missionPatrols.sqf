// Locality: server -- called by mission threads only, all server-side.
//
// _patrols scales the infantry ring only. A lighter variant of this function was kept as a
// separate copy and drifted from it; an argument cannot drift. No caller asks for a light ring
// today, so the default is the ring every mission thread has always spawned.
params ["_missionPos", "_radius", ["_patrols", 5]];

// Three distinct offsets: the ring was written as five spawns of which the last three shared a
// position, so anything past the third repeats it.
private _offsets = [[30, 20], [30, 0], [35, 0]];

// Claimed for the mission that ordered the ring, so its teardown collects it wherever it has
// patrolled to rather than only where it was put down. The claim lives here and not inside the
// builders because those are shared with zone and town garrisons, which no mission clock owns.
//
// Each builder keeps its own thread and is `call`ed from inside it rather than `spawn`ed directly,
// which is the only way to read back the group it returns. The wrapper is what makes that safe:
// the builders assign _radius, _group and a for-counter without `private`, so calling one straight
// from this scope would write those over the variables of the same name here.
private _fnc_claimInf = { [_this call fnc_createoppatrol2] call fnc_mission_claim };
private _fnc_claimTeam = { [_this call fnc_createopteam2] call fnc_mission_claim };
private _fnc_claimVeh = { [_this call fnc_random_veh] call fnc_mission_claim };

for "_i" from 1 to _patrols do {
    sleep 1;
    private _o = _offsets select ((_i - 1) min 2);
    [[(_missionPos select 0) + (_o select 0), (_missionPos select 1) + (_o select 1)], _radius] spawn _fnc_claimInf;
};
sleep 1;
[[(_missionPos select 0), (_missionPos select 1)+35], _radius] spawn _fnc_claimTeam;
sleep 1;
if (WARCOM_opfor_ap > 100) then {
    [OPFOR_Faction_X,"armored",[(_missionPos select 0)+30, (_missionPos select 1)+10],_radius] spawn _fnc_claimVeh;
} else {
    [OPFOR_Faction_X,"car",[(_missionPos select 0)+30, (_missionPos select 1)+10],_radius] spawn _fnc_claimVeh;
};
sleep 1;
[OPFOR_Faction_X,"car",[(_missionPos select 0)+28, (_missionPos select 1)+12],_radius] spawn _fnc_claimVeh;
