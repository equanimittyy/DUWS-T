// Locality: server -- OPCOM's fortification director, server-authoritative. One build per pass, in
// priority order, each AP-priced so it competes with the commander's other sinks and gated so nothing is
// built the enemy cannot pay for:
//   1. raise a radio tower toward the cap (the strongest rep lever, replacing what the player knocked down);
//   2. top a depleted zone back toward its stored cap (emplacements the player cleared);
//   3. thicken the band with a standalone emplacement in OPFOR-positive countryside.
// Placement is uniform for now -- targeting toward believed player positions waits on the belief store
// (docs/plans/opcom_plan.md). Started once by WARCOM init, on its own clock.
if (!isServer) exitWith {};

while {true} do {
    // A throw would kill this daemon for the whole session (see fnc_repetitive_cleanup).
    try {
    sleep (OPCOM_HP_PERIOD * OPCOM_TICK_PERIOD);

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
    //    registry; the cap is radius plus the zone's current tier, read live so a tier buy raises it.
    if (!_acted && {WARCOM_opfor_ap >= OPCOM_AP_TOPUP}) then {
        private _depleted = [];
        {
            _x params ["", "_zp", "_zs"];
            if ((WARCOM_zones_controled_by_BLUFOR findIf {(_x distance2D _zp) < 1}) >= 0) then { continue };
            private _zk = [_zp] call fnc_zone_key;
            private _cap = [_zk, _zs] call fnc_hardpoint_zone_cap;
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
                private _c = [_zp, _zs, 0, 6, 0.35, []] call fnc_safe_pos;
                if (_c isEqualTo []) exitWith { [] };
                [_c, _zp getDir _c]
            }] call fnc_hardpoint_lay;
            if (_added > 0) then {
                ["OPF", -OPCOM_AP_TOPUP, "opcom_zone_topup"] call fnc_ap_adjust;
                _acted = true;
            };
        };
    };

    // 3. Fortify the band with one standalone emplacement, sited the same cheap local-search way as the
    // start pass: fnc_hardpoint_band_anchor fixes a neighbourhood, then the draws stay within it.
    if (!_acted && {WARCOM_opfor_ap >= OPCOM_AP_BAND}) then {
        private _seq = missionNamespace getVariable ["DUWS_hpOpcomSeq", 0];
        missionNamespace setVariable ["DUWS_hpOpcomSeq", _seq + 1];
        private _built = [1, format ["hpopcom_%1", _seq], "", fnc_hardpoint_band_cand, {}, fnc_hardpoint_band_anchor] call fnc_hardpoint_lay;
        if (_built > 0) then {
            ["OPF", -OPCOM_AP_BAND, "opcom_band_build"] call fnc_ap_adjust;
        };
    };
    } catch {
        ["ERROR", "OPCOM", format ["hardpoint tick threw, thread held alive: %1", _exception]] call fnc_log;
        sleep 10;
    };
};
