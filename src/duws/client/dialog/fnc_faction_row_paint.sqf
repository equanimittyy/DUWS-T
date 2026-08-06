// Locality: client -- inherited from client/dialog/fnc_faction_confirm.sqf.
// Repaints one row of the confirmation screen from the working table. Called when the row is built
// and again whenever the key editor or the clear prompt changes it.
//
// The label carries "ROLE: classname" as one string rather than two controls, which is what makes
// the common case fit: the blufor_/opfor_ prefix and the _X suffix are dropped -- the column
// heading already says which side and the suffix carries nothing -- and 27 characters of the rest
// survive. Longer combinations cut off; the tooltip holds the untruncated form.
//
// A value may be an array: AutoDetect fills a role with every class it found for it, and
// fnc_faction_pick draws one per spawn. The row shows the representative that fnc_faction_pools_publish
// would take, with the rest of the pool counted after it, so an untouched key does not read as
// though it held a single class.

params ["_key"];

private _ctrls = uiNamespace getVariable ["duws_faction_row_ctrls", createHashMap];
private _label = _ctrls get _key;
if (isNil "_label") exitWith {};

private _value = "";
{
    private _found = (_x select 1) select { (_x select 0) isEqualTo _key };
    if !(_found isEqualTo []) exitWith { _value = (_found select 0) select 1; };
} forEach duws_faction_table;

private _pool = if (_value isEqualType []) then {_value} else {[_value]};
_pool = _pool select { _x isEqualType "" && {_x != ""} };

private _short = _key regexReplace ["^(blufor|opfor)_", ""];
_short = _short regexReplace ["_X$", ""];

private _clear = _ctrls get (_key + "_clear");

if (_pool isEqualTo []) exitWith {
    _label ctrlSetText format ["%1: %2", _short, localize "STR_DUWS_T_faction_confirm_missing"];
    _label ctrlSetTextColor [1, 0.35, 0.35, 1];
    _label ctrlSetTooltip format ["%1 = %2", _key, localize "STR_DUWS_T_faction_confirm_missing"];
    _label ctrlCommit 0;
    if (!isNil "_clear") then { _clear ctrlEnable false; };
};

private _class = _pool select 0;
private _extra = count _pool - 1;
private _display = getText (configFile >> "CfgVehicles" >> _class >> "displayName");

// 0 white: the faction's own first choice. 1 yellow: a lower rung or a borrow it still fields.
// 2 red: a vanilla stand-in, the same worst-case colour a missing role gets. An edit sets the key
// to 0 (see fnc_faction_key_apply), so a class the player picked stops reading as a fallback.
private _tiers = missionNamespace getVariable ["duws_faction_tiers", createHashMap];
private _tier = _tiers getOrDefault [_key, 0];

_label ctrlSetText format ["%1: %2%3", _short, _class,
    if (_extra > 0) then { format [" (+%1)", _extra] } else { "" }];
_label ctrlSetTextColor (switch (_tier) do {
    case 1: { [1, 0.82, 0.2, 1] };
    case 2: { [1, 0.35, 0.35, 1] };
    default { [1, 1, 1, 1] };
});
_label ctrlSetTooltip format ["%1 = %2%3%4%5",
    _key, _class,
    if (_display isEqualTo "") then {""} else {format ["  (%1)", _display]},
    if (_extra > 0) then { format ["  [%1 in pool]", count _pool] } else { "" },
    switch (_tier) do {
        case 1: { format ["  -- %1", localize "STR_DUWS_T_faction_confirm_tier_yellow"] };
        case 2: { format ["  -- %1", localize "STR_DUWS_T_faction_confirm_tier_red"] };
        default { "" };
    }];
_label ctrlCommit 0;
if (!isNil "_clear") then { _clear ctrlEnable true; };
