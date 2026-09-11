// Locality: client. Added at client_init and re-added by onPlayerRespawn, because the action
// dies with the body.
//
// One action on the player looking outward at whatever is under the cursor, rather than one
// action per corpse. The per-corpse shape needed a remoteExec with the JIP flag set per death,
// so the queue grew with the campaign's kill count instead of with its player count.
//
// The id is kept so onPlayerKilled can strip the action off the body being left behind. It does not
// die with its owner: the engine evaluates the conditions of actions on any object near a player,
// so without that removal every corpse the player leaves goes on polling this one for the rest of
// the campaign.
if (!hasInterface) exitWith {};

// The gate -- what is searchable, within reach, in view, and inside budget -- lives in
// fnc_search_pick, so the show condition and the exec resolve the same target. The condition runs
// constantly (an action on the player is never out of range of itself), so the pick keeps its work
// small: a cursor test first, and a nearestObjects scan only when an ordinary corpse is the target.
private _cond = "!isNull ([_target] call fnc_search_pick)";

private _id = [
    player,
    localize "STR_DUWS_T_INTEL_SEARCH_ACTION",
    "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_search_ca.paa",
    "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_search_ca.paa",
    _cond,
    _cond,
    {},
    {},
    // Re-picked here rather than captured at condition time: the two are a frame apart, and the
    // server re-checks anyway, so a target that moved out of reach is refused there, not paid here.
    { private _tgt = [player] call fnc_search_pick; if (!isNull _tgt) then { [_tgt, player] remoteExec ["fnc_search_claim", 2]; }; },
    {},
    [],
    6,
    30,
    // Not removed on completion: the claim broadcast by the server is what drops it, on every
    // machine at once. Removing it here would hide it on the searcher's screen only.
    false,
    false
] call BIS_fnc_holdActionAdd;

player setVariable ["DUWS_intel_search_actionId", _id];
