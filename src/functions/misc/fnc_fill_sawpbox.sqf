// 自定义弹药箱填充脚本（支持蓝/红/中立方，刷武器/弹匣/道具/背包）
if (!isServer) exitWith {};
_ammobox = _this select 0;
_side = _this select 1;

// ===================== 【核心：替换这里的类名为你想要的装备】 =====================
// 蓝方（blufor）物资列表
blufor_items = ["B_UavTerminal","Laserdesignator","Item_ToolKit"];
blufor_backpacks = ["B_HMG_01_support_F", "B_HMG_01_support_F", "B_GMG_01_A_weapon_F", "B_GMG_01_A_weapon_F", "B_UGV_02_Demining_backpack_F"];

// 全局清空弹药箱所有物资
clearMagazineCargoGlobal _ammobox;
clearWeaponCargoGlobal _ammobox;
clearItemCargoGlobal _ammobox;
clearBackpackCargoGlobal _ammobox;

// 按阵营填充物资（可自行修改后面的数字调整数量）
switch (_side) do {
	case "blufor": {
		{_ammobox addItemCargoGlobal [_x, 1];} forEach blufor_items;
		{_ammobox addBackpackCargoGlobal [_x, 1];} forEach blufor_backpacks;
	};
};