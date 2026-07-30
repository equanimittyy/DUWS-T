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