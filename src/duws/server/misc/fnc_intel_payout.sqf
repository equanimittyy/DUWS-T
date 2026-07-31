// Locality: server. The single payout point for every intel source -- the body search, the side
// missions, and the civilian menu when it lands -- so what one piece of intel is worth is decided
// in one file rather than at each faucet.
//
// Takes the position the intel was earned at, which only the town bucket uses, and who earned it,
// who is told when there is nothing left. Returns true if something was awarded, false if there
// was nothing left to give.
//
// _silent hands every line this would speak -- the reveal and the dry answer alike -- to the
// caller, and is for the one that reports its own result either way. Silencing only the dry answer
// is not enough: a caller that declines has to pay something else and would otherwise announce an
// empty search and then hand over a document, and a caller that succeeds would have Overlord
// broadcast the reveal on top of the line it speaks itself.
params [["_origin", []], ["_earner", objNull], ["_silent", false]];

if (!isServer) exitWith {false};

// Who hears about it. A null earner is a faucet with no one player to tell -- a mission completing
// is everyone's news -- and 0 carries it to every machine; anyone else earned the reveal
// themselves and is the only one told.
private _audience = if (isNull _earner) then { 0 } else { _earner };

// Rolled over the kinds that have something to give right now, not a fixed list: a kind whose
// pool is empty never enters the draw, and a campaign late enough to have found everything
// reports that instead of silently awarding nothing. They stay separate buckets rather than one
// merged pool because each picks its member on a different rule, not merely because they live in
// different arrays. Hidden normal hardpoints and enemy patrols join the draw when the systems
// behind them exist.
private _kinds = [];

private _hiddenZones = zone_namePOS_pairs select {!(_x select 2)};
if !(_hiddenZones isEqualTo []) then { _kinds pushBack "ZONE" };

// The town bucket ranks by distance, so it needs somewhere to measure from: where the intel was
// earned, or the HQ for a faucet that has no player to ask. With neither there is nothing to rank
// by, and the bucket sits out the draw rather than falling back to a random pick -- one feature
// quietly using two different rules is worse than it paying a zone instead.
private _from = _origin;
if (count _from < 2) then { _from = missionNamespace getVariable ["PosOfBLUHQ", []] };

// Towns are only ever hidden in hardcore, so outside it this stays empty and the payout is
// zones-only exactly as before.
private _towns = missionNamespace getVariable ["civ_locations", []];
private _hiddenTowns = [];
if (count _from >= 2) then {
    {
        if (!_x) then { _hiddenTowns pushBack _forEachIndex };
    } forEach (missionNamespace getVariable ["civ_visible", []]);
};
if !(_hiddenTowns isEqualTo []) then { _kinds pushBack "CIV" };

// The dry-pool line lives here rather than at each faucet because four of the six side-mission
// sites hand their result to a remoteExec and never see the return value, so they could not speak
// it. Overlord carries it when there is no earner to speak in their own voice.
if (_kinds isEqualTo []) exitWith {
    if (!_silent) then {
        private _speaker = if (isNull _earner) then { localize "STR_DUWS_T_OVERLORD" } else { name _earner };
        [_speaker, localize "STR_DUWS_T_8skllpyx"] remoteExec ["fnc_duws_dialogue", _audience];
    };
    false
};

private _awarded = false;
switch (selectRandom _kinds) do {

    // Random, and from the unrevealed set only. A zone is a target the campaign points the player
    // at, so which one comes next is a strategic question rather than a geographic one, and
    // nearest-first would march them outward in a spiral. Drawing from the unrevealed set rather
    // than from every zone and testing afterwards -- the shape this replaced -- stops the real
    // odds decaying as a campaign progresses, when late on most winning rolls land on ground
    // already found.
    case "ZONE": {
        _awarded = ["ONE", (selectRandom _hiddenZones) select 1, _audience, _silent] call fnc_zone_reveal;
    };

    // Nearest wins. A town is somewhere the player goes to do something -- trade, recruit, ask a
    // local -- so one on the far side of the map is worth no more to them than nothing happening.
    // Seeded from the first candidate rather than a sentinel distance, so there is no magic
    // number standing in for "further than any map".
    case "CIV": {
        private _closest = _hiddenTowns select 0;
        private _bestDist = _from distance2D (getPos (_towns select _closest));
        {
            private _dist = _from distance2D (getPos (_towns select _x));
            if (_dist < _bestDist) then { _bestDist = _dist; _closest = _x };
        } forEach _hiddenTowns;
        _awarded = [_closest, _audience, _silent] call fnc_civ_town_reveal;
    };

};

_awarded
