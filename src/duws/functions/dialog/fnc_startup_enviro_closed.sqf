// startup_dialog onUnload. Fires on any close of the environment screen.
// NEXT leaves duws_faction_reselect false and fnc_process_enviro_menu opens the
// campaign screen; Back sets it, so re-enter the faction/HQ flow instead.
if (!isNil "duws_faction_reselect" && {duws_faction_reselect}) then {
    duws_faction_reselect = false;
    [] spawn fnc_startup_faction_flow;
};
