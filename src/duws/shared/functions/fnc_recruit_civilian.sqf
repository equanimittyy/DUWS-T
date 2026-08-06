// Locality: all machines -- inherited from shared/functions/fnc_addRecruitAction.sqf.
params ["_civilian", "_caller"];

["INFO", "CIV", format ["Client called by %1 on %2", _caller, _civilian]] call fnc_log;

// Local debounce: blocks rapid re-clicks before the server round-trip answers.
if (_civilian getVariable ["recruit_processed_local", false]) exitWith {
    [localize "STR_DUWS_T_RECRUIT_ALREADY"] remoteExec ["hint", _caller];
};
_civilian setVariable ["recruit_processed_local", true];

[_civilian, _caller, netId _civilian, getPlayerUID _caller] remoteExec ["fnc_recruit_civilian_server", 2];