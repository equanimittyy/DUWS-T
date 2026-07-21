if (!hasInterface) exitWith {};
waitUntil {sleep 20;zoneundercontrolblu >= 1};  
sleep 20;
_fobsupp = [player,"fob_support"] call BIS_fnc_addCommMenuItem;
_fobinfo = ["info",[localize "STR_DUWS_T_o1u3365h",localize "STR_DUWS_T_8yt3il47"]] call bis_fnc_showNotification;

