// Locality: server. Runs the real roll and the real payout, and deliberately ignores the
// per-player attempt: at one attempt per 30-minute economy tick, exercising a 10% chance the
// honest way takes about five hours. Nothing else about the path is faked.
if (!isServer) exitWith {};

params ["_caller"];
if (isNull _caller) exitWith {};

// Names copied out as strings, zones and hardcore-hidden towns together. The entries themselves
// are handed out by reference, so a snapshot of them would mutate along with the array and show
// nothing changed.
private _fnc_hidden = {
    private _out = (zone_namePOS_pairs select {!(_x select 2)}) apply {_x select 0};
    private _towns = missionNamespace getVariable ["civ_locations", []];
    {
        if (!_x) then {
            private _name = text (_towns select _forEachIndex);
            _out pushBack (if (_name != "") then {_name} else {format ["Town %1", _forEachIndex]});
        };
    } forEach (missionNamespace getVariable ["civ_visible", []]);
    _out
};

private _hiddenBefore = call _fnc_hidden;

private _roll = random 1;
private _hit = _roll < intel_search_chance;

private _outcome = "MISS - no payout";
if (_hit) then {
    _outcome = if ([getPos _caller] call fnc_intel_payout) then {
        format ["HIT - revealed %1", (_hiddenBefore - (call _fnc_hidden)) param [0, "?"]]
    } else {
        "HIT - but every payout pool is empty"
    };
};

[format [
    "Intel search (debug)\n\nRoll %1 against a chance of %2\n%3\n\nHidden positions: %4 -> %5\nTask forces unblocked: %6\nYour real attempt is spent: %7",
    (round (_roll * 1000)) / 1000,
    intel_search_chance,
    _outcome,
    count _hiddenBefore,
    count (call _fnc_hidden),
    hardcore_visibleZone_found,
    _caller getVariable ["DUWS_intel_searched", false]
]] remoteExec ["hint", _caller];
