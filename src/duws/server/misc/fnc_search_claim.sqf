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

// "" means the searcher speaks as themselves, which is what a body search is. A source naming a
// speaker key overrides that, so a frisk still reports in the team's voice.
private _speakerKey = _config param [2, ""];
private _speaker = if (_speakerKey isEqualTo "") then { name _caller } else { localize _speakerKey };
private _nothingLine = localize (_config param [3, "STR_DUWS_T_INTEL_FOUND_n"]);
// ATL throughout: fnc_search_dropItems places with setPosATL, and a body on a roof drops its
// items through it if the two disagree.
private _origin = getPosATL _target;
private _remaining = +(_config select 1);
private _paid = false;

// Drawn without replacement. A kind that reports nothing left to give drops out and the rest are
// re-drawn, so an exhausted intel pool costs the search its best outcome rather than its voice.
while {!_paid && {!(_remaining isEqualTo [])}} do {
    private _kind = [_remaining] call fnc_search_drawKind;
    if (_kind isEqualTo "") exitWith {};

    switch (_kind) do {
        // The only kind that can decline: fnc_intel_payout returns false once every zone, town
        // and hardpoint is already revealed. It speaks its own line when it pays.
        case "intel": { _paid = [_origin, _caller] call fnc_intel_payout };

        case "pool": {
            [1, "search_pool"] call fnc_cp_adjust;
            ["BLU", 1, "search_pool"] call fnc_ap_adjust;
            [_speaker, localize "STR_DUWS_T_INTEL_FOUND_x"] remoteExec ["fnc_duws_dialogue", 0];
            ["infosearch", [localize "STR_DUWS_T_INTEL_BONUS_TITLE",
                format [localize "STR_DUWS_T_INTEL_BONUS_DESC", 1, 1]]] remoteExec ["BIS_fnc_showNotification", 0];
            _paid = true;
        };

        case "coins": {
            private _items = [];
            for "_i" from 1 to (1 + floor random 5) do { _items pushBack "Item_Money_roll" };
            [_items, _origin] call fnc_search_dropItems;
            [_speaker, localize "STR_DUWS_T_LOOT4"] remoteExec ["fnc_duws_dialogue", _caller];
            _paid = true;
        };

        // One item, not a handful: three documents off one body is three searches' worth of CP
        // for a single search. Phones share the pool with the files -- both exist only to be
        // turned in at the terminal, which already prices a phone above a file.
        case "document": {
            [[selectRandom ["Item_Files", "Item_Wallet_traitor", "Item_FlashDisk",
                "Item_SmartPhone", "Item_MobilePhone"]], _origin] call fnc_search_dropItems;
            [_speaker, localize "STR_DUWS_T_LOOT2"] remoteExec ["fnc_duws_dialogue", _caller];
            _paid = true;
        };

        // A row, not the absence of one. A search that finds nothing has to say so: four of six
        // faucets could not speak that outcome before, so a dry result read as a broken action.
        case "nothing": {
            [_speaker, _nothingLine] remoteExec ["fnc_duws_dialogue", _caller];
            _paid = true;
        };
    };

    _remaining = _remaining select { (_x select 0) != _kind };
};

// Every kind declined, which today only the intel-only sources can reach. Still speaks.
if (!_paid) then {
    [_speaker, _nothingLine] remoteExec ["fnc_duws_dialogue", _caller];
};
