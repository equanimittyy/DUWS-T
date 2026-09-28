// Locality: server. Gates a zone flagpole's R3F carry on ownership, and its factory on ownership and Fortification I.
//
// FlagPole_F is already an R3F movable class (inherits FlagCarrierCore), so R3F's own scanner attaches
// the carry action -- this only decides when it is live (R3F_LOG_disabled). The drop check tethers it to the zone
// (DUWS_fnc_carryDropped).
//
// @param 0 the flagpole
// @param 1 movable? (true while the zone is BLUFOR-held)

params ["_flg", ["_movable", false]];

if (!isServer) exitWith {};
if (isNull _flg) exitWith {};

// R3F disables objects by default and refuses every logistics action on a disabled one, so this flag is
// the whole BLUFOR-only restriction. Broadcast so every client and late joiner agrees.
_flg setVariable ["R3F_LOG_disabled", !_movable, true];
_flg setVariable ["R3F_LOG_CF_disabled", !_movable || {(missionNamespace getVariable ["DUWS_fortLevel", 0]) == 0}, true];
// A capture resets the tier to 0, and the factory's balance restarts with it: BLUFOR inherit nothing.
if (_movable) then { _flg setVariable ["R3F_LOG_CF_credits", 0, true] };

// Below arms the pole once; the capture handlers call back only to flip the gate above.
if (_flg getVariable ["DUWS_flagLogInit", false]) exitWith {};
_flg setVariable ["DUWS_flagLogInit", true];

// Own the R3F side-lock to WEST, or R3F stamps the pole its config side and a friendly player finds it
// locked. The disabled gate still governs when it actually moves.
_flg setVariable ["R3F_LOG_proprietaire_verrou", west, true];

// Seeded so a first drop off the zone sends the pole back: the drop check deletes an object with no good spot as a new build.
_flg setVariable ["DUWS_buildLastGood", getPosATL _flg];
