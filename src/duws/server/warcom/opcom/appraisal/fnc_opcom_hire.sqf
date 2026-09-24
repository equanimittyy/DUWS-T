// Locality: server, [] call'd at load. The Recruit rows that remain: a lift row, offered at the open zone nearest the
// rider its demand names.
if (!isServer) exitWith {};

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
    if (_zones isEqualTo []) exitWith { [] };
    ([_flags, _force, _moveType, _zones, _row] call DUWS_fnc_opcom_hireDemand) params ["_demand", "_at"];
    if (_demand <= 0) exitWith { [] };
    private _z = [_at, _zones] call DUWS_fnc_opcom_nearestOpen;
    if (_z isEqualTo []) exitWith { [] };
    private _zk = _z select 0;
    private _roster = ["roster", DUWS_fnc_opcom_rosterSweep] call DUWS_fnc_opcom_tickCached;
    private _mix = [["recruitMix"] call DUWS_fnc_opcom_archetypeTable, _roster select 0, _row, _roster select 1]
        call DUWS_fnc_opcom_mixFactor;
    [[[_row, _zk], _price, format ["Recruit %1 at %2", _row, [_zk] call DUWS_fnc_opcom_zoneLabel], _mix * _demand]]
};

DUWS_fnc_opcom_recruitRun = {
    params ["_target"];
    _target params ["_row", "_zk"];
    private _t = [_row, ([_zk] call fnc_site_at) get "pos", _zk, false] call fnc_opcom_recruit;
    !isNil "_t"
};
