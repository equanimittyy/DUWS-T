// Locality: server. The grid stage of each OPCOM tick. Holdings nobody is near stay deposited in a cached static layer,
// which changes only for a key a holding writer marked dirty; live sites, belief and taskings are deposited fresh on a
// copy of it every tick. Both layers share the one firepower metric (fnc_opcom_force), so the force ratio that reads
// them is meaningful.
if (!isServer) exitWith {};

// Swapped before any holding is read, the order DUWS_fnc_opcom_gridDirty relies on.
private _dirty = DUWS_opcom_gridDirty;
DUWS_opcom_gridDirty = createHashMap;

private _static = {
    params ["_layer"];
    [DUWS_opcom_gridStaticFri, DUWS_opcom_gridStaticEne] select (_layer isEqualTo "ene")
};
private _admit = {
    params ["_rec"];
    if (_rec isEqualTo []) exitWith {};
    _rec params ["_key", "_isStatic", "_layer", "_pos", "_weight", "_reach"];
    if (!_isStatic) exitWith { DUWS_opcom_gridAwake set [_key, [_pos, _reach]] };
    if (_weight > 0) then {
        [[_layer] call _static, _pos, _weight, _reach] call DUWS_fnc_opcom_deposit;
        DUWS_opcom_gridSrc set [_key, [_layer, _pos, _weight, _reach]];
    };
};

if (DUWS_opcom_gridDirtyAll) then {
    DUWS_opcom_gridDirtyAll = false;
    [DUWS_opcom_gridStaticFri] call DUWS_fnc_opcom_gridZeroBox;
    [DUWS_opcom_gridStaticEne] call DUWS_fnc_opcom_gridZeroBox;
    DUWS_opcom_gridSrc = createHashMap;
    DUWS_opcom_gridAwake = createHashMap;
    { [_x] call _admit } forEach (call DUWS_fnc_opcom_gridSources);
};

{
    private _old = DUWS_opcom_gridSrc get _x;
    if (!isNil "_old") then {
        _old params ["_layer", "_pos", "_weight", "_reach"];
        // Negated from the cache, never re-priced: the inputs have already changed.
        [[_layer] call _static, _pos, -_weight, _reach] call DUWS_fnc_opcom_deposit;
        DUWS_opcom_gridSrc deleteAt _x;
    };
    DUWS_opcom_gridAwake deleteAt _x;
    [[_x] call DUWS_fnc_opcom_gridSourceOf] call _admit;
} forEach keys _dirty;

// Built on copies and assigned last, never written in place: a reader holding a layer across a yield, such as the
// router, keeps one whole grid.
private _fri = +DUWS_opcom_gridStaticFri;
private _ene = +DUWS_opcom_gridStaticEne;
{
    _y params ["_pos", "_reach"];
    [_fri, _pos, [_x] call DUWS_fnc_garrisonForce, _reach] call DUWS_fnc_opcom_deposit;
} forEach DUWS_opcom_gridAwake;
[_fri, _ene] call DUWS_fnc_opcom_gridMobile;
DUWS_opcom_grid_fri = _fri;
DUWS_opcom_grid_ene = _ene;

if (!isNil "DUWS_opcom_gridDriftAsk") then {
    private _caller = DUWS_opcom_gridDriftAsk;
    DUWS_opcom_gridDriftAsk = nil;
    [_caller] call DUWS_fnc_opcom_gridDrift;
};
