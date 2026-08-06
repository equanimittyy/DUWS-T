// Server file: compiled by fnc_factions_check (server_init.sqf); the functions it defines run
// wherever their callers do, client dialogs included.
// First non-empty candidate, else []. Never nil: `select 0` on an empty array returns nil, and
// assigning nil *undefines* the variable -- a faction with no static AA left _turretAA undefined
// and took down the whole array fnc_parseFaction returns.
fnc_selectNonEmpty = compileFinal {
	private _found = _this select {!(_x isEqualTo [])};
	if (_found isEqualTo []) exitWith {[]};
	_found select 0
};

// spawn, do not call
fnc_vehiclePostInit = compileFinal {
		params ["_entity", ["_side", west]];

		// let the vehicle and crew spawn in
		sleep 1;
		[_entity, false, ["showcamonethull", 0.5, "showcamonetturret", 0.5, "showcamonetcannon", 0.5, "showslathull", 0.5]] call BIS_fnc_initVehicle;
		
		if (_entity isKindOf "ParachuteBase") exitWith {};

		// only AI-crewed vehicles of this side: skip empty, civilian, player-crewed, UAV
		if ({alive _x && {!isPlayer _x}} count crew _entity == 0 || {side _entity == civilian} || {side _entity != _side} || {unitIsUAV _entity}) exitWith {};		
		
		// wait for this side's foot units to exist
		waitUntil {sleep 1; {alive _x && {!isPlayer _x || {isPlayer leader _x}} && {side _x == _side} && {isNull objectParent _x}} count allUnits > 0 };

		_factionUnitRandom = selectRandom (allUnits select {alive _x && {!isPlayer _x} && {side _x == _side} && {isNull objectParent _x}});
		_factionVoice = speaker _factionUnitRandom;
		
		// vanilla fallback asset in use: reskin the crew (loadout/voice) and texture to the real faction
		if ( faction _factionUnitRandom != getText(configfile >> "CfgVehicles" >> typeOf _entity >> "faction") ) then {
		crew _entity select {alive _x} apply { _x setUnitLoadout getUnitLoadout _factionUnitRandom; _x setSpeaker _factionVoice };

			_availableTextures = ("true" configClasses (configfile >> "CfgVehicles" >> typeOf _entity >> "TextureSources") apply {configName _x}) - [(([_entity] call BIS_fnc_getVehicleCustomization select 0) select 0)];
			_availableTextureGeneric = selectRandom (_availableTextures select {"blu" in toLower _x || {"black" in toLower _x} || {"oliv" in toLower _x} || {"guer" in toLower _x} || {"gre" in toLower _x} || {"eaf" in toLower _x} || {"ion" in toLower _x} || {"idap" in toLower _x}});
			if (!isNil "_availableTextureGeneric") then { [_entity, _availableTextureGeneric] call BIS_fnc_initVehicle };
		};
};


// No in-tree caller left, but kept: it is publicVariable'd with the other detection helpers, so
// a third-party faction file may still call it -- and a missing broadcast name fails silently at
// the call site, not anywhere a linter or the boot self-check would catch.
fnc_padZero = compileFinal {
	switch (True) do { 
		case (_this < 10): {format ["0%1", str _this]};
		default {str _this};
	};
};

// cost of a type via a throwaway server-local reference object
fnc_enumCost = compileFinal {
	params ["_typeName"];
	// ships spawn multiple objects; skip the ref-object path and flat-rate them
	if (_typeName isKindOf "Ship") exitWith {20};
	_refObj = _typeName createVehicleLocal [1000,1000,2000];
	_refObj setVariable ["BIS_enableRandomization", false];
	_refObj setPhysicsCollisionFlag false;
	_refObj enableSimulation false;
	getPosATL _refObj nearObjects 300 select {_x isNotEqualTo _refObj} apply { deleteVehicle _x };
	_cost = _refObj call fnc_evalVehicleCost;
	deleteVehicle _refObj;
	_cost
};

fnc_enumCostFormatted = compileFinal {
	_typeName = _this;
	_typeCost = _typeName call fnc_enumCost;
	_typeDisplayName = getText (configFile >> "CfgVehicles" >> _typeName >> "displayName");
	_typeCostFormatted = [_typeName, _typeDisplayName + ' (' + str(_typeCost) + 'CP)', _typeCost];
	_typeCostFormatted
};

