// Locality: server. One roster for the whole team, held here and changed only here, so two players cannot deploy
// the same operative and a mission's growth reaches every player's menu. What a save keeps of it:
// docs/plans/campaign_persistence_plan.md#the-team.
if (!isServer) exitWith {};

duws_operator_list = [
[0.57,0.39,0.49,0.28,0.51,0.35,"Rifle Scout","Ready","Erik 'Ghost' Stefan","ghost","blufor_SPECOPS_X","H_Shemag_olive_hs",50],
[0.45,0.36,0.38,0.31,0.33,0.52,"Grenadier","Ready","Vincent 'Viper' Schmidt","viper","blufor_SPECOPS_GL_X","H_Booniehat_khk_hs",50],
[0.40,0.35,0.42,0.45,0.40,0.62,"Rifle LAT","Ready","Juan Santana","santana","blufor_SPECOPS_LAT_X","H_Booniehat_grn",50],
[0.35,0.33,0.39,0.38,0.24,0.53,"Rifle AA","Ready","Emil Patel","patel","blufor_SPECOPS_AA_X","H_HelmetB_camo",50],
[0.58,0.25,0.31,0.39,0.24,0.54,"Machinegunner","Ready","Angel Padilla","angel","blufor_SPECOPS_MG_X","H_Beret_02",50],
[0.33,0.29,0.33,0.37,0.41,0.21,"Medic","Ready","Julius 'Jester' Graves","jester","blufor_SPECOPS_MEDIC_X","H_Bandanna_camo",50],
[0.64,0.26,0.55,0.25,0.46,0.31,"Marksman","Ready","Gregory Rasputin","rasputin","blufor_SPECOPS_MARK_X","H_Watchcap_blk",50],
[0.68,0.22,0.58,0.28,0.31,0.21,"Sniper","Ready","Darius Lupea","lupey","blufor_SPECOPS_SNIPER_X","H_Booniehat_grn",50],
[0.38,0.41,0.42,0.29,0.33,0.36,"Saboteur (EXP)","Ready","S.D. 'Snake' Plissken","snake","blufor_SPECOPS_EXP_X","H_MilCap_gry",50],
[0.31,0.33,0.37,0.36,0.41,0.29,"Engineer","Ready","Timo 'Joker' Jokinen","joker","blufor_SPECOPS_ENG_X","H_Watchcap_blk",50],
[0.58,0.40,0.49,0.41,0.24,0.44,"Rifle Scout","Ready","Mario 'Spook' Lopez","spook","blufor_SPECOPS_X","H_Booniehat_grn",50],
[0.49,0.35,0.30,0.36,0.44,0.51,"Grenadier","Ready","Frederick Krueger","freddy","blufor_SPECOPS_GL_X","H_Cap_oli_hs",50],
[0.37,0.35,0.47,0.49,0.23,0.55,"Rifle LAT","Ready","Dirk Diggler","diggler","blufor_SPECOPS_LAT_X","H_Booniehat_khk_hs",50],
[0.30,0.40,0.49,0.41,0.24,0.44,"Rifle HAT","Ready","Sheev Palpatine","sheev","blufor_SPECOPS_HAT_X","H_HelmetB_camo",50],
[0.54,0.32,0.27,0.39,0.30,0.49,"Machinegunner","Ready","Hans Gruber","gruber","blufor_SPECOPS_MG_X","H_Cap_headphones",50],
[0.40,0.21,0.32,0.39,0.45,0.21,"Medic","Ready","Anton Kozlowski","kozlowski","blufor_SPECOPS_MEDIC_X","H_HelmetB_camo",50],
[0.62,0.25,0.57,0.29,0.30,0.27,"Marksman","Ready","Raymond Washington","rayray","blufor_SPECOPS_MARK_X","H_Shemag_olive_hs",50],
[0.41,0.45,0.68,0.27,0.30,0.24,"Sniper","Ready","Ernst Blofeld","blofeld","blufor_SPECOPS_SNIPER_X","H_Beret_red",50],
[0.45,0.32,0.55,0.66,0.61,0.24,"Saboteur (EXP)","Ready","Francisco 'Scar' Scaramanga","scar","blufor_SPECOPS_EXP_X","H_Beret_02",50],
[0.47,0.33,0.48,0.59,0.55,0.36,"Engineer","Ready","Victor Kolesov","kolesov","blufor_SPECOPS_ENG_X","H_MilCap_gry",50]
];
publicVariable "duws_operator_list";

/*
0: aim
1: reflexes
2: spotting
3: courage
4: communications
5: reload speed
6: role
7: status: "Ready" is not paid for yet; "Operating" and "Healed" are
8: name
9: CfgIdentity class, also the operative's key in a save
10: the faction global that names the soldier class, read at deploy so the class follows the faction resolved
11: hat
12: available spendable points
*/

// A publicVariable handler does not fire on the machine that broadcast, so the host repaints its own menu.
DUWS_fnc_operatorPublish = {
    publicVariable "duws_operator_list";
    if (!isNull (uiNamespace getVariable ["duws_operative_display", displayNull])) then { [] call fnc_lbselected };
};

// Tested again here: the client's copy can be a round trip old, so a quick second click would spend a point it lacks.
DUWS_fnc_operatorSpend = {
    params ["_i", "_stat"];
    private _row = duws_operator_list select _i;
    if ((_row select 12) <= 0 || {(_row select _stat) >= 1}) exitWith {};
    _row set [_stat, (_row select _stat) + 0.01];
    _row set [12, (_row select 12) - 1];
    call DUWS_fnc_operatorPublish;
};

// Scaled to 4 CP, the dearest regular soldier in the request menu, and rounded down so only a fully trained operative pays it.
DUWS_fnc_operatorRedeployCost = {
    params ["_row"];
    [floor (4 * ((_row select [0, 6]) call BIS_fnc_arithmeticMean))] call fnc_escalation_cost
};
publicVariable "DUWS_fnc_operatorRedeployCost";

// Reached by remoteExecCall, so the test and the claim run in one unscheduled step and two players cannot both
// take one operative.
DUWS_fnc_operatorClaim = {
    params ["_i", "_requester"];
    private _row = duws_operator_list select _i;
    if !((_row select 7) in ["Ready", "Healed"]) exitWith {};
    private _cost = if ((_row select 7) == "Ready") then { [8] call fnc_escalation_cost } else { [_row] call DUWS_fnc_operatorRedeployCost };
    if (commandpointsblu1 < _cost) exitWith { (localize "STR_DUWS_T_e95mc4lv") remoteExec ["hint", remoteExecutedOwner] };
    [-_cost, format ["purchase by %1", name _requester]] call fnc_cp_adjust;
    _row set [7, "Operating"];
    call DUWS_fnc_operatorPublish;
    [_i, _row] remoteExec ["fnc_operator_recruit", remoteExecutedOwner];
};

// Watched here rather than on the deploying client, so a player who leaves does not strand the operative as deployed.
DUWS_fnc_operatorWatch = {
    params ["_soldier", "_i"];
    waitUntil { sleep 5; !alive _soldier };
    (duws_operator_list select _i) set [7, "Healed"];
    call DUWS_fnc_operatorPublish;
};
