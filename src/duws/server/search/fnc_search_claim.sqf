// Locality: server -- the draw and every payout resolve here. A roll a client makes is a roll a
// client can retry, and the claim that makes a thing single-use only counts if it is authoritative.
//
// The claim is taken before the payout resolves, not after: the intel branch speaks across a
// sleep, and a claim written on the way out leaves that window open to a second searcher. It is
// broadcast so the action's condition drops it on every machine at once, which is what makes a
// body one search for the whole team rather than one per player.
if (!isServer) exitWith {};

params ["_target", "_caller"];
if (isNull _target || {isNull _caller}) exitWith {};

// Refused here, not only in the prompt: a condition a client evaluates is one a client can be made to skip.
if (_target getVariable ["DUWS_search_done", false]) exitWith {};
_target setVariable ["DUWS_search_done", true, true];

private _source = _target getVariable ["DUWS_search_src", ""];
private _config = DUWS_searchSources getOrDefault [_source, []];
private _count = 1;
if (_source isEqualTo "") then {
    // A dry search takes its step too.
    private _times = (missionNamespace getVariable ["DUWS_searchTimes", []]) select {time - _x < DUWS_searchCooldown};
    (DUWS_searchLadder select ((count _times) min (count DUWS_searchLadder - 1))) params ["_chance", "_weights", "_stepCount"];
    _config = [_chance, _weights];
    _count = _stepCount;
    _times pushBack time;
    missionNamespace setVariable ["DUWS_searchTimes", _times];
};
if (_config isEqualTo []) exitWith {};

private _nothingLine = localize (_config param [2, "STR_DUWS_T_INTEL_FOUND_n"]);

if (random 1 >= (_config select 0)) exitWith { [_nothingLine] remoteExec ["hint", _caller] };

private _remaining = +(_config select 1);
private _paid = false;

// What the document kind hands the searcher, analysed later at the terminal for CP. The item pool,
// its weights and its labels are shared (DUWS_intelDocuments in server_var_init) so a patrol camp's
// table draws the same classes rather than a second copy that drifts.
private _documents = DUWS_intelDocuments;
private _documentWeights = DUWS_intelDocumentWeights;
private _documentLabels = DUWS_intelDocumentLabels;

// One class for all _count copies, so one hint can name the find.
private _payDocument = {
    private _class = _documents selectRandomWeighted _documentWeights;
    private _label = localize (_documentLabels select (_documents find _class));
    private _line = if (_count > 1) then { format [localize "STR_DUWS_T_LOOT2_MANY", _count, _label] } else { format [localize "STR_DUWS_T_LOOT2", _label] };
    // The inventory takes the bare class, but DUWS_intelDocuments lists Item_* ground bodies -- strip it.
    [_class select [5], _count, _line] remoteExec ["fnc_loot_grant", _caller];
};

// Drawn without replacement. A kind that reports nothing left to give drops out and the rest are
// re-drawn, so an exhausted intel pool costs the search its best outcome rather than its voice.
while {!_paid && {!(_remaining isEqualTo [])}} do {
    private _kind = [_remaining] call fnc_search_drawKind;
    if (_kind isEqualTo "") exitWith {};

    switch (_kind) do {
        // The only kind that can decline: fnc_intel_payout returns false once every zone, town
        // and hardpoint is already revealed. Silenced when it declines, so the fallback below is
        // free to answer a decline without contradiction; a successful reveal announces itself.
        case "intel": {
            for "_i" from 1 to _count do {
                if ([getPosATL _target, _caller, true] call fnc_intel_payout) then { _paid = true };
            };
        };

        case "money": {
            private _rolls = _count * (1 + floor random 3);
            ["Money_roll", _rolls, format [localize "STR_DUWS_T_LOOT4", _rolls]] remoteExec ["fnc_loot_grant", _caller];
            _paid = true;
        };

        case "document": { call _payDocument; _paid = true };
    };

    _remaining = _remaining select { (_x select 0) != _kind };
};

// Intel was the last kind standing and the reveal pool is dry: reached by an intel-only source --
// a mission objective, and any source once every position is found. Drops a document in place of
// the reveal it cannot make, so a dry pool costs the search its best outcome, not its whole worth.
if (!_paid) then {
    call _payDocument;
};
