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

// The picked set is spent: clear the picker's cache (fnc_stratmap) so the next availability window
// rolls a fresh set instead of re-offering this now-live mission.
DUWS_missionOffers = [];