// heuristic vehicle value from type, weapons, armour, sensors, threat and capacity
fnc_evalVehicleCost = {
	_veh  = _this;
	_vehType = typeOf _veh;
	
	_typeMultiplier = switch true do {
		case (getText (configFile >> "CfgVehicles" >> _vehType >> "vehicleClass") isEqualTo "Autonomous")	:	{3};	// UAV
		case (_veh isKindOf "Plane" )		:	{2.5};
		case (_veh isKindOf "Helicopter" )	:	{2};
		case (_veh isKindOf "Tank" )	:	{1.1};
		case (_veh isKindOf "Car" )	:	{1.5};
		case (_veh isKindOf "StaticWeapon" )	:	{2};
		default {1};
	};
	
	_cost = 5;	// base cost
	_costModifier = 0;
	_threatModifier = 0;
	
	getArray (configFile >> "CfgVehicles" >> _vehType >> "threat") params [["_threatToInf", 0], ["_threatToArmor", 0], ["_threatToAir", 0]];	// {Soft, Armor, Air}
	_threatModifier = switch selectMax [_threatToInf, _threatToArmor, _threatToAir] do {
		case _threatToInf : {1.3};
		case _threatToArmor : {1.8};
		case _threatToAir : {3.5};
		default {1}
	};
	
	_armorModifier = linearConversion [0, 1000, getNumber (configFile >> "CfgVehicles" >> _vehType >> "armor"), 1, 2];

	_sensors = flatten listVehicleSensors _veh;
	_sensors = _sensors arrayIntersect _sensors;	// self-intersect to dedupe the sensor list
	_sensorModifier = count _sensors * 3;
	
	_turretCount = count allTurrets [_veh, false];
	_magazineCount = count magazines _veh;
	_seatCount  = count fullCrew [_veh, "", true];
	_pylonCount  = count getAllPylonsInfo _veh;
	_passengers = getNumber (configFile >> "CfgVehicles" >> _vehType >> "transportSoldier");
	_weaponCount = count weapons _veh;
	
	_isVehArty = getNumber (configFile >> "CfgVehicles" >> _vehType >> "artilleryScanner") isEqualTo 1;
	_isVehMed = getNumber (configfile >> "CfgVehicles" >> _vehType  >> "attendant") isEqualTo 1;
	_isVehSupply = true in (["transportAmmo","transportFuel", "transportRepair"] apply {getNumber (configfile >> "CfgVehicles" >> (_vehType)  >> _x) isNotEqualTo 0});
	_weaponTypes = flatten ((flatten ("getArray (_x >> 'weapons') isNotEqualTo []" configClasses (configFile >> "CfgVehicles" >> _vehType >> "Turrets") apply {getArray (_x >> 'weapons')})) apply { [configFile >> "CfgWeapons" >> _x, true] call BIS_fnc_returnParents }) apply {toLowerANSI _x};
	// _weaponTypes holds weapon parent classnames: MGunCore, CannonCore, GMG_F, MGun, LauncherCore

	if (_isVehMed || _isVehSupply) then						{_costModifier = _costModifier + 40};
		
	if (_isVehArty) then									 {_costModifier = _costModifier + 55};
		
	if ("cannoncore" in _weaponTypes) then					 {_costModifier = _costModifier + 0};
		
	if ("launchercore" in _weaponTypes) then				 {_costModifier = _costModifier + 15};
		
	if ("autocannon_base_f" in _weaponTypes) then			 {_costModifier = _costModifier + 10};
		
	if ("gmg_f" in _weaponTypes) then						 {_costModifier = _costModifier + 20};
		
	if ("mguncore" in _weaponTypes) then					 {_costModifier = _costModifier + 5};
		
	
	_cost = _cost + _costModifier + _turretCount + _magazineCount + _weaponCount + _pylonCount + _seatCount + _sensorModifier;
	_cost = _cost * _threatModifier * _armorModifier * _typeMultiplier;
	round linearConversion [0, 400, _cost, 5, 100, true]
};


// editor subcategory of an object or classname -- a quick vehicle-type signal
fnc_getEditorCategory = compileFinal {
	toLowerANSI getText ( configfile >> "CfgVehicles" >> ( if (typeName _this isEqualTo "OBJECT") then [{typeOf _this, _this}] ) >> "editorSubcategory" );
};

fnc_factionGetFilteredByEditorSubcat = {
	params ["_factionData", "_factionFilter"];
	_factionDataFiltered = _factionData select {_factionFilter in toLowerANSI getText ( configfile >> "CfgVehicles" >> _x >> "editorSubcategory" ) && {getNumber (configFile >> "CfgVehicles" >> _x >> "scopeCurator") == 2 || {getNumber (configFile >> "CfgVehicles" >> _x >> "scope") == 2 }}};
	
	// fallback for non-standard editor categories: less accurate, but better than empty
	if (_factionDataFiltered isEqualTo []) then {
		// only editor/Zeus-available objects (scope/scopeCurator == 2)
		_factionDataFiltered = _factionData select {getNumber (configFile >> "CfgVehicles" >> _x >> "scopeCurator") == 2 || {getNumber (configFile >> "CfgVehicles" >> _x >> "scope") == 2 }};
		_factionDataFiltered =  switch true do {
			case ("person" in _factionFilter) :	 	{_factionDataFiltered select {_x iskindOf "CAManBase"}};
			case ("turrets" in _factionFilter) :	{_factionDataFiltered select {_x iskindOf "StaticWeapon"}};
			case ("aas" in _factionFilter) :		{_factionDataFiltered select {_x isKindOf "LandVehicle" && {getNumber(configFile >> "CfgVehicles" >> _x >> "radarType") isEqualTo 2}}};
			// radarType 2 = vehicle radar (AAA, matched here); 0 none, 4 air (jets/gunships), 8 compass+turrets
			case ("artillery" in _factionFilter) :	{_factionDataFiltered select {getNumber (configFile >> "CfgVehicles" >> _x >> "artilleryScanner") isEqualTo 1}};
			case ("tank" in _factionFilter) :		{_factionDataFiltered select {_x iskindOf "Tank"}};
			case ("apc" in _factionFilter) :		{_factionDataFiltered select {_x iskindOf "Car" && {getNumber (configFile >> "CfgVehicles" >> _x >> "armor") > 300}}};
			case ("cars" in _factionFilter) :		{_factionDataFiltered select {_x iskindOf "Car"}};
			case ("drones" in _factionFilter) :		{_factionDataFiltered select {getText (configFile >> "CfgVehicles" >> _x >> "vehicleClass") isEqualTo "Autonomous"}};
			case ("boats" in _factionFilter) :		{_factionDataFiltered select {_x iskindOf "Ship"}};
			case ("submersibles" in _factionFilter) :		{_factionDataFiltered select {_x iskindOf "Ship"}};
			case ("helicopters" in _factionFilter) :		{_factionDataFiltered select {_x iskindOf "Helicopter"}};
			case ("planes" in _factionFilter) :		{_factionDataFiltered select {_x iskindOf "Plane"}};
			default {[]};
		};
	};

	_factionDataFiltered
};

fnc_filterByDisplayName = compileFinal {
	params ["_factionData", ["_filters", ["rifleman"]], ["_contains", true]];
	_factionData select {
		_type = _x;
		_match = true in ( 
			_filters apply {
				toLowerANSI _x in toLowerANSI getText (configFile >> "CfgVehicles" >> _type >> "displayName")
			}
		);
		if (_contains) then [{_match}, {!_match}]
	};
};

fnc_filterByClassName = compileFinal {
	params ["_factionData", ["_filters", ["rifleman"]], ["_contains", true]];
	_factionData select {
		_type = _x;
		_match = true in ( 
			_filters apply {
				toLowerANSI _x in toLowerANSI _type
			}
		);
		if (_contains) then [{_match}, {!_match}]
	};
};

