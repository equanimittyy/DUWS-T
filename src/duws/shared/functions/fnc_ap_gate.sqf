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
    private _rungs = missionNamespace getVariable ["DUWS_ap_tier_rungs", [60, 200, 350, 600]];
    private _need = _rungs param [_tier - 2, 1e9];
    private _earnedVar = ["WARCOM_opfor_ap_earned", "WARCOM_blufor_ap_earned"] select (_side == "BLU");
    (missionNamespace getVariable [_earnedVar, 0]) >= _need
};

// The display name a ladder tier carries on locked menu rows and in the campaign setup -- the
// capability the rung unlocks, not a bare number. An out-of-range tier falls back to the infantry
// floor rather than returning an empty string.
DUWS_fnc_tierName = {
    params ["_tier"];
    localize ([
        "STR_DUWS_T_tiername1", "STR_DUWS_T_tiername2", "STR_DUWS_T_tiername3",
        "STR_DUWS_T_tiername4", "STR_DUWS_T_tiername5"
    ] param [_tier - 1, "STR_DUWS_T_tiername1"])
};

// The ladder tier a purchasable vehicle sits at, mapped from the same DUWS_fnc_vehKind classifier the
// price reads -- so the rung that unlocks a vehicle and the CP it costs can never disagree. A carrier
// that seats a squad is a tier below the pure gun platform of the same chassis: an APC or IFV (T3)
// against an MBT (T4), a transport helicopter (T3) against a gunship (T4). UAVs sit at Mechanised (T3)
// armed or not -- even a recon drone outranges what infantry can field, and the armed ones carry more
// than a car. Logistics and boats are T1; an unarmed car splits on seats -- a quad or runabout T1, a
// larger passenger car T2. Anything the classifier cannot place falls to Mechanised (T3), not the
// infantry floor: an unrecognised hull -- most likely a modded one -- is gated rather than handed over
// free mid-game. DUWS_fnc_vehKind lives in shared/functions/fnc_veh_price.sqf, broadcast alongside.
DUWS_fnc_vehTier = {
    params ["_class"];
    if (_class == "") exitWith { 1 };
    switch ([_class] call DUWS_fnc_vehKind) do {
        case "planeArmed": { 5 };
        case "planeTransport": { 5 };
        case "tank": { 4 };
        case "aa": { 4 };
        case "arty": { 4 };
        case "heliArmed": { 4 };
        case "apcIfv": { 3 };
        case "heliTransport": { 3 };
        case "uav": { 3 };
        case "armedCar": { 2 };
        case "lightUnarmed": {
            private _cfg = configFile >> "CfgVehicles" >> _class;
            private _seats = (getNumber (_cfg >> "hasDriver")) + (getNumber (_cfg >> "transportSoldier"))
                + count ("true" configClasses (_cfg >> "Turrets"));
            [2, 1] select (_seats <= 2)
        };
        case "logi": { 1 };
        case "boat": { 1 };
        default { 3 };
    }
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

// Fills a listbox from tier-tagged rows: unlocked first (alphabetical), then locked bucketed by tier
// -- each tier's locked rows kept together, ascending, alphabetical within the tier. A locked row is
// greyed and its tier appended, so the player reads what is coming and what it costs to reach without
// the row vanishing. The row's identity rides in lbData for the buy handler, which can no longer trust
// position once the list is sorted.
//   _rows: [[_label, _tier, _unlocked, _data], ...]
DUWS_fnc_tierListFill = {
    params ["_ctrl", "_rows"];
    // Sort key is [prefix + tier segment + lowercased label, original index]. The prefix ("0" open,
    // "1" locked) puts unlocked ahead; a locked row inserts its tier so locked rows bucket by tier
    // before the label orders within; open rows carry no tier, staying one alphabetical block. The
    // index is a scalar tie-break so sort never compares the row payloads (two equal labels would
    // otherwise drop it onto a boolean it cannot order).
    private _keyed = [];
    {
        private _unlocked = _x select 2;
        private _key = if (_unlocked) then {
            "0" + toLower (_x select 0)
        } else {
            "1" + str (_x select 1) + toLower (_x select 0)
        };
        _keyed pushBack [_key, _forEachIndex];
    } forEach _rows;
    _keyed sort true;
    {
        (_rows select (_x select 1)) params ["_label", "_tier", "_unlocked", "_data"];
        private _text = _label;
        if (!_unlocked) then { _text = _text + " " + format [localize "STR_DUWS_T_tier_tag", [_tier] call DUWS_fnc_tierName] };
        private _i = lbAdd [_ctrl, _text];
        lbSetData [_ctrl, _i, _data];
        if (!_unlocked) then { lbSetColor [_ctrl, _i, [0.5, 0.5, 0.5, 1]] };
    } forEach _keyed;
};
