// Locality: server. True if this event kind may fire at the player's position. Hostile kinds -- those in a
// rep band topping out <= -10, derived from the table so a new hostile event needs no edit here -- are held
// off only near the player HQ: home base is the one guaranteed safe haven. Friendly towns, captured zones
// and FOBs do NOT hold them off -- forward friendly ground stays fair game. Benign kinds always pass.
// Shared by the runner's roll and the debug spawner so both honour the same gate.
params ["_kind", "_player"];
private _hostileKinds = [];
{
	_x params ["", "", "_hi", "_weights"];
	if (_hi <= -10) then { { _hostileKinds pushBackUnique (_x select 0) } forEach _weights };
} forEach [
#include "..\..\shared\includes\random_event_tables.hpp"
];
private _nearHQ = !(PosOfBLUHQ isEqualTo []) && {(getPos _player) distance2D PosOfBLUHQ <= AOI_HQ_REACH};
!(_kind in _hostileKinds) || {!_nearHQ}
