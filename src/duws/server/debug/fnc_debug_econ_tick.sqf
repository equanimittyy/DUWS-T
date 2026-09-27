// Locality: server. A real tick, not a dry run: it pays both sides, and the 30-minute clock keeps its own schedule.
if (!isServer) exitWith {};

diag_log "[DUWS econ tick debug]";
call fnc_zonesundercontrol;
