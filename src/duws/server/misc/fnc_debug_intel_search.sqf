// Locality: server. Runs the real roll and the real payout, and deliberately ignores the
// per-player attempt: at one attempt per 30-minute economy tick, exercising a 10% chance the
// honest way takes about five hours. Nothing else about the path is faked.
if (!isServer) exitWith {};

params ["_caller"];
if (isNull _caller) exitWith {};

// Names copied out as strings before the payout runs. The pairs themselves are handed out by
// reference, so a snapshot of them would mutate along with the array and show nothing changed.
private _hiddenBefore = (zone_namePOS_pairs select {!(_x select 2)}) apply {_x select 0};

private _roll = random 1;
private _hit = _roll < intel_search_chance;

private _outcome = "MISS - no payout";
if (_hit) then {
    _outcome = if (call fnc_intel_payout) then {
        private _revealed = _hiddenBefore select {
            private _name = _x;
            (zone_namePOS_pairs findIf {(_x select 0) == _name && {_x select 2}}) > -1
        };
        format ["HIT - revealed %1", _revealed param [0, "?"]]
    } else {
        "HIT - but every payout pool is empty"
    };
};

[format [
    "Intel search (debug)\n\nRoll %1 against a chance of %2\n%3\n\nHidden zones: %4 -> %5\nTask forces unblocked: %6\nYour real attempt is spent: %7",
    (round (_roll * 1000)) / 1000,
    intel_search_chance,
    _outcome,
    count _hiddenBefore,
    count (zone_namePOS_pairs select {!(_x select 2)}),
    hardcore_visibleZone_found,
    _caller getVariable ["DUWS_intel_searched", false]
]] remoteExec ["hint", _caller];
