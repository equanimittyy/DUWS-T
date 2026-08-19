// Locality: server -- called by mission threads only, all server-side.
//
// The guard ring for a mission site. Its bodies are searchable as any enemy corpse now, so this no
// longer flags them -- it only spawns the ring.
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
// See fnc_missionPatrols for why the Army Power rung is two tokens rather than a substitution.
{
    private _class = [_x] call DUWS_fnc_tokenClass;
    if (_class != "") then {
        [_class, [(_missionPos select 0)+30, (_missionPos select 1)+10], _radius] spawn _fnc_claimVeh;
        sleep 1;
    };
} forEach ["tank", "car"];
[["car"] call DUWS_fnc_tokenClass, [(_missionPos select 0)+28, (_missionPos select 1)+12], _radius] spawn _fnc_claimVeh;