fnc_factionGetFilteredByType = compileFinal {
	params ["_factionData", "_factionFilter"];
	_factionData select {_x isKindOf _factionFilter && {getNumber (configFile >> "CfgVehicles" >> _x >> "scopeCurator") == 2 || {getNumber (configFile >> "CfgVehicles" >> _x >> "scope") == 2 }}};
};

fnc_filterBySeats = compileFinal {
	params ["_factionData", "_minCrew", "_minCargo"];
	_factionData select {
		_crewCount = [_x, false] call BIS_fnc_crewCount; // crew seats only, no cargo; but FFV seats count as crew (bench Little Bird returns 6)
		_cargoCount =  ([_x, true] call BIS_fnc_crewCount) - _crewCount;
		(getNumber (configFile >> "CfgVehicles" >> _x >> "scopeCurator") == 2 || {getNumber (configFile >> "CfgVehicles" >> _x >> "scope") == 2 }) && 
		{_crewCount >= _minCrew} && 
		{_cargoCount >= _minCargo}
	}; 
};

// _transportType is a config key: transportAmmo / transportRepair / transportFuel / transportSoldier
fnc_filterByUtility = compileFinal {
	params ["_factionData", "_transportType"];
	_factionData select {getNumber (configFile >> "CfgVehicles" >> _x >> _transportType) > 0 && {getNumber (configFile >> "CfgVehicles" >> _x >> "scopeCurator") == 2 || {getNumber (configFile >> "CfgVehicles" >> _x >> "scope") == 2 }}};

};

fnc_filterByPylons = compileFinal {
	params ["_factionData", ["_hasPylon", true]];
	_factionData select {
		_pylonIsClass = isClass (configFile >> "CfgVehicles" >> _x >> "Components" >> "TransportPylonsComponent");
		(_hasPylon && _pylonIsClass || {!_hasPylon && !_pylonIsClass}) && 
		{getNumber (configFile >> "CfgVehicles" >> _x >> "scopeCurator") == 2 || {getNumber (configFile >> "CfgVehicles" >> _x >> "scope") == 2 }}
	};
};

fnc_filterByWeapons = compileFinal {
	params ["_factionData", ["_hasWeapons", true]];
	_factionData select {
		_weapons = flatten ("getArray (_x >> 'weapons') isNotEqualTo []" configClasses (configFile >> "CfgVehicles" >> _x >> "Turrets") apply {getArray (_x >> 'weapons')});
		(_hasWeapons && count _weapons isNotEqualTo 0 || {!_hasWeapons && count _weapons isEqualTo 0}) && 
		{getNumber (configFile >> "CfgVehicles" >> _x >> "scopeCurator") == 2 || {getNumber (configFile >> "CfgVehicles" >> _x >> "scope") == 2 }}
	};
};

fnc_isThreatTo = compileFinal {
	params ["_type"];
	getArray (configFile >> "CfgVehicles" >> _type >> "threat") params [["_threatToInf", 0], ["_threatToArmor", 0], ["_threatToAir", 0]];	// {Soft, Armor, Air}	
	_threatTo = switch selectMax [_threatToInf, _threatToArmor, _threatToAir] do {
		case _threatToInf : {"inf"};
		case _threatToArmor : {"armor"};
		case _threatToAir : {"air"};
	};
	_threatTo
};

// returns weapon parent classnames (MGunCore, CannonCore, GMG_F, MGun, LauncherCore) for type checks
fnc_vehicleWeaponType = compileFinal {
	params ["_type"];
	flatten ((flatten ("getArray (_x >> 'weapons') isNotEqualTo []" configClasses (configFile >> "CfgVehicles" >> _type >> "Turrets") apply {getArray (_x >> 'weapons')})) apply { [configFile >> "CfgWeapons" >> _x, true] call BIS_fnc_returnParents });
};

