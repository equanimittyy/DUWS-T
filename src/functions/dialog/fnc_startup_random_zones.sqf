
[] spawn fnc_process_campaign_menu;
waitUntil {sleep 0.1;createzone_server};

manually_chosen = false;publicVariable "manually_chosen";

// Give the go! WARCOM can continue execution
chosen_settings = true;publicVariable "chosen_settings"; 

diag_log format["--- DUWS_T CHOSEN SETTINGS -RANDOM----- Max radius: %1-------Min radius: %2-------Zones number: %3-------Command points: %4-------BLU AP: %5-------OPF AP: %6-------Weather type: %7-------BLU AI skill: %8-------OPF AI skill: %9",zones_max_radius,zones_min_radius,zones_number,commandpointsblu1,WARCOM_opfor_ap,WARCOM_blufor_ap,weather_type,blufor_ai_skill,opfor_ai_skill];
closeDialog 0;
