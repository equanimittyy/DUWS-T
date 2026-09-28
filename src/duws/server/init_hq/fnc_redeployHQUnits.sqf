// Locality: server -- the HQ action remoteExecs to target 2.
//
// Clears what the last placement owned and hands the rebuild to the shared placement routine, the
// way fnc_redeployFOBUnits delegates to its two builders. Placing units here as well is what let
// the build and the rebuild drift apart.
if (!isServer) exitWith {};

// One rebuild at a time. fnc_placeHQUnits below sleeps, so without this a second click would run a
// concurrent rebuild that deletes and re-places the same units mid-flight and charges again for it.
if (missionNamespace getVariable ["HQ_redeploy_busy", false]) exitWith {
    [localize "STR_DUWS_T_HQ_REDEPLOY_BUSY"] remoteExec ["hint", 0];
};

if (commandpointsblu1 < 2) exitWith {
    [localize "STR_DUWS_T_e95mc4lv"] remoteExec ["hint", [0,-2] select isDedicated];
};

// Raised before the charge, so the flag is already up when the next request arrives -- the same
// window fnc_redeployFOBUnits closes. Cleared once the rebuild below has placed.
missionNamespace setVariable ["HQ_redeploy_busy", true];

// call, not remoteExec to self: a queued debit runs a frame later and splits the check
// above from the deduction. Escalation is applied here rather than in fnc_pool_try_spend
// because this path never reaches the purchase handshake.
[-([2] call fnc_escalation_cost), "hq_redeploy"] call fnc_cp_adjust;

private _oldWeaponList = missionNamespace getVariable ["HQ_redeploy_weaponList", []];
{ if (!isNull _x) then { deleteVehicle _x; }; } forEach _oldWeaponList;

private _groupsToDelete = [
    "HQ_redeploy_weaponGroup",
    "HQ_redeploy_hqGuardsGroup0",
    "HQ_redeploy_hqGuardsGroup1",
    "HQ_redeploy_medGuardsGroup0",
    "HQ_redeploy_medGuardsGroup1",
    "HQ_redeploy_guardBoxGroup",
    "HQ_redeploy_patrolGroup"
];
{
    private _grp = missionNamespace getVariable [_x, grpNull];
    if (!isNull _grp) then {
        { deleteVehicle _x; } forEach (units _grp);
        deleteGroup _grp;
    };
} forEach _groupsToDelete;

private _towerGuards = missionNamespace getVariable ["HQ_redeploy_towerGuards", []];
{
    if (!isNull _x) then {
        { deleteVehicle _x; } forEach (units _x);
        deleteGroup _x;
    };
} forEach _towerGuards;

// Dead gunners only: DUWS_fnc_buildCrewClear would also delete a drone's AI crew, which is the drone itself.
private _buildKey = bluHQ_object getVariable ["DUWS_buildKey", ""];
{
    private _gun = _x;
    { _gun deleteVehicleCrew _x } forEach ((crew _gun) select { !alive _x });
} forEach (DUWS_compositions getOrDefault [_buildKey, []]);

// Anchors are already in the namespace from the build; the routine reads them itself.
call fnc_placeHQUnits;

[DUWS_compositions getOrDefault [_buildKey, []], true] call DUWS_fnc_buildCrew;

missionNamespace setVariable ["HQ_redeploy_busy", false];

[localize "STR_DUWS_T_REDEPLOY_SUCCESS"] remoteExec ["hint", 0];
