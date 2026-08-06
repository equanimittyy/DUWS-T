if (!isServer) exitWith {};
_ammobox = _this select 0;
_side = _this select 1;

blufor_items = ["B_UavTerminal","Laserdesignator","Item_ToolKit"];
blufor_backpacks = ["B_HMG_01_support_F", "B_HMG_01_support_F", "B_GMG_01_A_weapon_F", "B_GMG_01_A_weapon_F", "B_UGV_02_Demining_backpack_F"];

clearMagazineCargoGlobal _ammobox;
clearWeaponCargoGlobal _ammobox;
clearItemCargoGlobal _ammobox;
clearBackpackCargoGlobal _ammobox;

switch (_side) do {
	case "blufor": {
		{_ammobox addItemCargoGlobal [_x, 1];} forEach blufor_items;
		{_ammobox addBackpackCargoGlobal [_x, 1];} forEach blufor_backpacks;
	};
};