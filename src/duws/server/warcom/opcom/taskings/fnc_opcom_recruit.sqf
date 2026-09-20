// Locality: server. Hire one menu row into a resting `garrison` tasking, paid from the OPFOR wallet. Returns the
// tasking record, or nil if refused. The recruited unit is a distinct OPCOM garrison slot, not the base
// garrison's live-refill reserve pool -- a separate attrition system. _pay false leaves the charge to the caller,
// whose action price already carries the hire.
params ["_row", "_spawnPos", ["_homeZone", ""], ["_pay", true]];
if (!isServer) exitWith { nil };

private _menu = DUWS_opcom_recruitMenu getOrDefault [_row, []];
if (_menu isEqualTo []) exitWith { ["WARN", "OPCOM", format ["recruit: unknown menu row %1", _row]] call fnc_log; nil };
_menu params ["_comp", "_flags"];

// Zero force means an unresolvable/unbuilt token -- refused, not hired for free.
private _force = [_comp] call DUWS_fnc_tokenListForce;
if (_force <= 0) exitWith { ["WARN", "OPCOM", format ["recruit: row %1 has no resolvable force (unbuilt token?)", _row]] call fnc_log; nil };
private _cost = ceil ([_comp] call DUWS_fnc_opcom_listPrice);

if (_pay && {WARCOM_opfor_ap < _cost}) exitWith { ["INFO", "OPCOM", format ["recruit: %1 costs %2 AP, wallet %3 -- refused", _row, _cost, WARCOM_opfor_ap]] call fnc_log; nil };

// tokenClass "" = the faction cannot field this vehicle now (toggle off, or tier gate not met); a team token never trips.
private _blocked = _comp findIf { ([_x, "OPF"] call DUWS_fnc_tokenClass) isEqualTo "" };
if (_blocked >= 0) exitWith { ["INFO", "OPCOM", format ["recruit: faction cannot field %1 yet -- refused", _comp select _blocked]] call fnc_log; nil };

// A boat cannot rest on the land zone that raised it -- launch it from the zone's port. The port gate
// runs ahead of the AP charge, so a refusal needs no refund path.
private _moveType = [_comp] call DUWS_fnc_opcom_moveType;
if (_moveType isEqualTo "boat" && {[_homeZone] call DUWS_fnc_opcom_portOf < 0}) exitWith {
    ["INFO", "OPCOM", format ["recruit: zone %1 has no port -- boat refused", _homeZone]] call fnc_log; nil
};

if (_pay) then { ["OPF", -_cost, "opcom_recruit"] call fnc_ap_adjust };

private _id = DUWS_opcom_taskSeq;
DUWS_opcom_taskSeq = _id + 1;
private _pos = _spawnPos;
if (_moveType isEqualTo "boat") then {
    _pos = [[_homeZone] call DUWS_fnc_opcom_portOf] call DUWS_fnc_opcom_c2w;
};
// tokenClass redraws a random model per spawn, so a stow/re-spawn cycle would otherwise swap the hull.
private _spawnClass = [_comp select 0, "OPF"] call DUWS_fnc_tokenClass;
private _t = createHashMapFromArray [
    ["id", _id], ["order", "garrison"], ["target", []],
    ["pos", _pos], ["moveType", _moveType],
    ["menu", _row], ["comp", _comp], ["spawnClass", _spawnClass], ["flags", _flags],
    ["fullForce", _force], ["effForce", _force],
    ["route", []], ["leg", 0], ["routeMode", "grid"],
    ["status", "virtual"], ["grp", ""], ["hold", 0], ["homeZone", _homeZone],
    ["carrying", -1], ["ridingOn", -1], ["embarked", false], ["returnZone", ""]
];
DUWS_opcom_taskings pushBack _t;
// A garrison never streams; a combatant is fielded only through its zone's reserve pool.
if (_homeZone isNotEqualTo "") then { [_homeZone] call DUWS_fnc_opcom_zoneReserveSync };
["INFO", "OPCOM", format ["recruit: hired %1 (force %2, %3 AP) at %4 as tasking %5", _row, _force, _cost, _pos, _id]] call fnc_log;
_t
