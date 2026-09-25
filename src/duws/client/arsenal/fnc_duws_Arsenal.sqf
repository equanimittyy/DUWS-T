// Locality: client -- passed as an addAction function value in server/dialog/fnc_MHQ_deploy.sqf,
// client/dialog/fnc_request_support.sqf and client/init_hq/fnc_HQaddactions.sqf, so it runs on whoever
// opens the arsenal.

// Hybrid (default) count-tracks captured foreign gear against the banked pool; Full is the legacy
// everything-unlimited arsenal. The enforcer keys off DUWS_isRestrictedArsenal, so Full sets it
// false and opens the whole-config arsenal, Hybrid sets it true and opens the virtual cargo.
if ((missionNamespace getVariable ["DUWS_paramArsenal", 0]) == 1) then {
    player setVariable ["DUWS_isRestrictedArsenal", false];
    ["Open", true] call BIS_fnc_arsenal;
} else {
    player setVariable ["DUWS_isRestrictedArsenal", true];
    ["Open", false] call BIS_fnc_arsenal;
};