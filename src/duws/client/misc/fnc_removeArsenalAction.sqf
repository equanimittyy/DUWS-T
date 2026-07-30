params ["_obj"];
if (!hasInterface) exitWith {};
if (!isNull _obj) then {
    private _id = _obj getVariable ["arsenalActionID", -1];
    if (_id != -1) then {
        _obj removeAction _id;
        _obj setVariable ["arsenalActionID", nil];
    };
};
