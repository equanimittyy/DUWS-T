/**
 * Functions pack for showing units on the map as a custom markers.
 * Author: [PR]zemek kondor
 * Version: 1.1 (8 April 2010)
 */

if (!hasInterface) exitWith {};
/**
 * Holds delay of updating markers.
 */
kndr_MARKER_DELAY_UPDATE = 4;

/**
 * Holds object which have markers
 */
kndr_mrks = [];

/**
 * Holds markers for objects.
 */
kndr_objs = [];

/**
 * Flag if script should work.
 */
kndr_markerShowOn = true;

/**
 * Field for making unique markersname
 */
kndr_mrkNr = 0;

/**
 * Default marker color
 */
kndr_DEFAULT_MRK_CLR = "ColorBlue";
 
/**
 * Function which returns info if marker should be removed.
 * args: object
 */
kndr_needsRemove = 
{
	private ["_res"];
	_res = false;
	if (isNull (_this select 0)) then
	{
		_res = true;
	}
	else
	{
		if (not alive (_this select 0)) then
		{
			_res = true;
		};
	};
	_res
};

/**
 * Updates all markers (once).
 */
kndr_updateMarkers = 
{
	private ["_i", "_obj", "_mrk"];
	
	for "_i" from ((count kndr_objs) - 1) to 0 step -1 do
	{
		_obj = kndr_objs select _i;
		_mrk = kndr_mrks select _i;
		
		if ([_obj] call kndr_needsRemove) then
		{
			[_i] call kndr_removeMarker;
		}
		else
		{
			_mrk setMarkerPosLocal (getPos _obj);
			_mrk setMarkerDirLocal (getDir _obj);
		};
	};
};

/**
 * Returns default marker class for a given object type
 * args: object
 */
kndr_getDefaultMarkerClass = 
{
	private ["_res"];

	_res = "mil_dot";
	if (_aType isKindOf "Air") then
	{
		_res = "Air";
	}
	else
	{
		if (_aType isKindOf "Tank") then
		{
			_res = "Tank";
		}
		else
		{
			if ((_aType isKindOf "Car") or (_aType isKindOf "Motorcycle")) then
			{
				_res = "Car";
			};
		};
	};
	_res
};

/**
 * Set the speed of updating markers.
 * args: number - delay in seconds.
 */
kndr_setMarkerUpdateDelay = 
{
	kndr_MARKER_DELAY_UPDATE = _this select 0;
};

/**
 * Returns delay of updating markers (in seconds).
 */
kndr_getMarkerUpdateDelay = 
{
	kndr_MARKER_DELAY_UPDATE
};

/**
 * Assigning marker to object
 * args: [object, iconClass, iconColor, iconSizeX, iconSizeY, text]
 */
kndr_assignMarker = 
{
	private ["_mName", "_count", "_aObj", "_aClass", "_aColor", "_aIconX", "_aIconY", "_aText"];

	if (not isNull (_this select 0)) then
	{
		_aObj = _this select 0;
		_count = count _this;
		_aClass = if (_count > 1) then { _this select 1 } else { [_aObj] call kndr_getDefaultMarkerClass };
		_aColor = if (_count > 2) then { _this select 2 } else { kndr_DEFAULT_MRK_CLR };
		_aIconX = if (_count > 3) then { _this select 3 } else { 1 };
		_aIconY = if (_count > 4) then { _this select 4 } else { 1 };
		_aText = if (_count > 5) then { _this select 5 } else { "" };
	
		_mName = format["kndr_mrk%1", kndr_mrkNr];
		kndr_mrkNr = kndr_mrkNr + 1;
		
		createMarkerLocal [_mName, getPos _aObj];
		_mName setMarkerShapeLocal "ICON";
		_mName setMarkerTypeLocal _aClass;
		_mName setMarkerColorLocal _aColor;
		_mName setMarkerSizeLocal [_aIconX, _aIconY];
		_mName setMarkerTextLocal _aText;

		kndr_objs = kndr_objs + [_aObj];
		kndr_mrks = kndr_mrks + [_mName];
	} 
	else
	{
		["ERROR", "MARKERS", "kndr_markers: entry object is null!"] call fnc_log;
	};
};

/**
 * Removes marker for passed object.
 * args: object
 */
kndr_removeMarker =
{
	private ["_mrk", "_obj", "_index"];
	_obj = _this select 0;
	_index = kndr_objs find _obj;
	_mrk = kndr_mrks select _index;

	kndr_objs = kndr_objs - [_obj];
	kndr_mrks = kndr_mrks - [_mrk];

	deleteMarkerLocal _mrk;
};

/**
 * Starts showing markers.
 */
kndr_showMarkers = 
{
	kndr_markerShowOn = true;
	while {kndr_markerShowOn} do
	{
		[] call kndr_updateMarkers;
		sleep kndr_MARKER_DELAY_UPDATE;
	};
};

/**
 * Disables showing markers.
 */
kndr_disableShow = 
{
	kndr_markerShowOn = false;
};

/**
 * Changes marker text.
 * args: object, text
 */
kndr_setMarkerText = 
{
	private ["_i"];
	for "_i" from 0 to ((count kndr_objs) - 1) do
	{
		if ((_this select 0) == (kndr_objs select _i)) then
		{
			(kndr_mrks select  _i)  setMarkerTextLocal (_this select 1);
			if (true) exitWith {};
		};
	};
};

// Automatically run the system
[] spawn kndr_showMarkers;
