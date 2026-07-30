// Locality: client. Added at client_init and re-added by onPlayerRespawn, because the action
// dies with the body.
//
// One action on the player looking outward at whatever is under the cursor, rather than one
// action per corpse. The per-corpse shape needs a remoteExec with the JIP flag set per death
// (fnc_add_intel_on_death), and nothing ever removes those entries, so the JIP queue would grow
// with the campaign's kill count instead of with its player count.
//
// The id is kept so onPlayerKilled can strip the action off the body being left behind. It does not
// die with its owner: the engine evaluates the conditions of actions on any object near a player,
// so without that removal every corpse the player leaves goes on polling this one for the rest of
// the campaign.
if (!hasInterface) exitWith {};

// Clause order is load-bearing: an action on the player is evaluated constantly, because the
// player is never out of range of themselves. Each && takes a code block, so evaluation
// short-circuits, and the cheapest and most-often-false clauses come first -- only a body
// actually under the cursor and within reach reaches the config lookup in isKindOf.
//
// Written against _target where a handle is needed at all, the only one both condShow and
// condProgress share: BIS_fnc_holdActionAdd names the caller _this in one and _caller in the other.
// The spent flag is read off player rather than _target, which is the same object here but not on
// a body left behind by an earlier death: an action still hanging on one of those would otherwise
// test the corpse's flag and let a player search past their own spent attempt.
private _cond =
    "!isNil 'hardcore_mode_enable' && {hardcore_mode_enable}"
  + " && {!(player getVariable ['DUWS_intel_searched', false])}"
  + " && {!isNull cursorObject}"
  + " && {cursorObject distance _target < 3}"
  + " && {cursorObject isKindOf 'CAManBase'}"
  + " && {!alive cursorObject}"
  + " && {side group cursorObject == east}";

private _id = [
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
    30,
    // Not removed on completion: the spent flag in the condition is what hides it, so it returns
    // by itself when the economy tick clears the flag. Removing it here would need a re-add
    // driven from the tick, on every client, for a state the condition already reads.
    false,
    false
] call BIS_fnc_holdActionAdd;

player setVariable ["DUWS_intel_search_actionId", _id];

// A body the player has just respawned into carries no spent flag, so ask the server whether this
// window's attempt is already gone. Asked from here rather than from onPlayerRespawn because this is
// the one place the action is added, which covers the client's first boot as well as every respawn.
[player] remoteExec ["fnc_intel_search_restore", 2];
