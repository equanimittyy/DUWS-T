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

// Swept here rather than read from the pick's tick cache, which a build ordered since the last pick has outrun.
private _hps = (call DUWS_fnc_opcom_hpSweep) select 0;
private _hpAll = 0;
{ _hpAll = _hpAll + count _y } forEach _hps;
private _hpItem = {
    params ["_label", "_type"];
    [_label, count (_hps getOrDefault [_type, []]), [_type] call DUWS_fnc_opcom_hpCap]
};
private _open = call DUWS_fnc_opcom_zonesOpenSweep;
private _homed = call DUWS_fnc_opcom_homedSweep;
private _full = { (_homed getOrDefault [_x select 0, 0]) >= OPCOM_CAP_GARRISON } count _open;
private _slotsUsed = 0;
private _slotsCap = 0;
{
    _x params ["_zk", "_zs"];
    private _cap = [_zk, _zs] call fnc_hardpoint_zone_cap;
    _slotsCap = _slotsCap + _cap;
    _slotsUsed = _slotsUsed + (([_zk] call DUWS_fnc_opcom_zoneSlotsUsed) min _cap);
} forEach _open;
private _locked = ((keys DUWS_hardpointTier) select { (DUWS_hardpointTier get _x) > WARCOM_opfor_tier })
    apply { DUWS_hardpointName getOrDefault [_x, _x] };
_locked sort true;
private _reloading = 0;
{ if (_y > DUWS_opcom_tick) then { _reloading = _reloading + 1 } } forEach DUWS_opcom_gunReady;

// A [label, count, cap] item is drawn red once full; a string is drawn as it stands.
private _limits = [
    [format ["AP %1   income %2 per %3 min   picks %4/tick", WARCOM_opfor_ap, round WARCOM_opfor_lastIncome,
        DUWS_econ_period / 60, DUWS_opcom_picksPerTick]],
    [["Units", call DUWS_fnc_opcom_unitCount, OPCOM_CAP_UNITS], ["Supply", call DUWS_fnc_opcom_supplyCount, OPCOM_CAP_SUPPLY],
        ["Garrisons full", _full, count _open]],
    [["Hardpoints", _hpAll, OPCOM_CAP_HP_PER_ZONE * count zone_meta_array], ["Zone slots", _slotsUsed, _slotsCap]],
    [["Radio", "RADIO"] call _hpItem, ["OP", "OP"] call _hpItem, ["Mortar", "MORTAR"] call _hpItem, ["Arty", "ARTY"] call _hpItem],
    [["AT", "AT"] call _hpItem, ["AA", "AA"] call _hpItem, ["GMG", "GMG"] call _hpItem, ["Mines", "MINEFIELD"] call _hpItem],
    [[format ["Tier %1 locks %2", WARCOM_opfor_tier, _locked joinString ", "], format ["Tier %1 locks nothing", WARCOM_opfor_tier]]
        select (_locked isEqualTo []), format ["Guns reloading %1", _reloading]]
];

private _header = format ["OPCOM AI  %1   %2   tick %3", toUpper DUWS_opcom_aiMode, DUWS_opcom_archetype, DUWS_opcom_tick];
[_header, _rows, DUWS_opcom_aiEvents select { (_x select 0) > _since }, DUWS_opcom_aiSeq, _limits]
    remoteExecCall ["fnc_debug_opcom_ai_feed", _caller];
