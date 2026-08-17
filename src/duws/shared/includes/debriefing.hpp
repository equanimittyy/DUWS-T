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
		title = "$STR_DUWS_T_CAMPAIGN_LOST_TITLE";
		subtitle = "";
		// The hint's officer body, which carries no %1 to leave unsubstituted, so the card can
		// show it verbatim. Every loss is titled the same and named by its description alone.
		description = "$STR_DUWS_T_CAMPAIGN_LOST_OFFICER";
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

	// The card the abort button raises when the Game Master slot was never filled: not a campaign
	// loss (nothing was ever generated), so its own title and card text rather than the shared ones.
	class setup_aborted
	{
		title = "$STR_DUWS_T_NO_GM_TITLE";
		subtitle = "";
		description = "$STR_DUWS_T_NO_GM_ABORT_CARD";
		pictureBackground = "";
		picture = "\a3\ui_f\data\gui\cfg\hints\ActionMenu_ca.paa";
		pictureColor[] = {1,0,0,1};
	};
};
