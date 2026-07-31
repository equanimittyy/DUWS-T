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
// spam rather than as reporting. Hinted as well as spoken because the dialogue queue can hold a
// line behind other traffic, and a result the player held an action for should not scroll past.
private _fnc_report = {
    params ["_line"];
    [_speaker, _line] remoteExec ["fnc_duws_dialogue", _caller];
    [_line] remoteExec ["hint", _caller];
};

// What a document draw hands over, named once because the intel substitute at the bottom draws
// from it too. Every member clears the 1-3 CP the pool pays on the spot, which is what makes the
// trip back to the terminal worth taking. `Item_Files` is deliberately absent: the file is also
// what fnc_addRandomLoot puts on 80 % of enemies, so pricing it for a search prices every corpse
// in the campaign.
private _documents = ["Item_Wallet_traitor", "Item_FlashDisk", "Item_SmartPhone",
    "Item_MobilePhone"];

// The two kinds the substitute draw can also pay, hoisted so it does not need a second copy of
// either. `call` shares the caller's scope, so both read _documents, _origin, _caller and
// _fnc_report from here.
//
// CP only, and rolled: a search is a windfall for the player who made it, not a shift in the
// war's momentum, which is what AP measures and what every WARCOM wave threshold reads.
private _payPool = {
    private _cp = 1 + floor random 3;
    [_cp, "search_pool"] call fnc_cp_adjust;
    [localize "STR_DUWS_T_INTEL_FOUND_x"] call _fnc_report;
    ["infosearch", [localize "STR_DUWS_T_INTEL_BONUS_TITLE",
        format [localize "STR_DUWS_T_INTEL_BONUS_DESC", _cp]]] remoteExec ["BIS_fnc_showNotification", _caller];
};

// One item, not a handful: three documents off one body is three searches' worth of CP for a
// single search.
private _payDocument = {
    [[selectRandom _documents], _origin] call fnc_search_dropItems;
    [localize "STR_DUWS_T_LOOT2"] call _fnc_report;
};

// Drawn without replacement. A kind that reports nothing left to give drops out and the rest are
// re-drawn, so an exhausted intel pool costs the search its best outcome rather than its voice.
while {!_paid && {!(_remaining isEqualTo [])}} do {
    private _kind = [_remaining] call fnc_search_drawKind;
    if (_kind isEqualTo "") exitWith {};

    switch (_kind) do {
        // The only kind that can decline: fnc_intel_payout returns false once every zone, town
        // and hardpoint is already revealed. It speaks its own line when it pays. Silenced on the
        // dry path because the substitute below answers that case itself, and the two lines would
        // contradict each other.
        case "intel": { _paid = [_origin, _caller, false] call fnc_intel_payout };

        case "pool": { call _payPool; _paid = true };

        case "coins": {
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

// Every kind declined, so intel was the last one standing and there was nothing hidden left for it
// to reveal. One branch for both modes, because they differ only in what is hidden: hardcore
// reaches this once the map has been found, normal mode reaches it on every search of an
// intel-only source, and the search itself behaves the same either way.
//
// Half of these still come up empty. Paying every time would make a source that can only draw
// intel strictly better than one that can draw anything, since a body can roll `nothing` too --
// the substitute replaces what intel was worth, it does not add a floor the other kinds lack.
if (!_paid) then {
    switch ([[["document", 1], ["pool", 1], ["nothing", 2]]] call fnc_search_drawKind) do {
        case "document": { call _payDocument };
        case "pool": { call _payPool };
        default { [_nothingLine] call _fnc_report };
    };
};
