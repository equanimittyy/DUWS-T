// Locality: server -- executed once by server_fnc_init ([] call compile), defining the OPCOM force model:
// the single category -> power table and the resolvers that price a holding, a sighting or a hardpoint
// against it. Phase 2 swaps the influence grid's men-count metric for this firepower weight, so the grid
// rebuild, the sighting sweep and the force-emission readout all price through here and cannot drift into
// different units. Model: docs/plans/opcom/phase_2_force_weighting.md.
if (!isServer) exitWith {};

// Category -> grid power. The tune knobs: a man is 1, every other category is worth that many men of
// force. A category no resolver names (a boat, a mine) reads 0 -- no land-hold force. Keyed on the coarse
// force buckets fnc_classifyVehicle returns and the token map below lands on, so both sides share it.
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

// One composition token -> its force. A known vehicle/static token is its category's power; a team token
// is its men (each 1, from the roster count); a bare classname a faction named directly falls to a class
// lookup. Whole-token, mirroring the whole-token attrition the garrison ledger keeps.
DUWS_fnc_tokenPower = {
    params ["_token"];
    private _name = [_token] call DUWS_fnc_tokenName;
    private _cat = DUWS_forceTokenCat getOrDefault [_name, ""];
    if (_cat isNotEqualTo "") exitWith { OPCOM_FORCE getOrDefault [_cat, 0] };
    private _men = [_token] call DUWS_fnc_tokenMenCount;   // 0 for a non-team, so a bare class falls through
    if (_men > 0) exitWith { _men };
    [_name] call DUWS_fnc_classPower
};

// One class -> its force. For a sighted enemy hull, where there is no token to read: fnc_classifyVehicle
// resolves the class alone (see fn_factionAutoDetect), then the category maps to power. An unclassifiable
// class reads 0.
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

// A hardpoint type -> its composed force: every emplaced weapon in the type's layout plus its loose
// garrison. Each member of the layout (DUWS_hardpointComp_<type>) is classPower-priced and summed, so a
// prop -- sandbag, gate, mast -- classifies to nothing and adds 0, while a two-gun roadblock counts both
// guns and a fortified radio base its whole nest. Read off the layout data, not live objects, so it holds
// whether the emplacement is deployed or stowed (the grid deposits for a stowed hardpoint too).
DUWS_fnc_hpForce = {
    params ["_type"];
    private _comp = missionNamespace getVariable [format ["DUWS_hardpointComp_%1", _type], []];
    private _static = 0;
    { _static = _static + ([_x select 0] call DUWS_fnc_classPower) } forEach _comp;
    private _gar = DUWS_hardpointGarrison getOrDefault [_type, ""];
    private _tokens = if (_gar isEqualType "") then { [_gar] - [""] } else { _gar };
    _static + ([_tokens] call DUWS_fnc_tokenListForce)
};
