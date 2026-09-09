// Locality: server. Hire one menu row into a resting garrison tasking unit, paid from the OPFOR wallet.
// Returns the tasking record, or nil if refused. Phase 4 scores when to call this; Phase 3 drives it by hand.
//
// A recruited unit is a distinct one-per-zone garrison slot in the OPCOM store, resting with no order until
// OPCOM later draws it for an active tasking (docs/plans/opcom/opcom_plan.md). It is deliberately not the
// base garrison's live-refill reserve pool -- that is a separate attrition system.
params ["_row", "_spawnPos", ["_homeZone", ""]];
if (!isServer) exitWith { nil };

private _menu = DUWS_opcom_recruitMenu getOrDefault [_row, []];
if (_menu isEqualTo []) exitWith { ["WARN", "OPCOM", format ["recruit: unknown menu row %1", _row]] call fnc_log; nil };
_menu params ["_comp", "_flags"];

// Price is force: composition firepower times the one force->AP rate. Zero force means an unresolvable token
// (an unbuilt one such as boat) -- refused, not hired for free.
private _force = [_comp] call DUWS_fnc_tokenListForce;
if (_force <= 0) exitWith { ["WARN", "OPCOM", format ["recruit: row %1 has no resolvable force (unbuilt token?)", _row]] call fnc_log; nil };
private _cost = ceil (_force * OPCOM_AP_PER_FORCE);

if (WARCOM_opfor_ap < _cost) exitWith { ["INFO", "OPCOM", format ["recruit: %1 costs %2 AP, wallet %3 -- refused", _row, _cost, WARCOM_opfor_ap]] call fnc_log; nil };

// Faction/tier availability: tokenClass returns "" for a vehicle the OPFOR faction cannot field now (a
// campaign toggle off, or the earned-AP tier gate not met). A team token answers itself, so it never trips.
private _blocked = _comp findIf { ([_x, "OPF"] call DUWS_fnc_tokenClass) isEqualTo "" };
if (_blocked >= 0) exitWith { ["INFO", "OPCOM", format ["recruit: faction cannot field %1 yet -- refused", _comp select _blocked]] call fnc_log; nil };

["OPF", -_cost, "opcom_recruit"] call fnc_ap_adjust;

private _id = DUWS_opcom_taskSeq;
DUWS_opcom_taskSeq = _id + 1;
// A boat cannot rest on the land zone that raised it -- launch it from the nearest navigable water.
private _moveType = [_comp] call DUWS_fnc_opcom_moveType;
private _pos = if (_moveType isEqualTo "boat") then { [_spawnPos] call DUWS_fnc_opcom_nearestWater } else { _spawnPos };
private _t = createHashMapFromArray [
    ["id", _id], ["order", "garrison"], ["target", []],
    ["pos", _pos], ["moveType", _moveType],
    ["menu", _row], ["comp", _comp], ["flags", _flags],
    ["fullForce", _force], ["effForce", _force],
    ["route", []], ["leg", 0], ["routeMode", "grid"],
    ["status", "virtual"], ["grp", ""], ["hold", 0], ["homeZone", _homeZone],
    ["carrying", -1], ["ridingOn", -1], ["embarked", false], ["returnZone", ""]
];
DUWS_opcom_taskings pushBack _t;
// A garrison unit joins its zone's reserve so the existing wave spawns it to defend when the zone is contested.
if (_homeZone isNotEqualTo "") then { [_homeZone] call DUWS_fnc_opcom_zoneReserveSync };
["INFO", "OPCOM", format ["recruit: hired %1 (force %2, %3 AP) at %4 as tasking %5", _row, _force, _cost, _spawnPos, _id]] call fnc_log;
_t
