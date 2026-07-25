// Locality: server -- inherited from server/server_init.sqf.
_weather_loop = true;

// 确保 CIV_PRESENCE 已从环境菜单同步
waitUntil {!isNil "CIV_PRESENCE"};
switch (weather_type) do {
    case "tropical": {
		_firstWeather = random 8; 
		_firstWeather = (_firstWeather / 10); 
		_firstWeather = (_firstWeather + 0.2);  // base weather
		OvercastVar = _firstWeather;
		0 setOvercast OvercastVar;
		sleep 0.1;
		forceWeatherChange;
		sleep 0.1;
		[] spawn {
			while {true} do {
				_wait_after = random [3000,3900,4200];   // cloud patterns take 50min to fully change

				_fog_time = random 60; // MINUTES
				_fog_time = (_fog_time * 60); // transfor to seconds
				_fog_intensity = random 3;
				_fog_intensity = (_fog_intensity / 10); 
				_fog_intensity = (_fog_intensity + 0.1); 
				if (_fog_intensity<0.01) then {_fog_intensity = 0.01};
				_fog_height = random 1;
				_fog_height = (_fog_height / 10); // transforme en centiemes
				if (_fog_height<0.1) then {_fog_height = 0.1};

				FogArray = [_fog_intensity, _fog_height, 10];
				_fog_time setFog FogArray;

				_overcast_intensity = random 8; 
				_overcast_intensity = (_overcast_intensity / 10); 
				_overcast_intensity = (_overcast_intensity + 0.2);  // base weather
				OvercastVar = _overcast_intensity;
				0 setOvercast OvercastVar;

				_wait_total = _fog_time + _wait_after;
				_wait_total_minute = _wait_total / 60;
				sleep _wait_after;
			}; //end while
		};
    }; //end case
    case "arid": {
		_firstWeather = random 3;
		_firstWeather = (_firstWeather / 10);  // base weather
		OvercastVar = _firstWeather;
		0 setOvercast OvercastVar;
		sleep 0.1;
		forceWeatherChange;
		sleep 0.1;
		[] spawn {
			while {true} do {
				_wait_after = random [3000,3900,4200];   // cloud patterns take 50min to fully change

				_fog_time = random 60; // MINUTES
				_fog_time = (_fog_time * 60); // transform to seconds

				FogArray = [0.01, 0.01, 0.01];
				1 setFog FogArray;
				
				_overcast_intensity = random 3;
				_overcast_intensity = (_overcast_intensity / 10); 
				OvercastVar = _overcast_intensity;
				0 setOvercast OvercastVar;
				
				_fog_time = 0;
				_wait_total = _fog_time + _wait_after;
				_wait_total_minute = _wait_total / 60;
				sleep _wait_after;
			}; //end while
		};
    };
    case "temperate": {
		_firstWeather = random 4;
		_firstWeather = (_firstWeather / 10);
		_firstWeather = (_firstWeather + 0.3);  // base weather
		OvercastVar = _firstWeather;
		0 setOvercast OvercastVar;
		sleep 0.1;
		forceWeatherChange;
		sleep 0.1;
		[] spawn {
			while {true} do {
				_wait_after = random [3000,3900,4200];   // cloud patterns take 50min to fully change

				_fog_time = random 60; // MINUTES 
				_fog_time = (_fog_time * 60); // transform to seconds
				_fog_intensity = random 2;
				_fog_intensity = (_fog_intensity / 10); 
				if (_fog_intensity<0.01) then {_fog_intensity = 0.01};
				_fog_height = random 1;
				_fog_height = (_fog_height / 10); 
				if (_fog_height<0.1) then {_fog_height = 0.1};
				
				FogArray = [_fog_intensity, _fog_height, 10];
				_fog_time setFog FogArray;
				
				_overcast_intensity = random 5;
				_overcast_intensity = (_overcast_intensity / 10); 
				_overcast_intensity = (_overcast_intensity + 0.3);  
				OvercastVar = _overcast_intensity;
				0 setOvercast OvercastVar;

				_wait_total = _fog_time + _wait_after;
				_wait_total_minute = _wait_total / 60;
				sleep _wait_after;
			}; //end while
		};
    };
    case "temperate_cold": {
		_firstWeather = random 4;
		_firstWeather = (_firstWeather / 10);
		_firstWeather = (_firstWeather + 0.4);  // base weather is 0.4
		OvercastVar = _firstWeather;
		0 setOvercast OvercastVar;
		sleep 0.1;
		forceWeatherChange;
		sleep 0.1;
		[] spawn {
			while {true} do {
				_wait_after = random [3000,3900,4200];   // cloud patterns take 50min to fully change

				_fog_time = random 60; // MINUTES
				_fog_time = (_fog_time * 60); // transform to seconds
				_fog_intensity = random 2;
				_fog_intensity = (_fog_intensity / 10); 
				if (_fog_intensity<0.01) then {_fog_intensity = 0.01};
				_fog_height = random 1;
				_fog_height = (_fog_height / 10); 
				if (_fog_height<0.1) then {_fog_height = 0.1};
				FogArray = [_fog_intensity, _fog_height, 10];
				_fog_time setFog FogArray;
				
				_overcast_intensity = random 4;
				_overcast_intensity = (_overcast_intensity / 10); 
				_overcast_intensity = (_overcast_intensity + 0.4);  // base weather is 0.4
				OvercastVar = _overcast_intensity;
				0 setOvercast OvercastVar;

				_wait_total = _fog_time + _wait_after;
				_wait_total_minute = _wait_total / 60;
				sleep _wait_after;
			}; //end while
		};
    };
    case "mediterranean": {
		_firstWeather = random 6;
		_firstWeather = (_firstWeather / 10);
		OvercastVar = _firstWeather;
		0 setOvercast OvercastVar;
		sleep 0.1;
		forceWeatherChange;
		sleep 0.1;
		[] spawn {
			while {true} do {
				_wait_after = random [3000,3900,4200];   // cloud patterns take 50min to fully change

				_fog_time = random 60; // EN MINUTES !!
				_fog_time = (_fog_time * 60); // transform to seconds
				_fog_intensity = random 2;
				_fog_intensity = (_fog_intensity / 10); 
				if (_fog_intensity<0.01) then {_fog_intensity = 0.01};
				_fog_height = random 1;
				_fog_height = (_fog_height / 10); 
				if (_fog_height<0.1) then {_fog_height = 0.1};

				FogArray = [_fog_intensity, _fog_height, 10];
				_fog_time setFog FogArray;

				_overcast_intensity = random 6;
				_overcast_intensity = (_overcast_intensity / 10); 
				OvercastVar = _overcast_intensity;
				0 setOvercast OvercastVar;
				_wait_total = _fog_time + _wait_after;
				_wait_total_minute = _wait_total / 60;
				sleep _wait_after;
			}; //end while
		};
    };
	case "varied": {
		firstWeather = random 0.6;
		OvercastVar = firstWeather;
		//skipTime -24;
		//86400 setOvercast firstWeather;
		//skipTime 24;
		0 setOvercast firstWeather;
		sleep 0.1;
		forceWeatherChange;
		sleep 0.1;
		_wait_after = random [3000,3900,4200];   // cloud patterns take 50min to fully change
		sleep _wait_after;
        [] spawn {
			while {true} do {
				_wait_after = random [3000,3900,4200];   // cloud patterns take 50min to fully change
				_overcast_intensity = random 1;
				OvercastVar = _overcast_intensity;
				0 setOvercast OvercastVar;
				sleep _wait_after;
			}; //end while
		};
    };

	case "none": { //TODO Expand on this
        [] spawn {
			while {true} do {
				_wait_after = random 1800;

				_fog_time = 0;
				_fog_intensity = 0;
				_fog_height = 0;
				FogArray = [_fog_intensity, _fog_height, 10];
				_fog_time setFog FogArray;

				_overcast_intensity = 0;
				OvercastVar = _overcast_intensity;
				0 setOvercast OvercastVar;
			
				_wait_total = _fog_time + _wait_after;
				_wait_total_minute = _wait_total / 60;
				sleep _wait_after;
			}; //end while
		};
    };

};