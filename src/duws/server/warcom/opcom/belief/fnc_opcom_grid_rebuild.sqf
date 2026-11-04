// Locality: server. The grid stage of each OPCOM tick. Holdings nobody is near stay deposited in a cached static layer,
// which changes only for a key a holding writer marked dirty; live sites, belief and taskings are deposited fresh on a
// copy of it every tick. Both layers share the one firepower metric (fnc_opcom_force), so the force ratio that reads
// them is meaningful.
if (!isServer) exitWith {};

// Swapped before any holding is read, the order DUWS_fnc_opcom_gridDirty relies on.
private _dirty = _cmd get "gridDirty";
_cmd set ["gridDirty", createHashMap];

private _static = {
    params ["_layer"];
    [_cmd get "gridStaticFri", _cmd get "gridStaticEne"] select (_layer isEqualTo "ene")
};
private _admit = {
    params ["_rec"];
    if (_rec isEqualTo []) exitWith {};
    _rec params ["_key", "_isStatic", "_layer", "_pos", "_weight", "_reach"];
    if (!_isStatic) exitWith { (_cmd get "gridAwake") set [_key, [_pos, _reach, _layer]] };
    if (_weight > 0) then {
        [[_layer] call _static, _pos, _weight, _reach] call DUWS_fnc_opcom_deposit;
        (_cmd get "gridSrc") set [_key, [_layer, _pos, _weight, _reach]];
    };
};

if (_cmd get "gridDirtyAll") then {
    _cmd set ["gridDirtyAll", false];
    [_cmd get "gridStaticFri"] call DUWS_fnc_opcom_gridZeroBox;
    [_cmd get "gridStaticEne"] call DUWS_fnc_opcom_gridZeroBox;
    _cmd set ["gridSrc", createHashMap];
    _cmd set ["gridAwake", createHashMap];
    { [_x] call _admit } forEach (call DUWS_fnc_opcom_gridSources);
};

{
    private _old = (_cmd get "gridSrc") get _x;
    if (!isNil "_old") then {
        _old params ["_layer", "_pos", "_weight", "_reach"];
        // Negated from the cache, never re-priced: the inputs have already changed.
        [[_layer] call _static, _pos, -_weight, _reach] call DUWS_fnc_opcom_deposit;
        (_cmd get "gridSrc") deleteAt _x;
    };
    (_cmd get "gridAwake") deleteAt _x;
    [[_x] call DUWS_fnc_opcom_gridSourceOf] call _admit;
} forEach keys _dirty;

// Built on copies and assigned last, never written in place: a reader holding a layer across a yield, such as the
// router, keeps one whole grid.
private _fri = +(_cmd get "gridStaticFri");
private _ene = +(_cmd get "gridStaticEne");
{
    _y params ["_pos", "_reach", ["_layer", "fri"]];
    [[_fri, _ene] select (_layer isEqualTo "ene"), _pos, [_x] call DUWS_fnc_garrisonForce, _reach] call DUWS_fnc_opcom_deposit;
} forEach (_cmd get "gridAwake");
[_fri, _ene] call DUWS_fnc_opcom_gridMobile;
_cmd set ["grid_fri", _fri];
_cmd set ["grid_ene", _ene];

if (!isNil "DUWS_opcom_gridDriftAsk") then {
    private _caller = DUWS_opcom_gridDriftAsk;
    DUWS_opcom_gridDriftAsk = nil;
    [_caller] call DUWS_fnc_opcom_gridDrift;
};
