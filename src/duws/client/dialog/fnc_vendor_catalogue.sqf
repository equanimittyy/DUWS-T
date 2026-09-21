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
private _centre = ((missionNamespace getVariable ["duws_town_circles", []])
    param [_town, [[0,0,0], 0]]) select 0;
if (((missionNamespace getVariable ["DUWS_enemy_town_pos", []]) findIf {
    _x distance2D _centre < 1
}) >= 0) exitWith {
    hint format [localize "STR_DUWS_T_VENDOR_HOSTILE", _vendor getVariable ["DUWS_vendor_townName", ""]];
};

[localize "STR_DUWS_T_civ", localize "STR_DUWS_T_VENDOR_GREET"] call fnc_duws_dialogue;

// The dialog's controls run outside this scope and have no access to the addAction's _target, so the
// vendor is handed over through a global.
DUWS_vendor_target = _vendor;
duws_vendor_rows = [];
// The list the shown rows came from, not the combo's pick: a new pick shows old rows until its fetch
// answers, and those rows must keep their own list's price.
duws_vendor_list = "";
// Read by the painter below, which branches the preview, the second destination and its cap on it.
duws_vendor_kind = [_type] call fnc_vendor_kind;

// Asked of this display, never by bare IDC: a bare command would resolve against whatever display
// happened to be topmost.
duws_vendor_ctrl = {
    params ["_idc"];
    private _display = uiNamespace getVariable ["duws_vendor_display", displayNull];
    if (isNull _display) exitWith { controlNull };
    _display displayCtrl _idc
};

