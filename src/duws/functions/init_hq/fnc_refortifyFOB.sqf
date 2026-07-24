_aaPod = (_this select 3) select 0;
_glPod1 = (_this select 3) select 1;
_glPod2 = (_this select 3) select 2;
_atPod1 = (_this select 3) select 3;
_hmgPod1 = (_this select 3) select 4;
_centerPos = (_this select 3) select 5;
_fob = (_this select 3) select 6;
_id = (_this select 3) select 7;

_cost = 5;

if (commandpointsblu1 > _cost) then {
    [-_cost] remoteExec ["fnc_cp_adjust", 2];
    
    playSound "loadgun";

    {deletevehicle _x} foreach crew _aaPod + [_aaPod];
    {deletevehicle _x} foreach crew _glPod1 + [_glPod1];
    {deletevehicle _x} foreach crew _glPod2 + [_glPod2];
    {deletevehicle _x} foreach crew _atPod1 + [_atPod1];
    {deletevehicle _x} foreach crew _hmgPod1 + [_hmgPod1];

	_object = _this select 0;
    _object removeaction (_this select 2);
	_refortify = true;
    [(getpos _fob), _fob, _refortify, _id] spawn fnc_fortifyFOB;
} else {
    hint format [localize "STR_DUWS_T_p6sb3ply", _cost];
};