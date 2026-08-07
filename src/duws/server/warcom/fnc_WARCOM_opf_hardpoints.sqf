// Locality: server -- OPCOM's first real behaviour, and every placer and pool it touches is
// server-authoritative. This is the commander the WARCOM init comment was waiting on: nothing spawned
// OPFOR after generation because "an OPFOR commander decides it", and this is the smallest thing that
// decision can be -- spending OPFOR Army Power to fortify the ground the enemy holds.
//
// One build per pass, in priority order, each AP-priced so it competes with the commander's other
// sinks and gated so nothing is built the enemy cannot pay for:
//   1. raise a radio tower toward the cap -- the strongest rep lever, and it replaces what the player
//      has knocked down, lifting the global drift amplifier a point everywhere at once;
//   2. top a depleted zone back toward its stored cap -- inside-zone emplacements the player cleared;
//   3. thicken the band with a standalone emplacement in the OPFOR-positive countryside.
//
// Uniform placement for now: where the enemy fortifies with intent -- pushing toward where it believes
// the player operates -- waits on the belief store and the archetype weights (opfor_commander_loop_plan.md),
// which this cannot precede. The field is enough to place; the personality is the refinement that lands
// with belief. Started once by WARCOM init, on its own clock.
if (!isServer) exitWith {};

while {true} do {
    sleep OPCOM_HP_TICK;

    // One action a pass, gated by _acted rather than by exitWith/continue: inside a while body those
    // read as end-of-iteration, not as the "skip the rest, keep the clock" this wants.
    private _acted = false;

    // 1. Raise a tower toward the cap. Charged only if one actually stood up -- the band sampler can
    //    miss on a bad map, and a missed draw must not bill the enemy for nothing.
    if (DUWS_opforRadioLevel < AOI_OPFOR_TOWER_CAP && {WARCOM_opfor_ap >= OPCOM_AP_TOWER}) then {
        private _before = DUWS_opforRadioLevel;
        [1] call fnc_hardpoint_seed_radio;
        if (DUWS_opforRadioLevel > _before) then {
            ["OPF", -OPCOM_AP_TOWER, "opcom_radio_tower"] call fnc_ap_adjust;
            _acted = true;
        };
    };

    // 2. Top up a zone the player has thinned below its cap. A zone's live count is its rows in the
    //    registry; the cap was stored when the zone was first sited.
    if (!_acted && {WARCOM_opfor_ap >= OPCOM_AP_TOPUP}) then {
        private _depleted = [];
        {
            _x params ["", "_zp", "_zs"];
            if ((WARCOM_zones_controled_by_BLUFOR findIf {(_x distance2D _zp) < 1}) >= 0) then { continue };
            private _zk = [_zp] call fnc_zone_key;
            private _cap = missionNamespace getVariable [format ["DUWS_hpCap_%1", _zk], 0];
            private _live = { (_x select 4) isEqualTo _zk } count DUWS_hardpoints;
            if (_live < _cap) then { _depleted pushBack [_zp, _zs, _zk] };
        } forEach zone_meta_array;

        if (count _depleted > 0) then {
            (selectRandom _depleted) params ["_zp", "_zs", "_zk"];
            private _seq = missionNamespace getVariable ["DUWS_hpOpcomSeq", 0];
            missionNamespace setVariable ["DUWS_hpOpcomSeq", _seq + 1];
            // count 1, keyed off a global sequence so a top-up never collides with the initial ring or
            // another build; registered under the parent zone, so it streams with that zone.
            private _added = [1, format ["hpopcom_%1", _seq], _zk, {
                private _c = [_zp, 0, _zs, 6, 0, 0.35, 0] call BIS_fnc_findSafePos;
                [_c, _zp getDir _c]
            }] call fnc_hardpoint_lay;
            if (_added > 0) then {
                ["OPF", -OPCOM_AP_TOPUP, "opcom_zone_topup"] call fnc_ap_adjust;
                _acted = true;
            };
        };
    };

    // 3. Fortify the band with a standalone emplacement, sampled the same way as the start pass.
    if (!_acted && {WARCOM_opfor_ap >= OPCOM_AP_BAND}) then {
        private _seq = missionNamespace getVariable ["DUWS_hpOpcomSeq", 0];
        missionNamespace setVariable ["DUWS_hpOpcomSeq", _seq + 1];
        private _built = [1, format ["hpopcom_%1", _seq], "", { call DUWS_fnc_aoi_bandPos }] call fnc_hardpoint_lay;
        if (_built > 0) then {
            ["OPF", -OPCOM_AP_BAND, "opcom_band_build"] call fnc_ap_adjust;
        };
    };
};
