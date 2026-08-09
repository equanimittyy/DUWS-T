// Locality: client -- inherited from client/dialog/fnc_startup_next.sqf.

// MAX RADIUS
_index = lbCurSel 2100;
switch (_index) do
{

    case index_max_radius_500:
    {
    zones_max_radius = 500
    };

    case index_max_radius_750:
    {
    zones_max_radius = 750
    };

    case index_max_radius_1000:
    {
    zones_max_radius = 1000
    };

    case index_max_radius_1250:
    {
    zones_max_radius = 1250
    };

    case index_max_radius_1500:
    {
    zones_max_radius = 1500
    };

    case index_max_radius_1750:
    {
    zones_max_radius = 1750
    };

    case index_max_radius_2000:
    {
    zones_max_radius = 2000
    };

};

// MIN RADIUS
_index = lbCurSel 2101;
switch (_index) do
{
	case index_min_radius_350:
    {
    zones_min_radius = 350
    };

    case index_min_radius_500:
    {
    zones_min_radius = 500
    };

    case index_min_radius_750:
    {
    zones_min_radius = 750
    };

    case index_min_radius_1000:
    {
    zones_min_radius = 1000
    };

    case index_min_radius_1250:
    {
    zones_min_radius = 1250
    };

    case index_min_radius_1500:
    {
    zones_min_radius = 1500
    };

    case index_min_radius_1750:
    {
    zones_min_radius = 1750
    };

};

// ZONES NUMBER
_index = lbCurSel 2102;
switch (_index) do
{

    case index_amount_zones_1:
    {
    zones_number = 1
    };

    case index_amount_zones_2:
    {
    zones_number = 2
    };

    case index_amount_zones_3:
    {
    zones_number = 3
    };

    case index_amount_zones_4:
    {
    zones_number = 4
    };

    case index_amount_zones_5:
    {
    zones_number = 5
    };

    case index_amount_zones_6:
    {
    zones_number = 6
    };

    case index_amount_zones_7:
    {
    zones_number = 7
    };

    case index_amount_zones_8:
    {
    zones_number = 8
    };

    case index_amount_zones_9:
    {
    zones_number = 9
    };

    case index_amount_zones_10:
    {
    zones_number = 10
    };

    case index_amount_zones_15:
    {
    zones_number = 15
    };

    case index_amount_zones_20: { zones_number = 20 };
    case index_amount_zones_30: { zones_number = 30 };
    case index_amount_zones_40: { zones_number = 40 };

};

// MAX DIST FROM HQ
_index = lbCurSel 2103;
switch (_index) do
{

	case index_max_dist_hq_30:
    {
    zones_max_dist_from_hq = 3000;
    };

	case index_max_dist_hq_40:
    {
    zones_max_dist_from_hq = 4000;
    };

    case index_max_dist_hq_50:
    {
    zones_max_dist_from_hq = 5000;
    };

    case index_max_dist_hq_100:
    {
    zones_max_dist_from_hq = 10000;
    };

    case index_max_dist_hq_150:
    {
    zones_max_dist_from_hq = 15000;
    };

    case index_max_dist_hq_200:
    {
    zones_max_dist_from_hq = 20000;
    };
};

// MORE URBAN
_index = lbCurSel 2105;
switch (_index) do
{

    case index_more_urban_yes:
    {
    moreUrban = 1;
    };

    case index_more_urban_no:
    {
    moreUrban = 0;
    };

};


// Starting CP
_index = lbCurSel 2104;
switch (_index) do
{
	case index_amount_cp_0:   { commandpointsblu1 = 0 };
	case index_amount_cp_10:  { commandpointsblu1 = 10 };
	case index_amount_cp_20:  { commandpointsblu1 = 20 };
	case index_amount_cp_30:  { commandpointsblu1 = 30 };
	case index_amount_cp_50:  { commandpointsblu1 = 50 };
	case index_amount_cp_100: { commandpointsblu1 = 100 };
	case index_amount_cp_200: { commandpointsblu1 = 200 };
	case index_amount_cp_300: { commandpointsblu1 = 300 };
	case index_amount_cp_400: { commandpointsblu1 = 400 };
};

// CP REWARD
_index = lbCurSel 2106;
switch (_index) do {
    case index_cp_reward_multiplier_1:{
        cp_reward_multiplier = 1;
    };
    case index_cp_reward_multiplier_2:{
        cp_reward_multiplier = 2;
    };
    case index_cp_reward_multiplier_3:{
        cp_reward_multiplier = 3;
    };
    case index_cp_reward_multiplier_4:{
        cp_reward_multiplier = 4;
    };
    case index_cp_reward_multiplier_5:{
        cp_reward_multiplier = 5;
    };
};

// CP DEATH PENALTY
_index = lbCurSel 2107;
switch (_index) do {
    case index_cp_death_penalty_0:{
        DUWSMP_CP_death_cost = 0;
    };
    case index_cp_death_penalty_1:{
        DUWSMP_CP_death_cost = 1;
    };
    case index_cp_death_penalty_2:{
        DUWSMP_CP_death_cost = 2;
    };
    case index_cp_death_penalty_3:{
        DUWSMP_CP_death_cost = 3;
    };
    case index_cp_death_penalty_4:{
        DUWSMP_CP_death_cost = 4;
    };
    case index_cp_death_penalty_5:{
        DUWSMP_CP_death_cost = 5;
    };
    case index_cp_death_penalty_8:{
        DUWSMP_CP_death_cost = 8;
    };
    case index_cp_death_penalty_10:{
        DUWSMP_CP_death_cost = 10;
    };
};

