// Locality: server -- remoteExec'd to 2 by the OPCOM AI overlay's poll. Lines are drawn as structured text, so none
// may carry < > or &.
if (!isServer) exitWith {};
params ["_caller", ["_since", 0]];
if (isNull _caller) exitWith {};

#define AI_ROWS_MAX 6

private _active = createHashMap;
{
    if ((_x get "order") in ["move", "capture", "intercept"]) then {
        private _errand = (_x getOrDefault ["errand", []]) param [0, ""];
        private _zk = _x getOrDefault ["settleZone", ""];
        private _tgt = _x get "target";
        _active set [_x get "id", format ["#%1 %2 %3%4 to %5", _x get "id", _x get "menu", _x get "order",
            ["", format [" (%1)", _errand]] select (_errand isNotEqualTo ""),
            if (_zk isEqualTo "") then { mapGridPosition _tgt } else { [_zk] call DUWS_fnc_opcom_zoneLabel }]];
    };
} forEach DUWS_opcom_taskings;

// Diffed per poll rather than per tick, so the overlay costs the loop nothing. A gap of more than two ticks since the
// last poll rebaselines silently instead of reporting every order that ended while nobody watched.
if (DUWS_opcom_tick - (missionNamespace getVariable ["DUWS_opcom_aiPollTick", -99]) <= 2) then {
    {
        if !(_x in _active) then {
            private _t = [_x] call DUWS_fnc_opcom_byId;
            private _end = if (isNil "_t") then { "lost" } else { format ["ended, now %1", _t get "order"] };
            [format ["%1  %2", _y, _end]] call DUWS_fnc_opcom_aiEvent;
        };
    } forEach (missionNamespace getVariable ["DUWS_opcom_aiPrev", createHashMap]);
};
DUWS_opcom_aiPrev = _active;
DUWS_opcom_aiPollTick = DUWS_opcom_tick;

private _ids = keys _active;
_ids sort true;
private _rows = _ids apply { _active get _x };
{
    _x params ["", "_type", "_zk"];
    _rows pushBack format ["Build %1 at %2 (siting)", DUWS_hardpointName getOrDefault [_type, _type], [_zk] call DUWS_fnc_opcom_zoneLabel];
} forEach DUWS_opcom_buildsPending;
if (count _rows > AI_ROWS_MAX) then {
    _rows = (_rows select [0, AI_ROWS_MAX - 1]) + [format ["+%1 more", count _rows - AI_ROWS_MAX + 1]];
};

private _header = format ["OPCOM AI  %1   AP %2   tier %3   tick %4", toUpper DUWS_opcom_aiMode, WARCOM_opfor_ap, WARCOM_opfor_tier, DUWS_opcom_tick];
[_header, _rows, DUWS_opcom_aiEvents select { (_x select 0) > _since }, DUWS_opcom_aiSeq] remoteExecCall ["fnc_debug_opcom_ai_feed", _caller];
