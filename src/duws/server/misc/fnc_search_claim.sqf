// Locality: server -- the draw and every payout resolve here. A roll a client makes is a roll a
// client can retry, and the claim that makes a thing single-use only counts if it is authoritative.
//
// Stage two of a search. Stage one already happened when the entity was created
// (fnc_search_flag_group), so reaching here means the thing holds something; what is left is
// which kind, and whether that kind has anything left to give.
//
// The claim is taken before the payout resolves, not after: the intel branch speaks across a
// sleep, and a claim written on the way out leaves that window open to a second searcher. It is
// broadcast so the action's condition drops it on every machine at once, which is what makes a
// body one search for the whole team rather than one per player.
if (!isServer) exitWith {};

params ["_target", "_caller"];
if (isNull _target || {isNull _caller}) exitWith {};

private _source = _target getVariable ["DUWS_search_src", ""];
if (_source isEqualTo "") exitWith {};
if (_target getVariable ["DUWS_search_done", false]) exitWith {};
_target setVariable ["DUWS_search_done", true, true];

private _config = DUWS_searchSources getOrDefault [_source, []];
if (_config isEqualTo []) exitWith {};

// Every search speaks as the searcher, a frisk included: the player did the searching, so the
// report is theirs whether the pockets belonged to a corpse, a laptop or a detainee.
private _speaker = name _caller;
private _nothingLine = localize (_config param [2, "STR_DUWS_T_INTEL_FOUND_n"]);
// ATL throughout: fnc_search_dropItems places with setPosATL, and a body on a roof drops its
// items through it if the two disagree.
private _origin = getPosATL _target;
private _remaining = +(_config select 1);
private _paid = false;

// What a search found is one player's news, and the searcher is the only one told: a body is
// searched alone and a co-op session where every pocket emptied is announced to everyone reads as
// spam rather than as reporting. Bound to the searcher here so the six outcomes below each pass a
// line and nothing else; fnc_duws_report owns which surfaces a result lands on.
private _fnc_report = {
    params ["_line"];
    [_speaker, _line, _caller] call fnc_duws_report;
};

// The one exception to the rule above, and the reason it is a separate helper rather than a flag on
// it: a revealed position and a topped-up CP pool are shared state that lands on every player's map
// and terminal, so the team is told through a notification even though the search that bought it is
// still reported locally. Money, a document and an empty pocket move nothing anyone else can see
// and stay with the searcher.
private _fnc_notify = {
    params ["_title", "_desc"];
    ["infosearch", [_title, _desc]] remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated];
};

// What the document kind drops on the ground, analysed later at the terminal for CP. Only classes
// with an `Item_` ground variant go here: createVehicle needs one, and an item that lacks one
// vanishes when a player drops it. Wallet_traitor lacks that variant, so it stays out and no
// longer spawns at all.
//
// Weighted, not uniform: cheap 1-CP items dominate and the guaranteed-reveal FilesSecret is rare,
// so a search reveals the map on the order of once or twice per ten document draws rather than
// every third. Weights are parallel to _documents.
private _documents = ["Item_MobilePhone", "Item_Wallet_ID", "Item_SmartPhone",
    "Item_FlashDisk", "Item_Files", "Item_FilesSecret"];
private _documentWeights = [30, 30, 20, 10, 6, 4];

// Hoisted because the main draw and the intel-exhausted fallback both pay it -- the draw a 1-3
// roll, the fallback a flat 2 passed in. `call` shares the caller's scope, so it reads _fnc_report
// and _fnc_notify from here.
//
// CP, never AP: a search is a windfall for the player who made it, not a shift in the war's
// momentum, which is what AP measures and what every WARCOM wave threshold reads.
private _payCp = {
    params [["_amt", -1]];
    private _cp = if (_amt > 0) then { _amt } else { 1 + floor random 3 };
    [_cp, "search_pool"] call fnc_cp_adjust;
    [localize "STR_DUWS_T_INTEL_FOUND_x"] call _fnc_report;
    [localize "STR_DUWS_T_INTEL_BONUS_TITLE",
        format [localize "STR_DUWS_T_INTEL_BONUS_DESC", _cp]] call _fnc_notify;
};

// One item, not a handful: three documents off one body is three searches' worth of CP for a
// single search.
private _payDocument = {
    [[_documents selectRandomWeighted _documentWeights], _origin] call fnc_search_dropItems;
    [localize "STR_DUWS_T_LOOT2"] call _fnc_report;
};

// Drawn without replacement. A kind that reports nothing left to give drops out and the rest are
// re-drawn, so an exhausted intel pool costs the search its best outcome rather than its voice.
while {!_paid && {!(_remaining isEqualTo [])}} do {
    private _kind = [_remaining] call fnc_search_drawKind;
    if (_kind isEqualTo "") exitWith {};

    switch (_kind) do {
        // The only kind that can decline: fnc_intel_payout returns false once every zone, town
        // and hardpoint is already revealed. Silenced either way, so the substitute below is free
        // to answer a decline without the two lines contradicting each other, and a reveal is
        // reported here in the searcher's voice instead of as an Overlord broadcast to the AO.
        case "intel": {
            _paid = [_origin, _caller, true] call fnc_intel_payout;
            if (_paid) then {
                [localize "STR_DUWS_T_INTEL_FOUND_map"] call _fnc_report;
                [localize "STR_DUWS_T_INTEL_MAP_TITLE",
                    localize "STR_DUWS_T_INTEL_MAP_DESC"] call _fnc_notify;
            };
        };

        case "cp": { call _payCp; _paid = true };

        case "money": {
            private _items = [];
            for "_i" from 1 to (1 + floor random 5) do { _items pushBack "Item_Money_roll" };
            [_items, _origin] call fnc_search_dropItems;
            [localize "STR_DUWS_T_LOOT4"] call _fnc_report;
            _paid = true;
        };

        case "document": { call _payDocument; _paid = true };

        // A row, not the absence of one. A search that finds nothing has to say so: four of six
        // faucets could not speak that outcome before, so a dry result read as a broken action.
        case "nothing": {
            [_nothingLine] call _fnc_report;
            _paid = true;
        };
    };

    _remaining = _remaining select { (_x select 0) != _kind };
};

// Intel was the last kind standing and the reveal pool is dry: reached by an intel-only source --
// a mission objective, and any source once every position is found. Pays a flat 2 CP in place of
// the reveal it cannot make, so a dry pool costs the search its best outcome, not its whole worth.
if (!_paid) then {
    [2] call _payCp;
};
