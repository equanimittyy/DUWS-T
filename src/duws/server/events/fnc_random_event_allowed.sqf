// Locality: server. True if this event kind may fire at the player's position. Hostile kinds -- those in a
// rep band topping out <= -10, derived from the table so a new hostile event needs no edit here -- are held
// off a player standing on BLUFOR-covered ground: a turned town does not reach a player already safe on
// friendly territory. Benign kinds always pass. Shared by the runner's roll and the debug spawner so both
// honour the same AoI gate.
params ["_kind", "_player"];
private _hostileKinds = [];
{
	_x params ["", "", "_hi", "_weights"];
	if (_hi <= -10) then { { _hostileKinds pushBackUnique (_x select 0) } forEach _weights };
} forEach [
#include "..\..\shared\includes\random_event_tables.hpp"
];
!(_kind in _hostileKinds) || {!([getPos _player] call fnc_aoi_blufor_covers)}