fnc_unitParseRoles = compileFinal {
	// Unit role comes from the config icon (CfgVehicles >> type >> picture -> CfgVehicleIcons:
	// pictureHeal/Repair/...). Weapon role comes from the held weapon's UIPicture, secondary
	// before primary.
	fnc_IsMG = compileFinal {
		params ["_type"];
		// Belt-fed first (default mag 100+): an MG whatever its icon. 100 clears drums so a drum SMG is not one.
		private _mag = (getArray (configFile >> "CfgWeapons" >> _type >> "magazines")) param [0, ""];
		(_mag != "" && {getNumber (configFile >> "CfgMagazines" >> _mag >> "count") >= 100})
		|| {getText(configFile >> "CfgWeapons" >> _type >> "UIPicture") == "\a3\weapons_f\data\ui\icon_mg_ca.paa"}
		|| {getText(configFile >> "CfgWeapons" >> _type >> "cursor") == "mg"}
	};
	
	fnc_IsAT = compileFinal {
		params ["_type"];
		// A weapon in the launcher slot that is not an AA piece (the AA case runs before this in the
		// switch) is AT: rocket/missile launchers inherit the Launcher base whatever their icon.
		// A grenadier carries the GL as a primary muzzle, not a launcher, so this cannot steal them.
		(_type != "" && {_type isKindOf ["Launcher", configFile >> "CfgWeapons"]})
		|| {getText(configFile >> "CfgWeapons" >> _type >> "UIPicture") == "\a3\weapons_f\data\ui\icon_at_ca.paa"}
	};
	
	fnc_IsAA = compileFinal {
		params ["_type"];
		// The launcher's missile locks air (airLock >= 1): the config fact that separates an AA tube
		// from an AT one, ahead of the icon. A non-launcher secondary has no such magazine and fails.
		private _mag = (getArray (configFile >> "CfgWeapons" >> _type >> "magazines")) param [0, ""];
		(_mag != "" && {getNumber (configFile >> "CfgAmmo" >> getText (configFile >> "CfgMagazines" >> _mag >> "ammo") >> "airLock") >= 1})
		|| {getText(configFile >> "CfgWeapons" >> _type >> "UIPicture") == "\a3\weapons_f\data\ui\icon_aa_ca.paa"}
	};
	
	fnc_IsSniper = compileFinal {
		params ["_type"];
		getText(configFile >> "CfgWeapons" >> _type >> "UIPicture") == "\a3\weapons_f\data\ui\icon_sniper_ca.paa";
	};
	
	fnc_IsGrenadier = compileFinal {
		params ["_type"];
		// An underbarrel GL is a second muzzle (not "this") that carries its own magazines. That muzzle,
		// not the icon, is what a grenadier's rifle has and a plain rifle does not. Icon stays a fallback.
		private _hasUGL = ((getArray (configFile >> "CfgWeapons" >> _type >> "muzzles")) findIf {
			_x != "this" && {(getArray (configFile >> "CfgWeapons" >> _type >> _x >> "magazines")) isNotEqualTo []}
		}) >= 0;
		_hasUGL
		|| {getText(configFile >> "CfgWeapons" >> _type >> "UIPicture") == "\a3\weapons_f\data\ui\icon_gl_ca.paa"}
	};
	
	fnc_IsMedic = compileFinal {
		params ["_type"];
		getNumber (configfile >> "CfgVehicles" >> _type  >> "attendant") == 1;
	};
	
	fnc_IsEngineer = compileFinal {
		params ["_type"];
		getNumber(configFile >> "CfgVehicles" >> _type >> "engineer") == 1 && {(getNumber(configFile >> "CfgVehicles" >> _type >> "canDeactivateMines") != 1)};
	};
	
	fnc_IsEOD = compileFinal {
		params ["_type"];
		getNumber(configFile >> "CfgVehicles" >> _type >> "canDeactivateMines") == 1;
	};
	
	// These test the classname as well as the display name, and read it from their own _type
	// rather than the caller's _x: `call` shares the caller's scope, so the old reads only
	// worked from inside fnc_unitParseRoles' apply and errored anywhere else.
	fnc_IsOfficer = compileFinal {
		params ["_type"];
		"officer" in toLowerANSI ([configFile >> "CfgVehicles" >> _type] call BIS_fnc_displayName) || {"officer" in toLowerANSI _type}
	};

	// Whole classname segment, not a substring: "SL" matched every CUP_O_SLA_* unit, so the
	// entire Sahrani army read as squad leaders and nothing was left in _grunt. Same for "TL".
	fnc_IsSquadLead = compileFinal {
		params ["_type"];
		"squad" in toLowerANSI ([configFile >> "CfgVehicles" >> _type] call BIS_fnc_displayName) || {"sl" in (toLowerANSI _type splitString "_")}
	};

	fnc_IsTeamLead = compileFinal {
		params ["_type"];
		"team" in toLowerANSI ([configFile >> "CfgVehicles" >> _type] call BIS_fnc_displayName) || {"tl" in (toLowerANSI _type splitString "_")}
	};

	fnc_IsPilot = compileFinal {
		params ["_type"];
		"pilot" in toLowerANSI ([configFile >> "CfgVehicles" >> _type] call BIS_fnc_displayName) || {"pilot" in toLowerANSI _type}
	};

	// Segment match on "crew" as well as "crewman": mods split roughly evenly between
	// rhs_vdv_crew and ..._crewman, and a crewman left in a combat bucket garrisons a zone in
	// a tanker suit.
	fnc_IsCrewman = compileFinal {
		params ["_type"];
		"crewman" in toLowerANSI ([configFile >> "CfgVehicles" >> _type] call BIS_fnc_displayName)
			|| {"crewman" in toLowerANSI _type}
			|| {"crew" in (toLowerANSI _type splitString "_")}
	};

	fnc_IsDiver = compileFinal {
		params ["_type"];
		"diver" in toLowerANSI ([configFile >> "CfgVehicles" >> _type] call BIS_fnc_displayName) || {"diver" in toLowerANSI _type}
	};

	fnc_IsMarksman = compileFinal {
		params ["_type"];
		"marksman" in toLowerANSI ([configFile >> "CfgVehicles" >> _type] call BIS_fnc_displayName) || {"marksman" in toLowerANSI _type}
	};
	
	_grunt = [];
	_medic = [];
	_sl = [];
	_tl = [];
	_ar = [];
	_mg = [];
	_gl = [];
	_aa = [];
	_lat = [];
	_hat = [];
	_officer = [];
	_spec = [];
	_diver = [];
	_pilot = [];
	_crew = [];
	_marksman = [];
	_sniper = [];
	_eng = [];
	_exp = [];
	_uavOp = [];
	
	_spec_medic = [];
	_spec_sl = [];
	_spec_tl = [];
	_spec_ar = [];
	_spec_mg = [];
	_spec_gl = [];
	_spec_aa = [];
	_spec_lat = [];
	_spec_hat = [];
	_spec_marksman = [];
	_spec_sniper = [];
	_spec_eng = [];
	_spec_exp = [];
	
	_this apply {
		getUnitLoadout _x params ["_primaryWeapon", "_secondaryWeapon", "_handgunWeapon", "_uniform", "_vest", "_backpack", "_headgear", "_facewear", "_binocular", "_assignedItems"];
		// getUnitLoadout layout. Destructured here: 0 primary weapon, 1 secondary weapon
		// (weapon sub-index 4 = muzzle-1 magazine+ammo), 9 assigned items. Full array: BIS getUnitLoadout.
		
		_primaryWeaponIsSuppressed = if (count _primaryWeapon > 1) then [{_primaryWeapon # 1 isNotEqualTo ""}, {false}];
		// getUnitLoadout pads a weapon array to seven elements, absent attachments as "", so
		// `count > 3` only means a primary weapon exists, not that it has an optic. An iron-sighted
		// rifle read OpticsModes under CfgWeapons >> "" (no classes): selectMax got [] and returned
		// nil, and assigning nil undefines the variable, erroring both reads below. An optic with no
		// OpticsModes fails the same way, so check the modes, not the classname.
		private _opticsModes = [];
		if (count _primaryWeapon > 3 && {(_primaryWeapon # 3) isNotEqualTo ""}) then {
			_opticsModes = "true" configClasses (configFile >> "CfgWeapons" >> (_primaryWeapon # 3) >> "ItemInfo" >> "OpticsModes");
		};

		// Zero rather than the no-weapon fallback: a weapon whose optic cannot be read is a weapon
		// without a long-range optic, and 9999 would claim the opposite.
		_primaryWeaponOpticMaxZero = if (_opticsModes isEqualTo []) then {0} else {
			selectMax flatten (_opticsModes apply {getArray (_x >> "discreteDistance")})
		};
		_primaryWeaponOpticMaxZoom = if (_opticsModes isEqualTo []) then {0} else {
			selectMax (_opticsModes apply {getNumber (_x >> "distanceZoomMax")})
		};
		_primaryWeaponHasLongRangeOptic = _primaryWeaponOpticMaxZero > 1000 && {_primaryWeaponOpticMaxZoom > 700};

		// Same shape of fault: index 4 is the [magazine, count] pair, and a launcher carried without
		// a magazine leaves it empty, so `# 4 # 0` errored and left the cost undefined.
		private _secondaryMag = (_secondaryWeapon param [4, []]) param [0, ""];
		_secondaryWeaponDamageCost = if (_secondaryMag isEqualTo "") then {-1} else {
			getNumber (configFile >> "CfgAmmo" >> getText (configFile >> "CfgMagazines" >> _secondaryMag >> "ammo") >> "cost")
		};	// LAT < 400, HAT > 400
		_hasUAVterminal = "uav" in toLowerANSI (_assignedItems # 1);
		// param, not # 0: an unarmed unit has an empty weapon array, and indexing that handed
		// the role predicates below nothing at all -- one config lookup per weaponless unit,
		// erroring on every pass of the faction scan.
		_primaryType = _primaryWeapon param [0, ""];
		_secondaryType = _secondaryWeapon param [0, ""];
		
		if (_primaryWeaponIsSuppressed) then {
			_spec pushBackUnique _x;
			switch true do {
				case ( [_x] call fnc_IsDiver ) : { _diver pushBackUnique _x };
				case ( [_x] call fnc_IsMedic && {"Medikit" in flatten _backpack} ) : { _spec_medic pushBackUnique _x };
				case ( [_x] call fnc_IsEngineer ) : { _spec_eng pushBackUnique _x };
				case ( [_x] call fnc_IsEOD ) : { _exp pushBackUnique _x };
				case ( [_secondaryType] call fnc_IsAA ) : { _spec_aa pushBackUnique _x };
				case ( [_secondaryType] call fnc_IsAT && {_secondaryWeaponDamageCost > 400} ) : { _spec_hat pushBackUnique _x };
				case ( [_secondaryType] call fnc_IsAT && {_secondaryWeaponDamageCost < 400} ) : { _spec_lat pushBackUnique _x };
				case ( [_x] call fnc_IsSquadLead ) : { _spec_sl pushBackUnique _x };
				case ( [_x] call fnc_IsTeamLead ) : { _spec_tl pushBackUnique _x };
				case ( [_primaryType] call fnc_IsSniper ) : { _spec_sniper pushBackUnique _x };
				case ( [_x] call fnc_IsMarksman || {_primaryWeaponHasLongRangeOptic} ) : { _spec_marksman pushBackUnique _x };
				case ( [_primaryType] call fnc_IsGrenadier ) : { _spec_gl pushBackUnique _x };
				case ( [_primaryType] call fnc_IsMG && "rifleman" in toLowerANSI ([configFile >> "CfgVehicles" >> _x] call BIS_fnc_displayName) ) : { _spec_ar pushBackUnique _x };
				case ( [_primaryType] call fnc_IsMG && !("rifleman" in toLowerANSI ([configFile >> "CfgVehicles" >> _x] call BIS_fnc_displayName)) ) : { _spec_mg pushBackUnique _x };
			};
		};	// suppressed weapon -> classified as spec ops
		
		switch true do {
			// Pilots and crew first: they carry the same launchers and medikits as line infantry,
			// so lower down a crewman with an RPG became an AT rifleman and a garrison came out
			// dressed for a cockpit. The old fix stripped them back out by classname, but that
			// keyword list included "officer" and so emptied the officer role for factions that
			// spell their officers "officer".
			case ( [_x] call fnc_IsPilot ) : { _pilot pushBackUnique _x };
			case ( [_x] call fnc_IsCrewman ) : { _crew pushBackUnique _x };
			case ( [_x] call fnc_IsDiver ) : { _diver pushBackUnique _x };
			case ( [_x] call fnc_IsMedic && {"Medikit" in flatten _backpack} ) : { _medic pushBackUnique _x };
			case ( [_x] call fnc_IsEngineer ) : { _eng pushBackUnique _x };
			case ( [_x] call fnc_IsEOD ) : { _exp pushBackUnique _x };
			case ( [_secondaryType] call fnc_IsAA ) : { _aa pushBackUnique _x };
			case ( [_secondaryType] call fnc_IsAT && {_secondaryWeaponDamageCost > 400} ) : { _hat pushBackUnique _x };
			case ( [_secondaryType] call fnc_IsAT && {_secondaryWeaponDamageCost < 400} ) : { _lat pushBackUnique _x };
			case ( [_x] call fnc_IsOfficer ) : { _officer pushBackUnique _x };
			case ( [_x] call fnc_IsSquadLead ) : { _sl pushBackUnique _x };
			case ( [_x] call fnc_IsTeamLead ) : { _tl pushBackUnique _x };
			case ( [_primaryType] call fnc_IsSniper ) : { _sniper pushBackUnique _x };
			case ( [_x] call fnc_IsMarksman || {_primaryWeaponHasLongRangeOptic} ) : { _marksman pushBackUnique _x };
			case ( [_primaryType] call fnc_IsGrenadier ) : { _gl pushBackUnique _x };
			case ( ([_primaryType] call fnc_IsMG || {getText(configFile >> "CfgVehicles" >> _x >> "icon") isEqualTo "iconManMG"}) && "rifleman" in toLowerANSI ([configFile >> "CfgVehicles" >> _x] call BIS_fnc_displayName) ) : { _ar pushBackUnique _x };
			case ( ([_primaryType] call fnc_IsMG || {getText(configFile >> "CfgVehicles" >> _x >> "icon") isEqualTo "iconManMG"}) && !("rifleman" in toLowerANSI ([configFile >> "CfgVehicles" >> _x] call BIS_fnc_displayName)) ) : { _mg pushBackUnique _x };
			case ( _hasUAVterminal ) : { _uavOp pushBackUnique _x };
			case ( getText(configFile >> "CfgVehicles" >> _x >> "icon") isEqualTo "iconMan" ) : {_grunt pushBackUnique _x};
			default { _grunt pushBackUnique _x };
		};
		
	};
	
	[_grunt,_medic,_sl,_tl,_ar,_mg,_gl,_aa,_lat,_hat,_officer,_spec,_diver,_pilot,_crew,_marksman,_sniper,_eng,_exp,_uavOp] +
	[_spec,_spec_medic,_spec_sl,_spec_tl,_spec_ar,_spec_mg,_spec_gl,_spec_aa,_spec_lat,_spec_hat,_spec_marksman,_spec_sniper,_spec_eng,_spec_exp]
};

fnc_parseFaction = compileFinal {
	params [["_faction", if (is3DEN) then [{faction (get3DENSelected "Object" # 0)}, {faction player}] ]];
	// Config order, not shuffled: fnc_faction_pools publishes element 0 of each role as the
	// faction's stable representative, and a mod declares its mainstay before its variants. A
	// shuffle changed that representative every campaign (a faction's rifleman and operator both
	// came out as the same sniper); spawn variety comes from fnc_faction_pick over the pool.
	_factionData = ("gettext (_x >> 'faction') == _faction" configClasses (configfile >> "CfgVehicles")) apply {configName _x};

	// ignore unarmed infantry
	_infantry =	([ _factionData, "person" ] call fnc_factionGetFilteredByEditorSubcat) select {
		_x iskindOf 'CAManBase' && { {!(_x in ["Throw", "Put"])} count (getArray (configFile >> "CfgVehicles" >> _x >> "weapons")) > 0 }
	};
_infantry = _infantry select { getNumber (configFile >> "CfgVehicles" >> _x >> "scope") >= 2 };
	_infantryByRoles = _infantry call fnc_unitParseRoles;

	_turrets = [ _factionData, "turrets" ] call fnc_factionGetFilteredByEditorSubcat select { getText (configFile >> "CfgVehicles" >> _x >> "vehicleClass") isNotEqualTo "Autonomous" };
	_boat =	[ _factionData, "boats" ] call fnc_factionGetFilteredByEditorSubcat;
	_droneAir =	[ [ _factionData, "drones" ] call fnc_factionGetFilteredByEditorSubcat, "Air" ] call fnc_factionGetFilteredByType;
	_droneLand =	 [ [ _factionData, "drones" ] call fnc_factionGetFilteredByEditorSubcat, "LandVehicle" ] call fnc_factionGetFilteredByType;
	_droneStatic = _turrets select { getText (configFile >> "CfgVehicles" >> _x >> "vehicleClass") isEqualTo "Autonomous" };
	_submersible =	[ _factionData, "submersibles" ] call fnc_factionGetFilteredByEditorSubcat;
	// Match statics by weapon/scanner, not the vanilla StaticMGWeapon/GrenadeLauncher/Mortar base a mod
	// need not inherit -- else a faction's own gun is dropped for a vanilla one. AA/AT do it by threat.
	_turretHMG =	[ [ _turrets select {"MGunCore" in ([_x] call fnc_vehicleWeaponType)}, "StaticMGWeapon" ] call fnc_factionGetFilteredByType, _turrets select {"MGunCore" in ([_x] call fnc_vehicleWeaponType)} ] call fnc_selectNonEmpty;
	_turretGMG =	[ [ _turrets, "StaticGrenadeLauncher" ] call fnc_factionGetFilteredByType, _turrets select {"GMG_F" in ([_x] call fnc_vehicleWeaponType)} ] call fnc_selectNonEmpty;
	_turretMortar =	[ [ _turrets, "StaticMortar" ] call fnc_factionGetFilteredByType, _turrets select {getNumber (configFile >> "CfgVehicles" >> _x >> "artilleryScanner") isEqualTo 1} ] call fnc_selectNonEmpty;
	_turretAA =	 [ [ _turrets, "StaticAAWeapon" ] call fnc_factionGetFilteredByType, _turrets select {[_x] call fnc_isThreatTo isEqualTo "air"}] call fnc_selectNonEmpty;
	_turretAT =	[ [ _turrets, "StaticATWeapon" ] call fnc_factionGetFilteredByType, _turrets select {[_x] call fnc_isThreatTo isEqualTo "armor"}] call fnc_selectNonEmpty;
	_turretCannon =	[ [ _factionData, "turrets" ] call fnc_factionGetFilteredByEditorSubcat, "StaticCannon" ] call fnc_factionGetFilteredByType;
	_apcWheeled =	[ [ _factionData, "apc" ] call fnc_factionGetFilteredByEditorSubcat, "Car" ] call fnc_factionGetFilteredByType; 
	_apcTracked =	[ [ _factionData, "apc" ] call fnc_factionGetFilteredByEditorSubcat, "Tank" ] call fnc_factionGetFilteredByType; 
	_tank =	[ _factionData, "tank" ] call fnc_factionGetFilteredByEditorSubcat;
	_arty =	[ _factionData, "artillery" ] call fnc_factionGetFilteredByEditorSubcat;
	_antiAir =	[ _factionData, "aas" ] call fnc_factionGetFilteredByEditorSubcat;
	// Every soft-skin wheeled vehicle (isKindOf Car), cars and trucks alike: trucks sit under the
	// "Trucks" subcategory and the cars fallback only fires when cars is wholly empty, so a faction with
	// both dropped its trucks. Armor <= 300 keeps wheeled APCs (their own bucket) out of a transport role.
	private _wheeledSoft = _factionData select {
		_x isKindOf "Car"
		&& {getNumber (configFile >> "CfgVehicles" >> _x >> "scope") >= 2}
		&& {getNumber (configFile >> "CfgVehicles" >> _x >> "armor") <= 300}
	};
	_carArmed =	[ [ _wheeledSoft, 2,0 ] call fnc_filterBySeats, true] call fnc_filterByWeapons;
	_carTransport =	[ _wheeledSoft, 1, 6] call fnc_filterBySeats;
	_carRearm =	[ _wheeledSoft, "transportAmmo"] call fnc_filterByUtility;
	_carRepair =	[ _wheeledSoft, "transportRepair"] call fnc_filterByUtility;
	_carRefuel =	[ _wheeledSoft, "transportFuel"] call fnc_filterByUtility;
	// Armed by turret weapon OR pylon: a mod gunship arming through Turrets, not a pylon component, was
	// dropped and attack-heli fell to a vanilla airframe. Union keeps the pylon path for loadout jets.
	private _heliSeated = [ [ _factionData, "helicopters" ] call fnc_factionGetFilteredByEditorSubcat, 2,0 ] call fnc_filterBySeats;
	private _heliByPylon = _heliSeated call fnc_filterByPylons;
	_heliArmed =	_heliByPylon + (([ _heliSeated, true ] call fnc_filterByWeapons) select {!(_x in _heliByPylon)});
	// Count cargo seats as well as legacy transportSoldier: a seat-proxy transport reports
	// transportSoldier 0 and read as no transport, so TRANS fell through to the gunship. Floor of 4
	// cargo seats, what the taxi and paradrop calls need.
	private _heliList = _factionData select {_x isKindOf "Helicopter" && {getNumber (configFile >> "CfgVehicles" >> _x >> "scope") >= 2}};
	_heliTransport = (_heliList select {getNumber (configFile >> "CfgVehicles" >> _x >> "transportSoldier") >= 4}) + ([_heliList, 1, 4] call fnc_filterBySeats);
	_heliTransport = _heliTransport arrayIntersect _heliTransport;
	// Same union as _heliArmed: armed by pylon or by turret weapon.
	private _planeSeated = [ [ _factionData, "planes" ] call fnc_factionGetFilteredByEditorSubcat, 1,0 ] call fnc_filterBySeats;
	private _planeByPylon = _planeSeated call fnc_filterByPylons;
	_planeArmed =	_planeByPylon + (([ _planeSeated, true ] call fnc_filterByWeapons) select {!(_x in _planeByPylon)});
	_planeTransport =	[ [ _factionData, "planes" ] call fnc_factionGetFilteredByEditorSubcat, 6,0 ] call fnc_filterBySeats;
	[
		_infantry,
		_infantryByRoles,
		_boat, 
		_droneAir, _droneLand, _droneStatic, 
		_submersible, 
		_turretHMG, _turretGMG, _turretMortar,_turretAA,_turretAT, 
		_apcWheeled, _apcTracked, 
		_tank, 
		_arty, 
		_antiAir, 
		_carArmed, _carTransport, _carRearm, _carRepair, _carRefuel,
		_heliArmed, _heliTransport,
		_planeArmed  select { getText (configFile >> "CfgVehicles" >> _x >> "vehicleClass") isNotEqualTo "Autonomous" }, _planeTransport
	]
};


// Zombie faction? Matched on display name, not a per-mod class list: the mission supports two
// zombie mods and cannot name every faction they ship, but both name theirs for what they field.
// One test both ways -- zombies stay out of ordinary picks and are the only OPFOR the zombie mode
// offers. Markers live in the block, not a global: the block is what is published to clients, and
// a companion global would have to be published in lockstep.
fnc_factionIsZombie = compileFinal {
	params ["_factionClass"];
	private _name = toLower getText (configFile >> "CfgFactionClasses" >> _factionClass >> "displayName");
	(["zombie", "undead", "infected"] findIf { _name find _x >= 0 }) >= 0
};

// All valid factions, de-duplicated (a faction may be defined for several sides).
// _wantZombies inverts the zombie filter rather than lifting it: a caller gets the ordinary
// factions or the zombie ones, never both in one list.
fnc_getAllFactionsClean = compileFinal {
	params [["_wantZombies", false]];
	private _factionsRef = [];
	private _factions = [];

	(call BIS_fnc_getFactions) select {
		getNumber (configFile >> "CfgFactionClasses" >> _x >> "side") in [0,1,2]
		&& {([_x] call fnc_factionIsZombie) isEqualTo _wantZombies}
	} apply {
		_factionDisplayName = getText (configFile >> "CfgFactionClasses" >> _x >> "displayName");
		if !(_factionDisplayName in _factionsRef) then {
			_factionsRef append [getText (configFile >> "CfgFactionClasses" >> _x >> "displayName")];
			
			if (_factionDisplayName isEqualTo "") then {continue};	// faction has no name			

			_addon = configSourceMod (configFile >> "CfgFactionClasses" >> _x);
			_factions append [[format ["%1 - %2", _factionDisplayName, _addon], _x]];
		};
	};
	_factions
};

// One dialog is reused across the BLUFOR then OPFOR rounds: the first round builds
// it, later rounds relabel and re-enable the same display. It never closes between
// picks, so the settings/campaign menus stacked underneath stay unreachable until
// both factions are chosen (closing it early exposed the map for a few seconds).
fnc_factionSelector = compileFinal {
	params [ ["_prompt", "Select Faction"], ["_finalRound", true], ["_wantZombies", false] ];

	selectionDone = nil;
	DUWS_factionSelectFinal = _finalRound;	// read by the ButtonClick handler at click time

	factionList = [_wantZombies] call fnc_getAllFactionsClean;

	disableSerialization;

	// Display handle lives in uiNamespace: DISPLAY is non-serializable and the mission
	// namespace is saved, so storing it there errors on save.
	if (isNull (uiNamespace getVariable ["DUWS_factionSelectDisplay", displayNull])) then {

		private _guiEditorOutput = [
			1.063,
			["quickgui",[[0,0,1,1],0.025,0.04,"GUI_GRID"],0,0,0],
			[1450,"RscText",[1,"",["0.312812 * safezoneW + safezoneX","0.256 * safezoneH + safezoneY","0.157812 * safezoneW+0.5","0.636 * safezoneH"],[-1,-1,-1,-1],[-1,-1,-1,-1],[-1,-1,-1,-1],"","-1"],[]],
			[1451,"RscText",[1,"",["0.312812 * safezoneW + safezoneX","0.256 * safezoneH + safezoneY","0.157812 * safezoneW+0.5","0.636 * safezoneH"],[-1,-1,-1,-1],[-1,-1,-1,-1],[-1,-1,-1,-1],"","-1"],[]],
			[1500,"RscListBox",[1,"",["0.322812 * safezoneW + safezoneX","0.276 * safezoneH + safezoneY","0.137812 * safezoneW+0.5","0.224 * safezoneH"],[-1,-1,-1,-1],[-1,-1,-1,-1],[-1,-1,-1,-1],"","-1"],[]],
			[1600,"RscButton",[1,toUpper _prompt,["0.322812 * safezoneW + safezoneX","0.514 * safezoneH + safezoneY","0.136 * safezoneW+0.5","0.028 * safezoneH"],[-1,-1,-1,-1],[-1,-1,-1,-1],[-1,-1,-1,-1],"","-1"],[]],
			[1200,"RscPicture",[1,"#(argb,8,8,3)color(0,0,0,0.5)",["0.322812 * safezoneW + safezoneX","0.552 * safezoneH + safezoneY","0.136 * safezoneW+0.5","0.32 * safezoneH"],[-1,-1,-1,-1],[-1,-1,-1,-1],[-1,-1,-1,-1],"","-1"],[]],
			[1201,"RscStructuredText",[1,"",["0.322812 * safezoneW + safezoneX","0.672 * safezoneH + safezoneY","0.136 * safezoneW+0.5","0.08 * safezoneH"],[-1,-1,-1,-1],[-1,-1,-1,-1],[-1,-1,-1,-1],"","-1"],[]]
		];

		sleep 0.5;
		private _display = createDialog ["RscDisplayEmpty", false];
		uiNamespace setVariable ["DUWS_factionSelectDisplay", _display];

		{
			private _control = _display ctrlCreate [_x # 1, _x # 0];
			_control ctrlSetText (_x # 2 # 1);
			// DUWS setup-dialog palette: green backdrop (1450) under a translucent-black inner
			// panel (1451) so the red action button reads crisp, plus a transparent overlay
			// (1201) for the "no units" caption. Everything else takes the translucent black.
			switch (_x # 0) do {
				case 1450: { _control ctrlSetBackgroundColor [0.2,0.4,0.2,1]; };
				case 1600: { _control ctrlSetBackgroundColor [1,0,0,0.5]; };
				case 1201: { _control ctrlSetBackgroundColor [0,0,0,0]; };
				default { _control ctrlSetBackgroundColor [0,0,0,0.3]; };
			};
			_control ctrlSetPosition ((_x # 2 # 2) apply {call compile _x});
			_control ctrlCommit 0;
		} forEach (_guiEditorOutput select [2, 6]);

		{
			lbAdd [1500, _x # 0];
		} forEach factionList;

		(displayCtrl 1500) ctrlAddEventHandler ["LBSelChanged", {
			private _index = _this # 1;
			_faction = ((factionList # _index) # 1);
			// some factions misconfigure unit scope, so include hidden units (scope 1) as well as 2
			private _units = ("(configname _x iskindOf 'CAManBase') && (getNumber(_x >> 'scope') in  [1,2]) && (gettext (_x >> 'faction') == _faction)" configClasses (configfile >> "CfgVehicles")) apply {configName _x};

			if (_units isEqualTo []) exitWith {
				(displayCtrl 1200) ctrlSetText "";
				// Structured-text control: ctrlSetText would show the markup raw, so feed it a
				// parsed object. Caption sits centred over the preview, not a screen-centre titleText.
				(displayCtrl 1201) ctrlSetStructuredText (parseText "<t align='center' size='2' font='PuristaMedium' color='#ff0000'>FACTION HAS NO UNITS</t>");
			};

			// Random-cycle only units that have a preview image, so re-selecting keeps showing
			// different units instead of blanking whenever it lands on a preview-less unit.
			_factionRandomUnit = selectRandom (_units select { getText (configFile >> "CfgVehicles" >> _x >> "editorPreview") != "" });
			private _preview = "";
			if (!isNil "_factionRandomUnit") then {
				_preview = getText (configFile >> "CfgVehicles" >> _factionRandomUnit >> "editorPreview");
			};
			(displayCtrl 1200) ctrlSetText _preview;
			(displayCtrl 1201) ctrlSetStructuredText (parseText "");	// clear any stale "no units" caption
		}];

		(displayCtrl 1600) ctrlAddEventHandler ["ButtonClick", {
			_selected = factionList # (lbCurSel 1500);
			missionNamespace setVariable ["selectedFaction", _selected#1, true];

			// Selection only: the per-side fnc_factionGen is run later, at the
			// deferred commit, so the picker can show during setup without building
			// faction data before the player has locked settings in.
			selectionDone = true;
			publicVariable "selectedFaction";
			publicVariable "selectionDone";

			// Final round closes; earlier rounds lock the controls and wait so the
			// map/menus behind the dialog stay unreachable until the next round.
			if (DUWS_factionSelectFinal) then {
				closeDialog 0;
				uiNamespace setVariable ["DUWS_factionSelectDisplay", displayNull];
			} else {
				ctrlEnable [1500, false];
				ctrlEnable [1600, false];
				ctrlSetText [1600, "PLEASE WAIT..."];
			};
		}];

	} else {
		// Reuse round: relabel + re-enable the controls the previous round locked.
		ctrlSetText [1600, toUpper _prompt];
		ctrlEnable [1600, true];
		ctrlEnable [1500, true];
		(displayCtrl 1200) ctrlSetText "";
		(displayCtrl 1201) ctrlSetStructuredText (parseText "");
	};

	waitUntil {uiSleep 0.5;  !isNil "selectionDone" };

};

["fnc_selectNonEmpty","fnc_vehiclePostInit","fnc_padZero","fnc_enumCost","fnc_enumCostFormatted","fnc_evalVehicleCost","fnc_getEditorCategory","fnc_factionGetFilteredByEditorSubcat","fnc_filterByDisplayName","fnc_filterByClassName","fnc_factionGetFilteredByType","fnc_filterBySeats","fnc_filterByUtility","fnc_filterByPylons","fnc_filterByWeapons","fnc_isThreatTo","fnc_vehicleWeaponType","fnc_unitParseRoles","fnc_parseFaction","fnc_factionIsZombie","fnc_getAllFactionsClean","fnc_factionSelector"] apply { publicVariable _x };