
// FOR ZEUS
if (!isServer) exitWith {};
while {true} do { 

	if (ZeusStatus == 1) then {
		{ 
			if (side _x == west) then { 
				Curator addCuratorEditableObjects [[_x],true]; 
			}; 
			if (side _x == civilian) then { 
				Curator addCuratorEditableObjects [[_x],true]; 
			}; 
		} foreach allUnits;
		{ 
			if (side _x == west) then { 
				Curator addCuratorEditableObjects [[_x],true]; 
			}; 
			// Civ "vehicles" reveals the statics in zones
			// Bad for hardcore mode
			if (DUWS_MODE == "HARDCORE") then {
				if (side _x == civilian && _x isKindOf 'Air') then { 
					Curator addCuratorEditableObjects [[_x],true]; 
				};
			} else {
				if (side _x == civilian) then {
					Curator addCuratorEditableObjects [[_x],true];
				}; 
			};
		} foreach vehicles;
		
	} else {	

		Curator addCuratorEditableObjects [allMissionObjects "ALL", true];

	};
	
	sleep 30;

};