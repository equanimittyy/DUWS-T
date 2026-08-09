// Locality: client -- paints the open arsenal, so it runs on whoever opened it. Compiled once by
// client/client_init.sqf, then called every tick of the arsenal enforcer loop in initPlayerLocal.sqf.
//
// The stock virtual arsenal has no quantity concept: BIS_fnc_addVirtualWeaponCargo marks a class
// present, unlimited, full stop. The real per-class stock lives in DUWS_capturedPool; this overlays it
// onto the list rows the same way Antistasi's arsenal does -- a cosmetic count / infinity prefix
// repainted on every list redraw, backed by the authoritative pool. The arsenal underneath stays a
// dumb present/absent set.
//
// The number shown is the pool stock as broadcast, i.e. what was in stock when the arsenal opened. It
// does not tick down live as the player pulls items this session -- the pool is only settled on close
// (fnc_captured_pool_settle), which is where overdraw is stripped.
//
// The IDC macros (IDC_RSCDISPLAYARSENAL_LIST base + IDC_RSCDISPLAYARSENAL_TAB_* offsets) come from
// BIS's own header, so the control ids track the engine version instead of being hardcoded numbers.
#include "\A3\Ui_f\hpp\defineResinclDesign.inc"

// Available count for a class as the shelf actually enforces it: -1 means unlimited (rendered as the
// infinity glyph).
// Order matters -- each earlier rule is a hard override of the ones below it.
DUWS_fnc_arsenal_countFor = {
    params ["_cls"];
    // Full mode leaves the whole arsenal unlimited; the enforcer marks it non-restricted.
    if (!(player getVariable ["DUWS_isRestrictedArsenal", false])) exitWith { -1 };
    // Ammo untracked (the default): magazines are free in every mode, so never counted.
    if ((isClass (configFile >> "CfgMagazines" >> _cls)) && {!(missionNamespace getVariable ["DUWS_trackAmmo", false])}) exitWith { -1 };
    // Hybrid keeps standard-issue gear unlimited; Limited tracks it too, so only Hybrid short-circuits.
    if ((_cls in (missionNamespace getVariable ["DUWS_friendlyArsenal", []])) && {!(missionNamespace getVariable ["DUWS_arsenalLimited", false])}) exitWith { -1 };
    // Count-tracked: the pool is [[class, n], ...] with zero-count classes dropped, so absence is zero.
    private _pool = missionNamespace getVariable ["DUWS_capturedPool", []];
    private _i = _pool findIf { (_x select 0) isEqualTo _cls };
    if (_i < 0) then { 0 } else { (_pool select _i) select 1 }
};

// Repaint every populated, visible item list under the arsenal display. Only shown lists are walked:
// the arsenal shows just the active tab's list (plus the attachment/cargo lists when a weapon is
// selected), so this bounds the work regardless of how large the config is in Full mode.
DUWS_fnc_arsenal_paintCounts = {
    params [["_display", displayNull]];
    if (isNull _display) exitWith {};

    // Every browsable category list, left panel then right. Each control id is the shared list base
    // plus the category's tab offset.
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
        IDC_RSCDISPLAYARSENAL_TAB_ITEMBIPOD, IDC_RSCDISPLAYARSENAL_TAB_CARGOMAGALL,
        IDC_RSCDISPLAYARSENAL_TAB_CARGOTHROW, IDC_RSCDISPLAYARSENAL_TAB_CARGOPUT,
        IDC_RSCDISPLAYARSENAL_TAB_CARGOMISC
    ];

    {
        private _ctrl = _display displayCtrl (IDC_RSCDISPLAYARSENAL_LIST + _x);
        if (isNull _ctrl || {!(ctrlShown _ctrl)}) then { continue };
        // Cargo lists can be CT_LISTNBOX (multi-column); the rest are CT_LISTBOX. Class is column 0,
        // the visible name column 1, matching the arsenal's own row layout.
        private _isN = (ctrlType _ctrl) == 102;
        private _rows = if (_isN) then { (lnbSize _ctrl) select 0 } else { lbSize _ctrl };
        for "_i" from 0 to (_rows - 1) do {
            private _cls = if (_isN) then { _ctrl lnbData [_i, 0] } else { _ctrl lbData _i };
            if (_cls == "") then { continue };
            private _amt = [_cls] call DUWS_fnc_arsenal_countFor;
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
};
