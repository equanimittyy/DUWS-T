// Locality: server, executed at load by server_fnc_init ([] call compile) so it can define several
// functions. The OPCOM force model -- the category -> power table and the resolvers pricing a holding, a
// sighting or a hardpoint against it -- kept in one home so the grid rebuild, sighting sweep and force
// readout share the one metric and cannot drift apart. Model: docs/plans/opcom/phase_2_force_weighting.md.
if (!isServer) exitWith {};

// Category -> grid power, the tune knobs: a man is 1, each other category worth that many men of force.
// An unnamed category (a boat, a mine) reads 0 -- no land-hold force. Keyed on the coarse buckets
// fnc_classifyVehicle returns and the token map below lands on, so both sides share the one table.
OPCOM_FORCE = createHashMapFromArray [
    ["man",         1],
    ["static_mg",   2],
    ["static_hi",   4],
    ["static_arty", 1],
    ["car_unarmed", 2],
    ["car_armed",   3],
    ["apc",         4],
    ["ifv",         9],
    ["tank",        12],
    ["air",         15]
];

// Our vehicle/static composition-token names (fnc_zone_spawn_sizes) -> a force category. Team tokens are
// absent on purpose: a team owes men, priced by headcount, not off this map. A name found here is a known
// vehicle; a name absent is a team or a bare classname, which tokenPower resolves by its other two paths.
DUWS_forceTokenCat = createHashMapFromArray [
    ["car", "car_armed"], ["at_car", "car_armed"], ["aa_car", "car_armed"], ["truck", "car_unarmed"],
    ["apc", "apc"], ["ifv", "ifv"], ["tank", "tank"],
    ["attackheli", "air"], ["transheli", "air"], ["plane", "air"]
];

// One composition token -> its force: a known vehicle token by category power, a team by its men, a bare
// classname a faction named directly by class lookup. Whole-token, like the garrison ledger's attrition.
DUWS_fnc_tokenPower = {
    params ["_token"];
    private _name = [_token] call DUWS_fnc_tokenName;
    private _cat = DUWS_forceTokenCat getOrDefault [_name, ""];
    if (_cat isNotEqualTo "") exitWith { OPCOM_FORCE getOrDefault [_cat, 0] };
    private _men = [_token] call DUWS_fnc_tokenMenCount;   // 0 for a non-team, so a bare class falls through
    if (_men > 0) exitWith { _men };
    [_name] call DUWS_fnc_classPower
};

// One class -> its force, for a sighted enemy hull with no token to read: fnc_classifyVehicle resolves the
// class alone (see fn_factionAutoDetect), then category -> power. An unclassifiable class reads 0.
DUWS_fnc_classPower = {
    params ["_class"];
    OPCOM_FORCE getOrDefault [[_class] call fnc_classifyVehicle, 0]
};

// A token list -> total force. The stowed path for a garrison's surviving-token ledger and for a
// hardpoint's loose garrison alike, at full condition (no live objects to scale by).
DUWS_fnc_tokenListForce = {
    params ["_tokens"];
    private _n = 0;
    { _n = _n + ([_x] call DUWS_fnc_tokenPower) } forEach _tokens;
    _n
};

// A hardpoint type -> its composed force: every weapon in the type's layout (DUWS_hardpointComp_<type>),
// each classPower-priced and summed -- a prop classifies to 0, a two-gun roadblock counts both, a radio
// base its whole nest -- plus its loose garrison. Read off the layout data, not live objects, so it holds
// whether the emplacement is deployed or stowed (the grid deposits for a stowed row too).
DUWS_fnc_hpForce = {
    params ["_type"];
    private _comp = missionNamespace getVariable [format ["DUWS_hardpointComp_%1", _type], []];
    private _static = 0;
    { _static = _static + ([_x select 0] call DUWS_fnc_classPower) } forEach _comp;
    private _gar = DUWS_hardpointGarrison getOrDefault [_type, ""];
    private _tokens = if (_gar isEqualType "") then { [_gar] - [""] } else { _gar };
    _static + ([_tokens] call DUWS_fnc_tokenListForce)
};
