class CfgDebriefing
{  
	class island_captured_win
	{
		title = "$STR_DUWS_T_9dt4d8rm";
		subtitle = "";
		description = "$STR_DUWS_T_zoriyn4u";
		pictureBackground = "";
		picture = "\a3\Ui_f\data\GUI\Cfg\CommunicationMenu\attack_ca.paa";
		pictureColor[] = {0.0,0,1,1};
	};

 	class officerkilled
	{
		title = "$STR_DUWS_T_vl40q84w";
		subtitle = "";
		description = "$STR_DUWS_T_b212193q";
		pictureBackground = "";
		picture = "\a3\ui_f\data\gui\cfg\hints\ActionMenu_ca.paa";
		pictureColor[] = {1,0,0,1};
	};
 	class island_ruined
	{
		title = "$STR_DUWS_T_CAMPAIGN_LOST_TITLE";
		subtitle = "";
		// Its own key, not the hint's: config text is shown verbatim, so the hint's %1 map-name
		// placeholder would reach the player unsubstituted on the outro card.
		description = "$STR_DUWS_T_CAMPAIGN_LOST_CARD";
		pictureBackground = "";
		picture = "\a3\ui_f\data\gui\cfg\hints\ActionMenu_ca.paa";
		pictureColor[] = {1,0,0,1};
	};
};
