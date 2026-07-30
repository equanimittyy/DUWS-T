// Locality: client -- spawned from client/client_init.sqf.
// Announces that the FOB has appeared in the requests menu. It used to hand the comm-menu item
// over free at this point; the FOB is bought like every other support now, and the first zone
// capture is what puts its row on that list.
if (!hasInterface) exitWith {};
waitUntil {sleep 20;zoneundercontrolblu >= 1};
sleep 20;
["info",[localize "STR_DUWS_T_o1u3365h",localize "STR_DUWS_T_8yt3il47"]] call bis_fnc_showNotification;
