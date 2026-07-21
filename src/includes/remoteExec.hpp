class CfgRemoteExec
{
	// List of script functions allowed to be sent from client via remoteExec
	class Functions
	{
		// RemoteExec modes:
		// 0- turned off
		// 1- turned on, taking whitelist into account
		// 2- turned on, ignoring whitelist (default, because of backward compatibility)
		mode = 2;

		// Ability to send jip messages: 0-disabled, 1-enabled (default)
		jip = 1;

		// your functions here
		
		/*class DUWS_fnc_fob
		{
			allowedTargets = 1;	// can target clients
			jip = 1;			// sending JIP messages is enabled for this function (overrides settings in the Functions class)
		};
		};
		class DUWS_fnc_playerTF
		{
			allowedTargets = 2;	// can target server
			jip = 1;			// sending JIP messages is enabled for this function (overrides settings in the Functions class)
		};
		
		//class YourFunctionOne { allowedTargets = 1; }; // can target only clients
		//class YourFunctionTwo { allowedTargets = 2; }; // can target only the server
		class vcm_serverask { allowedTargets = 0;jip = 1; };
		class VCM_PublicScript { allowedTargets = 0;jip = 1; };
		class BIS_fnc_debugConsoleExec { allowedTargets = 0;jip = 1; };
		class SpawnScript { allowedTargets = 0;jip = 1; };
		class enableSimulationGlobal { allowedTargets = 0;jip = 1; };
		class VCM_fnc_KnowAbout { allowedTargets = 0;jip = 1; };
		*/
	};


	// List of script commands allowed to be sent from client via remoteExec
	class Commands
	{
		mode = 2;
		jip = 1;
		
		// your commands here
		
		/*class execVM
		{
			allowedTargets = 2;	// can target only the server
			jip = 0;			// sending JIP is turned off (overrides settings in the Commands class)
		};*/
		
	};


};