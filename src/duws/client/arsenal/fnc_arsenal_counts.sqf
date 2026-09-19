// Locality: client -- paints the open arsenal, so it runs on whoever opened it. Compiled once by
// client/client_init.sqf, then called every tick of the arsenal enforcer loop in initPlayerLocal.sqf.
//
// The stock virtual arsenal has no quantity concept: BIS_fnc_addVirtualWeaponCargo just marks a class
// present, unlimited. The real per-class stock lives in DUWS_capturedPool; this overlays it onto the
// list rows the way Antistasi's arsenal does -- a cosmetic count/infinity prefix repainted on every
// redraw, backed by the authoritative pool, while the arsenal underneath stays a dumb present/absent
// set.
//
// The number shown is the live broadcast pool minus this session's local takes: it refreshes under an
// open arsenal on any server rebroadcast (the enforcer's restock tick diffs it and forces a re-stamp),
// and DUWS_arsenalTaken subtracts the player's own uncommitted draws. The authoritative settle still
// lands on close (fnc_captured_pool_settle), where overdraw is stripped.
//
// The IDC macros (IDC_RSCDISPLAYARSENAL_LIST base + IDC_RSCDISPLAYARSENAL_TAB_* offsets) come from
// BIS's own header, so the control ids track the engine version instead of being hardcoded numbers.
#include "\A3\Ui_f\hpp\defineResinclDesign.inc"

DUWS_fnc_arsenal_canon = {
    params ["_cls"];
    private _canon = configName (configFile >> "CfgMagazines" >> _cls);
    if (_canon == "") then { _canon = configName (configFile >> "CfgWeapons" >> _cls) };
    if (_canon == "") then { _canon = configName (configFile >> "CfgVehicles" >> _cls) };
    if (_canon == "") then { _cls } else { _canon }
};

// Available count for a class as the shelf actually enforces it: -1 means unlimited (rendered as the
// infinity glyph). Order matters -- each earlier rule is a hard override of the ones below it.
DUWS_fnc_arsenal_countFor = {
    params ["_cls"];
    // Full mode leaves the whole arsenal unlimited; the enforcer marks it non-restricted.
    if (!(player getVariable ["DUWS_isRestrictedArsenal", false])) exitWith { -1 };
    // Startup kit stays the player's to re-draw in Hybrid: the gear deployed with is unlimited there,
    // including a BLUFOR default class the detected faction never fields -- absent from the friendly
    // snapshot, it would otherwise read as an empty pool ([0]). Limited tracks everything and has no
    // unlimited floor, so the kit counts down like any other gear; its friendly classes are pool-seeded
    // at boot, so only a rare non-fielded default reads [0] there.
    if (!(missionNamespace getVariable ["DUWS_arsenalLimited", false]) && {_cls in (player getVariable ["DUWS_startupKit", []])}) exitWith { -1 };
    // Ammo untracked (the default): magazines are free in every mode, so never counted.
    if ((isClass (configFile >> "CfgMagazines" >> _cls)) && {!(missionNamespace getVariable ["DUWS_trackAmmo", false])}) exitWith { -1 };
    // Hybrid keeps standard-issue gear unlimited; Limited tracks it too, so only Hybrid short-circuits.
    if ((_cls in (missionNamespace getVariable ["DUWS_friendlyArsenal", []])) && {!(missionNamespace getVariable ["DUWS_arsenalLimited", false])}) exitWith { -1 };
    // Count-tracked: pool is [[class, n], ...], zero-count classes dropped so absence reads zero. It
    // only settles on arsenal close; this session's takes/returns are reflected live by subtracting
    // the open-time loadout delta the enforcer keeps in DUWS_arsenalTaken (held now but not at open =
    // withdrawn, one fewer available) -- display only, the pool itself stays untouched until close.
    // The compatible-magazines list hands back lowercased classnames (BIS folds case from the weapon's
    // config mag list), while the pool and DUWS_arsenalTaken key on the config's own case. isEqualTo
    // and the HashMap key are both case-sensitive, so a lowercased class read [0]. Canonicalise to the
    // declared case first; configName resolves it (a tracked class is always in one of these).
    _cls = [_cls] call DUWS_fnc_arsenal_canon;
    private _pool = missionNamespace getVariable ["DUWS_capturedPool", []];
    private _i = _pool findIf { (_x select 0) isEqualTo _cls };
    private _n = if (_i < 0) then { 0 } else { (_pool select _i) select 1 };
    private _taken = missionNamespace getVariable "DUWS_arsenalTaken";
    private _off = if (isNil "_taken") then { 0 } else { _taken getOrDefault [_cls, 0] };
    (_n - _off) max 0
};

