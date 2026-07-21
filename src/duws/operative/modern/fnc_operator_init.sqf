
duws_operator_list=[
[0.57,0.39,0.49,0.28,0.51,0.35,"Rifle Scout","Ready","Erik 'Ghost' Stefan","ghost",blufor_SPECOPS_X,"H_Shemag_olive_hs",0,50],			
[0.45,0.36,0.38,0.31,0.33,0.52,"Grenadier","Ready","Vincent 'Viper' Schmidt","viper",blufor_SPECOPS_GL_X,"H_Booniehat_khk_hs",0,50],	
[0.40,0.35,0.42,0.45,0.40,0.62,"Rifle LAT","Ready","Juan Santana","santana",blufor_SPECOPS_LAT_X,"H_Booniehat_grn",0,50],				
[0.35,0.33,0.39,0.38,0.24,0.53,"Rifle AA","Ready","Emil Patel","patel",blufor_SPECOPS_AA_X,"H_HelmetB_camo",0,50],						
[0.58,0.25,0.31,0.39,0.24,0.54,"Machinegunner","Ready","Angel Padilla","angel",blufor_SPECOPS_MG_X,"H_Beret_02",0,50],					
[0.33,0.29,0.33,0.37,0.41,0.21,"Medic","Ready","Julius 'Jester' Graves","jester",blufor_SPECOPS_MEDIC_X,"H_Bandanna_camo",0,50],		
[0.64,0.26,0.55,0.25,0.46,0.31,"Marksman","Ready","Gregory Rasputin","rasputin",blufor_SPECOPS_MARK_X,"H_Watchcap_blk",0,50],			
[0.68,0.22,0.58,0.28,0.31,0.21,"Sniper","Ready","Darius Lupea","lupey",blufor_SPECOPS_SNIPER_X,"H_Booniehat_grn",0,50],					
[0.38,0.41,0.42,0.29,0.33,0.36,"Sabotuer (EXP)","Ready","S.D. 'Snake' Plissken","snake",blufor_SPECOPS_EXP_X,"H_MilCap_gry",0,50],		
[0.31,0.33,0.37,0.36,0.41,0.29,"Engineer","Ready","Timo 'Joker' Jokinen","joker",blufor_SPECOPS_ENG_X,"H_Watchcap_blk",0,50],			
[0.58,0.40,0.49,0.41,0.24,0.44,"Rifle Scout","Ready","Mario 'Spook' Lopez","spook",blufor_SPECOPS_X,"H_Booniehat_grn",0,50],			
[0.49,0.35,0.30,0.36,0.44,0.51,"Grenadier","Ready","Frederick Krueger","freddy",blufor_SPECOPS_GL_X,"H_Cap_oli_hs",0,50],				
[0.37,0.35,0.47,0.49,0.23,0.55,"Rifle LAT","Ready","Dirk Diggler","diggler",blufor_SPECOPS_LAT_X,"H_Booniehat_khk_hs",0,50],			
[0.30,0.40,0.49,0.41,0.24,0.44,"Rifle HAT","Ready","Sheev Palpatine","sheev",blufor_SPECOPS_HAT_X,"H_HelmetB_camo",0,50],				
[0.54,0.32,0.27,0.39,0.30,0.49,"Machinegunner","Ready","Hans Gruber","gruber",blufor_SPECOPS_MG_X,"H_Cap_headphones",0,50],				
[0.40,0.21,0.32,0.39,0.45,0.21,"Medic","Ready","Anton Kozlowski","kozlowski",blufor_SPECOPS_MEDIC_X,"H_HelmetB_camo",0,50],				
[0.62,0.25,0.57,0.29,0.30,0.27,"Marksman","Ready","Raymond Washington","rayray",blufor_SPECOPS_MARK_X,"H_Shemag_olive_hs",0,50],		
[0.41,0.45,0.68,0.27,0.30,0.24,"Sniper","Ready","Ernst Blofeld","blofeld",blufor_SPECOPS_SNIPER_X,"H_Beret_red",0,50],					
[0.45,0.32,0.55,0.66,0.61,0.24,"Sabotuer (EXP)","Ready","Francisco 'Scar' Scaramanga","scar",blufor_SPECOPS_EXP_X,"H_Beret_02",0,50],	
[0.47,0.33,0.48,0.59,0.55,0.36,"Engineer","Ready","Victor Kolesov","kolesov",blufor_SPECOPS_ENG_X,"H_MilCap_gry",0,50]				
];


/*
0: aim
1: reflexes
2: spotting
3: courage
4: communications
5: reload speed
6: role
7: status (always "Ready")
8: name
9: CfgIdentity class
10: soldier class
11: hat
12: time before heal
13: available spendable points
*/

