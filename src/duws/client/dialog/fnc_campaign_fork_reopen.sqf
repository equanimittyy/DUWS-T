// Locality: client -- the game master's machine, from the faction screen's Back (fnc_startup_faction_flow.sqf).
// client_init is still waiting on chosen_settings behind this, so a load needs nothing more here, and a new
// campaign re-enters the setup chain at its head.
[] remoteExec ["DUWS_fnc_saveReopen", 2];
while {!(["BOOT", "the server reopening the load screen", {DUWS_setupPhase isEqualTo "choose"}, 60] call fnc_waitLogged)} do {};
[] call fnc_campaign_fork;
while {!(["BOOT", "the server's answer to the load screen", {DUWS_setupPhase isNotEqualTo "choose"}, 600] call fnc_waitLogged)} do {};
if (DUWS_setupPhase isEqualTo "new") then { [] spawn fnc_startup_faction_flow };
