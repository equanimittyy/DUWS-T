// Locality: server -- HandleHeal fires where the healed unit is local, and civilians are the
// server's.
// Listening to the engine rather than offering an action removes the farm the custom heal
// action had: that one credited any civilian, wounded or not, consumed nothing when its 70 %
// roll failed, and drew its FirstAidKits from an arsenal with no limit -- so twenty clicks
// around one town bought the BLUFOR band. Vanilla healing only fires on a unit that is
// actually hurt, and the window below caps what a town can pay out however many are.
params ["_unit", "_healer"];

if (!isServer) exitWith { false };
if (isNull _healer || {!isPlayer _healer}) exitWith { false };

private _idx = _unit getVariable ["civ_locIndex", -1];
if (_idx < 0) exitWith { false };

// Keyed to the campaign economy tick's own sequence number rather than a clock of its own, so
// every town rolls over on the same payout the CP and AP income lands on. A second timer here
// would drift out of phase with it, which is the failure that merged those two in the first
// place. HandleHeal can fire more than once for a single treatment; the same window absorbs it.
private _window = econ_tick;
private _key = format ["civ_heal_window_%1", _idx];
if ((missionNamespace getVariable [_key, -1]) == _window) exitWith { false };

missionNamespace setVariable [_key, _window];
[_idx, 1, "healed_civilian"] call fnc_town_rep_adjust;

false