// Price, affordability and the two destinations, repainted from whichever row is selected.
duws_vendor_paint = {
    private _classCtrl = [8907] call duws_vendor_ctrl;
    if (isNull _classCtrl) exitWith {};
    private _class = _classCtrl lbData (lbCurSel _classCtrl);
    private _money = [player] call fnc_money_count;

    if (_class isEqualTo "") exitWith {
        ([8908] call duws_vendor_ctrl) ctrlSetText "#(argb,8,8,3)color(0,0,0,0.5)";
        ([8909] call duws_vendor_ctrl) ctrlSetStructuredText parseText "";
        ([8910] call duws_vendor_ctrl) ctrlSetStructuredText parseText "";
        ([8911] call duws_vendor_ctrl) ctrlSetText format [localize "STR_DUWS_T_VENDOR_MONEY", _money];
        { ([_x] call duws_vendor_ctrl) ctrlEnable false } forEach [8913, 8914];
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

    private _name = getText (_cfg >> "displayName");
    ([8910] call duws_vendor_ctrl) ctrlSetStructuredText parseText format ["<t size='0.8'>%1</t>",
        if (_name isEqualTo "") then {_class} else {format ["%1  --  %2", _name, _class]}];

    private _price = [_class, duws_vendor_list] call fnc_vendor_price;
    ([8911] call duws_vendor_ctrl) ctrlSetText
        format [localize "STR_DUWS_T_VENDOR_PRICE", _price, _money];

    private _afford = _price >= 0 && {_money >= _price};
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

duws_vendor_fill = {
    private _rows = [[8907] call duws_vendor_ctrl, [8905] call duws_vendor_ctrl, duws_vendor_rows]
        call fnc_class_rows_fill;
    // lbSetCurSel raises no LBSelChanged on an empty list, so the panel has to be repainted here.
    if (_rows isEqualTo []) then { [] call duws_vendor_paint };
};

// Spawned: the ask blocks on the server, and LBSelChanged is unscheduled.
duws_vendor_fetch = {
    params ["_list"];
    // Held up while the answer is in flight: the Everything list is a whole-config sweep and takes
    // long enough that an unlabelled empty panel would read as a shop with nothing to sell.
    ([8911] call duws_vendor_ctrl) ctrlSetText (localize "STR_DUWS_T_faction_edit_working");
    [_list] spawn {
        params ["_list"];
        private _rows = [duws_vendor_kind, _list] call fnc_vendor_ask;
        private _stockCtrl = [8903] call duws_vendor_ctrl;
        if (isNull _stockCtrl) exitWith {};
        // A slow answer must not overwrite a newer pick: the player can change list while the first
        // sweep is still running.
        if ((_stockCtrl lbData (lbCurSel _stockCtrl)) != _list) exitWith {};
        duws_vendor_rows = _rows;
        duws_vendor_list = _list;
        [] call duws_vendor_fill;
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
private _gear = duws_vendor_kind isEqualTo "gear";
(_display displayCtrl 8913) ctrlSetTooltip
    (localize (["STR_DUWS_T_VENDOR_TAKE_TT_VEH", "STR_DUWS_T_VENDOR_TAKE_TT"] select _gear));
(_display displayCtrl 8914) ctrlSetText
    (localize (["STR_DUWS_T_VENDOR_STORE_VEH", "STR_DUWS_T_VENDOR_STORE"] select _gear));
(_display displayCtrl 8914) ctrlSetTooltip
    (localize (["STR_DUWS_T_VENDOR_STORE_TT_VEH", "STR_DUWS_T_VENDOR_STORE_TT"] select _gear));

// The faction browser's left-hand combo, repurposed from a faction picker to a stock picker.
private _listLabels = createHashMapFromArray [
    ["civilian", "STR_DUWS_T_VENDOR_STOCK_CIV"],
    ["blufor",   "STR_DUWS_T_VENDOR_STOCK_BLUFOR"],
    ["opfor",    "STR_DUWS_T_VENDOR_STOCK_OPFOR"],
    ["all",      "STR_DUWS_T_VENDOR_STOCK_ALL"]
];
private _stockCtrl = _display displayCtrl 8903;
{
    _stockCtrl lbSetData [_stockCtrl lbAdd (localize (_listLabels get _x)), _x];
} forEach ([_type] call fnc_vendor_lists);

private _fnc_buy = {
    params ["_store"];
    private _classCtrl = [8907] call duws_vendor_ctrl;
    private _class = _classCtrl lbData (lbCurSel _classCtrl);
    if (_class isEqualTo "") exitWith {};
    [DUWS_vendor_target, player, _class, duws_vendor_list, _store] remoteExec ["fnc_vendor_buy", 2];

    // Money leaves on the server, so the count here only moves once the removal replicates back. The
    // panel waits for that rather than repainting a figure the player has already spent.
    [[player] call fnc_money_count] spawn {
        params ["_before"];
        private _deadline = diag_tickTime + 3;
        waitUntil {
            sleep 0.2;
            ([player] call fnc_money_count) != _before || {diag_tickTime > _deadline}
        };
        if !(isNull (uiNamespace getVariable ["duws_vendor_display", displayNull])) then {
            [] call duws_vendor_paint;
        };
    };
};
uiNamespace setVariable ["duws_vendor_buy", _fnc_buy];

// Attached after the stock combo is filled, so the lbSetCurSel below is the first thing to fire them.
(_display displayCtrl 8903) ctrlAddEventHandler ["LBSelChanged", {
    params ["_ctrl", "_idx"];
    [_ctrl lbData _idx] call duws_vendor_fetch;
}];
(_display displayCtrl 8907) ctrlAddEventHandler ["LBSelChanged", { [] call duws_vendor_paint }];
(_display displayCtrl 8905) ctrlAddEventHandler ["KeyUp", { [] call duws_vendor_fill }];
(_display displayCtrl 8913) ctrlAddEventHandler ["ButtonClick", {
    [false] call (uiNamespace getVariable "duws_vendor_buy");
}];
(_display displayCtrl 8914) ctrlAddEventHandler ["ButtonClick", {
    [true] call (uiNamespace getVariable "duws_vendor_buy");
}];

[] call duws_vendor_paint;
_stockCtrl lbSetCurSel 0;
