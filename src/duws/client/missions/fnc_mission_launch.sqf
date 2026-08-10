// Locality: client -- invoked from a strategic-map mission block, which runs on whoever opened
// the map. The thread itself is remoteExec'd to the server, as it was when each block spelled the
// call out inline.
//
// BIS_fnc_strategicMapOpen runs its per-mission block with no arguments, and an SQF block captures
// no locals, so the block can carry nothing but a literal index. This turns that index back into
// the position and name the search picked for it.
params ["_type"];

private _defs = [
#include "..\..\shared\includes\mission_types.hpp"
];
if (_type < 0 || {_type >= count _defs}) exitWith {
    ["ERROR", "MISSION", format ["launch: no mission type %1", _type]] call fnc_log;
};

private _slot = (DUWS_missionSlots param [_type, []]);
if (_slot isEqualTo []) exitWith {
    ["ERROR", "MISSION", format ["launch: type %1 has no slot; the map offered a mission the search never filled", _type]] call fnc_log;
};

_slot params ["_pos", "_name"];
[_pos, _name] remoteExec [(_defs select _type) select 0, 2];

// Consume the cached batch: its positions were placed once, and the next generation must draw a
// fresh set. Cleared here, the one point both the map picker and the old strategic map reach, so
// neither reopens onto a batch holding the mission just launched.
uiNamespace setVariable ["DUWS_sideMissionCache", nil];
