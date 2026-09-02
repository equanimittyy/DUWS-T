// Runs on every machine: BuildingChanged is local, so only the machine that simulated a building's
// damage sees it, and each firing forwards the ruined position to the server-owned counter. The
// listen host reaches this twice (direct call, not the broadcast), so the flag makes it idempotent
// -- a second handler would double every count.
if (!isNil "DUWS_escalation_watching") exitWith {};
DUWS_escalation_watching = true;

addMissionEventHandler ["BuildingChanged", {
    params ["_old", "_new"];
    // The census counts House on these same terms, so both sides of the ratio must match or the
    // level overruns on a map never flattened. Military stays out both sides for gameplay: razing
    // enemy fortifications is the objective, not a step toward the loss condition. Filtered here so
    // only real ruin crosses the wire.
    if ((getText (configFile >> "CfgVehicles" >> typeOf _new >> "editorSubcategory")) == "EdSubcat_Military") exitWith {};
    if (((_old call BIS_fnc_objectType) select 1) != "House") exitWith {};
    [getPos _new] remoteExec ["fnc_escalation_report", 2];
}];