// init functions for adding skills
DUWS_operator_add_aim = {
	_selected_index = lbCurSel 1500;
	_selected_soldier = duws_operator_list select _selected_index; // get the selected soldier from the array of soldier using the selected index
	
	_selected_soldier_aim = _selected_soldier select 0;
	_selected_soldier_points = _selected_soldier select 13;
	if (_selected_soldier_points <= 0) exitWith {hint "You have no points available"};
	if (_selected_soldier_aim >= 1) exitWith {hint "This stat is already at the maximum"};
	
	_selected_soldier_aim_new = _selected_soldier_aim + 0.01; // update the variable
	_selected_soldier set [0,_selected_soldier_aim_new];
	
	_selected_soldier_pts_new = _selected_soldier_points - 1;
	_selected_soldier set [13,_selected_soldier_pts_new];
	[] spawn fnc_LBselected;
	hint "New stats will be applied at the next deployment of this operative";
	};
	
DUWS_operator_add_reflexes = {
	_selected_index = lbCurSel 1500;
	_selected_soldier = duws_operator_list select _selected_index; // get the selected soldier from the array of soldier using the selected index
	
	_selected_soldier_reflexes = _selected_soldier select 1;
	_selected_soldier_points = _selected_soldier select 13;
	if (_selected_soldier_points <= 0) exitWith {hint "You have no points available"};
	if (_selected_soldier_reflexes >= 1) exitWith {hint "This stat is already at the maximum"};
	
	_selected_soldier_reflexes_new = _selected_soldier_reflexes + 0.01; // update the variable
	_selected_soldier set [1,_selected_soldier_reflexes_new];
	
	_selected_soldier_pts_new = _selected_soldier_points - 1;
	_selected_soldier set [13,_selected_soldier_pts_new];
	[] spawn fnc_LBselected;
	hint "New stats will be applied at the next deployment of this operative";
	};	
	
DUWS_operator_add_spotting = {
	_selected_index = lbCurSel 1500;
	_selected_soldier = duws_operator_list select _selected_index; // get the selected soldier from the array of soldier using the selected index
	
	_selected_soldier_spotting = _selected_soldier select 2;
	_selected_soldier_points = _selected_soldier select 13;
	if (_selected_soldier_points <= 0) exitWith {hint "You have no points available"};
	if (_selected_soldier_spotting >= 1) exitWith {hint "This stat is already at the maximum"};
	
	_selected_soldier_spotting_new = _selected_soldier_spotting + 0.01; // update the variable
	_selected_soldier set [2,_selected_soldier_spotting_new];
	
	_selected_soldier_pts_new = _selected_soldier_points - 1;
	_selected_soldier set [13,_selected_soldier_pts_new];
	[] spawn fnc_LBselected;
	hint "New stats will be applied at the next deployment of this operative";
	};
	
DUWS_operator_add_courage = {
	_selected_index = lbCurSel 1500;
	_selected_soldier = duws_operator_list select _selected_index; // get the selected soldier from the array of soldier using the selected index
	
	_selected_soldier_courage = _selected_soldier select 3;
	_selected_soldier_points = _selected_soldier select 13;
	if (_selected_soldier_points <= 0) exitWith {hint "You have no points available"};
	if (_selected_soldier_courage >= 1) exitWith {hint "This stat is already at the maximum"};
	
	_selected_soldier_courage_new = _selected_soldier_courage + 0.01; // update the variable
	_selected_soldier set [3,_selected_soldier_courage_new];
	
	_selected_soldier_pts_new = _selected_soldier_points - 1;
	_selected_soldier set [13,_selected_soldier_pts_new];
	[] spawn fnc_LBselected;
	hint "New stats will be applied at the next deployment of this operative";
	};
	
DUWS_operator_add_comms = {
	_selected_index = lbCurSel 1500;
	_selected_soldier = duws_operator_list select _selected_index; // get the selected soldier from the array of soldier using the selected index
	
	_selected_soldier_comms = _selected_soldier select 4;
	_selected_soldier_points = _selected_soldier select 13;
	if (_selected_soldier_points <= 0) exitWith {hint "You have no points available"};
	if (_selected_soldier_comms >= 1) exitWith {hint "This stat is already at the maximum"};
	
	_selected_soldier_comms_new = _selected_soldier_comms + 0.01; // update the variable
	_selected_soldier set [4,_selected_soldier_comms_new];
	
	_selected_soldier_pts_new = _selected_soldier_points - 1;
	_selected_soldier set [13,_selected_soldier_pts_new];
	[] spawn fnc_LBselected;
	hint "New stats will be applied at the next deployment of this operative";
	};
	
DUWS_operator_add_reload = {
	_selected_index = lbCurSel 1500;
	_selected_soldier = duws_operator_list select _selected_index; // get the selected soldier from the array of soldier using the selected index
	
	_selected_soldier_reload = _selected_soldier select 5;
	_selected_soldier_points = _selected_soldier select 13;
	if (_selected_soldier_points <= 0) exitWith {hint "You have no points available"};
	if (_selected_soldier_reload >= 1) exitWith {hint "This stat is already at the maximum"};
	
	_selected_soldier_reload_new = _selected_soldier_reload + 0.01; // update the variable
	_selected_soldier set [5,_selected_soldier_reload_new];
	
	_selected_soldier_pts_new = _selected_soldier_points - 1;
	_selected_soldier set [13,_selected_soldier_pts_new];
	[] spawn fnc_LBselected;
	hint "New stats will be applied at the next deployment of this operative";
	};