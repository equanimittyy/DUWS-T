// Locality: server -- a client's completed defuse hold reaches here by name (remoteExec to 2 from the
// hold-action set up in fnc_random_event_ied), for a live IED or a decoy alike, since the player cannot tell
// them apart. Re-checks the pile is still unresolved (it may have cooked off, or been cleared by someone else
// the same frame), clears the charge on every client, then pays a command point only if it was live -- a
// decoy defuses to nothing. CP goes straight through fnc_cp_adjust: it is a reward, not a purchase, so it
// skips the escalation the pool-spend handshake applies.
if (!isServer) exitWith {};
params [["_pile", objNull]];
if (isNull _pile) exitWith {};
private _state = _pile getVariable ["DUWS_ied_state", "gone"];
if (_state == "gone") exitWith {};

_pile setVariable ["DUWS_ied_state", "gone", false];
_pile setVariable ["DUWS_ied_active", false, true];   // drops the hold action on every client
if (_state == "live") then { [1, "ied_defused"] call fnc_cp_adjust };
// Leave the pile standing as defused junk and hand it to the map cleanup. A raw DUWS_binMe flag would be
// inert on it -- fnc_repetitive_cleanup only binMe-reaps allUnits + vehicles, and a junk pile is a static
// prop in neither; fnc_duws_disposeAfter routes it through the sweep that does collect props, off-screen.
[_pile] call fnc_duws_disposeAfter;
