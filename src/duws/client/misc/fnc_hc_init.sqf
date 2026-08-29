// Locality: client -- inherited from client/client_init.sqf.

_playerName = vehiclevarname player;
_var = format["%1_HC_module", _playerName];
_grplogic = createGroup sideLogic;
_HC_module = _grplogic createUnit ["HighCommand",[0,0,0] , [], 0, "NONE"];
_grplogic deleteGroupWhenEmpty true;
_HC_module synchronizeObjectsAdd [player];
missionNamespace setVariable [_var, _HC_module, true];

// One HC subordinate, so the player is not handed command of every BLUFOR unit directly.
_var = format["%1_HC_sub_module", _playerName];
_grplogic = createGroup sideLogic;
_HC_sub_module = _grplogic createUnit ["HighCommandsubordinate",[0,0,0] , [], 0, "NONE"];
_grplogic deleteGroupWhenEmpty true;
_HC_sub_module synchronizeObjectsAdd [_HC_module];
missionNamespace setVariable [_var, _HC_sub_module, true];

_var = format["%1HC", _playerName];
missionNamespace setVariable [_var, [], true];
