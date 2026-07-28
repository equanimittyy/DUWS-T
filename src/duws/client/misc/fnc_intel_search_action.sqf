// Locality: client. Added at client_init and re-added by onPlayerRespawn, because the action
// dies with the body.
//
// One action on the player looking outward at whatever is under the cursor, rather than one
// action per corpse. The per-corpse shape needs a remoteExec with the JIP flag set per death
// (fnc_add_intel_on_death), and nothing ever removes those entries, so the JIP queue would grow
// with the campaign's kill count instead of with its player count.
if (!hasInterface) exitWith {};

// Clause order is load-bearing: an action on the player is evaluated constantly, because the
// player is never out of range of themselves. Each && takes a code block, so evaluation
// short-circuits, and the cheapest and most-often-false clauses come first -- only a body
// actually under the cursor and within reach reaches the config lookup in isKindOf.
//
// Written against _target, the only handle both condShow and condProgress share:
// BIS_fnc_holdActionAdd names the caller _this in one and _caller in the other.
private _cond =
    "!isNil 'hardcore_mode_enable' && {hardcore_mode_enable}"
  + " && {!(_target getVariable ['DUWS_intel_searched', false])}"
  + " && {!isNull cursorObject}"
  + " && {cursorObject distance _target < 3}"
  + " && {cursorObject isKindOf 'CAManBase'}"
  + " && {!alive cursorObject}"
  + " && {side group cursorObject == east}";

[
    player,
    localize "STR_DUWS_T_INTEL_SEARCH_ACTION",
    "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_search_ca.paa",
    "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_search_ca.paa",
    _cond,
    _cond,
    {},
    {},
    { [player] remoteExec ["fnc_intel_search", 2]; },
    {},
    [],
    6,
    6,
    // Not removed on completion: the spent flag in the condition is what hides it, so it returns
    // by itself when the economy tick clears the flag. Removing it here would need a re-add
    // driven from the tick, on every client, for a state the condition already reads.
    false,
    false
] call BIS_fnc_holdActionAdd;
