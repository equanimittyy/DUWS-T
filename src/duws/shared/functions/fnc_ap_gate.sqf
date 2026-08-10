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
    if (_class isKindOf "Car") exitWith {
        // Total seats from config, not fullCrew: fullCrew needs a spawned object, but this runs on a
        // classname in the menu build. Driver + cargo + gunner turrets; a quad or 2-seat runabout is T1.
        private _seats = (getNumber (_cfg >> "hasDriver")) + _cargo + count ("true" configClasses (_cfg >> "Turrets"));
        [2, 1] select (_seats <= 2)
    };
    1
};

// The BLUFOR squad catalogue the request menu offers and its two handlers resolve. The section token
// in lbData is "<HC|TF>:<type>"; this maps <type> to the faction global holding [roster, cost], the
// High Command squad-type label the server names counters by, the menu string key, and the AP tier
// that gates it.  [type, global, HCsquadtype, labelKey, tier]
DUWS_blufor_squads = [
    ["Recon", "blufor_RECON_TEAM_X",    "Infantry", "STR_DUWS_T_SQUAD_RECON", 1],
    ["Inf",   "blufor_INF_SQUAD_X",     "Infantry", "STR_DUWS_T_SQUAD_INF",   1],
    ["Motor", "blufor_MOTOR_SECTION_X", "Motor",    "STR_DUWS_T_SQUAD_MOTOR", 2],
    ["Mech",  "blufor_MECH_SECTION_X",  "Mech",     "STR_DUWS_T_SQUAD_MECH",  3],
    ["Armor", "blufor_ARMOR_SECTION_X", "Armor",    "STR_DUWS_T_SQUAD_ARMOR", 4]
];
DUWS_fnc_squadRow = {
    params ["_type"];
    private _i = DUWS_blufor_squads findIf { (_x select 0) == _type };
    if (_i < 0) then { [] } else { DUWS_blufor_squads select _i }
};

// Fills a listbox from tier-tagged rows: unlocked first, then locked, each block alphabetical by
// label. A locked row is greyed and its tier appended, so the player reads what is coming and what it
// costs to reach without the row vanishing. The row's identity rides in lbData for the buy handler,
// which can no longer trust position once the list is sorted.
//   _rows: [[_label, _tier, _unlocked, _data], ...]
DUWS_fnc_tierListFill = {
    params ["_ctrl", "_rows"];
    // Sort key is [ "0"/"1" + lowercased label, original index ]: the prefix puts unlocked ahead of
    // locked, the label orders each block, and the index is a scalar tie-break so sort never has to
    // compare the row payloads -- two identical labels would otherwise drop it onto a boolean it
    // cannot order.
    private _keyed = [];
    {
        _keyed pushBack [(["1", "0"] select (_x select 2)) + toLower (_x select 0), _forEachIndex];
    } forEach _rows;
    _keyed sort true;
    {
        (_rows select (_x select 1)) params ["_label", "_tier", "_unlocked", "_data"];
        private _text = _label;
        if (!_unlocked) then { _text = _text + " " + format [localize "STR_DUWS_T_tier_tag", _tier] };
        private _i = lbAdd [_ctrl, _text];
        lbSetData [_ctrl, _i, _data];
        if (!_unlocked) then { lbSetColor [_ctrl, _i, [0.5, 0.5, 0.5, 1]] };
    } forEach _keyed;
};
