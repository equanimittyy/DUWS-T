if (!isServer) exitWith {};
// CP every 30 mins (1800) 
_undercontrol = true;
while {_undercontrol} do {
    waitUntil {sleep 20;zoneundercontrolblu > 0};  // make sure there is at least 1 zone under control
    sleep 1800;
    waitUntil {sleep 20;zoneundercontrolblu > 0}; // check if there is still at least 1 zone under control

	["CPzonehold",[(zoneundercontrolblu*6),zoneundercontrolblu]] remoteExec ['BIS_fnc_showNotification', [0,-2] select isDedicated,false];

    commandpointsblu1 = commandpointsblu1 + (zoneundercontrolblu*6);
    publicVariable "commandpointsblu1";
    ctrlSetText [1000, format["%1",commandpointsblu1]];
    [localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_zonesundercontrol"] remoteExec ["BIS_fnc_showSubtitle", 0];
    [] remoteExec ["fnc_broadcastRadioChatter", 0];
};