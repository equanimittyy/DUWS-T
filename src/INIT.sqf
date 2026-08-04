#include "duws\shared\includes\build_stamp.hpp"

// Names the build the rest of the log is about. A .pbo carries no other mark of the source it
// was packed from, so "was the fix in the mission I just tested?" is otherwise unanswerable
// after the fact -- and a stale .pbo left in mpmissions reads exactly like a failed fix.
diag_log format ["------------------ DUWS_T START ---- build %1 ---- player: %2", DUWS_BUILD_STAMP, profileName];

// Lobby log level, read on every machine because each keeps its own copy of the global.
// Must land before server_init/client_init compile fnc_log_init, which only defaults the
// level when it is still nil. Left unset if the parameter is missing, so a mission built
// without it still gets fnc_log_init's default rather than a hard-coded one from here.
private _logLevel = "DUWS_LogLevel" call BIS_fnc_getParamValue;
if (_logLevel isEqualType 0) then { duws_log_level = _logLevel };


_duwst_isHostedserver = if (isServer && !isDedicated) then {true} else {false};
_duwst_isServer = if (isDedicated || _duwst_isHostedserver) then {true} else {false};
_duwst_isClient = if ((_duwst_isHostedserver || !isDedicated) && (hasInterface)) then {true} else {false};
_duwst_isHeadless = if !(hasInterface || isDedicated) then {true} else {false};

// Every machine needs a local default so the waits below have a Bool to test, but only the server
// may broadcast one: on a joining client this runs before the JIP variable sync is guaranteed to
// have landed, and an ungated client would publish false over the server's true and stall every
// machine still waiting on the flag.
if (isNil "serverinit_complete") then {
	serverinit_complete = false;
	if (isServer) then { publicVariable "serverinit_complete" };
};

if (_duwst_isServer || _duwst_isHostedserver || _duwst_isHeadless) then 
{
	[] execVM "duws\server\server_init.sqf"; 
};

if (_duwst_isClient) then 
{
    [] execVM "duws\client\client_init.sqf"; 
};
setGroupIconsVisible [true,false]; //now everyone can see enemies on map
// INIT R3F Logistics
// - has to be run by client and server
waitUntil {sleep 5;serverinit_complete};
waituntil {sleep 5;WARCOM_init_done;};
execVM "modules\R3F_LOG\init.sqf";

