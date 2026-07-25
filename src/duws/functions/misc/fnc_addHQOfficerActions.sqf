// Locality: client; the addAction bodies below run on the machine that triggers them, not here.
// fnc_addHQOfficerActions.sqf
if (!hasInterface) exitWith {};

params ["_officer"];

if (isNull _officer) exitWith {};

// 防重
if (_officer getVariable ["officer_actions_done", false]) exitWith {};
_officer setVariable ["officer_actions_done", true];

if ((vehiclevarname player) in Request_Players) then {
    _officer addAction [localize "STR_DUWS_T_l0xark5g", fnc_squad_manage, "", 95, true, true, "", "_this == player && {_this distance _target < 3}"];
    _officer addAction [localize "STR_DUWS_T_4jabuvz6", fnc_groupReset, "", 0, true, true, "", "_this == player && {_this distance _target < 3}"];
};

// Help now lives in the map's Notes as the "DUWS_T Manual" diary (fnc_duws_help),
// not as a scroll-menu drawer here.
