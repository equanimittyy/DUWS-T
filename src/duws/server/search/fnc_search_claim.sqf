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

// Every body is single-use. A flagged body -- an objective corpse, a placed laptop/armour, a
// frisked civilian -- pays its own table; any other corpse is an ordinary combat search, gated by
// the session-wide budget and rolled here (combat is not rolled at spawn). Both stamp
// DUWS_search_done when searched, and a searched body is refused here -- the authoritative point,
// since a condition a client evaluates is a condition a client can be made to skip.
if (_target getVariable ["DUWS_search_done", false]) exitWith {};

private _source = _target getVariable ["DUWS_search_src", ""];
private _flagged = _source != "";
if (!_flagged) then { _source = "combat" };

// Budget gated here at the top level, not nested in the else below. exitWith unwinds past a
// then/else to the whole function (see arma_engine_gotchas), so a guard nested in the else would
// read as skipping only the stamp while in fact abandoning the payout -- gating here keeps it plain.
if (!_flagged && {count ((missionNamespace getVariable ["DUWS_searchTimes", []]) select {time - _x < DUWS_searchCooldown}) >= DUWS_searchAllowance}) exitWith {};

// Stamped before the payout resolves so a second searcher through the claim race finds it done.
_target setVariable ["DUWS_search_done", true, true];
if (!_flagged) then {
    // Combat spends a budget slot too -- a dry search is still a search. Pruned on write to stay
    // bounded to the window; one shared session budget in missionNamespace, broadcast.
    private _times = (missionNamespace getVariable ["DUWS_searchTimes", []]) select {time - _x < DUWS_searchCooldown};
    _times pushBack time;
    missionNamespace setVariable ["DUWS_searchTimes", _times, true];
};

private _config = DUWS_searchSources getOrDefault [_source, []];
if (_config isEqualTo []) exitWith {};

private _nothingLine = localize (_config param [2, "STR_DUWS_T_INTEL_FOUND_n"]);

// The success roll, spent here rather than at spawn now that combat flags nothing: whether this
// body held anything is decided at the search. Objective and civ_frisk carry chance 1 and never
// miss, so this only ever thins the combat source.
if (random 1 >= (_config select 0)) exitWith { [_nothingLine] remoteExec ["hint", _caller] };

private _remaining = +(_config select 1);
private _paid = false;

// What a search found is one player's news, shown in the searcher's hint box alone: a body is
// searched alone, and a co-op session where every emptied pocket is announced to everyone reads as
// spam. No subtitle -- a search is the player rifling a corpse, not a character speaking a line.
private _fnc_hint = {
    params ["_line"];
    [_line] remoteExec ["hint", _caller];
};

// The one outcome the whole team is told about: a revealed position lands on every player's map, so
// the reveal is broadcast as a notification card. CP, money, a document and an empty pocket move
// nothing anyone else can see and stay in the searcher's hint box.
private _fnc_notify = {
    params ["_title", "_desc"];
    ["infosearch", [_title, _desc]] remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated];
};

// What the document kind hands the searcher, analysed later at the terminal for CP. The item pool,
// its weights and its labels are shared (DUWS_intelDocuments in server_var_init) so a patrol camp's
// table draws the same classes rather than a second copy that drifts.
private _documents = DUWS_intelDocuments;
private _documentWeights = DUWS_intelDocumentWeights;
private _documentLabels = DUWS_intelDocumentLabels;

// One item, not a handful: three documents off one body is three searches' worth of CP for a
// single search. The hint names which one, so the player knows its worth before the terminal.
private _payDocument = {
    private _class = _documents selectRandomWeighted _documentWeights;
    private _label = localize (_documentLabels select (_documents find _class));
    // The inventory takes the bare class, but DUWS_intelDocuments lists Item_* ground bodies -- strip it.
    [_class select [5], 1, format [localize "STR_DUWS_T_LOOT2", _label]] remoteExec ["fnc_search_grant", _caller];
};

// Drawn without replacement. A kind that reports nothing left to give drops out and the rest are
// re-drawn, so an exhausted intel pool costs the search its best outcome rather than its voice.
while {!_paid && {!(_remaining isEqualTo [])}} do {
    private _kind = [_remaining] call fnc_search_drawKind;
    if (_kind isEqualTo "") exitWith {};

    switch (_kind) do {
        // The only kind that can decline: fnc_intel_payout returns false once every zone, town
        // and hardpoint is already revealed. Silenced when it declines, so the fallback below is
        // free to answer a decline without contradiction; a successful reveal is the one search
        // outcome the whole team sees, broadcast as a notification card.
        case "intel": {
            _paid = [getPosATL _target, _caller, true] call fnc_intel_payout;
            if (_paid) then {
                [localize "STR_DUWS_T_INTEL_MAP_TITLE",
                    localize "STR_DUWS_T_INTEL_MAP_DESC"] call _fnc_notify;
            };
        };

        case "money": {
            private _count = 1 + floor random 3;
            ["Money_roll", _count, format [localize "STR_DUWS_T_LOOT4", _count]] remoteExec ["fnc_search_grant", _caller];
            _paid = true;
        };

        case "document": { call _payDocument; _paid = true };

        // A row, not the absence of one. A search that finds nothing has to say so: four of six
        // faucets could not speak that outcome before, so a dry result read as a broken action.
        case "nothing": {
            [_nothingLine] call _fnc_hint;
            _paid = true;
        };
    };

    _remaining = _remaining select { (_x select 0) != _kind };
};

// Intel was the last kind standing and the reveal pool is dry: reached by an intel-only source --
// a mission objective, and any source once every position is found. Drops a document in place of
// the reveal it cannot make, so a dry pool costs the search its best outcome, not its whole worth.
if (!_paid) then {
    call _payDocument;
};
