// Locality: server -- inherited from server/server_init.sqf.
//
// Five of the seven climates are one routine: set an opening overcast, force it, then loop
// re-rolling fog and overcast on the same cadence. They were written out per climate, so the four
// numbers that actually differ sat inside four near-identical copies of the loop. The two that are
// not that shape stay below as code: "varied" runs no fog at all and waits out a full cycle before
// its loop starts, and "none" pins everything to zero.
//
// setOvercast and setFog self-synchronise from the server, so nothing here broadcasts: a client
// wanting the current sky reads `overcast` / `fogParams`, which return the engine's own state.

waitUntil {!isNil "CIV_PRESENCE"};

// [opening overcast rand, its base, loop overcast rand, its base, fog intensity rand, its base,
//  fog is a fixed haze rather than a rolling bank]
private _climates = createHashMapFromArray [
    ["tropical",       [8, 0.2, 8, 0.2, 3, 0.1, false]],
    ["arid",           [3, 0,   3, 0,   0, 0,   true ]],
    ["temperate",      [4, 0.3, 5, 0.3, 2, 0,   false]],
    ["temperate_cold", [4, 0.4, 4, 0.4, 2, 0,   false]],
    ["mediterranean",  [6, 0,   6, 0,   2, 0,   false]]
];

private _def = _climates getOrDefault [weather_type, []];

if !(_def isEqualTo []) exitWith {
    _def params ["_firstRand", "_firstBase", "_loopRand", "_loopBase", "_fogRand", "_fogBase", "_fogFixed"];

    0 setOvercast ((random _firstRand) / 10 + _firstBase);
    sleep 0.1;
    forceWeatherChange;
    sleep 0.1;

    [_loopRand, _loopBase, _fogRand, _fogBase, _fogFixed] spawn {
        params ["_loopRand", "_loopBase", "_fogRand", "_fogBase", "_fogFixed"];
        while {true} do {
            // Cloud patterns take about 50 minutes to change fully, so a shorter wait would set a
            // target the sky never reaches before the next roll replaces it.
            private _wait = random [3000, 3900, 4200];

            if (_fogFixed) then {
                1 setFog [0.01, 0.01, 0.01];
            } else {
                private _fogTime = (random 60) * 60;
                private _intensity = (random _fogRand) / 10 + _fogBase;
                if (_intensity < 0.01) then { _intensity = 0.01 };
                private _height = (random 1) / 10;
                if (_height < 0.1) then { _height = 0.1 };
                _fogTime setFog [_intensity, _height, 10];
            };

            0 setOvercast ((random _loopRand) / 10 + _loopBase);

            sleep _wait;
        };
    };
};

switch (weather_type) do {

    // Overcast only, and rolled straight rather than out of ten -- this is the climate that is
    // allowed to be anything, so it spans the full range instead of a band. firstWeather is global
    // here as it always was.
    case "varied": {
        firstWeather = random 0.6;
        0 setOvercast firstWeather;
        sleep 0.1;
        forceWeatherChange;
        sleep 0.1;
        // Waits out one full cycle before the loop takes over, so the opening sky is the one the
        // player flies the intro under.
        sleep (random [3000, 3900, 4200]);
        [] spawn {
            while {true} do {
                private _wait = random [3000, 3900, 4200];
                0 setOvercast (random 1);
                sleep _wait;
            };
        };
    };

    case "none": { //TODO Expand on this
        [] spawn {
            while {true} do {
                private _wait = random 1800;
                0 setFog [0, 0, 10];
                0 setOvercast 0;
                sleep _wait;
            };
        };
    };

};
