if (!isServer) exitWith {};
_vehClass = _this select 1;
_position = _this select 2;

_side = WEST;

// The bucket's candidate tokens, each resolved against the BLUFOR AP ladder: a token whose rung is
// unmet resolves to "" and drops out, so the patrol fields only what BLUFOR has earned -- transport
// heli at tier 3, attack heli at tier 4, jet at tier 5.
private _tokens = switch (_vehClass) do {
	case "car":     { ["car"] };
	case "armored": { ["apc", "ifv", "tank"] };
	case "air":     { ["transheli", "attackheli", "plane"] };
	default { [] };
};
private _classes = (_tokens apply { [_x, "BLU"] call DUWS_fnc_tokenClass }) select { _x != "" };
if (_classes isEqualTo []) exitWith {};
private _vehClassName = selectRandom _classes;

private _vehpos = [[(_position select 0)+10, (_position select 1)+0],200,400,15,0,0.5,0,[],[]] call BIS_fnc_findSafePos;
if (_vehClass == "air") then {
	_vec = [random [-1,0,1], random [-1,0,1], 0];
	_vehpos = ((vectorNormalized _vec) vectorMultiply 500) vectorAdd _position;
	_vehpos = [_vehpos select 0, _vehpos select 1, (_vehpos select 2)+800];
};

private _createdVehFnc = [_vehpos,0,_vehClassName,_side] call bis_fnc_spawnvehicle;
private _veh = _createdVehFnc select 0;

if (_vehClass == "air") then {
	_veh engineOn true;
	_veh flyInHeight 150;
};

private _vehGroup = _createdVehFnc select 2;
_vehGroup deleteGroupWhenEmpty true;

{
	_x setSkill blufor_ai_skill_random;
} foreach units _vehGroup;

[_vehGroup] spawn fnc_WARCOM_wp_blu_patrol;
