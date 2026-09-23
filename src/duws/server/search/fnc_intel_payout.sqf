// Locality: server. The single payout point for every intel source -- the body search, the side
// missions, the civilian menu when it lands, and the Intelligence Center's clock -- so what one
// piece of intel is worth is decided in one file rather than at each faucet.
//
// A payout has two halves and pays both. The pool half reveals one position out of what is still
// hidden; the contact half plots a random number of OPCOM units where they are marching. They answer
// different questions -- where the war is, and what the enemy is doing right now -- so making them
// compete for one draw only ever starved whichever mattered more that hour.
//
// Takes the position the intel was earned at, which only the town bucket uses, and who earned it,
// who is told when there is nothing left. Returns true if either half paid. A pool reveal is
// announced by its writer; the contact batch is announced here, one line for the whole batch.
//
// _silent drops the dry answer, for a caller that pays something else on a decline and would
// otherwise announce an empty search and then hand over a document.
params [["_origin", []], ["_earner", objNull], ["_silent", false]];

if (!isServer) exitWith {false};

// Who hears the dry answer. A null earner is a faucet with no one player to tell -- a mission
// completing is everyone's news -- and 0 carries it to every machine; anyone else asked for the
// intel themselves and is the only one told.
private _audience = if (isNull _earner) then { 0 } else { _earner };

private _awarded = false;

// ---- the pool half ----
// Rolled over the kinds that have something to give right now, not a fixed list: a kind whose
// pool is empty never enters the draw, and a campaign that has found everything pays this half
// nothing rather than silently awarding it. They stay separate buckets rather than one
// merged pool because each picks its member on a different rule, not merely because they live in
// different arrays.
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

// Hardpoints are hidden only under hardcore, like towns, so outside it this stays empty and the
// payout is unchanged. A zone-child hardpoint is gated behind its parent: it enters the pool only
// once that zone is revealed, so the player finds the zone before its guns. A standalone hardpoint
// has no parent and is always eligible. Matched by key -- fnc_zone_key of a revealed zone's centre
// is the same key the hardpoint row carries (both derive from the one zone-centre position).
private _revealedZoneKeys = [];
{
    if (_x select 2) then { _revealedZoneKeys pushBack ([_x select 1] call fnc_zone_key) };
} forEach zone_namePOS_pairs;
private _hiddenHPs = DUWS_hardpoints select {
    !(_x select 5) && { (_x select 4) isEqualTo "" || {(_x select 4) in _revealedZoneKeys} }
};
if !(_hiddenHPs isEqualTo []) then { _kinds pushBack "HP" };

if (_kinds isNotEqualTo []) then {
    switch (selectRandom _kinds) do {

        // Random, and from the unrevealed set only. A zone is a target the campaign points the player
        // at, so which one comes next is a strategic question rather than a geographic one, and
        // nearest-first would march them outward in a spiral. Drawing from the unrevealed set rather
        // than from every zone and testing afterwards -- the shape this replaced -- stops the real
        // odds decaying as a campaign progresses, when late on most winning rolls land on ground
        // already found.
        case "ZONE": {
            _awarded = ["ONE", (selectRandom _hiddenZones) select 1] call fnc_zone_reveal;
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
            _awarded = [_closest] call fnc_civ_town_reveal;
        };

        // Random from the eligible unrevealed set, like the zone bucket: a hardpoint is a target the
        // campaign points the player at, not a place they are measured a distance from.
        case "HP": {
            _awarded = ["ONE", (selectRandom _hiddenHPs) select 0] call fnc_hardpoint_reveal;
        };

    };
};

// ---- the contact half ----
// Gated on the player knowing where at least one enemy zone is. A march plotted across ground whose
// owner they have never found names nothing, and in hardcore that blank map is the opening the first
// zone is there to end -- intel that jumped straight to enemy movements would answer a question the
// player has not yet earned the right to ask.
private _knownOpfor = false;
{
    private _zp = _x select 1;
    if (!_knownOpfor && {_x select 2}
        && {(WARCOM_zones_controled_by_OPFOR findIf { (_x distance2D _zp) < 1 }) >= 0}) then {
        _knownOpfor = true;
    };
} forEach zone_namePOS_pairs;

if (_knownOpfor) then {
    // Virtual taskings only: a streamed one stands inside a player's bubble already, and its record's
    // position is frozen at the cell it de-virted in, so plotting it would mark stale ground the
    // player is standing on. One already plotted is out, or its own markers would be redrawn.
    private _contacts = DUWS_opcom_taskings select {
        ((_x get "order") in ["move", "capture", "intercept"])
        && {(_x get "grp") isEqualTo ""}
        && {!((_x get "id") in DUWS_intel_contactIds)}
    };
    // Uniform over 0 to all of them. Zero is a real answer -- a sector with nothing moving in it --
    // and it costs the payout nothing, because the pool half has already paid.
    private _plotted = (_contacts call BIS_fnc_arrayShuffle) select [0, floor (random ((count _contacts) + 1))];
    private _n = 0;
    { if ([_x] call DUWS_fnc_intel_contactReveal) then { _n = _n + 1 } } forEach _plotted;
    if (_n > 0) then {
        _awarded = true;
        // One line for the batch: a line per contact would queue eight of them behind each other,
        // and only the single-contact case has one place worth naming.
        private _line = if (_n == 1) then {
            format [localize "STR_DUWS_T_INTEL_REVEAL_CONTACT_LINE", [(_plotted select 0) get "pos"] call fnc_place_name]
        } else {
            format [localize "STR_DUWS_T_INTEL_REVEAL_CONTACT_MANY", _n]
        };
        [localize "STR_DUWS_T_ALLSEER", _line] remoteExec ["fnc_duws_dialogue", 0];
    };
};

// The dry line lives here rather than at each faucet because four of the six side-mission sites hand
// their result to a remoteExec and never see the return value, so they could not speak it. Overlord
// carries it when there is no earner to speak in their own voice.
if (!_awarded && {!_silent}) then {
    private _speaker = if (isNull _earner) then { localize "STR_DUWS_T_OVERLORD" } else { name _earner };
    [_speaker, localize "STR_DUWS_T_8skllpyx"] remoteExec ["fnc_duws_dialogue", _audience];
};

_awarded
