
_index = lbCurSel 2103;

_cost = 0;
CAPInUse = true;

_spawnPos = getmarkerpos str blu_hq_markername;
_spawnPos = [(_spawnPos select 0)+500, _spawnPos select 1, (_spawnPos select 2)+500];

_grouptype = [blufor_PLANE_FIGHTER_X];

if (commandpointsblu1 < _cost) exitWith
{
	["info",[localize "STR_DUWS_T_e95mc4lv",format[localize "STR_DUWS_T_p6sb3ply",_cost]]] call bis_fnc_showNotification;
	sleep 15;
	_hcCAP = [player,"hc_CAP"] call BIS_fnc_addCommMenuItem;
	hcCAS = _hcCAP;
	CAPInUse = false;
};

_group = [_spawnPos, WEST, _grouptype, [], [], blufor_ai_skill] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;
player hcsetgroup [_group,""];
[-_cost] remoteExec ["fnc_cp_adjust", 2];
DUWS_number_CAS = DUWS_number_CAS + 1;
_group setGroupId [format[localize "STR_DUWS_T_8mtxjfj3",DUWS_number_CAS]];
hint localize "STR_DUWS_T_gu6cbc5f";
    _speaker = localize "STR_DUWS_T_OVERLORD";
    _message = ([localize "STR_DUWS_T_squadready"] call fnc_cs);
    [_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
    [] remoteExec ["fnc_broadcastRadioChatter", 0];
			 
sleep 600;
_hcCAP = [player,"hc_CAP"] call BIS_fnc_addCommMenuItem;
hcCAS = _hcCAP;
CAPInUse = false;
    



