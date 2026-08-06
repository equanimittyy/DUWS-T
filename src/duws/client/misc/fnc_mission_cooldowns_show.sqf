// Locality: client -- reads the mission clock and hints, so it runs on whoever asked.
/*
    The side-mission cooldown readout, once. Names come from the shared definition table, whose row
    order is the mission type, so a new side mission needs no edit here.
*/
if (!hasInterface) exitWith {};

private _defs = [
#include "..\..\shared\includes\mission_types.hpp"
];

private _lines = [];
{
    // Seconds, not campaign hours: nothing that drags the clock -- resting, a Zeus jumping to
    // night -- shortens the wait. Both floored: the clock is fractional, and an unfloored
    // remainder printed as "0.000381".
    private _remaining = [_forEachIndex] call fnc_mission_cooldown_left;
    private _name = localize (_x select 1);

    _lines pushBack (if (_remaining <= 0) then {
        format ["%1: %2", _name, localize "STR_DUWS_T_COOLDOWN_READY"]
    } else {
        format ["%1: %2m%3s", _name, floor (_remaining / 60), floor (_remaining % 60)]
    });
} forEach _defs;

hint (_lines joinString "\n");
