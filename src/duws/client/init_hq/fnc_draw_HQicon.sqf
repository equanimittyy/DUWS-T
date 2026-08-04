// Locality: client -- inherited from client/client_init.sqf.

HQ_draw_icon = {
	drawIcon3D ["\a3\ui_f\data\gui\cfg\hints\Commanding_ca.paa", [0.2,1,0.2,0.5], [PosOfBLUHQ select 0,PosOfBLUHQ select 1,2.5], 1, 1, 0, "Headquarters", 1, 0.025, "TahomaB"];
};

// 30 m in and out, matching the facility icons in fnc_draw_HQfacilities.sqf: the two are read
// together and a base icon that outranged its own signposts read as the odd one out.
while {alive hq_blu1} do {
    waitUntil {sleep 2; player distance PosOfBLUHQ < 30};
    _addStackedEHfnc = ["draw_hq_icon", "onEachFrame", "HQ_draw_icon"] call BIS_fnc_addStackedEventHandler;
    sleep 0.1;

    waitUntil {sleep 0.2; player distance PosOfBLUHQ > 30};
    [_addStackedEHfnc, "onEachFrame"] call BIS_fnc_removeStackedEventHandler;
    onEachFrame {};
};