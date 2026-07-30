// Locality: client -- passed as an addAction function value in server/dialog/fnc_MHQ_deploy.sqf,
// client/dialog/fnc_request_support.sqf and client/init_hq/fnc_HQaddactions.sqf, so it runs on whoever
// opens the arsenal.

player setVariable ["DUWS_isRestrictedArsenal", true];
["Open", false] call BIS_fnc_arsenal;