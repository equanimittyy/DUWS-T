// Locality: client -- inherited from client/client_init.sqf.

// create && synchronize HC with player
_playerName = vehiclevarname player;
_var = format["%1_HC_module", _playerName];
_grplogic = createGroup sideLogic;
_HC_module = _grplogic createUnit ["HighCommand",[0,0,0] , [], 0, "NONE"];
_grplogic deleteGroupWhenEmpty true;
_HC_module synchronizeObjectsAdd [player];
missionNamespace setVariable [_var, _HC_module, true];

// make 1 HC subordinate so that player will not control all blufor forces
_var = format["%1_HC_sub_module", _playerName];
_grplogic = createGroup sideLogic;
_HC_sub_module = _grplogic createUnit ["HighCommandsubordinate",[0,0,0] , [], 0, "NONE"];
_grplogic deleteGroupWhenEmpty true;
_HC_sub_module synchronizeObjectsAdd [_HC_module];
missionNamespace setVariable [_var, _HC_sub_module, true];

//Create a variable for players HC squads
_var = format["%1HC", _playerName];
missionNamespace setVariable [_var, [], true];
