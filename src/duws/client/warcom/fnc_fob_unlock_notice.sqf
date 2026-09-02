// Locality: client -- spawned from client/client_init.sqf.
// Announces that the FOB has appeared in the requests menu. The FOB is bought like every other
// support, and the first zone capture is what puts its row on that list.
if (!hasInterface) exitWith {};
waitUntil {sleep 20;zoneundercontrolblu >= 1};
sleep 20;
["info",[localize "STR_DUWS_T_o1u3365h",localize "STR_DUWS_T_8yt3il47"]] call bis_fnc_showNotification;
