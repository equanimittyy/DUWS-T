  _handle = createDialog "startup_dialog2";
  waitUntil {dialog};

  /// MAX RADIUS
  index_max_radius_2000 = lbAdd [2100, "2000m"];
  index_max_radius_1750 = lbAdd [2100, "1750m"];
  index_max_radius_1500 = lbAdd [2100, "1500m"];
  index_max_radius_1250 = lbAdd [2100, "1250m"];
  index_max_radius_1000 = lbAdd [2100, "1000m"];
  index_max_radius_750 = lbAdd [2100, "750m"];
  index_max_radius_500 = lbAdd [2100, localize "STR_DUWS_T_xuanxiang1"];
  lbSetCurSel [2100, index_max_radius_500];

  // MIN RADIUS
  index_min_radius_1750 = lbAdd [2101, "1750m"];
  index_min_radius_1500 = lbAdd [2101, "1500m"];
  index_min_radius_1250 = lbAdd [2101, "1250m"];
  index_min_radius_1000 = lbAdd [2101, "1000m"];
  index_min_radius_750 = lbAdd [2101, "750m"];
  index_min_radius_500 = lbAdd [2101, "500m"];
  index_min_radius_350 = lbAdd [2101, localize "STR_DUWS_T_xuanxiang2"];
  lbSetCurSel [2101, index_min_radius_350];

// AMOUNT ENEMY ZONES
index_amount_zones_40 = lbAdd [2102, localize "STR_DUWS_T_jooz8g8q4"];   // 40个战区
index_amount_zones_30 = lbAdd [2102, localize "STR_DUWS_T_jooz8g8q3"];   // 30个战区
index_amount_zones_20 = lbAdd [2102, localize "STR_DUWS_T_jooz8g8q2"];   // 20个战区
index_amount_zones_15 = lbAdd [2102, localize "STR_DUWS_T_jooz8g8q"];
index_amount_zones_10 = lbAdd [2102, localize "STR_DUWS_T_8gqzfdui"];
index_amount_zones_9 = lbAdd [2102, "9"];
index_amount_zones_8 = lbAdd [2102, "8"];
index_amount_zones_7 = lbAdd [2102, "7"];
index_amount_zones_6 = lbAdd [2102, "6"];
index_amount_zones_5 = lbAdd [2102, "5"];
index_amount_zones_4 = lbAdd [2102, localize "STR_DUWS_T_xuanxiang3"];
index_amount_zones_3 = lbAdd [2102, "3"];
index_amount_zones_2 = lbAdd [2102, "2"];
index_amount_zones_1 = lbAdd [2102, "1"];
lbSetCurSel [2102, index_amount_zones_4];

// MAX DISTANCE FROM HQ
index_max_dist_hq_30 = lbAdd [2103, localize "STR_DUWS_T_blqblz86"];
index_max_dist_hq_40 = lbAdd [2103, "4 km"];
index_max_dist_hq_50 = lbAdd [2103, "5 km"];
index_max_dist_hq_100 = lbAdd [2103, "10 km"];
index_max_dist_hq_150 = lbAdd [2103, localize "STR_DUWS_T_xuanxiang4"];
index_max_dist_hq_200 = lbAdd [2103, "20 km"];
lbSetCurSel [2103, index_max_dist_hq_150];

// MORE URBAN
index_more_urban_yes = lbAdd [2105, localize "STR_DUWS_T_x4zs3lsg2"];
index_more_urban_no = lbAdd [2105, localize "STR_DUWS_T_x4zs3lsg1"];
lbSetCurSel [2105, index_more_urban_yes];

// STARTING CP AVAILABLE
index_amount_cp_100 = lbAdd [2104, localize "STR_DUWS_T_9pfd6w8o"];
index_amount_cp_200 = lbAdd [2104, "200"];
index_amount_cp_400 = lbAdd [2104, localize "STR_DUWS_T_xuanxiang5"];
lbSetCurSel [2104, index_amount_cp_100];

// CP Reward Multiplier
index_cp_reward_multiplier_one = lbAdd [2106, localize "STR_DUWS_T_xuanxiang6"];
index_cp_reward_multiplier_two = lbAdd [2106, localize "STR_DUWS_T_xuanxiang7"];
lbSetCurSel [2106, index_cp_reward_multiplier_one];

