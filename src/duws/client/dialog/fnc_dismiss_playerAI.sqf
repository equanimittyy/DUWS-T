// Locality: client -- invoked from a dialog action (shared/includes/squadmng.hpp:49).

_arrayOfYellowUnits = [];

{
    _team = assignedTeam _x;
    if (_team == "YELLOW") then {
        _arrayOfYellowUnits = _arrayOfYellowUnits + [_x];
    }
} forEach units group player;

if (count _arrayOfYellowUnits<1) exitWith {hint localize "STR_DUWS_T_5i5rdhy7"};

_newGroup = createGroup WEST;
_arrayOfYellowUnits join _newGroup; 
player hcSetGroup [_newGroup,""];
_newGroup setVariable ["DUWS_hcCommander", getPlayerUID player, true];

hint localize "STR_DUWS_T_c2hnymzn";