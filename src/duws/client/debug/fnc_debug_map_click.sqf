// Locality: client. Spawned because a row runs unscheduled and the pick waits on a click. _code gets [[x, y, 0], _args].
params ["_title", "_detail", "_code", ["_args", []]];
[_title, _detail, _code, _args] spawn {
    params ["_title", "_detail", "_code", "_args"];
    private _pos = [format ["<t size='2' color='#00ffff'>%1</t><br/>%2 Close the map to cancel.", _title, _detail]] call fnc_map_pick_pos;
    if (_pos isEqualTo []) exitWith {};
    [[_pos select 0, _pos select 1, 0], _args] call _code;
};