//CP Death Penalty
index_cp_death_penalty_five = lbAdd [2107, localize "STR_DUWS_T_xuanxiang8"];
index_cp_death_penalty_eight = lbAdd [2107, localize "STR_DUWS_T_xuanxiang9"];
index_cp_death_penalty_ten = lbAdd [2107, localize "STR_DUWS_T_xuanxiang10"];
lbSetCurSel [2107, index_cp_death_penalty_five];

// BLUFOR AP
index_blufor_ap_10 = lbAdd [2108, "10"];
index_blufor_ap_50 = lbAdd [2108, localize "STR_DUWS_T_xuanxiang11"];
index_blufor_ap_80 = lbAdd [2108, "80"];
index_blufor_ap_110 = lbAdd [2108, localize "STR_DUWS_T_57jjx7d6"];
index_blufor_ap_150 = lbAdd [2108, "150"];
index_blufor_ap_200 = lbAdd [2108, localize "STR_DUWS_T_rf9c6kt2"];
lbSetCurSel [2108, index_blufor_ap_50];

// OPFOR AP
index_opfor_ap_50 = lbAdd [2109, "50"];
index_opfor_ap_80 = lbAdd [2109, localize "STR_DUWS_T_xuanxiang12"];
index_opfor_ap_110 = lbAdd [2109, localize "STR_DUWS_T_57jjx7d6"];
index_opfor_ap_170 = lbAdd [2109, "170"];
index_opfor_ap_200 = lbAdd [2109, localize "STR_DUWS_T_rf9c6kt2"];
lbSetCurSel [2109, index_opfor_ap_80];

// AI BLU SKILL
index_blu_skill_elite = lbAdd [2110, localize "STR_DUWS_T_7ovwb13n"];
index_blu_skill_commando = lbAdd [2110, localize "STR_DUWS_T_i9ql9ndj"];
index_blu_skill_veteran = lbAdd [2110, localize "STR_DUWS_T_7szkelef"];
index_blu_skill_trained = lbAdd [2110, localize "STR_DUWS_T_njgzfxj4"];
index_blu_skill_rookie = lbAdd [2110, localize "STR_DUWS_T_hjz2qz8j"];
lbSetCurSel [2110, index_blu_skill_veteran];

// AI OPF SKILL
index_op_skill_elite = lbAdd [2111, localize "STR_DUWS_T_7ovwb13n"];
index_op_skill_commando = lbAdd [2111, localize "STR_DUWS_T_i9ql9ndj"];
index_op_skill_veteran = lbAdd [2111, localize "STR_DUWS_T_7szkelef"];
index_op_skill_trained = lbAdd [2111, localize "STR_DUWS_T_njgzfxj4"];
index_op_skill_rookie = lbAdd [2111, localize "STR_DUWS_T_hjz2qz8j"];
lbSetCurSel [2111, index_op_skill_trained];

// OPFOR Air/Tank Assets
index_opfor_AT_yes_yes = lbAdd [2112, localize "STR_DUWS_T_dge86ern"];
index_opfor_AT_yes_no = lbAdd [2112, localize "STR_DUWS_T_z4j9n0qo"];
index_opfor_AT_no_yes = lbAdd [2112, localize "STR_DUWS_T_reguyhhi"];
index_opfor_AT_no_no = lbAdd [2112, localize "STR_DUWS_T_ps661jx6"];
lbSetCurSel [2112, index_opfor_AT_yes_yes];


// ENEMY MULTIPLIER
index_enemyunit_multiplier_2 = lbAdd [2113, localize "STR_DUWS_T_xuanxiang13"];
index_enemyunit_multiplier_3 = lbAdd [2113, localize "STR_DUWS_T_xuanxiang14"];
lbSetCurSel [2113, index_enemyunit_multiplier_2];

// Restore selections when the player returns to this screen via the Back button.
if (!isNil "duws_campaign_sel") then {
    { lbSetCurSel [2100 + _forEachIndex, _x]; } forEach duws_campaign_sel;
};

// Hardcore hides the zones, so hand-placing them would defeat the mode: force
// random by disabling START-M (idc 1601). Re-evaluated on every entry, so a Back
// to the environment screen that turns hardcore off re-enables it.
if (hardcore_mode_enable) then {
    ctrlEnable [1601, false];
};



