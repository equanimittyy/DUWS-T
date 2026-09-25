// Locality: server, executed at load by server_fnc_init ([] call compile) so it can define several
// functions. A port is the water cell a coastal zone owns for its boats (spawn point, garrison anchor), drawn
// from the router's own water mask so it is always routable. A zone with no port refuses boats outright.
if (!isServer) exitWith {};

DUWS_fnc_opcom_portOf = {
    params ["_key"];
    DUWS_opcom_zonePort getOrDefault [_key, -1]
};

DUWS_fnc_opcom_ports_init = {
    private _ports = createHashMap;
    private _w = DUWS_opcom_grid_w;
    DUWS_opcom_box params ["_minCx", "_minCy", "_maxCx", "_maxCy"];

    private _fnc_landAdj = {
        params ["_ni"];
        private _ix = _ni mod _w;
        private _iy = floor (_ni / _w);
        private _found = false;
        for "_dy" from -1 to 1 do {
            for "_dx" from -1 to 1 do {
                if (!_found && {_dx != 0 || _dy != 0}) then {
                    private _nx = _ix + _dx;
                    private _ny = _iy + _dy;
                    if (_nx >= _minCx && {_nx <= _maxCx} && {_ny >= _minCy} && {_ny <= _maxCy}) then {
                        _found = DUWS_opcom_grid_land select (_ny * _w + _nx);
                    };
                };
            };
        };
        _found
    };

    private _cands = [];
    {
        if ((_x select [0, 5]) == "zone_") then {
            private _zpos = ([_x] call fnc_site_at) getOrDefault ["pos", []];
            if (_zpos isNotEqualTo []) then {
                private _ci = [_zpos] call DUWS_fnc_opcom_w2c;
                private _cx = _ci mod _w;
                private _cy = floor (_ci / _w);
                private _list = [];
                for "_dy" from -3 to 3 do {
                    for "_dx" from -3 to 3 do {
                        private _nx = _cx + _dx;
                        private _ny = _cy + _dy;
                        if (_nx >= _minCx && {_nx <= _maxCx} && {_ny >= _minCy} && {_ny <= _maxCy}) then {
                            private _ni = _ny * _w + _nx;
                            if ((DUWS_opcom_grid_water select _ni) >= 0) then {
                                _list pushBack [_zpos distance2D ([_ni] call DUWS_fnc_opcom_c2w), _ni];
                            };
                        };
                    };
                };
                if (_list isNotEqualTo []) then {
                    _list sort true;
                    _cands pushBack [_list select 0 select 0, _x, _list];
                };
            };
        };
    } forEach keys DUWS_sites;

    // Nearest-paired zones claim first, so a contested cell keeps its closest zone.
    _cands sort true;

    private _claimed = createHashMap;
    {
        _x params ["_bestD", "_key", "_list"];
        private _done = false;
        {
            private _ni = _x select 1;
            if (!_done && {!(_claimed getOrDefault [_ni, false])}) then {
                // A zone's own nearest cell needs no land check; a fallback must reach land.
                if (_forEachIndex == 0 || { [_ni] call _fnc_landAdj }) then {
                    _ports set [_key, _ni];
                    _claimed set [_ni, true];
                    _done = true;
                };
            };
        } forEach _list;
    } forEach _cands;

    // Named off the zone's position, like fnc_createzone's pair, so the reveal paint and the capture
    // recolours reach it by name; the colour is read off the zone icon, never fixed, so it reads for whoever holds it.
    {
        private _zpos = ([_x] call fnc_site_at) get "pos";
        private _zi = format ["%1%2", round (_zpos select 0), round (_zpos select 1)];
        private _pm = _zi + "port";
        createMarker [str(_pm), [_y] call DUWS_fnc_opcom_c2w];
        str(_pm) setMarkerShape "ICON";
        str(_pm) setMarkerType "loc_Quay";
        str(_pm) setMarkerColor (getMarkerColor str(_zi));
        str(_pm) setMarkerSize [0.7, 0.7];
        str(_pm) setMarkerAlpha ([0, 1] select (!hardcore_mode_enable));
    } forEach _ports;

    // Published whole and last: the overlay gather takes its presence as OPCOM init done.
    DUWS_opcom_zonePort = _ports;
};
