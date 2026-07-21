
// Add Action for "Squad Leads" to End or Extend (Domination mode) the campaign

campaign_status = "CAMPAIGN";

if ((vehiclevarname player) in Request_Players) then {
	hq_blu1 addaction [localize "STR_DUWS_T_xh2xta45",{campaign_status = "FINISH"}, "", 6, true, true, "", "_this == player"];
	// if less than 5, allow extended
	if (amount_zones_created < 3) then{
		hq_blu1 addaction [localize "STR_DUWS_T_9eomgiq6",{campaign_status = "DOMINATION"}, "", 5, true, true, "", "_this == player"];
	};
};

while {true} do {
	// someone else ended campaign
	if (DUWS_MODE == "FINISH") exitWith {};
	// someone else chose 'extended'
	if (DUWS_MODE == "DOMINATION") exitWith {};
	// this player ended campaign
	if (campaign_status == "FINISH") exitWith {
		DUWS_MODE = "FINISH";publicVariable "DUWS_MODE";
	};
	// this player chose 'extended'
	if (campaign_status == "DOMINATION") exitWith {
		DUWS_MODE = "DOMINATION";publicVariable "DUWS_MODE";
	};
	sleep 2;
};

removeAllActions hq_blu1;