// Logs every input countFor weighed for a [0] row, once per class per open. *Key fields match
// case-insensitively, so a key differing from the row only in case exposes a case-sensitive miss;
// shelf "-" means BIS listed the row with no cargo behind it: held gear if held matches, else a
// preset's base row.
DUWS_fnc_arsenal_logZero = {
    params ["_cls", "_tab"];
    private _seen = missionNamespace getVariable "DUWS_arsenal_zeroLogged";
    if (isNil "_seen" || {_cls in _seen}) exitWith {};
    _seen set [_cls, true];
    private _canon = [_cls] call DUWS_fnc_arsenal_canon;
    private _ciKey = {
        params ["_arr", "_c"];
        private _j = _arr findIf { _x isEqualType "" && {_x == _c} };
        if (_j < 0) then { "-" } else { _arr select _j }
    };
    private _pool = missionNamespace getVariable ["DUWS_capturedPool", []];
    private _i = _pool findIf { (_x select 0) isEqualTo _canon };
    private _poolKeys = _pool apply { _x select 0 };
    private _taken = missionNamespace getVariable "DUWS_arsenalTaken";
    private _shelf = [];
    {
        _shelf append flatten (missionNamespace getVariable [_x, []]);
    } forEach ["bis_addVirtualWeaponCargo_cargo", "bis_addVirtualItemCargo_cargo",
        "bis_addVirtualMagazineCargo_cargo", "bis_addVirtualBackpackCargo_cargo"];
    ["DEBUG", "GEAR", format ["[0] %1 canon=%2 tab=%3 pool=%4 poolKey=%5 taken=%6 friendlyKey=%7 kit=%8 shelf=%9 held=%10",
        _cls, _canon, _tab,
        if (_i < 0) then { 0 } else { (_pool select _i) select 1 },
        [_poolKeys, _canon] call _ciKey,
        if (isNil "_taken") then { 0 } else { _taken getOrDefault [_canon, 0] },
        [missionNamespace getVariable ["DUWS_friendlyArsenal", []], _cls] call _ciKey,
        _cls in (player getVariable ["DUWS_startupKit", []]),
        [_shelf, _cls] call _ciKey,
        [flatten getUnitLoadout player, _cls] call _ciKey]] call fnc_log;
};

