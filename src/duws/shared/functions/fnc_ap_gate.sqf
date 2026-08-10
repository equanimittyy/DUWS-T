// Locality: any -- broadcast from server_fnc_init. The request menus grey and sort their rows by the
// Army Power ladder client-side, and the squad server guards test the same gate, so both halves must
// resolve identically. Reads only broadcast state (WARCOM_<side>_ap_earned, DUWS_ap_tier_rungs).

// Whether a side has earned the rung a tier sits behind. Tier 1 is the floor and always open; a tier
// past the rung table is treated as unreachable rather than throwing. The rungs carry a vanilla
// fallback so a menu opened before the broadcast lands still gates honestly rather than opening
// everything.
DUWS_fnc_ap_unlocked = {
    params ["_side", "_tier"];
    if (_tier <= 1) exitWith { true };
    private _rungs = missionNamespace getVariable ["DUWS_ap_tier_rungs", [100, 175, 300, 500]];
    private _need = _rungs param [_tier - 2, 1e9];
    private _earnedVar = ["WARCOM_opfor_ap_earned", "WARCOM_blufor_ap_earned"] select (_side == "BLU");
    (missionNamespace getVariable [_earnedVar, 0]) >= _need
};

// The ladder tier a purchasable vehicle sits at, read from its config kind rather than a per-faction
// table -- the shop pulls arbitrary classnames from faction files this mission does not own. A carrier
// that seats a squad is a tier below the pure gun platform of the same chassis: an APC or IFV (T3)
// against an MBT (T4), a transport helicopter (T3) against a gunship (T4). A car of two seats or fewer
// (a quad, a light runabout) drops to T1; a larger one is T2. Anything the kinds below do not claim --
// a truck, a boat, a logistics vehicle -- is T1.
DUWS_fnc_vehTier = {
    params ["_class"];
    if (_class == "") exitWith { 1 };
    private _cfg = configFile >> "CfgVehicles" >> _class;
    private _cargo = getNumber (_cfg >> "transportSoldier");
    if (_class isKindOf "Plane") exitWith { 5 };
    if (_class isKindOf "Helicopter") exitWith { [4, 3] select (_cargo >= 4) };
    if (_class isKindOf "Tank" || {_class isKindOf "Wheeled_APC_F"}) exitWith {
        [4, 3] select (_cargo >= 4)
    };
    if (_class isKindOf "Car") exitWith { [2, 1] select ((count fullCrew [_class, "", true]) <= 2) };
    1
};

// Fills a listbox from tier-tagged rows: unlocked first, then locked, each block alphabetical by
// label. A locked row is greyed and its tier appended, so the player reads what is coming and what it
// costs to reach without the row vanishing. The row's identity rides in lbData for the buy handler,
// which can no longer trust position once the list is sorted.
//   _rows: [[_label, _tier, _unlocked, _data], ...]
DUWS_fnc_tierListFill = {
    params ["_ctrl", "_rows"];
    // Composite string key: "0"/"1" puts unlocked ahead of locked, the lowercased label orders each
    // block. SQF sort takes string subarray keys, so no numeric collation is needed.
    private _keyed = _rows apply {
        _x params ["_label", "", "_unlocked"];
        [(["1", "0"] select _unlocked) + toLower _label, _x]
    };
    _keyed sort true;
    {
        (_x select 1) params ["_label", "_tier", "_unlocked", "_data"];
        private _text = _label;
        if (!_unlocked) then { _text = _text + " " + format [localize "STR_DUWS_T_tier_tag", _tier] };
        private _i = lbAdd [_ctrl, _text];
        lbSetData [_ctrl, _i, _data];
        if (!_unlocked) then { lbSetColor [_ctrl, _i, [0.5, 0.5, 0.5, 1]] };
    } forEach _keyed;
};
