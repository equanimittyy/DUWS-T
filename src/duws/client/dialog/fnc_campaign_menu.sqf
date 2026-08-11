// Locality: client -- inherited from client/dialog/fnc_callsign_back.sqf.
  // Same flag and the same reason as the environment screen: preselecting a combo raises the
  // event a player's click raises, and only the player's counts as leaving the preset.
  duws_preset_applying = true;

  createDialog "startup_dialog2";
  waitUntil {dialog};

  // Marks a combo's default entry with a localised "(Default)" suffix at runtime, not
  // in the stringtable, so shared Yes/No and skill labels stay unchanged elsewhere.
  private _setDefault = {
      params ["_idc", "_i"];
      lbSetCurSel [_idc, _i];
      lbSetText [_idc, _i, (lbText [_idc, _i]) + " " + (localize "STR_DUWS_T_default_suffix")];
  };

  /// MAX RADIUS
  index_max_radius_2000 = lbAdd [2100, "2000m"];
  index_max_radius_1750 = lbAdd [2100, "1750m"];
  index_max_radius_1500 = lbAdd [2100, "1500m"];
  index_max_radius_1250 = lbAdd [2100, "1250m"];
  index_max_radius_1000 = lbAdd [2100, "1000m"];
  index_max_radius_750 = lbAdd [2100, "750m"];
  index_max_radius_500 = lbAdd [2100, localize "STR_DUWS_T_zoneradiusmax500"];
  [2100, index_max_radius_500] call _setDefault;

  // MIN RADIUS
  index_min_radius_1750 = lbAdd [2101, "1750m"];
  index_min_radius_1500 = lbAdd [2101, "1500m"];
  index_min_radius_1250 = lbAdd [2101, "1250m"];
  index_min_radius_1000 = lbAdd [2101, "1000m"];
  index_min_radius_750 = lbAdd [2101, "750m"];
  index_min_radius_500 = lbAdd [2101, "500m"];
  index_min_radius_350 = lbAdd [2101, localize "STR_DUWS_T_zoneradiusmin350"];
  [2101, index_min_radius_350] call _setDefault;

// AMOUNT ENEMY ZONES
index_amount_zones_40 = lbAdd [2102, localize "STR_DUWS_T_jooz8g8q4"];
index_amount_zones_30 = lbAdd [2102, localize "STR_DUWS_T_jooz8g8q3"];
index_amount_zones_20 = lbAdd [2102, localize "STR_DUWS_T_jooz8g8q2"];
index_amount_zones_15 = lbAdd [2102, localize "STR_DUWS_T_jooz8g8q"];
index_amount_zones_10 = lbAdd [2102, localize "STR_DUWS_T_8gqzfdui"];
index_amount_zones_9 = lbAdd [2102, "9"];
index_amount_zones_8 = lbAdd [2102, "8"];
index_amount_zones_7 = lbAdd [2102, "7"];
index_amount_zones_6 = lbAdd [2102, "6"];
index_amount_zones_5 = lbAdd [2102, "5"];
index_amount_zones_4 = lbAdd [2102, localize "STR_DUWS_T_zonecount4"];
index_amount_zones_3 = lbAdd [2102, "3"];
index_amount_zones_2 = lbAdd [2102, "2"];
index_amount_zones_1 = lbAdd [2102, "1"];
[2102, index_amount_zones_4] call _setDefault;

// MAX DISTANCE FROM HQ
index_max_dist_hq_30 = lbAdd [2103, localize "STR_DUWS_T_blqblz86"];
index_max_dist_hq_40 = lbAdd [2103, "4 km"];
index_max_dist_hq_50 = lbAdd [2103, "5 km"];
index_max_dist_hq_100 = lbAdd [2103, "10 km"];
index_max_dist_hq_150 = lbAdd [2103, localize "STR_DUWS_T_hqdistmax15km"];
index_max_dist_hq_200 = lbAdd [2103, "20 km"];
[2103, index_max_dist_hq_150] call _setDefault;

// MORE URBAN
index_more_urban_yes = lbAdd [2105, localize "STR_DUWS_T_x4zs3lsg2"];
index_more_urban_no = lbAdd [2105, localize "STR_DUWS_T_x4zs3lsg1"];
[2105, index_more_urban_yes] call _setDefault;

// STARTING CP AVAILABLE
index_amount_cp_0 = lbAdd [2104, "0"];
index_amount_cp_10 = lbAdd [2104, "10"];
index_amount_cp_20 = lbAdd [2104, "20"];
index_amount_cp_30 = lbAdd [2104, "30"];
index_amount_cp_50 = lbAdd [2104, "50"];
index_amount_cp_100 = lbAdd [2104, "100"];
index_amount_cp_200 = lbAdd [2104, "200"];
index_amount_cp_300 = lbAdd [2104, "300"];
index_amount_cp_400 = lbAdd [2104, localize "STR_DUWS_T_startcp400"];
[2104, index_amount_cp_100] call _setDefault;

// Reward Multiplier (scales both CP and AP mission payouts)
index_cp_reward_multiplier_1 = lbAdd [2106, "1x"];
index_cp_reward_multiplier_2 = lbAdd [2106, "2x"];
index_cp_reward_multiplier_3 = lbAdd [2106, "3x"];
index_cp_reward_multiplier_4 = lbAdd [2106, "4x"];
index_cp_reward_multiplier_5 = lbAdd [2106, "5x"];
[2106, index_cp_reward_multiplier_1] call _setDefault;