// Repaints every populated, visible item list under the arsenal display: only shown lists are walked
// (the arsenal shows just the active tab's list, plus attachment/cargo lists when a weapon is
// selected), bounding the work regardless of how large the config is in Full mode.
DUWS_fnc_arsenal_paintCounts = {
    params [["_display", displayNull]];
    if (isNull _display) exitWith {};

    // Full leaves the whole-config arsenal unlimited and unrestricted: no per-row count means anything,
    // and stamping thousands of rows only fights BIS's own repopulation of that list. Paint nothing.
    if (!(player getVariable ["DUWS_isRestrictedArsenal", false])) exitWith {};

    // Every browsable category list, left panel then right; each control id is the shared list base
    // plus the category's tab offset. Both magazine lists are walked: the compact "compatible mags"
    // list (CARGOMAG, the default view) is a separate control from "all mags" (CARGOMAGALL) --
    // stamping only the latter left the default mag tab uncounted.
    private _tabs = [
        IDC_RSCDISPLAYARSENAL_TAB_PRIMARYWEAPON, IDC_RSCDISPLAYARSENAL_TAB_SECONDARYWEAPON,
        IDC_RSCDISPLAYARSENAL_TAB_HANDGUN, IDC_RSCDISPLAYARSENAL_TAB_UNIFORM,
        IDC_RSCDISPLAYARSENAL_TAB_VEST, IDC_RSCDISPLAYARSENAL_TAB_BACKPACK,
        IDC_RSCDISPLAYARSENAL_TAB_HEADGEAR, IDC_RSCDISPLAYARSENAL_TAB_GOGGLES,
        IDC_RSCDISPLAYARSENAL_TAB_NVGS, IDC_RSCDISPLAYARSENAL_TAB_BINOCULARS,
        IDC_RSCDISPLAYARSENAL_TAB_MAP, IDC_RSCDISPLAYARSENAL_TAB_GPS,
        IDC_RSCDISPLAYARSENAL_TAB_RADIO, IDC_RSCDISPLAYARSENAL_TAB_COMPASS,
        IDC_RSCDISPLAYARSENAL_TAB_WATCH, IDC_RSCDISPLAYARSENAL_TAB_ITEMOPTIC,
        IDC_RSCDISPLAYARSENAL_TAB_ITEMACC, IDC_RSCDISPLAYARSENAL_TAB_ITEMMUZZLE,
        IDC_RSCDISPLAYARSENAL_TAB_ITEMBIPOD,
        IDC_RSCDISPLAYARSENAL_TAB_CARGOMAG, IDC_RSCDISPLAYARSENAL_TAB_CARGOMAGALL,
        IDC_RSCDISPLAYARSENAL_TAB_CARGOTHROW, IDC_RSCDISPLAYARSENAL_TAB_CARGOPUT,
        IDC_RSCDISPLAYARSENAL_TAB_CARGOMISC
    ];

    // Called every frame, so it must be near-free when nothing changed. A rebuilt list (tab switch, or
    // BIS repopulating a weapon's attachment sublists on selection) comes back BIS-plain; a list this
    // pass already stamped starts its first row with the "[" of our prefix. Skip the stamped ones and
    // only walk the freshly-rebuilt list -- that re-stamp lands within a frame of the rebuild, so the
    // plain state is never on screen long enough to flicker. `_force` (set after a live re-stock or
    // insert appends an unstamped row to an already-stamped list) overrides the skip for one pass.
    private _force = missionNamespace getVariable ["DUWS_arsenal_forcePaint", false];

    {
        private _ctrl = _display displayCtrl (IDC_RSCDISPLAYARSENAL_LIST + _x);
        if (isNull _ctrl || {!(ctrlShown _ctrl)}) then { continue };
        // Walk only the two list shapes the arsenal actually uses: a cargo list is CT_LISTNBOX (102,
        // multi-column, class in column 0), every other tab CT_LISTBOX (5). Skip any other type -- a
        // not-yet-shaped control mid-rebuild, or a non-list control in the id space -- so lnb*/lb* is
        // never called on a control that can't take it, the shape that errored on rapid tab clicks.
        private _t = ctrlType _ctrl;
        if (_t != 5 && {_t != 102}) then { continue };
        private _isN = _t == 102;
        private _rows = if (_isN) then { (lnbSize _ctrl) select 0 } else { lbSize _ctrl };
        // Already stamped and not forced: BIS has not rebuilt this list since our last pass, so leave
        // it. Our prefix always begins with "[", which no config display name does.
        if (!_force && {_rows > 0}) then {
            private _first = if (_isN) then { _ctrl lnbText [0, 1] } else { _ctrl lbText 0 };
            if ((_first select [0, 1]) == "[") then { continue };
        };
        for "_i" from 0 to (_rows - 1) do {
            private _cls = if (_isN) then { _ctrl lnbData [_i, 0] } else { _ctrl lbData _i };
            if (_cls == "") then { continue };
            private _amt = [_cls] call DUWS_fnc_arsenal_countFor;
            if (_amt == 0 && {duws_log_level >= 4}) then { [_cls, _x] call DUWS_fnc_arsenal_logZero; };
            // Prefix is rebuilt onto the config display name, never onto the row's current text, so a
            // repaint cannot stack "[3] [3] name".
            private _pfx = if (_amt < 0) then { "[∞] " } else { format ["[%1] ", _amt] };
            private _cfg = configFile >> "CfgWeapons" >> _cls;
            if (!isClass _cfg) then { _cfg = configFile >> "CfgMagazines" >> _cls; };
            if (!isClass _cfg) then { _cfg = configFile >> "CfgVehicles" >> _cls; };
            private _name = getText (_cfg >> "displayName");
            if (_name == "") then { _name = _cls; };
            if (_isN) then { _ctrl lnbSetText [[_i, 1], _pfx + _name]; }
            else { _ctrl lbSetText [_i, _pfx + _name]; };
        };
    } forEach _tabs;

    if (_force) then { missionNamespace setVariable ["DUWS_arsenal_forcePaint", false]; };
};

