// Locality: server. Gates a zone flagpole's R3F carry on ownership and tethers it to the zone.
//
// FlagPole_F is already an R3F movable class (inherits FlagCarrierCore), so R3F's own scanner attaches
// the carry action -- this only decides when it is live (R3F_LOG_disabled) and reins the pole in on drop.
//
// @param 0 the flagpole
// @param 1 movable? (true while the zone is BLUFOR-held)
// @param 2 zone centre, read only on the first call (arms the tether)

params ["_flg", ["_movable", false], ["_zonePos", []]];

if (!isServer) exitWith {};
if (isNull _flg) exitWith {};

// R3F disables objects by default and refuses every logistics action on a disabled one, so this flag is
// the whole BLUFOR-only restriction. Broadcast so every client and late joiner agrees.
_flg setVariable ["R3F_LOG_disabled", !_movable, true];

// Below arms the pole once; the capture handlers call back only to flip the gate above.
if (_flg getVariable ["DUWS_flagLogInit", false]) exitWith {};
_flg setVariable ["DUWS_flagLogInit", true];

// Own the R3F side-lock to WEST, or R3F stamps the pole its config side and a friendly player finds it
// locked. The disabled gate still governs when it actually moves.
_flg setVariable ["R3F_LOG_proprietaire_verrou", west, true];

// 50 m tether. R3F publishes the carrier on R3F_LOG_est_deplace_par and clears it on release; on a
// release beyond 50 m of the centre, send the pole back to its last good spot and tell the carrier.
private _zc = +_zonePos;
[_flg, _zc] spawn {
	params ["_flg", "_zc"];
	private _lastGood = getPosATL _flg;
	while { !isNull _flg } do {
		waitUntil { sleep 0.5; isNull _flg || !isNull (_flg getVariable ["R3F_LOG_est_deplace_par", objNull]) };
		if (isNull _flg) exitWith {};
		private _carrier = _flg getVariable ["R3F_LOG_est_deplace_par", objNull];

		waitUntil { sleep 0.3; isNull _flg || isNull (_flg getVariable ["R3F_LOG_est_deplace_par", objNull]) };
		if (isNull _flg) exitWith {};

		// Settle before judging where it landed; if it was picked straight back up, wait for the next drop.
		sleep 5;
		if (isNull _flg) exitWith {};
		if (isNull (_flg getVariable ["R3F_LOG_est_deplace_par", objNull])) then {
			if (_flg distance2D _zc > 50) then {
				_flg setPosATL _lastGood;
				if (isPlayer _carrier) then {
					(localize "STR_DUWS_T_flag_placement_failed") remoteExec ["hint", _carrier];
				};
			} else {
				_lastGood = getPosATL _flg;
			};
		};
	};
};