// ARMY POWER BLUFOR
_index = lbCurSel 2108;
switch (_index) do
{
    // Starting tier -> starting AP: the seven rows are the ladder's rungs plus zero, so a preset
    // lands one on each tier. fnc_WARCOM_init seeds the earned counter and tier from this value.
    case index_blufor_ap_t0: { WARCOM_blufor_ap = 0; };
    case index_blufor_ap_t1: { WARCOM_blufor_ap = 10; };
    case index_blufor_ap_t2: { WARCOM_blufor_ap = 40; };
    case index_blufor_ap_t3: { WARCOM_blufor_ap = 65; };
    case index_blufor_ap_t4: { WARCOM_blufor_ap = 100; };
    case index_blufor_ap_t5: { WARCOM_blufor_ap = 136; };
    case index_blufor_ap_t6: { WARCOM_blufor_ap = 150; };
    case index_blufor_ap_t7: { WARCOM_blufor_ap = 200; };
};

// ARMY POWER OPFOR
_index = lbCurSel 2109;
switch (_index) do
{
    // Same rungs on the OPFOR side.
    case index_opfor_ap_t0: { WARCOM_opfor_ap = 0; };
    case index_opfor_ap_t1: { WARCOM_opfor_ap = 10; };
    case index_opfor_ap_t2: { WARCOM_opfor_ap = 40; };
    case index_opfor_ap_t3: { WARCOM_opfor_ap = 65; };
    case index_opfor_ap_t4: { WARCOM_opfor_ap = 100; };
    case index_opfor_ap_t5: { WARCOM_opfor_ap = 136; };
    case index_opfor_ap_t6: { WARCOM_opfor_ap = 150; };
    case index_opfor_ap_t7: { WARCOM_opfor_ap = 200; };
};

// AI BLUFOR Skill
_index = lbCurSel 2110;
switch (_index) do
{

    case index_blu_skill_elite:
    {
    blufor_ai_skill = [0.85,1.0];
    };

    case index_blu_skill_commando:
    {
    blufor_ai_skill = [0.75,0.85];
    };

    case index_blu_skill_veteran:
    {
    blufor_ai_skill = [0.55,0.75];
    };

    case index_blu_skill_trained:
    {
    blufor_ai_skill = [0.35,0.55];
    };

    case index_blu_skill_rookie:
    {
    blufor_ai_skill = [0.25,0.35];
    };

};

// AI opf Skill
_index = lbCurSel 2111;
switch (_index) do
{

    case index_op_skill_elite:
    {
    opfor_ai_skill = [0.85,1.0];
    };

    case index_op_skill_commando:
    {
    opfor_ai_skill = [0.75,0.85];
    };

    case index_op_skill_veteran:
    {
    opfor_ai_skill = [0.55,0.75];
    };

    case index_op_skill_trained:
    {
    opfor_ai_skill = [0.35,0.55];
    };

    case index_op_skill_rookie:
    {
    opfor_ai_skill = [0.25,0.35];
    };

};


// OPFOR AIR/TANK ASSETS
_index = lbCurSel 2112;
switch (_index) do
{

    case index_opfor_AT_yes_yes:
    {
    AttackHeli = 1;
	HeavyArmor = 1;
    };

    case index_opfor_AT_yes_no:
    {
    AttackHeli = 1;
	HeavyArmor = 0;
    };

    case index_opfor_AT_no_yes:
    {
    AttackHeli = 0;
	HeavyArmor = 1;
    };

    case index_opfor_AT_no_no:
    {
    AttackHeli = 0;
	HeavyArmor = 0;
    };

};

// ENEMY MULTIPLIER
_index = lbCurSel 2113;
switch (_index) do
{
    case index_enemyunit_multiplier_1:
    {
    enemyunitMultiplier = 1;
    };

    case index_enemyunit_multiplier_2:
    {
    enemyunitMultiplier = 2;
    };

    case index_enemyunit_multiplier_3:
    {
    enemyunitMultiplier = 3;
    };

};

// CHECK IF MAX/MIN RADIUS PARAMETERS CORRECT
if (zones_max_radius <= zones_min_radius) then {
	_swap1 = zones_min_radius;
	_swap2 = zones_max_radius - 25;
	zones_min_radius = _swap2;
	zones_max_radius = _swap1;
};

zones_spacing = zones_max_radius * 1.8;  // zone distance from center to center
publicVariable "zones_spacing";

publicVariable "zones_max_radius";
publicVariable "zones_min_radius";

publicVariable "zones_number";
publicVariable "zones_max_dist_from_hq";

publicVariable "moreUrban";
publicVariable "commandpointsblu1";

publicVariable "cp_reward_multiplier";
publicVariable "DUWSMP_CP_death_cost";

publicVariable "WARCOM_opfor_ap";
publicVariable "WARCOM_blufor_ap";

publicVariable "AttackHeli";
publicVariable "HeavyArmor";
publicVariable "enemyunitMultiplier";

//OPFOR AI SKILL
_min = opfor_ai_skill select 0;
_max = opfor_ai_skill select 1;
_skill = _max - _min;
opfor_ai_skill_random = (random _skill) + _min;
publicVariable "opfor_ai_skill";
publicVariable "opfor_ai_skill_random";

//BLUFOR AI SKILL
_min = blufor_ai_skill select 0;
_max = blufor_ai_skill select 1;
_skill = _max - _min;
blufor_ai_skill_random = (random _skill) + _min;
publicVariable "blufor_ai_skill";
publicVariable "blufor_ai_skill_random";

// This reads the live campaign combos, so it runs while startup_dialog2 is still
// open (from START-R / START-M) and is safe to re-run when the player steps Back
// and forward. The fire-once commit (apocalypse scan, civ init, createzone_server,
// chosen_settings) is deferred to the callsign screen's Confirm (fnc_callsign_confirm)
// so it never repeats on a Back/re-confirm.
