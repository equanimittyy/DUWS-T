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
    ["air",         15],
    ["boat",        2]
];

// Our vehicle/static composition-token names (fnc_zone_spawn_sizes) -> a force category. Team tokens are
// absent on purpose: a team owes men, priced by headcount, not off this map. A name found here is a known
// vehicle; a name absent is a team or a bare classname, which tokenPower resolves by its other two paths.
DUWS_forceTokenCat = createHashMapFromArray [
    ["car", "car_armed"], ["at_car", "car_armed"], ["aa_car", "car_armed"], ["truck", "car_unarmed"],
    ["apc", "apc"], ["ifv", "ifv"], ["tank", "tank"],
    ["attackheli", "air"], ["transheli", "air"], ["plane", "air"], ["boat", "boat"]
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

// A sighted enemy group -> the strength a belief stamp carries: firepower (a dismounted man 1, each crewed
// hull its class power once, crew not re-counted) plus a premium per human aboard. No damage scaling -- a
// sighting reads firepower and intent, not condition; decay is the fog, not battle damage. Shared by both
// belief sensors (the A3 last-seen sweep and the recon bubble) so belief is stamped on one scale.
DUWS_fnc_opcom_sightStr = {
    params ["_grp"];
    private _gu = units _grp;
    private _seenVeh = [];
    private _fp = 0;
    {
        private _veh = vehicle _x;
        if (_veh isEqualTo _x) then {
            _fp = _fp + 1;
        } else {
            if !(_veh in _seenVeh) then {
                _seenVeh pushBack _veh;
                _fp = _fp + ([typeOf _veh] call DUWS_fnc_classPower);
            };
        };
    } forEach _gu;
    _fp + OPCOM_PLAYER_WORTH * ({isPlayer _x} count _gu)
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

// A zone's surviving centre statics -> their force. The prefab guns at a zone centre are streamed
// composition members, not garrison tokens, so garrisonForce adds them here. Stow-independent: the alive
// StaticWeapon members when deployed, else the stow records -- survivors only, since a wrecked gun is
// never recorded, so destruction persists across a stream cycle and never respawns.
DUWS_fnc_zoneStaticForce = {
    params ["_key"];
    private _n = 0;
    if (_key in DUWS_stowed) then {
        {
            if ((_x select 0) isKindOf ["StaticWeapon", configFile >> "CfgVehicles"]) then {
                _n = _n + ([_x select 0] call DUWS_fnc_classPower);
            };
        } forEach (DUWS_stowed getOrDefault [_key, []]);
    } else {
        {
            if (alive _x && {_x isKindOf "StaticWeapon"}) then {
                _n = _n + ([typeOf _x] call DUWS_fnc_classPower);
            };
        } forEach ((DUWS_compositions getOrDefault [_key, []]) select {!isNull _x});
    };
    _n
};
