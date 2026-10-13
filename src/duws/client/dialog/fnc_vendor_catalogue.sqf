// Locality: the player who opened it. Draws the shop panel and greys what the server would refuse
// anyway.
//
// Everything greyed here is advisory. The money count is this machine's snapshot, the town's band is
// a broadcast derivative, and the range is read once rather than polled -- fnc_vendor_buy re-tests all
// three when a row is actually bought. Greying spares the player a click that would fail; it decides
// nothing.
//
// Must be spawned: the stock fetch blocks on the server's answer.
if (!hasInterface) exitWith {};

params ["_vendor"];
if (isNull _vendor) exitWith {};

private _town = _vendor getVariable ["DUWS_vendor_town", -1];
private _type = _vendor getVariable ["DUWS_vendor_type", ""];
([_type] call fnc_vendor_type) params ["_nameKey"];

// A shop under a garrison's eye does not sell. civ_town_rep is server-only, so the client reads the
// band off DUWS_enemy_town_pos, which fnc_enemy_towns_refresh rebuilds on every crossing, against the
// town centre duws_town_circles already broadcasts. The refusal is the whole exchange: no catalogue
// is shown behind it. An employer keeps working in a hostile town, which is why that gate is a
// property of the shop rather than of the vendor framework.
private _inTown = _town >= 0;
if (_inTown && {
    private _centre = ((missionNamespace getVariable ["duws_town_circles", []])
        param [_town, [[0,0,0], 0]]) select 0;
    ((missionNamespace getVariable ["DUWS_enemy_town_pos", []]) findIf {
        _x distance2D _centre < 1
    }) >= 0
}) exitWith {
    hint format [localize "STR_DUWS_T_VENDOR_HOSTILE", _vendor getVariable ["DUWS_vendor_townName", ""]];
};