//CP Death Penalty
index_cp_death_penalty_0 = lbAdd [2107, "0"];
index_cp_death_penalty_1 = lbAdd [2107, "1"];
index_cp_death_penalty_2 = lbAdd [2107, "2"];
index_cp_death_penalty_3 = lbAdd [2107, "3"];
index_cp_death_penalty_4 = lbAdd [2107, "4"];
index_cp_death_penalty_5 = lbAdd [2107, "5"];
index_cp_death_penalty_8 = lbAdd [2107, "8"];
index_cp_death_penalty_10 = lbAdd [2107, "10"];
[2107, index_cp_death_penalty_2] call _setDefault;

// BLUFOR starting tier (1-5) -- the campaign begins with BLUFOR's capability ladder already at this
// tier (fnc_WARCOM_init seeds earned + tier, opens the wallet at 0). Tier 1 is infantry from scratch;
// tier 5 opens with jets. The label shows the earned-AP floor of the tier (the rung it seeds) and the
// capability it reaches named in brackets; the infantry floor shows the raw AP alone, since starting
// with nothing unlocked needs no name. The number is the earned counter, not a spendable bank.
index_blufor_ap_t1 = lbAdd [2108, "0"];
index_blufor_ap_t2 = lbAdd [2108, format ["60 (%1)", localize "STR_DUWS_T_tiername2"]];
index_blufor_ap_t3 = lbAdd [2108, format ["200 (%1)", localize "STR_DUWS_T_tiername3"]];
index_blufor_ap_t4 = lbAdd [2108, format ["350 (%1)", localize "STR_DUWS_T_tiername4"]];
index_blufor_ap_t5 = lbAdd [2108, format ["500 (%1)", localize "STR_DUWS_T_tiername5"]];
[2108, index_blufor_ap_t1] call _setDefault;

// OPFOR starting tier -- same ladder.
index_opfor_ap_t1 = lbAdd [2109, "0"];
index_opfor_ap_t2 = lbAdd [2109, format ["60 (%1)", localize "STR_DUWS_T_tiername2"]];
index_opfor_ap_t3 = lbAdd [2109, format ["200 (%1)", localize "STR_DUWS_T_tiername3"]];
index_opfor_ap_t4 = lbAdd [2109, format ["350 (%1)", localize "STR_DUWS_T_tiername4"]];
index_opfor_ap_t5 = lbAdd [2109, format ["500 (%1)", localize "STR_DUWS_T_tiername5"]];
[2109, index_opfor_ap_t2] call _setDefault;

// AI BLU SKILL
index_blu_skill_elite = lbAdd [2110, localize "STR_DUWS_T_7ovwb13n"];
index_blu_skill_commando = lbAdd [2110, localize "STR_DUWS_T_i9ql9ndj"];
index_blu_skill_veteran = lbAdd [2110, localize "STR_DUWS_T_7szkelef"];
index_blu_skill_trained = lbAdd [2110, localize "STR_DUWS_T_njgzfxj4"];
index_blu_skill_rookie = lbAdd [2110, localize "STR_DUWS_T_hjz2qz8j"];
[2110, index_blu_skill_veteran] call _setDefault;

// AI OPF SKILL
index_op_skill_elite = lbAdd [2111, localize "STR_DUWS_T_7ovwb13n"];
index_op_skill_commando = lbAdd [2111, localize "STR_DUWS_T_i9ql9ndj"];
index_op_skill_veteran = lbAdd [2111, localize "STR_DUWS_T_7szkelef"];
index_op_skill_trained = lbAdd [2111, localize "STR_DUWS_T_njgzfxj4"];
index_op_skill_rookie = lbAdd [2111, localize "STR_DUWS_T_hjz2qz8j"];
[2111, index_op_skill_trained] call _setDefault;

// OPFOR Air/Tank Assets
index_opfor_AT_yes_yes = lbAdd [2112, localize "STR_DUWS_T_dge86ern"];
index_opfor_AT_yes_no = lbAdd [2112, localize "STR_DUWS_T_z4j9n0qo"];
index_opfor_AT_no_yes = lbAdd [2112, localize "STR_DUWS_T_reguyhhi"];
index_opfor_AT_no_no = lbAdd [2112, localize "STR_DUWS_T_ps661jx6"];
[2112, index_opfor_AT_yes_yes] call _setDefault;


// ENEMY MULTIPLIER
index_enemyunit_multiplier_1 = lbAdd [2113, "1x"];
index_enemyunit_multiplier_2 = lbAdd [2113, "2x"];
index_enemyunit_multiplier_3 = lbAdd [2113, "3x"];
[2113, index_enemyunit_multiplier_1] call _setDefault;

// Restore selections when the player returns to this screen via the Back button.
if (!isNil "duws_campaign_sel") then {
    { lbSetCurSel [2100 + _forEachIndex, _x]; } forEach duws_campaign_sel;
};

// The preset row lives on the environment screen, which is answered before this one, so there is
// nothing to repaint here -- only the state to drop. The row shows Custom when the player steps
// back to it.
private _display = uiNamespace getVariable ["duws_startup_display", displayNull];
{
    (_display displayCtrl _x) ctrlAddEventHandler ["LBSelChanged", {
        if (duws_preset_applying) exitWith {};
        duws_preset = "custom";
    }];
} forEach [2100,2101,2102,2103,2104,2105,2106,2107,2108,2109,2110,2111,2112,2113];

duws_preset_applying = false;

