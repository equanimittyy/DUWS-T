// Locality: client; the addAction bodies below run on the machine that triggers them, not here.
#include "..\..\shared\includes\action_style.hpp"

if (!hasInterface) exitWith {};
params ["_hq"];
_hq addAction [
    ACT_COMMIT("STR_DUWS_T_REDEPLOY_ACTION"),
    {
        // Advisory only; fnc_redeployHQUnits checks and charges on the server.
        if (commandpointsblu1 < 2) exitWith { hint format [localize "STR_DUWS_T_REDEPLOY_NO_CP", 2]; };
        [player] remoteExec ["fnc_redeployHQUnits", 2];
    },
    [], 10, true, true, "", "true"
];