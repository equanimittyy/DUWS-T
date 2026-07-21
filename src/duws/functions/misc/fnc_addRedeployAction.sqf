if (!hasInterface) exitWith {};
params ["_hq"];
_hq addAction [
    localize "STR_DUWS_T_REDEPLOY_ACTION",
    {
        if (commandpointsblu1 < 2) exitWith { hint format [localize "STR_DUWS_T_REDEPLOY_NO_CP", 2]; };
        [player] remoteExec ["fnc_redeployHQUnits", 2];
    },
    nil, 6, true, true, "", "true"
];