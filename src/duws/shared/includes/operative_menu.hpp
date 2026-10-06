
class RscTextWhite: RscText
{
	colorText[] = {1,1,1,1};
};

class operativemaingui
{
	idd = -1;
	movingenable = true;
	onLoad = "uiNamespace setVariable ['duws_operative_display', _this select 0];";

class controls
{
class background_operative: RscText
{
	idc = 1018;
	x = 2.5 * GUI_GRID_W + GUI_GRID_X;
	y = 4 * GUI_GRID_H + GUI_GRID_Y;
	w = 34.5 * GUI_GRID_W;
	h = 16.5 * GUI_GRID_H;
	colorBackground[] = {0,0,0,0.3};
};
class operative_skill_bg: RscText
{
	x = 14.2 * GUI_GRID_W + GUI_GRID_X;
	y = 6.8 * GUI_GRID_H + GUI_GRID_Y;
	w = 12.6 * GUI_GRID_W;
	h = 11 * GUI_GRID_H;
	colorBackground[] = {0,0,0,1};
};
class operative_status_bg: operative_skill_bg
{
	x = 28.2 * GUI_GRID_W + GUI_GRID_X;
	w = 7.1 * GUI_GRID_W;
	h = 6 * GUI_GRID_H;
};
class operative_role_bg: operative_status_bg
{
	y = 14.3 * GUI_GRID_H + GUI_GRID_Y;
	h = 3.5 * GUI_GRID_H;
};
class operative_main_frame: RscFrame
{
	idc = 1800;
	text = "Recruit special operatives";
	x = 3 * GUI_GRID_W + GUI_GRID_X;
	y = 4.5 * GUI_GRID_H + GUI_GRID_Y;
	w = 33.5 * GUI_GRID_W;
	h = 15.5 * GUI_GRID_H;
	colorBackground[] = {0,0,0,0};
};
class operative_exit_button: RscButton
{
	idc = 1600;
	text = "EXIT";
	x = 30.5 * GUI_GRID_W + GUI_GRID_X;
	y = 18.5 * GUI_GRID_H + GUI_GRID_Y;
	w = 5 * GUI_GRID_W;
	h = 1 * GUI_GRID_H;
	action = "closeDialog 0";
};
class operative_recruit_button: RscButton
{
	idc = 1601;
	text = "DEPLOY (X CP)";
	x = 17.5 * GUI_GRID_W + GUI_GRID_X;
	y = 18.5 * GUI_GRID_H + GUI_GRID_Y;
	w = 12 * GUI_GRID_W;
	h = 1 * GUI_GRID_H;
	tooltip = "Add this operative to your squad";
};
class operative_info_button: RscButton
{
	idc = 1602;
	text = "INFO";
	x = 13.5 * GUI_GRID_W + GUI_GRID_X;
	y = 18.5 * GUI_GRID_H + GUI_GRID_Y;
	w = 3.5 * GUI_GRID_W;
	h = 1 * GUI_GRID_H;
	tooltip = "";
	action = "hint ""Open your map and read the ''Special operatives'' tab for more informations about operatives""";	
};
class operative_listbox: RscListbox
{
	idc = 1500;
	x = 3.5 * GUI_GRID_W + GUI_GRID_X;
	y = 6 * GUI_GRID_H + GUI_GRID_Y;
	w = 9.5 * GUI_GRID_W;
	h = 13.5 * GUI_GRID_H;
	onLBSelChanged  = "[] spawn fnc_LBselected";
};
class operative_skill_frame: RscFrame
{
	idc = 1801;
	text = "Skills";
	x = 14 * GUI_GRID_W + GUI_GRID_X;
	y = 6 * GUI_GRID_H + GUI_GRID_Y;
	w = 13 * GUI_GRID_W;
	h = 12 * GUI_GRID_H;
};
class operative_aim_txt: RscTextWhite
{
	idc = 1000;
	text = "Aiming:";
	x = 14.5 * GUI_GRID_W + GUI_GRID_X;
	y = 7 * GUI_GRID_H + GUI_GRID_Y;
	w = 3.5 * GUI_GRID_W;
	h = 1 * GUI_GRID_H;
	tooltip = "General accuracy of the operative with weapons";
};
class operative_spot_txt: RscTextWhite
{
	idc = 1001;
	text = "Spotting:";
	x = 14.5 * GUI_GRID_W + GUI_GRID_X;
	y = 10 * GUI_GRID_H + GUI_GRID_Y;
	w = 4.5 * GUI_GRID_W;
	h = 1 * GUI_GRID_H;
	tooltip = "General spotting skill of the operative";
};
class operative_courage_txt: RscTextWhite
{
	idc = 1002;
	text = "Courage:";
	x = 14.5 * GUI_GRID_W + GUI_GRID_X;
	y = 11.5 * GUI_GRID_H + GUI_GRID_Y;
	w = 4.5 * GUI_GRID_W;
	h = 1 * GUI_GRID_H;
	tooltip = "Morale of the operative";
};
class operative_communications_txt: RscTextWhite
{
	idc = 1003;
	text = "Communications: ";
	x = 14.5 * GUI_GRID_W + GUI_GRID_X;
	y = 13 * GUI_GRID_H + GUI_GRID_Y;
	w = 8 * GUI_GRID_W;
	h = 1 * GUI_GRID_H;
	tooltip = "Affects how quickly recognized targets are shared with the group";
};
class operative_reflexes_txt: RscTextWhite
{
	idc = 1004;
	text = "Reflexes:";
	x = 14.5 * GUI_GRID_W + GUI_GRID_X;
	y = 8.5 * GUI_GRID_H + GUI_GRID_Y;
	w = 4.5 * GUI_GRID_W;
	h = 1 * GUI_GRID_H;
	tooltip = "Affects how quickly the operative can rotate and stabilize its aim";
};
class operative_reload_txt: RscTextWhite
{
	idc = 1005;
	text = "Reload speed:";
	x = 14.5 * GUI_GRID_W + GUI_GRID_X;
	y = 14.5 * GUI_GRID_H + GUI_GRID_Y;
	w = 6.5 * GUI_GRID_W;
	h = 1 * GUI_GRID_H;
	tooltip = "How quickly the operative reloads and switches weapons";
};
class operative_aiming_value: RscTextWhite
{
	idc = 1006;
	text = "xxx";
	x = 18.5 * GUI_GRID_W + GUI_GRID_X;
	y = 7 * GUI_GRID_H + GUI_GRID_Y;
	w = 5 * GUI_GRID_W;
	h = 1 * GUI_GRID_H;
	tooltip = "General accuracy of the operative with weapons";
};
class operative_reflexes_value: RscTextWhite
{
	idc = 1007;
	text = "xxx";
	x = 19.5 * GUI_GRID_W + GUI_GRID_X;
	y = 8.5 * GUI_GRID_H + GUI_GRID_Y;
	w = 4.5 * GUI_GRID_W;
	h = 1 * GUI_GRID_H;
	tooltip = "Affects how quickly the operative can rotate and stabilize its aim";
};
class operative_spotting_value: RscTextWhite
{
	idc = 1008;
	text = "xxx";
	x = 19.5 * GUI_GRID_W + GUI_GRID_X;
	y = 10 * GUI_GRID_H + GUI_GRID_Y;
	w = 4.5 * GUI_GRID_W;
	h = 1 * GUI_GRID_H;
	tooltip = "General spotting skill of the operative";
};
class operative_courage_value: RscTextWhite
{
	idc = 1009;
	text = "xxx";
	x = 19.5 * GUI_GRID_W + GUI_GRID_X;
	y = 11.5 * GUI_GRID_H + GUI_GRID_Y;
	w = 4.5 * GUI_GRID_W;
	h = 1 * GUI_GRID_H;
	tooltip = "Morale of the operative";
};
class operative_communications_value: RscTextWhite
{
	idc = 1010;
	text = "xxx";
	x = 23 * GUI_GRID_W + GUI_GRID_X;
	y = 13 * GUI_GRID_H + GUI_GRID_Y;
	w = 3.5 * GUI_GRID_W;
	h = 1 * GUI_GRID_H;
	tooltip = "Affects how quickly recognized targets are shared with the group";
};
class operative_reload_value: RscTextWhite
{
	idc = 1011;
	text = "xxx";
	x = 21.5 * GUI_GRID_W + GUI_GRID_X;
	y = 14.5 * GUI_GRID_H + GUI_GRID_Y;
	w = 5 * GUI_GRID_W;
	h = 1 * GUI_GRID_H;
	tooltip = "How quickly the operative reloads and switches weapons";
};
class operative_role_frame: RscFrame
{
	idc = 1802;
	text = "Role";
	x = 28 * GUI_GRID_W + GUI_GRID_X;
	y = 13.5 * GUI_GRID_H + GUI_GRID_Y;
	w = 7.5 * GUI_GRID_W;
	h = 4.5 * GUI_GRID_H;
};
class operative_status_frame: RscFrame
{
	idc = 1803;
	text = "Status";
	x = 28 * GUI_GRID_W + GUI_GRID_X;
	y = 6 * GUI_GRID_H + GUI_GRID_Y;
	w = 7.5 * GUI_GRID_W;
	h = 7 * GUI_GRID_H;
};
class operative_status_value: RscTextWhite
{
	idc = 1013;
	text = "xxxx";
	x = 28.5 * GUI_GRID_W + GUI_GRID_X;
	y = 7 * GUI_GRID_H + GUI_GRID_Y;
	w = 6.5 * GUI_GRID_W;
	h = 1 * GUI_GRID_H;
};
class operative_redeploy_cost: RscTextWhite
{
	idc = 1012;
	text = "Redeploy:";
	x = 28.5 * GUI_GRID_W + GUI_GRID_X;
	y = 10 * GUI_GRID_H + GUI_GRID_Y;
	w = 6.5 * GUI_GRID_W;
	h = 1 * GUI_GRID_H;
};
class operative_role_value: RscTextWhite
{
	idc = 1014;
	text = "xxxx";
	x = 28.5 * GUI_GRID_W + GUI_GRID_X;
	y = 15 * GUI_GRID_H + GUI_GRID_Y;
	w = 6.5 * GUI_GRID_W;
	h = 1.5 * GUI_GRID_H;
};
class operative_redeploy_cost_value: RscTextWhite
{
	idc = 1016;
	text = "xxxx";
	x = 28.5 * GUI_GRID_W + GUI_GRID_X;
	y = 11.5 * GUI_GRID_H + GUI_GRID_Y;
	w = 6.5 * GUI_GRID_W;
	h = 1 * GUI_GRID_H;
};
class operative_available_points_txt: RscTextWhite
{
	idc = 1015;
	text = "Available points:";
	x = 14.5 * GUI_GRID_W + GUI_GRID_X;
	y = 16 * GUI_GRID_H + GUI_GRID_Y;
	w = 8 * GUI_GRID_W;
	h = 1 * GUI_GRID_H;
	tooltip = "Available points to spend";
};
class operative_available_points_value: RscTextWhite
{
	idc = 1017;
	text = "xxx";
	x = 22.5 * GUI_GRID_W + GUI_GRID_X;
	y = 16 * GUI_GRID_H + GUI_GRID_Y;
	w = 3.5 * GUI_GRID_W;
	h = 1 * GUI_GRID_H;
	tooltip = "Available points to spend";
};
class operative_add_aiming: RscButton
{
	idc = 1603;
	text = "+";
	x = 25.5 * GUI_GRID_W + GUI_GRID_X;
	y = 7 * GUI_GRID_H + GUI_GRID_Y;
	w = 1 * GUI_GRID_W;
	h = 1 * GUI_GRID_H;
	tooltip = "Spend 1 point on this skill";
	action  = "[0] call DUWS_operator_add"; 
};
class operative_add_reflexes: RscButton
{
	idc = 1604;
	text = "+";
	x = 25.5 * GUI_GRID_W + GUI_GRID_X;
	y = 8.5 * GUI_GRID_H + GUI_GRID_Y;
	w = 1 * GUI_GRID_W;
	h = 1 * GUI_GRID_H;
	tooltip = "Spend 1 point on this skill";
	action  = "[1] call DUWS_operator_add"; 
};
class operative_add_spotting: RscButton
{
	idc = 1605;
	text = "+";
	x = 25.5 * GUI_GRID_W + GUI_GRID_X;
	y = 10 * GUI_GRID_H + GUI_GRID_Y;
	w = 1 * GUI_GRID_W;
	h = 1 * GUI_GRID_H;
	tooltip = "Spend 1 point on this skill";
	action  = "[2] call DUWS_operator_add"; 
};
class operative_add_courage: RscButton
{
	idc = 1606;
	text = "+";
	x = 25.5 * GUI_GRID_W + GUI_GRID_X;
	y = 11.5 * GUI_GRID_H + GUI_GRID_Y;
	w = 1 * GUI_GRID_W;
	h = 1 * GUI_GRID_H;
	tooltip = "Spend 1 point on this skill";
	action  = "[3] call DUWS_operator_add"; 
};
class operative_add_comms: RscButton
{
	idc = 1607;
	text = "+";
	x = 25.5 * GUI_GRID_W + GUI_GRID_X;
	y = 13 * GUI_GRID_H + GUI_GRID_Y;
	w = 1 * GUI_GRID_W;
	h = 1 * GUI_GRID_H;
	tooltip = "Spend 1 point on this skill";
	action  = "[4] call DUWS_operator_add"; 
};
class operative_add_reload: RscButton
{
	idc = 1608;
	text = "+";
	x = 25.5 * GUI_GRID_W + GUI_GRID_X;
	y = 14.5 * GUI_GRID_H + GUI_GRID_Y;
	w = 1 * GUI_GRID_W;
	h = 1 * GUI_GRID_H;
	tooltip = "Spend 1 point on this skill";
	action  = "[5] call DUWS_operator_add"; 
};






};
};
