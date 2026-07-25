// Locality: client -- startup_dialog2's onUnload handler (shared/includes/campaign_menu.hpp:8).
if (chosen_settings) exitWith {};
// Advancing forward to the callsign screen (START-R / START-M): the button handler
// reopens the flow, so don't treat this close as a Back to the enviro screen.
if (!isNil "duws_campaign_forward" && {duws_campaign_forward}) exitWith { duws_campaign_forward = false; };
[] spawn fnc_enviro_menu;
