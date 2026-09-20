// Locality: client -- invoked from a dialog action.

if (isnil ("Mission_available")) then {Mission_available = true;publicVariable "Mission_available"};
if (!Mission_available) exitWith {
_speaker = localize "STR_DUWS_T_OVERLORD";
_speakeracteam = localize "STR_DUWS_T_actionteam";
_message = ([localize "STR_DUWS_T_missioncooldown"] call fnc_cs);
_message1 = localize "STR_DUWS_T_missioncooldown2";
// Stays on the opener's machine: spawned by the request-menu action, which already runs there.
// Previously addressed to player1, which in co-op showed one player the refusal for another's click.
hint format [localize "STR_DUWS_T_MISSION_COOLDOWN", [] call fnc_mission_gate_time];
[_speakeracteam, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 4;
[_speaker, _message1] remoteExec ["fnc_duws_dialogue", 0];
};

if (!((vehiclevarname player) in game_master)) exitWith {hint format [localize "STR_DUWS_T_eck4xh9m", call fnc_gm_occupant]};

// Gates the whole list, not each type -- one gate per mission would leave the player browsing
// offers none of which can start. Same three-in-game-hour wait fnc_mission_begin enforces
// server-side, checked here (ahead of the cached-offer reuse below, so a cached open obeys it too)
// so the player is told before the map opens.
private _gateLeft = [] call fnc_mission_gate_left;
if (_gateLeft > 0) exitWith {
	hint format [localize "STR_DUWS_T_MISSION_COOLDOWN", [] call fnc_mission_gate_time];
};

// Reuse a still-current offer set instead of re-rolling it: regenerating on every open handed a
// backed-out player seven brand-new missions to reconsider. Persists until one is picked
// (fnc_mission_launch clears it) or the debug re-roll fires; reached only past the Mission_available
// and game_master gates above, so a cached open still obeys the start gate.
private _cachedOffers = missionNamespace getVariable ["DUWS_missionOffers", []];
if !(_cachedOffers isEqualTo []) exitWith {
	array_of_missions = _cachedOffers select 0;
	DUWS_missionSlots = _cachedOffers select 1;
	DUWS_rewardBoost  = _cachedOffers select 2;
	hint localize "STR_DUWS_T_mission_selector_title";
	private _night = (daytime > 20) || (daytime < 5);
	[(findDisplay 46), getpos player, array_of_missions, [], [], [], 1, _night] call BIS_fnc_strategicMapOpen;
};

array_of_missions = [];

failsafe_not_found = true;

_handle = [] spawn {

  _kibot_pos_array_missionPos = [[-99999,-99999,-99999]];

  // Included inside the block, not above it: a spawned block captures no locals.
  private _missionDefs = [
  #include "..\..\shared\includes\mission_types.hpp"
  ];
  // Positions and names the launcher blocks read back, one slot per type. A global because those
  // blocks run later, from the map, and capture nothing.
  DUWS_missionSlots = [];
  { DUWS_missionSlots pushBack [] } forEach _missionDefs;

  // Drawn WITHOUT replacement so the offer set holds distinct types; a type that fails to site is
  // dropped and another drawn, so a slot is never left empty on a no-fit.
  private _bag = [];
  { _bag pushBack _forEachIndex } forEach _missionDefs;

  private _missionDraw = 7 min (count _bag);

  // Two offers push deep into enemy ground (hard, a difficulty-scaled bonus); the rest seat on the
  // frontline (easy, base pay). Any type may fill a hard slot: findSite scores a deep placement 0 where
  // no enemy is near, so a type with no enemy-dense fit yields no hard site and that slot redraws.
  private _hardWant = 2 min _missionDraw;
  private _filled = 0;
  private _hardFilled = 0;
  private _hardOffers = [];   // [name, depth-from-friendly] per hard offer -> multiplier after the loop

  // Anchors for the hard-offer depth calc below: friendly-held ground is HQ, FOBs, and captured zones.
  // Placement weighting lives in server/missions/fnc_mission_findSite, called per offer below, so the
  // debug force tool sites through the same logic instead of a copy.
  private _bluHeld = if (isNil "WARCOM_zones_controled_by_BLUFOR") then {[]} else {WARCOM_zones_controled_by_BLUFOR};
  private _friendlyAnchors = +_bluHeld;
  if (!(PosOfBLUHQ isEqualTo [])) then { _friendlyAnchors pushBack PosOfBLUHQ };
  if (!(isNil "Array_of_FOBpos")) then { { _friendlyAnchors pushBack _x } forEach Array_of_FOBpos };

  // Each pass removes one type from the bag whether or not it sited, so the loop always terminates on an
  // empty bag; _filled advances only on a real offer.
  while {_filled < _missionDraw && {count _bag > 0}} do {

	progressLoadingScreen (_filled / _missionDraw);

	private _wantHard = _hardFilled < _hardWant;
	private _idx = -1;

	// Debug one-shot: force a chosen type into this draw, still through the normal site finder so a
	// no-fit drops it as a random draw would -- placement is never faked. Set by the re-roll picker.
	private _forced = missionNamespace getVariable ["DUWS_dbgForceDrawType", -1];
	if (_forced >= 0 && {(_bag findIf {_x == _forced}) >= 0}) then {
		_idx = _forced;
		_wantHard = false;
		DUWS_dbgForceDrawType = -1;
	} else {
		_idx = selectRandom _bag;
	};
	_bag = _bag select { _x != _idx };

	// Same siting the debug force tool uses. _kibot_pos_array_missionPos is the keep-apart list, seeded
	// with a sentinel at the top of this thread. The rule (column 13) makes siting vet and hand back a
	// convoy destination zone; a [] result means no fit -> draw a different type for this slot.
	private _rule = (_missionDefs select _idx) select 13;
	private _found = [_wantHard, getPos player, _kibot_pos_array_missionPos, _rule] call fnc_mission_findSite;

	if (_found isEqualTo []) then {
		["INFO", "MISSION", format ["site: type %1 found no fit, drawing another", _idx]] call fnc_log;
	} else {
		_found params ["_foundSafePos", "_destZone"];
		_kibot_pos_array_missionPos pushBack _foundSafePos;

		// The row supplies the description, the icon and the launcher; the search supplies the position
		// and the name, which go into the shared slot array the launcher reads back.
		(_missionDefs select _idx) params ["", "_nameKey", "_desc", "_icon", "", "_launcher", "_mcp", "_map", "_mrep", "_mdl", "", "_obj", ["_note", ""]];
		private _name = [0] call fnc_random_name;
		DUWS_missionSlots set [_idx, [_foundSafepos, _name, _destZone]];

		// The stats block mirrors the journal's (fnc_missionTaskCreate) but prints a time band, not a
		// deadline clock: pre-pick, the deadline has not been rolled. Name, type and note all come
		// from mission_types.hpp, so editing a row moves the map and paid figures together. REP
		// prints only where the type grants it.
		private _descFull = localize _desc;
		if (_note != "") then { _descFull = _descFull + "<br />" + format [localize "STR_DUWS_T_mission_note_line", localize _note] };
		_descFull = _descFull + "<br />" + localize "STR_DUWS_T_mission_divider";
		_descFull = _descFull + format [localize "STR_DUWS_T_mission_name_line", localize _nameKey];
		_descFull = _descFull + format [localize "STR_DUWS_T_mission_type_line", (toUpper (_obj select [0,1])) + (_obj select [1])];
		_descFull = _descFull + format [localize "STR_DUWS_T_mission_cpap", _mcp, _map];
		if (_mrep > 0) then { _descFull = _descFull + format [localize "STR_DUWS_T_mission_rep", _mrep] };
		_mdl params ["_dlMinH", "_dlMaxH"];
		_descFull = _descFull + ([_dlMinH, _dlMaxH] call fnc_time_band);

		// Record hard offers with their depth from friendly-held ground; the loop's tail turns depth
		// into the 1.5x-2x multiplier. Same anchor set the frontier search measures against.
		if (_wantHard) then {
			private _depth = if (_friendlyAnchors isEqualTo []) then {
				_foundSafepos distance PosOfBLUHQ
			} else {
				selectMin (_friendlyAnchors apply {_foundSafepos distance2D _x})
			};
			_hardOffers pushBack [_name, _depth];
			_hardFilled = _hardFilled + 1;
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

		["INFO", "MISSION", format ["offer: type=%1 name=%2 pos=%3",
			_idx, _name, _foundSafepos]] call fnc_log;

		_filled = _filled + 1;
	};
  };

  // Offers found -> arm the map open; an empty set (nothing sited anywhere) still trips the failsafe.
  failsafe_not_found = (array_of_missions isEqualTo []);

  // Hard offers pay a difficulty-scaled bonus: multiplier spans 1.5x (shallowest of the hard set) to
  // 2x (deepest), linear in depth from friendly-held ground. Easy offers get no entry and pay flat.
  // fnc_mission_reward reads DUWS_rewardBoost back on the server as [name, multiplier] pairs,
  // overwritten each request -- safe because a request is gated shut while a mission is live
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
  // paid x1.5 to substitute the absent town-CP faucet (server/missions/fnc_mission_reward.sqf). That
  // gate is civ_town_rep being empty (server-only); CIV_PRESENCE is the broadcast setting deciding it,
  // so the client reproduces the same condition here to surface the lift on every offer.
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

// Cache the freshly rolled set so a back-out and reopen shows the same missions rather than a new
// roll. Only a successful roll is stored (past the failsafe above); cleared on pick or debug re-roll.
DUWS_missionOffers = [array_of_missions, DUWS_missionSlots, DUWS_rewardBoost];

hint localize "STR_DUWS_T_mission_selector_title";

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

