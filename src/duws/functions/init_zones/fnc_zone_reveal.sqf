// Locality: server -- inherited from misc/fnc_enterlocation.sqf.

// ZONE REVEAL
params ["_one_or_all","_zonePos"];

switch (_one_or_all) do {

	case "ONE": {
		// Reveal 1x Zone
		{
			if ((str (_x select 1) == str (_zonePos)) && (_x select 2 == false)) exitWith {
				hardcore_visibleZone_found = true;publicVariable "hardcore_visibleZone_found";
				_markername = format["%1%2",round(_zonePos select 0),round(_zonePos select 1)]; // Define marker name
				_markername2 = format["%1%2ellipse",round(_zonePos select 0),round(_zonePos select 1)]; // Define marker name
				str(_markername) setMarkerAlpha 1; 
				str(_markername2) setMarkerAlpha 0.3; 
				_x set [2,true];
				[localize "STR_DUWS_T_1vp3mgnc"] spawn fnc_sideChat_filter;
				[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_zonereveal"] remoteExec ["BIS_fnc_showSubtitle", 0];
                [] remoteExec ["fnc_broadcastRadioChatter", 0];
				
			};
		} foreach zone_namePOS_pairs;
	};

	case "ALL": {
		// Reveal ALL Zones
		{
			_zonePos = _x select 1;
			hardcore_visibleZone_found = true;publicVariable "hardcore_visibleZone_found";
			_markername = format["%1%2",round(_zonePos select 0),round(_zonePos select 1)]; // Define marker name
			_markername2 = format["%1%2ellipse",round(_zonePos select 0),round(_zonePos select 1)]; // Define marker name
			str(_markername) setMarkerAlpha 1; 
			str(_markername2) setMarkerAlpha 0.3; 
			_x set [2,true];
		} foreach zone_namePOS_pairs;

		[{hint localize "STR_DUWS_T_daqqfq5j"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];

	};

};

publicVariable "zone_namePOS_pairs";

// NO INTEL FOR 20 min
_temp = master_Intel_chance;
master_Intel_chance = 0;
publicVariable "master_Intel_chance";
sleep 1200;
master_Intel_chance = _temp;
publicVariable "master_Intel_chance";


