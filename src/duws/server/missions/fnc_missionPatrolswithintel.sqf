// Locality: server -- called by mission threads only, all server-side.
//
// The guard ring plus the corpse-search flag, for the missions whose bodies are worth searching.
params ["_missionPos", "_radius"];

// Claimed for the mission that ordered the ring; see fnc_missionPatrols for why the claim lives
// here rather than inside the builders, and why each builder is called from inside its own thread.
private _fnc_claimInf = { [_this call fnc_createoppatrol2] call fnc_mission_claim };
private _fnc_claimTeam = { [_this call fnc_createopteam2] call fnc_mission_claim };
private _fnc_claimVeh = { [_this call fnc_random_veh] call fnc_mission_claim };

sleep 1;
[[(_missionPos select 0)+30, (_missionPos select 1)+20], _radius] spawn _fnc_claimInf;
sleep 1;
[[(_missionPos select 0)+30, (_missionPos select 1)], _radius] spawn _fnc_claimInf;
sleep 1;
[[(_missionPos select 0)+35, (_missionPos select 1)], _radius] spawn _fnc_claimInf;
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

// Swept rather than claimed: the flag has to reach whatever else is standing there too, since a
// mission drawn next to a zone puts that zone's garrison inside the same fight.
[_missionPos, _radius] spawn {
    params ["_pos", "_rad"];
    sleep 5; // let the ring finish spawning
    private _units = _pos nearEntities [["CAManBase", "LandVehicle", "Air"], _rad * 1.5];
    {
        if (side _x == EAST && !isPlayer _x && !(_x getVariable ["intel_action_added", false])) then {
            [[_x], "mission"] call fnc_search_flag_group;
            _x setVariable ["intel_action_added", true];
        };
    } forEach _units;
};
