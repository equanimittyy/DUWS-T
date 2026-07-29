// Locality: server. Ends an arrest without a search, handing the detainee back to their town.
//
// No reputation is returned: the town saw the weapon raised, which is what fnc_civ_arrest charged
// for, and letting the player undo that by being polite afterwards would make the arrest free.
// The civilian stays spent -- one exchange is all a person is worth -- so releasing them does not
// reopen the interaction menu.
if (!isServer) exitWith {};

params ["_civilian", "_caller"];

if (isNull _civilian || isNull _caller) exitWith {};
if (!alive _civilian) exitWith {};
if (!(_civilian getVariable ["isSurrendered", false])) exitWith {};

// Broadcast: the search action's condition and the panic sweep both read this flag, and neither
// runs on this machine. Clearing it is also what lets a released civilian flee gunfire again.
_civilian setVariable ["isSurrendered", false, true];
// Out of the surrender pose everywhere, or they walk their circuit with their hands in the air.
[_civilian, ""] remoteExec ["switchMove", 0];

[name _caller, localize "STR_DUWS_T_RELEASE1"] remoteExec ["fnc_duws_dialogue", _caller];

// PATH is disabled from the arrest through the surrender, so this is what puts them back on their
// feet; fnc_civ_resume draws the circuit they walk from wherever they were stopped.
_civilian enableAI "PATH";
[_civilian] call fnc_civ_resume;

sleep 2;
if (isNull _civilian || !alive _civilian) exitWith {};
[localize "STR_DUWS_T_civ", localize "STR_DUWS_T_RELEASE2"] remoteExec ["fnc_duws_dialogue", _caller];
