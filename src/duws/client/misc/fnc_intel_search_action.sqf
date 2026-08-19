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

// Clause order is load-bearing: an action on the player is evaluated constantly, because the
// player is never out of range of themselves. Each && takes a code block, so evaluation
// short-circuits, and the cheapest, most-often-false clauses come first -- only a body under the
// cursor and within reach reaches the branch below. Everything is read off cursorObject (the thing
// looked at), not _target (the player).
//
// Two ways a thing is searchable. Flagged branch: an objective body or a placed object (laptop,
// armour) a mission marked, or a surrendered detainee -- single-use, and the type test it carries
// is what lets a laptop and a living-but-surrendered man through where a corpse test could not.
// Combat branch: any enemy corpse, flag-free, gated only by the per-player clock -- this is what
// makes every enemy body searchable without flagging one at spawn. A claimed objective body (done)
// fails the flagged branch and drops to the combat branch, so it becomes an ordinary corpse rather
// than going dead under the cursor. Cooldown read via getVariable with a default: the broadcast
// DUWS_searchCooldown may not have landed when this first evaluates.
private _cond =
    "!isNull cursorObject"
  + " && {cursorObject distance _target < 3}"
  + " && {"
  + "     ("
  + "       (cursorObject getVariable ['DUWS_search_src', '']) != ''"
  + "       && {!(cursorObject getVariable ['DUWS_search_done', false])}"
  + "       && {!(cursorObject isKindOf 'CAManBase') || {!alive cursorObject} || {cursorObject getVariable ['isSurrendered', false]}}"
  + "     )"
  + "     || {"
  + "       cursorObject isKindOf 'CAManBase'"
  + "       && {!alive cursorObject}"
  + "       && {side cursorObject == east}"
  + "       && {time - (_target getVariable ['DUWS_lastSearch', -1e10]) > (missionNamespace getVariable ['DUWS_searchCooldown', 300])}"
  + "     }"
  + "   }";

private _id = [
    player,
    localize "STR_DUWS_T_INTEL_SEARCH_ACTION",
    "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_search_ca.paa",
    "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_search_ca.paa",
    _cond,
    _cond,
    {},
    {},
    // cursorObject is re-read here rather than captured at condition time: the two are a frame
    // apart, and the server re-checks the flag anyway, so a body that moved out from under the
    // cursor is refused there rather than paid for here.
    { [cursorObject, player] remoteExec ["fnc_search_claim", 2]; },
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
