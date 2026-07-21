
// BEGIN OF SPAWN "IF MHQ DESTROYED"

waituntil {sleep 10;!alive MHQ1};
	
if (MHQ_deployed) then {

	MHQ_respawn call BIS_fnc_removeRespawnPosition;
    MHQ_respawn = nil;
    publicVariable "MHQ_respawn";

	deleteVehicle MHQ_tent;
	deleteVehicle MHQ_ammobox;
	
	MHQ_deployed = false;
	publicVariable "MHQ_deployed";

};

removeAllActions MHQ1;
		
support_mobile_HQ_available = true;
publicVariable "support_mobile_HQ_available";

// Remove Marker
//[MHQ1] remoteExec ["kndr_removeMarker", [0,-2] select isDedicated,true];

["info",[localize "STR_DUWS_T_scudflh9",localize "STR_DUWS_T_scudflh9"]] remoteExec ['BIS_fnc_showNotification',[0,-2] select isDedicated,false];
	
