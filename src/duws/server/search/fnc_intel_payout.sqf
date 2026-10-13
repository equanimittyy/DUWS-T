// Locality: server. The single payout point for every intel source -- the body search, the side
// missions, the civilian menu when it lands, and the Intelligence Center's clock -- so what one
// piece of intel is worth is decided in one file rather than at each faucet.
//
// A payout has two halves and pays both. The pool half reveals one position out of what is still
// hidden; the contact half plots a random share of the eligible OPCOM units where they stand.
// They answer different questions -- where the war is, and what the enemy is doing right
// now -- so making them compete for one draw only ever starved whichever mattered more that hour.
//
// Takes the position the intel was earned at, which only the town bucket uses, and who earned it,
// who is the only one told when there is nothing left. Returns true if either half paid. A pool reveal is
// announced by its writer; the contact batch is announced here, one line for the whole batch.
//
// _silent drops the dry answer, for a caller that pays something else on a decline and would
// otherwise announce an empty search and then hand over a document.
//
// _radius is how far the source's knowledge reaches, 0 for the whole map. A source that knows only
// its own ground passes one and takes whatever falls inside it, including nothing.
params [["_origin", []], ["_earner", objNull], ["_silent", false], ["_radius", 0], ["_pool", true]];

if (!isServer) exitWith {false};

// Measured from _origin, never from the _from fallback below: that one stands in the HQ when there
// is no origin, which is not where the source is. A reach with nothing to measure from therefore
// reaches nothing rather than quietly reaching everywhere.
private _fnc_inReach = {
    params ["_pos"];
    _radius <= 0 || {count _origin >= 2 && {(_origin distance2D _pos) <= _radius}}
};

private _awarded = false;

// ---- the pool half ----
// Rolled over the kinds that have something to give right now, not a fixed list: a kind whose
// pool is empty never enters the draw, and a campaign that has found everything pays this half
// nothing rather than silently awarding it. They stay separate buckets rather than one
// merged pool because each picks its member on a different rule, not merely because they live in
// different arrays.
private _kinds = [];

// A live recon job's target is left for the job to reveal, or the hold the player is sent to pays for nothing.
private _reconTargets = missionNamespace getVariable ["DUWS_recon_targets", []];
private _fnc_unclaimed = { params ["_pos"]; (_reconTargets findIf { _x distance2D _pos < 1 }) < 0 };

private _hiddenZones = zone_namePOS_pairs select {!(_x select 2) && {[_x select 1] call _fnc_inReach} && {[_x select 1] call _fnc_unclaimed}};
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
        if (!_x && {[getPos (_towns select _forEachIndex)] call _fnc_inReach}) then {
            _hiddenTowns pushBack _forEachIndex;
        };
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
    && {[_x select 1] call _fnc_inReach} && {[_x select 1] call _fnc_unclaimed}
};
if !(_hiddenHPs isEqualTo []) then { _kinds pushBack "HP" };

if (_pool && {_kinds isNotEqualTo []}) then {
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
    // A garrison rests on its home zone, so plotting one whose zone is still hidden would mark that zone.
    private _contacts = DUWS_opcom_taskings select {
        ((_x get "order") isNotEqualTo "garrison" || {(_x get "homeZone") in _revealedZoneKeys})
        && {[_x get "pos"] call _fnc_inReach}
    };
    // Rounded up, so a payout with anything eligible plots at least one unit: a payout of nothing reads
    // as an unreliable source rather than as a quiet sector.
    (DUWS_intel_share_by_level select (missionNamespace getVariable ["DUWS_intelLevel", 0])) params ["_lo", "_hi"];
    private _want = ceil ((_lo + random (_hi - _lo)) * count _contacts);
    { [_x] call DUWS_fnc_intel_contactReveal } forEach ((_contacts call BIS_fnc_arrayShuffle) select [0, _want]);
    if (_want > 0) then {
        _awarded = true;
        // One line for the batch: a line per contact would queue eight of them behind each other.
        [localize "STR_DUWS_T_ALLSEER", localize "STR_DUWS_T_INTEL_REVEAL_CONTACT_MANY"] remoteExec ["fnc_duws_dialogue", 0];
    };
};

// The dry line lives here rather than at each faucet because four of the six side-mission sites hand
// their result to a remoteExec and never see the return value, so they could not speak it. It is the
// searcher's own report of their own search, so a faucet with no one player behind it says nothing
// rather than putting the line in a command call sign's mouth.
if (!_awarded && {!_silent} && {!isNull _earner}) then {
    [name _earner, localize "STR_DUWS_T_8skllpyx"] remoteExec ["fnc_duws_dialogue", _earner];
};

_awarded
