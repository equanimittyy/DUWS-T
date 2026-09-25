// Locality: server -- the SITREP support asks for it by remoteExec.
if (!isServer) exitWith {};
if !(["SITREP"] call DUWS_fnc_campaignSave) exitWith {};

// The carry lets the caller offer this campaign to another server's load screen; a host's profile holds the store.
if (remoteExecutedOwner > 2) then {
	["carry", [DUWS_campaignID, (call DUWS_fnc_saveNamespace) getVariable [format ["DUWST_save_%1", DUWS_campaignID], ""]]]
		remoteExec ["fnc_campaign_reply", remoteExecutedOwner];
};
