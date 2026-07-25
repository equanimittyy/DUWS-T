
diag_log format ["------------------ DUWS_T START ----v0------ player: %1", profileName];


_duwst_isHostedserver = if (isServer && !isDedicated) then {true} else {false};
_duwst_isServer = if (isDedicated || _duwst_isHostedserver) then {true} else {false};
_duwst_isClient = if ((_duwst_isHostedserver || !isDedicated) && (hasInterface)) then {true} else {false};
_duwst_isHeadless = if !(hasInterface || isDedicated) then {true} else {false};

if (isNil "serverinit_complete") then {
	serverinit_complete = false;publicVariable "serverinit_complete";
};

if (_duwst_isServer || _duwst_isHostedserver || _duwst_isHeadless) then 
{
	[] execVM "duws\server\server_init.sqf"; 
};

if (_duwst_isClient) then 
{
    [] execVM "duws\init\client_init.sqf"; 
};
setGroupIconsVisible [true,false]; //now everyone can see enemies on map
// INIT R3F Logistics
// - has to be run by client and server
waitUntil {sleep 5;serverinit_complete};
waituntil {sleep 5;WARCOM_init_done;};
execVM "modules\R3F_LOG\init.sqf";

