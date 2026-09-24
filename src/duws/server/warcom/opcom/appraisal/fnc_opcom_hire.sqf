// Locality: server, [] call'd at load. The Recruit rows, one per recruit-menu row (opcom_plan.md §Appraisal): a
// combatant row offers every open zone under its garrison cap, a recon or transport row the open zone nearest the
// demand blocking it.
if (!isServer) exitWith {};

// The combatants homed at each zone, the set its reserve pool fields (DUWS_fnc_opcom_zoneReserveSync).
DUWS_fnc_opcom_homedSweep = {
    private _out = createHashMap;
    {
        if ((_x get "order") isEqualTo "garrison" && {(_x get "status") isNotEqualTo "dead"}
            && {!("noncombat" in (_x get "flags"))}) then {
            private _hz = _x get "homeZone";
            _out set [_hz, (_out getOrDefault [_hz, 0]) + 1];
        };
    } forEach DUWS_opcom_taskings;
    _out
};

DUWS_fnc_opcom_recruitTargets = {
    params ["_row"];
    private _menu = DUWS_opcom_recruitMenu getOrDefault [_row, []];
    private _price = OPCOM_AP_UNIT getOrDefault [_row, -1];
    if (_menu isEqualTo [] || {_price < 0}) exitWith { [] };
    _menu params ["_comp", "_flags"];
    if (!("supply" in _flags) && {(call DUWS_fnc_opcom_unitCount) >= OPCOM_CAP_UNITS}) exitWith { [] };
    // An empty class is a faction that cannot field the row now, which fnc_opcom_recruit refuses at the hire.
    if ((_comp findIf { ([_x, "OPF"] call DUWS_fnc_tokenClass) isEqualTo "" }) >= 0) exitWith { [] };
    private _force = [_comp] call DUWS_fnc_tokenListForce;
    if (_force <= 0) exitWith { [] };
    private _moveType = [_comp] call DUWS_fnc_opcom_moveType;
    private _zones = call DUWS_fnc_opcom_zonesOpen;
    // A boat rests at its zone's port, so a portless zone raises none.
    if (_moveType isEqualTo "boat") then { _zones = _zones select { ([_x select 0] call DUWS_fnc_opcom_portOf) >= 0 } };
    if !("noncombat" in _flags) then {
        private _homed = ["homed", DUWS_fnc_opcom_homedSweep] call DUWS_fnc_opcom_tickCached;
        _zones = _zones select { (_homed getOrDefault [_x select 0, 0]) < OPCOM_CAP_GARRISON };
    };
    if (_zones isEqualTo []) exitWith { [] };
    ([_flags, _force, _moveType, _zones, _row] call DUWS_fnc_opcom_hireDemand) params ["_demand", "_at"];
    private _roster = ["roster", DUWS_fnc_opcom_rosterSweep] call DUWS_fnc_opcom_tickCached;
    private _mix = [["recruitMix"] call DUWS_fnc_opcom_archetypeTable, _roster select 0, _row, _roster select 1]
        call DUWS_fnc_opcom_mixFactor;

    if ("noncombat" in _flags || {"recon" in _flags}) exitWith {
        private _z = if (_demand <= 0) then { [] } else { [_at, _zones] call DUWS_fnc_opcom_nearestOpen };
        if (_z isEqualTo []) then { [] } else {
            private _zk = _z select 0;
            [[[_row, _zk], _price, format ["Recruit %1 at %2", _row, [_zk] call DUWS_fnc_opcom_zoneLabel],
                _mix * _demand]]
        }
    };

    // The larger, never the sum: a hire joins its zone's reserve pool at once, but serves one role at a time.
    _zones apply {
        _x params ["_zk", "", "", "_worth", "_exp"];
        [[_row, _zk], _price, format ["Recruit %1 at %2", _row, [_zk] call DUWS_fnc_opcom_zoneLabel],
            _mix * (_demand max
                ([_worth, _exp, _force, [_zk] call DUWS_fnc_opcom_zoneForce] call DUWS_fnc_opcom_hireDefense))]
    }
};

DUWS_fnc_opcom_recruitRun = {
    params ["_target"];
    _target params ["_row", "_zk"];
    private _t = [_row, ([_zk] call fnc_site_at) get "pos", _zk, false] call fnc_opcom_recruit;
    !isNil "_t"
};
