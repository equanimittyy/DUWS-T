// Locality: client -- inherited from client/dialog/fnc_startup_next.sqf.
//
// Each combo carries its value as lbData (set in fnc_campaign_menu), so a setting is read straight off
// the selected row -- no per-combo index-to-value switch, and adding an option is a fill-side row only.
// Compound rows unpack a comma list: skill "min,max", the AT combo "attackHeli,heavyArmour".

zones_max_radius       = parseNumber (lbData [2100, lbCurSel 2100]);
zones_min_radius       = parseNumber (lbData [2101, lbCurSel 2101]);
zones_number           = parseNumber (lbData [2102, lbCurSel 2102]);
zones_max_dist_from_hq = parseNumber (lbData [2103, lbCurSel 2103]);
commandpointsblu1      = parseNumber (lbData [2104, lbCurSel 2104]);
cp_reward_multiplier   = parseNumber (lbData [2106, lbCurSel 2106]);
DUWSMP_CP_death_cost   = parseNumber (lbData [2107, lbCurSel 2107]);
WARCOM_blufor_ap       = parseNumber (lbData [2108, lbCurSel 2108]);
WARCOM_opfor_ap        = parseNumber (lbData [2109, lbCurSel 2109]);
enemyunitMultiplier    = parseNumber (lbData [2113, lbCurSel 2113]);
garrison_density       = parseNumber (lbData [2114, lbCurSel 2114]);

blufor_ai_skill = (lbData [2110, lbCurSel 2110]) splitString "," apply { parseNumber _x };
opfor_ai_skill  = (lbData [2111, lbCurSel 2111]) splitString "," apply { parseNumber _x };

// AT combo packs both toggles as "attackHeli,heavyArmour".
private _at = (lbData [2112, lbCurSel 2112]) splitString "," apply { parseNumber _x };
AttackHeli = _at select 0;
HeavyArmor = _at select 1;

if (zones_max_radius <= zones_min_radius) then {
	_swap1 = zones_min_radius;
	_swap2 = zones_max_radius - 25;
	zones_min_radius = _swap2;
	zones_max_radius = _swap1;
};

zones_spacing = zones_max_radius * 0.5;  // edge-to-edge gap: keeps a zone's 1.5x-radius contact trigger off its neighbour
publicVariable "zones_spacing";

publicVariable "zones_max_radius";
publicVariable "zones_min_radius";

publicVariable "zones_number";
publicVariable "zones_max_dist_from_hq";

publicVariable "commandpointsblu1";
publicVariable "garrison_density";

publicVariable "cp_reward_multiplier";
publicVariable "DUWSMP_CP_death_cost";

publicVariable "WARCOM_opfor_ap";
publicVariable "WARCOM_blufor_ap";

publicVariable "AttackHeli";
publicVariable "HeavyArmor";
publicVariable "enemyunitMultiplier";

_min = opfor_ai_skill select 0;
_max = opfor_ai_skill select 1;
_skill = _max - _min;
opfor_ai_skill_random = (random _skill) + _min;
publicVariable "opfor_ai_skill";
publicVariable "opfor_ai_skill_random";

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
