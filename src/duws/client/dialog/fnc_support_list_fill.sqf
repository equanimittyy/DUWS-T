// Locality: client -- called from the request dialog (client/dialog/fnc_request_menu.sqf) and
// again after every purchase or refund, so it runs on whoever has the menu open.
//
// Two mechanisms, permanent first: a permanent row is bought once for the whole team and stays
// bought, a consumable row belongs to its buyer and refunds at what it charged. Rows come from the
// catalogue (client/supports/fnc_supports_init.sqf) rather than being written out here, because
// the row index used to be a literal agreed between this file and fnc_request_support.sqf --
// adding a row anywhere but the end repointed every row below it at another support's price and
// flag, and the colour pass it fed had already drifted onto the wrong rows once.
//
// Rebuilt wholesale rather than repainted a row at a time: a purchase moves the slot count in the
// consumable heading as well as that row's own colour, and repainting one without the other lets
// the two drift apart again.
//
// Colour carries state, not category: green is owned, orange is a permanent nobody has bought yet,
// grey is withheld by insurgent mode or by the AP tier. Category is carried by the two headings and
// the order under them, so a bought permanent turning green loses nothing.
params [["_keepSel", 1]];

lbClear 2103;

private _defs = [] call fnc_support_defs;
private _insurgent = !isNil "insurgent_mode_enable" && {insurgent_mode_enable};
private _escalated = (missionNamespace getVariable ["escalation_multiplier", 1]) > 1;
private _rows = [];   // listbox index -> its def, [] for a heading

{
    private _kind = _x;
    private _heading = if (_kind == "PERM") then {
        localize "STR_DUWS_T_SUPPORT_HEAD_PERM"
    } else {
        format [localize "STR_DUWS_T_SUPPORT_HEAD_CONS", support_count, support_max_slots]
    };
    private _headRow = lbAdd [2103, _heading];
    lbSetColor [2103, _headRow, [0.5, 0.5, 0.5, 1]];
    _rows pushBack [];

    // Tier-locked rows drop to the bottom of the section, the curated order kept within the open and
    // the locked halves. A support below BLUFOR's earned tier is greyed and tier-tagged rather than
    // dropped, so the player reads what the ladder still owes them.
    private _sectionDefs = _defs select { (_x select 1) == _kind };
    private _openDefs = _sectionDefs select { ["BLU", [_x select 0] call fnc_support_tier] call DUWS_fnc_ap_unlocked };
    private _lockedDefs = _sectionDefs select { !(["BLU", [_x select 0] call fnc_support_tier] call DUWS_fnc_ap_unlocked) };

    {
        _x params ["_key", "_defKind", "_cost", "_flagVar", "_labelKey", "_commItem",
            "_insBlocked", "_modernOnly"];
        private _free = _key == "mobile_HQ" && _insurgent;
        private _label = localize ([_labelKey, "STR_DUWS_T_b7gmddq3_free"] select _free);
        // The price bracket. A dual-cost support carries its whole price built here -- its CP half was
        // lifted out of the English and Original label strings so the AP can join it in one bracket --
        // while a CP-only row keeps the base cost baked in its label and takes only the escalation
        // surcharge appended. Both scale the CP by escalation; the mode's free rows carry a 0 CP label
        // and take neither. Only English and Original were stripped, so the other languages still show
        // their own baked bracket ahead of this one until they are retranslated.
        private _apCost = _x param [8, 0];
        if (_apCost > 0) then {
            private _cp = if (_escalated && !_free) then { [_cost] call fnc_escalation_cost } else { _cost };
            _label = _label + format [" (%1CP, %2AP)", _cp, _apCost];
        } else {
            if (_escalated && !_free) then {
                _label = format [localize "STR_DUWS_T_escalation_row", _label, [_cost] call fnc_escalation_cost];
            };
        };
        // The tier tag, appended after the price. A locked row is greyed below, whatever state colour
        // it would otherwise have carried.
        private _tier = [_key] call fnc_support_tier;
        private _tierLocked = !(["BLU", _tier] call DUWS_fnc_ap_unlocked);
        if (_tierLocked) then {
            _label = _label + " " + format [localize "STR_DUWS_T_tier_tag", [_tier] call DUWS_fnc_tierName];
        };
        private _row = lbAdd [2103, _label];
        private _colour = [1, 1, 1, 1];
        if (_defKind == "PERM") then { _colour = [1, 0.502, 0, 1] };
        if (missionNamespace getVariable [_flagVar, false]) then { _colour = [0, 1, 0, 1] };
        if (_insBlocked && _insurgent) then { _colour = [0.5, 0.5, 0.5, 1] };
        if (_tierLocked) then { _colour = [0.5, 0.5, 0.5, 1] };
        lbSetColor [2103, _row, _colour];
        _rows pushBack _x;
    } forEach (_openDefs + _lockedDefs);
} forEach ["PERM", "CONS"];

uiNamespace setVariable ["DUWS_support_rows", _rows];
lbSetCurSel [2103, _keepSel min ((count _rows) - 1)];
