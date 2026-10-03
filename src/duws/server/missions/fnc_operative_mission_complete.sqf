// Locality: server -- called from fnc_captured and fnc_mission_reward, both server-side.

{
_selected_soldier_aim = _x select 0;
_selected_soldier_reflexes = _x select 1;
_selected_soldier_spotting = _x select 2;
_selected_soldier_courage = _x select 3;
_selected_soldier_comms = _x select 4;
_selected_soldier_reload = _x select 5;

_selected_soldier_aim_new = _selected_soldier_aim + ((round (random 5))/100);
_selected_soldier_reflexes_new = _selected_soldier_reflexes + ((round (random 5))/100);
_selected_soldier_spotting_new = _selected_soldier_spotting + ((round (random 5))/100);
_selected_soldier_courage_new = _selected_soldier_courage + ((round (random 5))/100);
_selected_soldier_comms_new = _selected_soldier_comms + ((round (random 5))/100);
_selected_soldier_reload_new = _selected_soldier_reload + ((round (random 5))/100);

if (_selected_soldier_aim_new > 1) then {_selected_soldier_aim_new = 1};
if (_selected_soldier_reflexes_new > 1) then {_selected_soldier_reflexes_new = 1};
if (_selected_soldier_spotting_new > 1) then {_selected_soldier_spotting_new = 1};
if (_selected_soldier_courage_new > 1) then {_selected_soldier_courage_new = 1};
if (_selected_soldier_comms_new > 1) then {_selected_soldier_comms_new = 1};
if (_selected_soldier_reload_new > 1) then {_selected_soldier_reload_new = 1};

_x set [0,_selected_soldier_aim_new];
_x set [1,_selected_soldier_reflexes_new];
_x set [2,_selected_soldier_spotting_new];
_x set [3,_selected_soldier_courage_new];
_x set [4,_selected_soldier_comms_new];
_x set [5,_selected_soldier_reload_new];
} forEach duws_operator_list;

// setSkill works only where the unit is local, which for a squad's AI is its leader's machine.
{
    private _unit = _x;
    private _pairs = ["aimingAccuracy", "aimingShake", "aimingSpeed", "spotDistance", "spotTime", "courage", "reloadSpeed", "commanding"]
        apply { [_x, (_unit skill _x) + ((round (random 5))/100)] };
    [[_unit, _pairs], { params ["_unit", "_pairs"]; { _unit setSkill _x } forEach _pairs }] remoteExec ["call", _unit];
} forEach (allUnits select { !isPlayer _x && {((units group _x) findIf { isPlayer _x }) >= 0} });

{
_status = _x select 7;
	if (_status == "Operating") then {
	_spendable_pts = _x select 13;
	_spendable_pts_new = _spendable_pts + 20;
	_x set [13,_spendable_pts_new];
	};
} forEach duws_operator_list;
call DUWS_fnc_operatorPublish;
