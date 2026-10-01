// Locality: client. The client half of the search gate: returns the object this player's search
// should target right now, or objNull. Called from the hold-action's show condition (every eval)
// and again from its exec a frame later; the server re-validates whatever it hands back.
//
// Two kinds of target. A flagged body -- a manhunt HVT's corpse, or a surrendered civilian being
// frisked -- stays cursor-precise: a deliberate, unambiguous pick, and a living detainee is not a
// corpse the cone scan would ever find. An ordinary enemy corpse is taken by nearest-in-view-cone
// within reach instead, so a ragdoll need only be faced, not have the cursor land on it. A body
// already searched (DUWS_search_done) is excluded from both, so every corpse is offered once.
//
// Flagged targets are single-use and bypass the budget; the combat corpse is gated by it here for
// the prompt, and again on the server for authority. Budget and class list read with defaults: their
// broadcasts may not have landed when this first evaluates.
//
// Enemy is matched by class against DUWS_enemyManClasses (recorded at each EAST death), never `side _x`
// (every corpse reports civilian) or config side (the mod's side, not the side the mission fields it on).
// A class also survives the AGC corpse-swap, which a flag on the body would not.
params ["_who"];
private _reach = 3;

private _c = cursorObject;
if (
    !isNull _c && {_c distance _who < _reach}
    && {(_c getVariable ["DUWS_search_src", ""]) != ""}
    && {!(_c getVariable ["DUWS_search_done", false])}
    && {!(_c isKindOf "CAManBase") || {!alive _c} || {_c getVariable ["isSurrendered", false]}}
) exitWith { _c };

private _window = missionNamespace getVariable ["DUWS_searchCooldown", 900];
private _spent = (missionNamespace getVariable ["DUWS_searchTimes", []]) select {time - _x < _window};
if (count _spent >= (missionNamespace getVariable ["DUWS_searchAllowance", 3])) exitWith { objNull };

private _enemyClasses = missionNamespace getVariable ["DUWS_enemyManClasses", []];
private _eye = eyePos _who;
private _look = eyeDirection _who;
private _best = objNull;
private _bestDist = _reach;
{
    if (
        !alive _x
        && {!(_x getVariable ["DUWS_search_done", false])}
        && {_x distance _who < _bestDist}
        && {typeOf _x in _enemyClasses}
    ) then {
        private _rel = (eyePos _x) vectorDiff _eye;
        private _mag = vectorMagnitude _rel;
        // dot > 0.5 == within ~60 deg of view: "generally facing", not "cursor on it".
        if (_mag > 0 && {(_look vectorDotProduct (_rel vectorMultiply (1 / _mag))) > 0.5}) then {
            _best = _x;
            _bestDist = _x distance _who;
        };
    };
} forEach (nearestObjects [_who, ["CAManBase"], _reach]);

_best
