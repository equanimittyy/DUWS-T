// Locality: all machines -- inherited from shared/functions/fnc_MHQ_addActions.sqf.

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

// The unlock is the team's and stays bought; what a wreck costs is the designation token, so the
// comm-menu item goes back to everyone rather than the purchase going back on sale. Whoever spent
// theirs designating this one gets it back; whoever never spent theirs is skipped by the duplicate
// guard in fnc_support_comm_add.
["mobile_HQ"] remoteExec ["fnc_support_comm_add", 0];

// Remove Marker
//[MHQ1] remoteExec ["kndr_removeMarker", [0,-2] select isDedicated,true];

["info",[localize "STR_DUWS_T_scudflh9",localize "STR_DUWS_T_scudflh9"]] remoteExec ['BIS_fnc_showNotification',[0,-2] select isDedicated,false];
	