if (_inTown) then { [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_VENDOR_GREET"] call fnc_duws_dialogue };

// The dialog's controls run outside this scope and have no access to the addAction's _target, so the
// vendor is handed over through a global.
DUWS_vendor_target = _vendor;
// [category, name, class, price, picture] per row, sorted so each category's rows are contiguous.
duws_vendor_rows = [];
// The list the shown rows came from, not the combo's pick; "" while a fetch is in flight.
duws_vendor_list = "";
duws_vendor_discount = 0;
// An index into the kind's DUWS_vendorCategories list, or -1 for All.
duws_vendor_cat = -1;
duws_vendor_kind = [_type] call fnc_vendor_kind;

// Asked of this display, never by bare IDC: a bare command would resolve against whatever display
// happened to be topmost.
duws_vendor_ctrl = {
    params ["_idc"];
    private _display = uiNamespace getVariable ["duws_vendor_display", displayNull];
    if (isNull _display) exitWith { controlNull };
    _display displayCtrl _idc
};

duws_vendor_paint = {
    private _listCtrl = [8907] call duws_vendor_ctrl;
    if (isNull _listCtrl) exitWith {};
    private _sel = lbCurSel _listCtrl;
    private _class = _listCtrl lbData _sel;
    private _money = [player] call fnc_money_funds;

    ([8911] call duws_vendor_ctrl) ctrlSetText str _money;
    private _discountCtrl = [8916] call duws_vendor_ctrl;
    _discountCtrl ctrlSetText format ["%1%2", duws_vendor_discount, "%"];
    _discountCtrl ctrlSetTextColor ([[1, 1, 1, 1], [0.2, 0.5, 1, 1]] select (duws_vendor_discount > 0));

    if (_class isEqualTo "") exitWith {
        ([8908] call duws_vendor_ctrl) ctrlSetText "#(argb,8,8,3)color(0,0,0,0.5)";
        ([8909] call duws_vendor_ctrl) ctrlSetStructuredText parseText "";
        ([8910] call duws_vendor_ctrl) ctrlSetStructuredText parseText "";
        ([8915] call duws_vendor_ctrl) ctrlSetText "--";
        {
            private _button = [_x] call duws_vendor_ctrl;
            _button ctrlEnable false;
            if (duws_vendor_kind isEqualTo "gear") then { _button ctrlSetTooltip "" };
        } forEach [8913, 8914];
    };

    private _cfg = [_class] call fnc_vendor_classCfg;
    // A vehicle carries an editorPreview render; gear lives in CfgWeapons and CfgMagazines and carries
    // only its inventory icon. One order covers both, so the panel needs no branch on what is sold.
    private _pic = getText (_cfg >> "editorPreview");
    if (_pic isEqualTo "") then { _pic = getText (_cfg >> "picture") };
    if (_pic isEqualTo "") then { _pic = getText (_cfg >> "ItemInfo" >> "picture") };
    ([8908] call duws_vendor_ctrl) ctrlSetText
        (if (_pic isEqualTo "") then {"#(argb,8,8,3)color(0,0,0,0.5)"} else {_pic});
    ([8909] call duws_vendor_ctrl) ctrlSetStructuredText parseText (if (_pic isEqualTo "") then {
        format ["<t align='center' size='1.4' font='PuristaMedium' color='#ff5555'>%1</t>",
            localize "STR_DUWS_T_faction_edit_nopreview"]
    } else {""});

    private _name = _listCtrl lbText _sel;
    if (duws_vendor_kind isEqualTo "gear") then {
        private _pack = [_class] call fnc_vendor_packSize;
        _name = format ["%1 x %2", _pack, _name];
        ([8913] call duws_vendor_ctrl) ctrlSetTooltip format [localize "STR_DUWS_T_VENDOR_TAKE_TT", _pack];
        ([8914] call duws_vendor_ctrl) ctrlSetTooltip format [localize "STR_DUWS_T_VENDOR_STORE_TT", _pack];
    };
    ([8910] call duws_vendor_ctrl) ctrlSetStructuredText parseText format [
        "<t align='left' size='1.3'>%1</t><br/><t align='left' color='#a0a0a0'>%2</t><br/><br/><t align='left'>%3</t>",
        _name, _class, getText (_cfg >> "descriptionShort")];

    private _price = _listCtrl lbValue _sel;
    ([8915] call duws_vendor_ctrl) ctrlSetText str _price;

    private _afford = _money >= _price;
    ([8913] call duws_vendor_ctrl) ctrlEnable _afford;
    // The second destination is offered only where it would actually take the thing: the arsenal
    // counts a class only in Limited mode or when it is foreign, and each of the three garage pools
    // has its own cap, so a full land pool must not grey out a boat.
    private _canStore = if (duws_vendor_kind isEqualTo "gear") then {
        [_class] call fnc_vendor_poolCounts
    } else {
        private _di = [[_class] call DUWS_fnc_vehDomain] call DUWS_fnc_garageDomainIndex;
        (([] call DUWS_fnc_garageUsed) select _di) < (([] call DUWS_fnc_garageCaps) select _di)
    };
    ([8914] call duws_vendor_ctrl) ctrlEnable (_afford && _canStore);
};

// Callers run it unscheduled: a scheduled rebuild can be suspended straight after lbClear and draw a
// half-built list.
duws_vendor_fill = {
    private _listCtrl = [8907] call duws_vendor_ctrl;
    if (isNull _listCtrl) exitWith {};
    private _keep = _listCtrl lbData (lbCurSel _listCtrl);
    lbClear _listCtrl;
    if (duws_vendor_list isEqualTo "") exitWith {
        _listCtrl lbAdd (localize "STR_DUWS_T_faction_edit_working");
        [] call duws_vendor_paint;
    };

    private _filter = toLower (ctrlText ([8905] call duws_vendor_ctrl));
    private _money = [player] call fnc_money_funds;
    private _labels = DUWS_vendorCategories get duws_vendor_kind;
    private _heading = -1;
    private _first = -1;
    private _sel = -1;
    {
        _x params ["_cat", "_name", "_class", "_price", "_pic"];
        // Case-insensitive substring over both the display name and the classname, so a filter
        // matches either what the player reads or the raw class they already know.
        if ((duws_vendor_cat < 0 || {_cat == duws_vendor_cat}) && {_filter isEqualTo ""
            || {(toLower _name) find _filter >= 0} || {(toLower _class) find _filter >= 0}}) then {
            // Headings only in the All view: a single category is already named on its picker.
            if (duws_vendor_cat < 0 && {_cat != _heading}) then {
                _heading = _cat;
                private _h = _listCtrl lbAdd format ["--- %1 ---", toUpper (localize (_labels select _cat))];
                _listCtrl lbSetColor [_h, [0.5, 0.5, 0.5, 1]];
            };
            private _i = _listCtrl lbAdd _name;
            _listCtrl lbSetData [_i, _class];
            _listCtrl lbSetValue [_i, _price];
            _listCtrl lbSetPicture [_i, _pic];
            _listCtrl lbSetTextRight [_i, str _price];
            if (_price > _money) then {
                _listCtrl lbSetColor [_i, [0.5, 0.5, 0.5, 1]];
                _listCtrl lbSetColorRight [_i, [0.5, 0.5, 0.5, 1]];
            };
            if (_first < 0) then { _first = _i };
            if (_class isEqualTo _keep) then { _sel = _i };
        };
    } forEach duws_vendor_rows;

    // lbSetCurSel raises no LBSelChanged on an empty list, so the panel has to be repainted here.
    if (_first < 0) exitWith { [] call duws_vendor_paint };
    _listCtrl lbSetCurSel ([_sel, _first] select (_sel < 0));
};

duws_vendor_fetch = {
    params ["_list"];
    duws_vendor_list = "";
    duws_vendor_rows = [];
    [] call duws_vendor_fill;
    // Spawned: the ask blocks on the server, and LBSelChanged is unscheduled.
    [_list] spawn {
        params ["_list"];
        ([duws_vendor_kind, _list, DUWS_vendor_target] call fnc_vendor_ask) params ["_rows", "_discount"];
        // Priced once per list rather than per redraw: the Everything list runs to thousands of rows,
        // and the filter redraws on every keystroke.
        private _shown = _rows apply {
            _x params ["_name", "_class", "_cat"];
            [_cat, _name, _class, [_class, _list, _discount] call fnc_vendor_price,
                getText (([_class] call fnc_vendor_classCfg) >> "picture")]
        };
        _shown sort true;
        private _present = [];
        { _present pushBackUnique (_x select 0) } forEach _shown;

        isNil {
            private _stockCtrl = [8903] call duws_vendor_ctrl;
            // A slow answer must not overwrite a newer pick: the player can change list while the
            // first sweep is still running.
            if (isNull _stockCtrl || {(_stockCtrl lbData (lbCurSel _stockCtrl)) != _list}) exitWith {};
            duws_vendor_rows = _shown;
            duws_vendor_list = _list;
            duws_vendor_discount = _discount;

            // Only the categories this list stocks, so no pick comes up empty. Its LBSelChanged does
            // the fill.
            private _catCtrl = [8906] call duws_vendor_ctrl;
            lbClear _catCtrl;
            _catCtrl lbSetValue [_catCtrl lbAdd (localize "STR_DUWS_T_VENDOR_CAT_ALL"), -1];
            private _pick = 0;
            {
                if (_forEachIndex in _present) then {
                    private _i = _catCtrl lbAdd (localize _x);
                    _catCtrl lbSetValue [_i, _forEachIndex];
                    if (_forEachIndex == duws_vendor_cat) then { _pick = _i };
                };
            } forEach (DUWS_vendorCategories get duws_vendor_kind);
            _catCtrl lbSetCurSel _pick;
        };
    };
};

if (!createDialog "vendor_catalogue") exitWith {};
waitUntil { dialog };

private _display = uiNamespace getVariable ["duws_vendor_display", displayNull];
if (isNull _display) exitWith {
    ["ERROR", "VENDOR", "catalogue opened but stashed no display"] call fnc_log;
    closeDialog 0;
};

(_display displayCtrl 8901) ctrlSetText (localize _nameKey);

// The two destinations are the same choice at every shop, but not the same words: gear goes to the
// arsenal or into a holder at the buyer's feet, a vehicle to the base garage or the street outside.
// Gear tooltips name the pack size, so duws_vendor_paint sets them per row.
private _gear = duws_vendor_kind isEqualTo "gear";
(_display displayCtrl 8914) ctrlSetText
    (localize (["STR_DUWS_T_VENDOR_STORE_VEH", "STR_DUWS_T_VENDOR_STORE"] select _gear));
if (!_gear) then {
    (_display displayCtrl 8913) ctrlSetTooltip localize "STR_DUWS_T_VENDOR_TAKE_TT_VEH";
    (_display displayCtrl 8914) ctrlSetTooltip localize "STR_DUWS_T_VENDOR_STORE_TT_VEH";
};

private _listLabels = createHashMapFromArray [
    ["civilian", "STR_DUWS_T_VENDOR_STOCK_CIV"],
    ["blufor",   "STR_DUWS_T_VENDOR_STOCK_BLUFOR"],
    ["opfor",    "STR_DUWS_T_VENDOR_STOCK_OPFOR"],
    ["all",      "STR_DUWS_T_VENDOR_STOCK_ALL"],
    ["hq",       "STR_DUWS_T_VENDOR_STOCK_BLUFOR"]
];
private _stockCtrl = _display displayCtrl 8903;
{
    _stockCtrl lbSetData [_stockCtrl lbAdd (localize (_listLabels get _x)), _x];
} forEach ([_type] call fnc_vendor_lists);

private _fnc_buy = {
    params ["_store"];
    private _listCtrl = [8907] call duws_vendor_ctrl;
    private _class = _listCtrl lbData (lbCurSel _listCtrl);
    if (_class isEqualTo "") exitWith {};
    [DUWS_vendor_target, player, _class, duws_vendor_list, _store] remoteExec ["fnc_vendor_buy", 2];

    // Money leaves on the server, so the count here only moves once the removal replicates back. The
    // panel waits for that rather than repainting a figure the player has already spent.
    [[player] call fnc_money_funds] spawn {
        params ["_before"];
        private _deadline = diag_tickTime + 3;
        waitUntil {
            sleep 0.2;
            ([player] call fnc_money_funds) != _before || {diag_tickTime > _deadline}
        };
        if !(isNull (uiNamespace getVariable ["duws_vendor_display", displayNull])) then {
            // Refilled, not just repainted: rows the purchase put out of reach turn grey.
            isNil { [] call duws_vendor_fill };
        };
    };
};
uiNamespace setVariable ["duws_vendor_buy", _fnc_buy];

// Attached after the stock combo is filled, so the lbSetCurSel below is the first thing to fire them.
(_display displayCtrl 8903) ctrlAddEventHandler ["LBSelChanged", {
    params ["_ctrl", "_idx"];
    [_ctrl lbData _idx] call duws_vendor_fetch;
}];
(_display displayCtrl 8906) ctrlAddEventHandler ["LBSelChanged", {
    params ["_ctrl", "_idx"];
    duws_vendor_cat = _ctrl lbValue _idx;
    [] call duws_vendor_fill;
}];
(_display displayCtrl 8907) ctrlAddEventHandler ["LBSelChanged", { [] call duws_vendor_paint }];
(_display displayCtrl 8905) ctrlAddEventHandler ["KeyUp", { [] call duws_vendor_fill }];
(_display displayCtrl 8913) ctrlAddEventHandler ["ButtonClick", {
    [false] call (uiNamespace getVariable "duws_vendor_buy");
}];
(_display displayCtrl 8914) ctrlAddEventHandler ["ButtonClick", {
    [true] call (uiNamespace getVariable "duws_vendor_buy");
}];

_stockCtrl lbSetCurSel 0;
