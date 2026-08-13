// Locality: client -- invoked from a dialog action.


///// DUWS_T  RERUN THE OPFOR FACTION FILE FOR JIP SIDE MISSION GEN
if (hasInterface && isMultiplayer)	then {
	[] call fnc_OPFOR_FactionFile_X;
	sleep 1;
};

if (isnil ("Mission_available")) then {Mission_available = true;publicVariable "Mission_available"};
if (!Mission_available) exitWith {
_speaker = localize "STR_DUWS_T_OVERLORD";
_speakeracteam = localize "STR_DUWS_T_actionteam";
_message = ([localize "STR_DUWS_T_missioncooldown"] call fnc_cs);
_message1 = localize "STR_DUWS_T_missioncooldown2";
// Answers the player who opened the menu, so it stays on their machine: this function is spawned
// by the request-menu action and already runs there. It was addressed to player1, which in co-op
// showed one player the refusal for another player's click.
hint localize "STR_DUWS_T_b68ftbvf";
[_speakeracteam, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 4;
[_speaker, _message1] remoteExec ["fnc_duws_dialogue", 0];
};

if (!((vehiclevarname player) in game_master)) exitWith {hint ([localize "STR_DUWS_T_eck4xh9m"] call fnc_cs)};

// init the array of missions
array_of_missions = [];

failsafe_not_found = true;
failsafe_not_found2 = false;
[] spawn {  // Spawn the secondary failsafe
	uiSleep 20;
	failsafe_not_found2 = true;
};

_handle = [] spawn {  // Spawn the MAIN SEARCH

  _counter = 0;
  _kibot_pos_array_missionPos = [[-99999,-99999,-99999]];

  // Included inside the block, not above it: a spawned block captures no locals.
  private _missionDefs = [
  #include "..\..\shared\includes\mission_types.hpp"
  ];
  // Positions and names the launcher blocks read back, one slot per type. A global because the
  // blocks run later, from the map, and capture nothing.
  DUWS_missionSlots = [];
  { DUWS_missionSlots pushBack [] } forEach _missionDefs;

  _missionCount = [];
  { _missionCount pushBack _forEachIndex } forEach _missionDefs;
  _missionShuffle = _missionCount call BIS_fnc_arrayShuffle;
  // Seven drawn from the shuffled seventeen, not all of them. Every candidate costs a
  // BIS_fnc_findSafePos search before it can be offered, so the full pool spent that search
  // ten extra times to build a list no one reads to the bottom of.
  _missionDraw = 7 min (count _missionCount);

  // Split the draw by difficulty: most offers seat near the frontline (easy, base pay); the rest push
  // deep into enemy ground (hard, a difficulty-scaled bonus). Hard is capped at 2 and easy takes the
  // remainder, so a short pool degrades to fewer hard rather than a negative easy count.
  private _hardCount = 2 min _missionDraw;
  private _easyCount = _missionDraw - _hardCount;
  private _hardOffers = [];   // [name, depth-from-friendly] per hard offer -> multiplier after the loop

  // Weighting for the anchor search. A request is drawn onto the frontline -- the seam where
  // friendly-held ground (HQ, FOBs, captured zones) meets OPFOR-held ground -- with a broad enough
  // spread that offers straddle it into both sides rather than piling on one point. The fortified
  // positions push back: a zone hard, a hardpoint gently, so an offer lands in the no-man's-land near
  // the objectives without dropping onto one. As zones fall the seam advances with the front. Reads the
  // same ownership and hardpoint stores the map readout uses; the friendly-AoI exclusion is server-side.
  // Easy offers use this seam weighting; hard offers instead route to _fnHardScore below -- deep, hugging
  // enemy zones/hardpoints, no repulsion.
  private _frontWidth = 0.3;     // frontline spread: half-weight this fraction either side of the seam; larger spreads wider
  private _zoneRepel   = 1200;   // zone-edge standoff the weight fights for, metres -- aggressive
  private _hpRepel     = 300;    // hardpoint standoff the weight fights for, metres -- soft
  private _frontierBand = 2000;  // metres past an OPFOR zone edge the countryside search spans

  // Hard-offer scoring: deep behind friendly lines, surrounded by enemy placements, behind a gauntlet.
  // Easy offers never read these -- they only feed _fnHardScore.
  private _depthScale  = 1500;   // depth half-weight distance from friendly-held ground, metres
  private _densRadius  = 1500;   // hard cutoff: only enemy zones/hardpoints within this of the spot feed the "surrounded" score, metres. Nothing in range -> the offer is dropped
  private _gauntCorr   = 400;    // approach-corridor half-width, metres -- enemy features inside it gate the objective
  private _hardBand    = 800;    // countryside: metres past a chosen zone edge a hard objective may drift; tighter than the easy band, to hug the cluster

  private _bluHeld = if (isNil "WARCOM_zones_controled_by_BLUFOR") then {[]} else {WARCOM_zones_controled_by_BLUFOR};
  private _friendlyAnchors = +_bluHeld;
  if (!(PosOfBLUHQ isEqualTo [])) then { _friendlyAnchors pushBack PosOfBLUHQ };
  if (!(isNil "Array_of_FOBpos")) then { { _friendlyAnchors pushBack _x } forEach Array_of_FOBpos };

  // Repulsor footprints as [pos, radius]: every zone by its own radius, every live hardpoint as a
  // point (radius 0). Precomputed once -- ownership and the hardpoint registry are fixed for the few
  // seconds this picker runs.
  private _zoneFoot = zone_meta_array apply {_x params ["", "_zp", "_zs"]; [_zp, _zs]};
  private _hpFoot = if (isNil "DUWS_hardpoints") then {[]} else {DUWS_hardpoints apply {[_x select 1, 0]}};

  // OPFOR-held zones: candidates for the countryside branch, and the enemy reference the urban weight
  // measures toward. A zone is OPFOR unless its centre sits in the BLUFOR-held list -- the same
  // control test the capture triggers and the AoI field use.
  private _opforZoneCands = [];
  {
      _x params ["", "_zp", "_zs"];
      if ((_bluHeld findIf {(_x distance2D _zp) < 1}) < 0) then {
          _opforZoneCands pushBack [[_zp, _zs], _zp];
      };
  } forEach zone_meta_array;
  private _opforCenters = _opforZoneCands apply {_x select 1};

  // Enemy attractors for the hard score as [pos, radius]: OPFOR zones by their own radius, hardpoints as
  // points. The repulsors above keep easy offers off these; hard offers are pulled toward them, so the
  // same stores read with opposite sign. The radius lets the density score measure distance to a zone's
  // edge, not its centre, so a large zone reads as near from farther out.
  private _enemyPts = (_opforZoneCands apply {[_x select 1, (_x select 0) select 1]}) + _hpFoot;

  // Soft repulsion from a footprint set: 0 on top of the nearest feature's edge, 0.5 at _scale beyond
  // it, approaching 1 far out. A larger _scale fights harder and from farther. Empty set -> 1 (no push).
  private _fnRepel = {
      params ["_pos", "_feats", "_scale"];
      if (_feats isEqualTo []) exitWith {1};
      private _d = 0 max (selectMin (_feats apply {(_pos distance2D (_x select 0)) - (_x select 1)}));
      _d / (_d + _scale)
  };

  // [_cands, _fnWeight] -> one item. _cands are [item, pos] pairs; _fnWeight scores a position in
  // [0,1]. All weights zero (or no candidates) -> flat random, so a degenerate map never returns nil.
  // The weight blocks read _friendlyAnchors / _opforCenters / the repel sets from this scope -- valid
  // because call keeps the picker's locals in view down the stack.
  private _fnPick = {
      params ["_cands", "_fnWeight"];
      private _items = _cands apply {_x select 0};
      if (_items isEqualTo []) exitWith {objNull};
      private _weights = _cands apply {(_x select 1) call _fnWeight};
      if ((_weights findIf {_x > 0}) < 0) exitWith {selectRandom _items};
      _items selectRandomWeighted _weights
  };

  // Perpendicular distance from feature _f to the approach segment _a->_p, plus the raw projection
  // parameter _t (0 at _a, 1 at _p). Lets the hard score spot enemy features straddling the approach.
  private _fnSegDist = {
      params ["_a", "_p", "_f"];
      private _dx = (_p select 0) - (_a select 0);
      private _dy = (_p select 1) - (_a select 1);
      private _len2 = _dx*_dx + _dy*_dy;
      if (_len2 < 1) exitWith {[_f distance2D _a, 0]};   // _a ~ _p: no meaningful approach line
      private _t = (((_f select 0) - (_a select 0))*_dx + ((_f select 1) - (_a select 1))*_dy) / _len2;
      private _tc = 0 max (_t min 1);
      private _cx = (_a select 0) + _tc*_dx;
      private _cy = (_a select 1) + _tc*_dy;
      [sqrt ((((_f select 0)-_cx)^2) + (((_f select 1)-_cy)^2)), _t]
  };

  // Hard-offer score. Density of nearby enemy placements leads and gates: a spot with no enemy zone or
  // hardpoint within _densRadius scores 0 and is never offered, so hard missions stop landing isolated.
  // Depth behind friendly lines and an approach gauntlet only rank the survivors. selectRandomWeighted
  // normalises, so magnitudes only need to rank. No repulsors: hard offers hug the enemy; the 400 m
  // fnc_pos_claimed gate still keeps them off a zone.
  private _fnHardScore = {
      private _pos = _this;

      // Surrounded by enemy placements -- the lead term and the gate. Linear falloff to the zone edge,
      // summed over every placement inside _densRadius; a hard cutoff, so distant zones no longer leak in
      // through a fat tail. Squared below, so a spot ringed by several placements far outweighs one that
      // merely grazes a single edge. Empty sum -> isolated -> dropped.
      private _dens = 0;
      {
          private _de = 0 max ((_pos distance2D (_x select 0)) - (_x select 1));
          if (_de < _densRadius) then { _dens = _dens + (1 - _de / _densRadius) };
      } forEach _enemyPts;
      if (_dens <= 0) exitWith {0};

      // Deep behind friendly lines -- a mild tiebreak among the surrounded spots, not a rescue for lonely ones.
      private _fDists = if (_friendlyAnchors isEqualTo []) then {[]} else {_friendlyAnchors apply {_pos distance2D _x}};
      private _dFri = if (_fDists isEqualTo []) then {_depthScale} else {selectMin _fDists};
      private _fDepth = _dFri / (_dFri + _depthScale);

      // Run the gauntlet -- enemy features straddling the approach from the nearest friendly anchor.
      private _fGaunt = 0.2;
      if !(_fDists isEqualTo []) then {
          private _a = _friendlyAnchors select (_fDists find _dFri);
          {
              ([_a, _pos, _x select 0] call _fnSegDist) params ["_perp", "_t"];
              if (_perp < _gauntCorr && _t > 0.15 && _t < 0.95) then {
                  _fGaunt = _fGaunt + (1 - _perp / _gauntCorr);
              };
          } forEach _enemyPts;
      };

      (_dens ^ 2) * (0.15 + _fDepth) * _fGaunt
  };

  // Urban weight (easy offers): a bell peaked on the seam. enemyness is 0 in the friendly rear, 0.5 on the
  // seam, ->1 deep in enemy ground; the bell peaks on 0.5 and thins toward either extreme (never zero, so
  // the spread survives), then zones push hard and hardpoints gently. Hard offers exit early to _fnHardScore.
  private _fnUrbanWeight = {
      private _pos = _this;
      if (_hard) exitWith { _pos call _fnHardScore };
      private _dFri = if (_friendlyAnchors isEqualTo []) then {1e6} else {selectMin (_friendlyAnchors apply {_pos distance2D _x})};
      private _dOpf = if (_opforCenters isEqualTo []) then {_dFri} else {selectMin (_opforCenters apply {_pos distance2D _x})};
      private _enemyness = _dFri / ((_dFri + _dOpf) max 1);
      private _front = 1 / (1 + (((_enemyness - _peakEnemyness) / _frontWidth) ^ 2));
      _front
        * ([_pos, _zoneFoot, _zoneRepel] call _fnRepel)
        * ([_pos, _hpFoot, _hpRepel] call _fnRepel)
  };

  // Countryside weight: among OPFOR zones an easy offer favours the front ones -- nearest friendly ground.
  // A hard offer scores each zone by _fnHardScore at its centre, so the draw prefers a zone that is deep,
  // ringed by other enemy placements, and behind a gauntlet. The band search and fnc_pos_claimed give the
  // standoff, no repulsor.
  private _fnZoneWeight = {
      if (_hard) exitWith { _this call _fnHardScore };
      private _dFri = if (_friendlyAnchors isEqualTo []) then {1} else {1 max (selectMin (_friendlyAnchors apply {_this distance2D _x}))};
      1 / _dFri
  };

  while {_counter < _missionDraw} do {

	// Proportional to the draw, not a fixed 0.1 a step: that constant was sized for the old
	// full-pool loop and would now stall the bar at 0.6.
	_progress = _counter / _missionDraw;
	progressLoadingScreen _progress;

	// This offer's difficulty: the last _hardCount of the draw push deep, the rest seat on the front.
	// _hard is read by both weight functions down the call stack -- SQF resolves it dynamically through
	// the callers, the same way the anchors are read. Hard routes to _fnHardScore, easy to the seam.
	private _hard = _counter >= _easyCount;
	private _peakEnemyness = 0.5;   // seam target for the easy urban bell; hard offers ignore it

	// DUWS_T "More Urban": near a building, clear of zone centres.

	_Posfound = false;
	_ZnLocation = [];
	_foundSafePos = [];

	while {!_Posfound} do {
		
		if (moreUrban == 1 && failsafe_not_found2 == false) then {
			// MORE URBAN -- named location, weighted onto the frontline and off the fortifications
			_ZnAnchor = position ([MissionLocations apply {[_x, position _x]}, _fnUrbanWeight] call _fnPick);
			_ZnLocation = [_ZnAnchor, 100, 400,10,0,0.3,0,[],[[0,0],[0,0]]] call BIS_fnc_findSafePos;
			_Building = nearestBuilding _ZnLocation;
			_foundSafePos = [(getpos _Building select 0),(getpos _Building select 1)];
		}else{
			// LESS URBAN -- OPFOR countryside band, front zones favoured. Falls back to the old
			// HQ ring only when every zone is already BLUFOR-held (win state).
			if (_opforZoneCands isEqualTo []) then {
				_foundSafePos = [PosOfBLUHQ, 0, (zones_max_dist_from_hq*1.5),5,0,0.3,0,[],[[0,0],[0,0]]] call BIS_fnc_findSafePos;
			} else {
				([_opforZoneCands, _fnZoneWeight] call _fnPick) params ["_pzp", "_pzs"];
				// Hard drifts a tighter band so the objective stays inside the enemy cluster it picked.
				private _band = if (_hard) then {_hardBand} else {_frontierBand};
				_foundSafePos = [_pzp, _pzs, _pzs + _band,5,0,0.3,0,[],[[0,0],[0,0]]] call BIS_fnc_findSafePos;
			};
		};

		_Posfound = true;

		// Clear of every zone, by the zone's own radius rather than the campaign ceiling. The 400 m
		// on top is roughly what a mission's objective drifts from the anchor offered here
		// (fnc_missionTargetPos), so an anchor accepted a metre outside a zone does not hand that
		// thread fifty rejections and an abort. The drifted position is tested again there, which is
		// the test that actually decides; this one only keeps the offer off a zone.
		if ([_foundSafePos, 400] call fnc_pos_claimed) then {_Posfound = false};

	};
 
	// CREATE AN ARRAY OF POSSIBLE POSITIONS
    _found_dist_away = true;
    _kibot_distances_array = [];
    // for each element of the array of safe positions, 
    for [{_t=1}, {_t <= count _kibot_pos_array_missionPos}, {_t=_t+1}] do 
    {                                         
        // get the index of the element
        _kibot_pos_array_missionPos_index = _t-1;
        // create an array of all missionPos distances to current _foundSafePos.
        _kibot_distances_array = _kibot_distances_array +[(_kibot_pos_array_missionPos select _kibot_pos_array_missionPos_index) distance (_foundSafePos)]; 
    };
    // for each element of the array of distances we just generated...
    for [{_t=1}, {_t<=count _kibot_distances_array}, {_t=_t+1}] do
    {                                           
        // get the index of the tested element
        _kibot_distances_array_index = _t-1;
        // select an element with index so we can check it
        _check = (_kibot_distances_array select _kibot_distances_array_index);
        // check the distances contained in the distances array 1 by 1. If a distance is inferior to defined values, dump it.
        if (_check < 250) then {
            // If any mission is <250m away, tell it to this variable;
            _found_dist_away = false;   
        };
    };

    if (_foundsafePos distance player > 1500
        && _found_dist_away
        && _foundsafePos distance hq_blu1 < (zones_max_dist_from_hq*1.5)) then {

        // A VALID POS HAS BEEN FOUND add the position to the array of missionPos
        _kibot_pos_array_missionPos = _kibot_pos_array_missionPos + [_foundSafePos];
		
		// Clears against the draw, not the pool: the loop stops at _missionDraw, so comparing
		// with the full pool size leaves the failsafe armed and aborts every request.
		if (_counter == _missionDraw-1) then {failsafe_not_found = false;};
		_currentMission = _missionShuffle select _counter;

		// Add each mission type to stratmap array. The row supplies the description, the icon and
		// the launcher; the search supplies the position and the name, which go into the shared
		// slot array the launcher reads back.
		(_missionDefs select _currentMission) params ["", "", "_desc", "_icon", "", "_launcher", "_mcp", "_map", "_mrep", "_mdl"];
		private _name = [0] call fnc_random_name;
		DUWS_missionSlots set [_currentMission, [_foundSafepos, _name]];

		// Reward and deadline lines built from the table, not written into the briefing string, so
		// editing the number in mission_types.hpp moves the map figure and the paid figure together.
		// REP is printed only where the type grants it. The reward-boost and civs-off tags below
		// append to this same description control, which renders the <br /> structured text.
		private _descFull = (localize _desc) + format [localize "STR_DUWS_T_mission_cpap", _mcp, _map];
		if (_mrep > 0) then { _descFull = _descFull + format [localize "STR_DUWS_T_mission_rep", _mrep] };
		_mdl params ["_dlMinH", "_dlMaxH"];
		_descFull = _descFull + (if (_dlMinH >= _dlMaxH)
			then { format [localize "STR_DUWS_T_mission_time_fixed", _dlMinH] }
			else { format [localize "STR_DUWS_T_mission_time_range", _dlMinH, _dlMaxH] });

		// Record hard offers with their depth from friendly-held ground; the loop's tail turns
		// depth into the 1.5x-2x multiplier. Same anchor set the frontier search measured against.
		if (_hard) then {
			private _depth = if (_friendlyAnchors isEqualTo []) then {
				_foundSafepos distance PosOfBLUHQ
			} else {
				selectMin (_friendlyAnchors apply {_foundSafepos distance2D _x})
			};
			_hardOffers pushBack [_name, _depth];
		};

		array_of_missions pushBack [
			_foundSafepos,
			_launcher,
			_name,
			_descFull,
			"",
			_icon,
			1,
			[]
		];

        _counter = _counter + 1;
	};
  };

  // Hard offers pay a difficulty-scaled bonus: their multiplier spans 1.5x (shallowest of the hard
  // set) to 2x (deepest), linear in depth from friendly-held ground. Easy offers get no entry and pay
  // flat. fnc_mission_reward reads DUWS_rewardBoost back on the server as [name, multiplier] pairs.
  // Overwritten each request -- safe because a request is gated shut while a mission is live
  // (Mission_available).
  private _hardDepths = _hardOffers apply {_x select 1};
  private _dmin = if (_hardDepths isEqualTo []) then {0} else {selectMin _hardDepths};
  private _dmax = if (_hardDepths isEqualTo []) then {0} else {selectMax _hardDepths};
  private _span = (_dmax - _dmin) max 1;   // guard a single hard offer (or a depth tie) against /0
  DUWS_rewardBoost = _hardOffers apply {
      _x params ["_nm", "_dp"];
      [_nm, 1.5 + 0.5 * ((_dp - _dmin) / _span)]
  };
  publicVariable "DUWS_rewardBoost";

  // Surface the bonus on the map so the incentive is visible: append a red structured-text tag, with
  // the offer's own multiplier, to each hard offer's description. The description control renders
  // structured text -- the per-type briefings already carry <br /> and their base CP/AP figures.
  {
      _x params ["_bn", "_bm"];
      private _ri = array_of_missions findIf {(_x select 2) isEqualTo _bn};
      if (_ri >= 0) then {
          private _tag = format ["<br /><t color='#ff0000'>%1</t>",
              format [localize "STR_DUWS_T_reward_boost_tag", (round (_bm * 10)) / 10]];
          private _row = array_of_missions select _ri;
          _row set [3, (_row select 3) + _tag];
      };
  } forEach DUWS_rewardBoost;

  // Civs-off CP lift: with no town-rep economy (civilians off, or the RAVAGE/WBK modes) mission CP is
  // paid x1.5 to substitute the absent town-CP faucet (server/missions/fnc_mission_reward.sqf). The gate
  // there is civ_town_rep being empty, which is server-only; CIV_PRESENCE is the broadcast setting that
  // decides it, so the client reproduces the same condition to surface the lift on every offer.
  if ((isNil "CIV_PRESENCE") || {CIV_PRESENCE in ["NONE", "RAVAGE", "WBK"]}) then {
      private _civTag = format ["<br /><t color='#ff0000'>%1</t>", localize "STR_DUWS_T_reward_civsoff_tag"];
      { _x set [3, (_x select 3) + _civTag] } forEach array_of_missions;
  };

  missionSearchDone = 1;
};

_maxTime = diag_tickTime + 60; // max 60s of loadingscreen before failsafe aborts
startLoadingScreen [localize "STR_DUWS_T_dmfmwmfp"];
waitUntil { uiSleep .01; !isNil "missionSearchDone" || diag_tickTime > _maxTime };
missionSearchDone = nil;
endLoadingScreen;
terminate _handle;

if (failsafe_not_found == true) exitWith {hint localize "STR_DUWS_T_crtzxs0j"};

hint localize "STR_DUWS_T_mission_selector_title";

// NOW OPEN THE MAP
_isNight = false;
if ((20 < daytime) OR (daytime < 5)) then {_isNight=true};

// https://community.bistudio.com/wiki/BIS_fnc_StrategicMapOpen
// 0: DISPLAY - parent display. When empty, mission display is used.
// 1: ARRAY - default view position in format [x,y,y] or [x,y]
// 2: ARRAY - list of missions in format:
// 3: ARRAY - list of ORBAT groups in format:
// 4: ARRAY - list of markers revealed in strategic map (will be hidden when map is closed)
// 5: ARRAY - list of custom images in format:
// 6: NUMBER - value in range <0-1> defining weather on strategic map (i.e. density of clouds)
// 7: BOOL - true for night version of strategic map (darker with blue tone)

[(findDisplay 46), getpos player, array_of_missions, [], [], [], 1, _isNight] call BIS_fnc_strategicMapOpen;

