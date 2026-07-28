// Locality: server. The single payout point for every intel source -- the body search, the side
// missions, and the civilian menu when it lands -- so what one piece of intel is worth is decided
// in one file rather than at each faucet.
//
// Returns true if something was awarded, false if there was nothing left to give.
if (!isServer) exitWith {false};

// Rolled over the kinds that have something to give right now, not a fixed list: a kind whose
// pool is empty never enters the draw, and a campaign late enough to have found everything
// reports that instead of silently awarding nothing. Hidden normal hardpoints and enemy patrols
// join the draw when the systems behind them exist; zones are the only kind implemented today.
private _kinds = [];

private _hiddenZones = zone_namePOS_pairs select {!(_x select 2)};
if !(_hiddenZones isEqualTo []) then { _kinds pushBack "ZONE" };

if (_kinds isEqualTo []) exitWith {false};

private _awarded = false;
switch (selectRandom _kinds) do {

    // Draws from the unrevealed zones only. The shape this replaces drew from every zone and
    // then tested whether it happened to be hidden, so the odds decayed as a campaign
    // progressed: late on, most successful rolls landed on ground already found.
    case "ZONE": {
        _awarded = ["ONE", (selectRandom _hiddenZones) select 1] call fnc_zone_reveal;
    };

};

_awarded
