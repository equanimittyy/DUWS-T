
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

    // 新增：
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

	case index_amount_cp_400:
    {
    commandpointsblu1 = 400
    };

	case index_amount_cp_200:
    {
    commandpointsblu1 = 200
    };

	case index_amount_cp_100:
    {
    commandpointsblu1 = 100
    };

};

// CP REWARD
_index = lbCurSel 2106;
switch (_index) do {
    case index_cp_reward_multiplier_one:{
        cp_reward_multiplier = 1;
    };
    case index_cp_reward_multiplier_two:{
        cp_reward_multiplier = 2;
    };
};

// CP DEATH PENALTY
_index = lbCurSel 2107;
switch (_index) do {
    case index_cp_death_penalty_five:{
        DUWSMP_CP_death_cost = 5;
    };
    case index_cp_death_penalty_eight:{
        DUWSMP_CP_death_cost = 8;
    };
    case index_cp_death_penalty_ten:{
        DUWSMP_CP_death_cost = 10;
    };
};

// ARMY POWER BLUFOR
_index = lbCurSel 2108;
switch (_index) do
{

    case index_blufor_ap_10:
    {
    WARCOM_blufor_ap = 10;
    };

    case index_blufor_ap_50:
    {
    WARCOM_blufor_ap = 50;
    };

    case index_blufor_ap_80:
    {
    WARCOM_blufor_ap = 80;
    };

    case index_blufor_ap_110:
    {
    WARCOM_blufor_ap = 110;
    };

	case index_blufor_ap_150:
    {
    WARCOM_blufor_ap = 150;
    };

	case index_blufor_ap_200:
    {
    WARCOM_blufor_ap = 200;
    };

};

// ARMY POWER OPFOR
_index = lbCurSel 2109;
switch (_index) do
{
    case index_opfor_ap_50:
    {
    WARCOM_opfor_ap = 50;
    };

    case index_opfor_ap_80:
    {
    WARCOM_opfor_ap = 80;
    };

    case index_opfor_ap_110:
    {
    WARCOM_opfor_ap = 110;
    };

	case index_opfor_ap_170:
    {
    WARCOM_opfor_ap = 170;
    };

	case index_opfor_ap_200:
    {
    WARCOM_opfor_ap = 200;
    };

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

// Apocalypse and civilian init fire here, at final commit, rather than between
// the two setup screens -- otherwise returning via Back and re-confirming would
// re-run them: apocalypse re-scans the whole map, and civ init would lock in
// whichever faction was chosen on the first pass.
if (apocalypse_mode) then {
    if (isServer) then {
        [] spawn fnc_apocalypse_buildings;
    } else {
        [] remoteExec ["fnc_apocalypse_buildings", 2];
    };
};
if (!isNil "CIV_PRESENCE" && {CIV_PRESENCE != "NONE"}) then {
    [] remoteExec ["fnc_civ_init_Tomata", 2];
};

// TELL WARCOM THE ZONE VARIABLES ARE SET
createzone_server = true;
publicVariable "createzone_server";