// Make a class banked or quick-kitted while the arsenal is open appear without a tab switch. BIS only
// refills a category on (re)entry and its category selector is buttons we cannot reselect, so the row
// is added to the matching category list directly; a later natural rebuild replaces it with BIS's
// sorted row (the class stays in the virtual cargo). Name and picture are read from config exactly as
// BIS builds the row; the count prefix is left to the next paintCounts. A class BIS_fnc_itemType does
// not resolve to a handled tab is skipped -- it still appears on the next tab switch, never an error.
DUWS_fnc_arsenal_insert = {
    params [["_display", displayNull], ["_cls", ""]];
    if (isNull _display || {_cls == ""}) exitWith {};

    ([_cls] call BIS_fnc_itemType) params ["_cat", "_sub"];
    private _off = switch (_sub) do {
        case "Handgun": { IDC_RSCDISPLAYARSENAL_TAB_HANDGUN };
        case "Launcher"; case "MissileLauncher"; case "RocketLauncher": { IDC_RSCDISPLAYARSENAL_TAB_SECONDARYWEAPON };
        case "Uniform": { IDC_RSCDISPLAYARSENAL_TAB_UNIFORM };
        case "Vest": { IDC_RSCDISPLAYARSENAL_TAB_VEST };
        case "Backpack": { IDC_RSCDISPLAYARSENAL_TAB_BACKPACK };
        case "Headgear": { IDC_RSCDISPLAYARSENAL_TAB_HEADGEAR };
        case "Glasses": { IDC_RSCDISPLAYARSENAL_TAB_GOGGLES };
        case "NVGoggles": { IDC_RSCDISPLAYARSENAL_TAB_NVGS };
        case "Binocular": { IDC_RSCDISPLAYARSENAL_TAB_BINOCULARS };
        // Attachments are omitted on purpose: their lists are filtered to the selected weapon, so an
        // inserted attachment could land under a weapon it does not fit. BIS surfaces it on the next
        // compatible-weapon selection instead.
        case "Map": { IDC_RSCDISPLAYARSENAL_TAB_MAP };
        case "GPS": { IDC_RSCDISPLAYARSENAL_TAB_GPS };
        case "Radio": { IDC_RSCDISPLAYARSENAL_TAB_RADIO };
        case "Compass": { IDC_RSCDISPLAYARSENAL_TAB_COMPASS };
        case "Watch": { IDC_RSCDISPLAYARSENAL_TAB_WATCH };
        default {
            switch (_cat) do {
                case "Weapon": { IDC_RSCDISPLAYARSENAL_TAB_PRIMARYWEAPON };
                case "Magazine": { IDC_RSCDISPLAYARSENAL_TAB_CARGOMAGALL };
                default { -1 };
            };
        };
    };
    if (_off < 0) exitWith {
        if (duws_log_level >= 4) then { ["DEBUG", "GEAR", format ["insert %1: unresolved (cat=%2 sub=%3)", _cls, _cat, _sub]] call fnc_log; };
    };

    private _ctrl = _display displayCtrl (IDC_RSCDISPLAYARSENAL_LIST + _off);
    if (isNull _ctrl) exitWith {
        if (duws_log_level >= 4) then { ["DEBUG", "GEAR", format ["insert %1: null list ctrl (off=%2)", _cls, _off]] call fnc_log; };
    };

    private _cfg = configFile >> "CfgWeapons" >> _cls;
    if (!isClass _cfg) then { _cfg = configFile >> "CfgMagazines" >> _cls; };
    if (!isClass _cfg) then { _cfg = configFile >> "CfgVehicles" >> _cls; };
    private _name = getText (_cfg >> "displayName");
    if (_name == "") then { _name = _cls; };
    private _pic = getText (_cfg >> "picture");

    private _has = false;
    if (ctrlType _ctrl == 102) then {
        private _rows = (lnbSize _ctrl) select 0;
        for "_i" from 0 to (_rows - 1) do { if ((_ctrl lnbData [_i, 0]) == _cls) exitWith { _has = true } };
        if (!_has) then {
            private _cols = (lnbSize _ctrl) select 1;
            private _blank = []; for "_c" from 1 to _cols do { _blank pushBack "" };
            private _row = _ctrl lnbAddRow _blank;
            _ctrl lnbSetData [[_row, 0], _cls];
            _ctrl lnbSetText [[_row, 1], _name];
            if (_pic != "") then { _ctrl lnbSetPicture [[_row, 0], _pic]; };
        };
    } else {
        private _rows = lbSize _ctrl;
        for "_i" from 0 to (_rows - 1) do { if ((_ctrl lbData _i) == _cls) exitWith { _has = true } };
        if (!_has) then {
            private _row = _ctrl lbAdd _name;
            _ctrl lbSetData [_row, _cls];
            if (_pic != "") then { _ctrl lbSetPicture [_row, _pic]; };
        };
    };

    if (duws_log_level >= 4) then { ["DEBUG", "GEAR", format ["insert %1 off=%2 shown=%3 %4", _cls, _off, ctrlShown _ctrl, ["added", "already-present"] select _has]] call fnc_log; };
};
