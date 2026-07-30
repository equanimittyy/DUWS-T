// Locality: server -- called by mission threads only, all server-side.
//
// _patrols scales the infantry ring only. A lighter variant of this function was kept as a
// separate copy and drifted from it; an argument cannot drift. No caller asks for a light ring
// today, so the default is the ring every mission thread has always spawned.
params ["_missionPos", "_radius", ["_patrols", 5]];

// Three distinct offsets: the ring was written as five spawns of which the last three shared a
// position, so anything past the third repeats it.
private _offsets = [[30, 20], [30, 0], [35, 0]];

for "_i" from 1 to _patrols do {
    sleep 1;
    private _o = _offsets select ((_i - 1) min 2);
    [[(_missionPos select 0) + (_o select 0), (_missionPos select 1) + (_o select 1)], _radius, false] spawn fnc_createoppatrol2;
};
sleep 1;
[[(_missionPos select 0), (_missionPos select 1)+35], _radius, false] spawn fnc_createopteam2;
sleep 1;
if (WARCOM_opfor_ap > 100) then {
    [OPFOR_Faction_X,"armored",[(_missionPos select 0)+30, (_missionPos select 1)+10],_radius] spawn fnc_random_veh;
} else {
    [OPFOR_Faction_X,"car",[(_missionPos select 0)+30, (_missionPos select 1)+10],_radius] spawn fnc_random_veh;
};
sleep 1;
[OPFOR_Faction_X,"car",[(_missionPos select 0)+28, (_missionPos select 1)+12],_radius] spawn fnc_random_veh;
