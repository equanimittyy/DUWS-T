// Locality: each client -- the thread remoteExecs it (JIP, keyed on the house) so a shot fired on any
// machine registers. A server-only HitPart would miss every round a client fires.
//
// Point-blank breach: a hit only counts when the shooter is within REACH of the impact, so a locked house
// cannot be cracked from across the street -- the raider has to be at the door. The struck door is resolved
// from the hit and handed to the server breach, which opens that one door and, first time, wakes the house.
// The handler stays (no self-removal): each door is a separate shot, and the server debounces re-hits.
params ["_house"];
if (isNull _house) exitWith {};
#define REACH 5   // TUNABLE, metres from the impact to the shooter

_house addEventHandler ["HitPart", {
    private _hit = _this select 0;
    _hit params ["_target", "_shooter", "", "_pos", "", "_sels"];
    if (isNull _target || {!(missionNamespace getVariable ["DUWS_safehouse_active", false])}) exitWith {};
    if (_shooter distance _pos > REACH) exitWith {};   // not point-blank: no breach

    // Which door: a door's fire-geometry component carries the same index as its door_<n>_rot animation
    // source, so match the number in a hit selection to a door source. No match (an odd model, or a wall
    // hit) -> "" and the server opens the next still-shut door instead, so a point-blank shot always bites.
    private _firstInt = {
        private _r = "";
        { if (_x >= 48 && {_x <= 57}) then { _r = _r + toString [_x] } else { if (_r != "") exitWith {} } } forEach (toArray _this);
        if (_r == "") then { -1 } else { parseNumber _r }
    };
    private _door = "";
    {
        private _n = parseNumber (_x select [5]);
        if ((_sels findIf { (_x call _firstInt) == _n }) >= 0) exitWith { _door = _x };
    } forEach ([_target] call fnc_house_doors);

    [_target, _door] remoteExec ["fnc_raid_safehouse_breach", 2];
}];
