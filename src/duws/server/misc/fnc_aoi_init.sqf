// Locality: server -- every reader (the rep drift on the economy tick, the hardpoint band siting)
// runs on the server, and the emitters this reads (zones, FOBs, the HQ, banded towns, the standing
// radio towers) are all authoritative there. Definitions only; the callers are elsewhere.
//
// The area of influence is a signed coverage field, not a magnitude and not a grid. Coverage is a
// hard edge: an emitter covers every point within reach of its OUTER edge and nothing past it -- no
// falloff, no per-emitter strength -- because the drift it drives is a flat step, not a weighted one.
// Reach from the outer edge, not the centre, is the whole mechanic: a naturally large zone claims
// proportionally more ground than a small one, and the band it owns outside its own footprint is
// where standalone hardpoints are sited. The field is derived from live campaign state each time it
// is asked, so there is no second store to keep in step. See docs/opfor_area_of_influence_plan.md.
if (!isServer) exitWith {};

// [_pos, _side] call DUWS_fnc_aoi_covers -> bool. Is _pos within reach of any _side ("opfor"/"blufor")
// emitter. Short-circuits on the first cover. The two named primitives below are thin wrappers, so a
// zone's controller resolution and the banded-town gate live in one place rather than two.
DUWS_fnc_aoi_covers = {
    params ["_pos", "_side"];
    private _opfor = _side isEqualTo "opfor";

    // OPFOR radio towers: AOI_TOWER_REACH from the mast, the longest reach on the map. Read live from
    // the registry, so a stowed tower still projects its coverage and a cleared one stops projecting
    // at once, whether or not a player is near enough for it to stream in.
    if (_opfor && {(DUWS_hardpoints findIf {
        (_x select 2) isEqualTo "RADIO" && {(_pos distance2D (_x select 1)) <= AOI_TOWER_REACH}
    }) >= 0}) exitWith { true };

    // Zones: their controller's side, reach measured from the radius (bigger zone, more band). Control
    // is by proximity to the BLUFOR-held list, the same test the capture triggers use; a zone not in
    // it is OPFOR, which is every zone at campaign start.
    if ((zone_meta_array findIf {
        _x params ["", "_zp", "_zs"];
        private _zBlu = (WARCOM_zones_controled_by_BLUFOR findIf {(_x distance2D _zp) < 1}) >= 0;
        (_zBlu != _opfor) && {(_pos distance2D _zp) <= _zs + AOI_ZONE_REACH}
    }) >= 0) exitWith { true };

    // Player HQ (BLUFOR): AOI_HQ_REACH from the flag. Empty until the HQ is placed.
    if (!_opfor && {!(PosOfBLUHQ isEqualTo []) && {(_pos distance2D PosOfBLUHQ) <= AOI_HQ_REACH}}) exitWith { true };

    // FOBs (BLUFOR): AOI_FOB_REACH from each.
    if (!_opfor && {(Array_of_FOBpos findIf {(_pos distance2D _x) <= AOI_FOB_REACH}) >= 0}) exitWith { true };

    // Banded towns: a town emits for its side only once its reputation has fully crossed +-10 -- the
    // same band that flips it for garrison and income. A neutral town is inert, so influence spreads
    // only after a town has fully fallen, never from one merely leaning. Reach = civ_radius +
    // AOI_TOWN_REACH. The three arrays are index-parallel and absent (empty) with civilians off.
    private _reps = missionNamespace getVariable ["civ_town_rep", []];
    private _locs = missionNamespace getVariable ["civ_locations", []];
    private _radii = missionNamespace getVariable ["civ_radii", []];
    // forEach, not findIf: the banded test is on the rep but the reach is on the parallel civ_radius,
    // and only forEach exposes _forEachIndex to cross into the sibling arrays. exitWith breaks it.
    private _hit = false;
    {
        private _banded = if (_opfor) then { _x <= -10 } else { _x >= 10 };
        if (_banded && {(_pos distance2D (getPos (_locs select _forEachIndex))) <= (_radii select _forEachIndex) + AOI_TOWN_REACH}) exitWith { _hit = true };
    } forEach _reps;
    _hit
};

// [_pos] call fnc_aoi_opfor_covers / fnc_aoi_blufor_covers -> bool. The two primitives the drift
// reads directly, so it can add the radio-tower amplifiers on top of a flat coverage step.
fnc_aoi_opfor_covers  = { [_this, "opfor"]  call DUWS_fnc_aoi_covers };
fnc_aoi_blufor_covers = { [_this, "blufor"] call DUWS_fnc_aoi_covers };

// [_pos] call fnc_aoi_field_at -> -1 / 0 / +1, OPFOR-positive dominance: +1 OPFOR-only, -1
// BLUFOR-only, 0 contested or empty. What the hardpoint siting reads (a candidate is in the band when
// this is positive and it is outside every zone).
fnc_aoi_field_at = {
    params ["_pos"];
    private _o = [_pos, "opfor"]  call DUWS_fnc_aoi_covers;
    private _b = [_pos, "blufor"] call DUWS_fnc_aoi_covers;
    ([0, 1] select _o) - ([0, 1] select _b)
};

// [_pos] call fnc_aoi_in_any_zone -> bool. Point inside any zone's own radius, whoever holds it.
// Inside a zone is the zone hardpoint system's ground, gated by the capture trigger; the band is the
// countryside between, so the siting mask excludes zone interiors even though the field still covers
// them (a town under a zone still drifts).
fnc_aoi_in_any_zone = {
    params ["_pos"];
    (zone_meta_array findIf { (_pos distance2D (_x select 1)) <= (_x select 2) }) >= 0
};

// [] call DUWS_fnc_aoi_bandPos -> [_pos, _radialDir] in the OPFOR-positive band, or [] if the draw
// missed. One candidate for the band, shared by the campaign-start pass, the tower seed and the OPCOM
// tick so all three sample the same ground the same way. It draws an annulus around a random OPFOR
// zone (from its edge out to AOI_ZONE_REACH) and keeps the point only where the field reads
// OPFOR-positive and it is outside every zone -- so it lands in the countryside the enemy holds, never
// inside a zone. _radialDir is the outward bearing from that zone, for fnc_hardpoint_facing; the zone
// centre is appended as a third element so the AoI band pass can face a local hardpoint outward from it.
DUWS_fnc_aoi_bandPos = {
    private _opforZones = [];
    {
        _x params ["", "_zp", "_zs"];
        if ((WARCOM_zones_controled_by_BLUFOR findIf {(_x distance2D _zp) < 1}) < 0) then {
            _opforZones pushBack [_zp, _zs];
        };
    } forEach zone_meta_array;
    if (_opforZones isEqualTo []) exitWith { [] };

    (selectRandom _opforZones) params ["_ozp", "_ozs"];
    private _c = [_ozp, _ozs, _ozs + AOI_ZONE_REACH, 8, 0, 0.35, 0] call BIS_fnc_findSafePos;
    if (([_c] call fnc_aoi_field_at) <= 0) exitWith { [] };
    if ([_c] call fnc_aoi_in_any_zone) exitWith { [] };
    [_c, _ozp getDir _c, _ozp]
};
