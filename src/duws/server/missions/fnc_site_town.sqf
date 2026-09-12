// Shared offer-time town finder: nearest town centre not in the enemy band, within reach. Runs client-side in
// the picker, so broadcast state only; civilians off leaves duws_town_circles empty and returns [].
//
// Not shared by the raid and informant finders on purpose: those pick the nearest town of ANY allegiance and
// need the town's radius or list index, neither of which this filters for or returns.
//
// Contract: [_pos, _maxReach] -> [] reject, or [_townCentre] accept.
params ["_pos", "_maxReach"];

private _circles = missionNamespace getVariable ["duws_town_circles", []];
if (_circles isEqualTo []) exitWith { [] };

private _enemyTowns = missionNamespace getVariable ["DUWS_enemy_town_pos", []];
private _bestPos = [];
private _bestD = 1e9;
{
    _x params ["_c", ""];
    if ((_enemyTowns findIf { _x distance2D _c < 5 }) < 0) then {
        private _d = _c distance2D _pos;
        if (_d < _bestD) then { _bestD = _d; _bestPos = _c };
    };
} forEach _circles;

if (_bestPos isEqualTo [] || {_bestD > _maxReach}) exitWith { [] };
[_bestPos]
