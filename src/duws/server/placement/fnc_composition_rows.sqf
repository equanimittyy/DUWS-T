// Locality: server -- definition only, registered in server_fnc_init.sqf ahead of every caller.
//
// [_name, _layer] call fnc_composition_rows -> [[class, offX, offY, offZ, dir, isWeapon], ...]
// _name is an Eden composition under src/duws/compositions/, which description.ext includes as
// CfgCompositions >> _name. A non-empty _layer keeps only the objects under that top-level Eden layer.
//
// Offsets come from the DUWS_ORIGIN marker, in the frame DUWS_FRONT points down, never from Eden's
// center[]: a layout moved or turned before it was saved still reads back the same rows. Eden stores
// each height as the model centre over the ground beneath that object, which is what a weapon row's Z
// means to fnc_static_place, so heights pass through measured from the origin pole's base.
#define ORIGIN_POLE_Z 3.9775

fnc_composition_rows = {
    params ["_name", ["_layer", ""]];

    private _objects = [];
    private _markers = createHashMap;
    // Only objects are kept: Eden saves a static's crew as a Group and a module as a Logic, and
    // createVehicle cannot build either.
    private _walk = {
        params ["_items", "_topLayer"];
        {
            switch (getText (_x >> "dataType")) do {
                case "Object": {
                    private _var = getText (_x >> "Attributes" >> "name");
                    if (_var in ["DUWS_ORIGIN", "DUWS_FRONT"]) then {
                        _markers set [_var, _x];
                    } else {
                        if (_layer isEqualTo "" || {_topLayer isEqualTo _layer}) then { _objects pushBack _x };
                    };
                };
                case "Layer": {
                    [_x >> "Entities", [_topLayer, getText (_x >> "name")] select (_topLayer isEqualTo "")] call _walk;
                };
            };
        } forEach ("true" configClasses _items);
    };
    [missionConfigFile >> "CfgCompositions" >> _name >> "items", ""] call _walk;

    if (count _markers < 2) exitWith {
        ["ERROR", "COMPOSITION", format ["%1: no CfgCompositions class, or no DUWS_ORIGIN and DUWS_FRONT marker", _name]] call fnc_log;
        []
    };

    private _pos = {
        (getArray (_this >> "PositionInfo" >> "position")) params ["_px", "_ph", "_py"];
        [_px, _py, _ph]
    };
    ((_markers get "DUWS_ORIGIN") call _pos) params ["_ox", "_oy", "_oz"];
    private _front = (_markers get "DUWS_FRONT") call _pos;
    private _bear = ((_front select 0) - _ox) atan2 ((_front select 1) - _oy);
    private _cd = cos _bear;
    private _sd = sin _bear;
    private _base = _oz - ORIGIN_POLE_Z;
    private _weapons = DUWS_staticRoles apply { _x select 0 };

    _objects apply {
        (_x call _pos) params ["_px", "_py", "_ph"];
        private _dx = _px - _ox;
        private _dy = _py - _oy;
        private _class = getText (_x >> "type");
        [
            _class,
            _dx * _cd - _dy * _sd,
            _dx * _sd + _dy * _cd,
            _ph - _base,
            ((deg ((getArray (_x >> "PositionInfo" >> "angles")) param [1, 0])) - _bear + 360) % 360,
            _class in _weapons
        ]
    }
};
