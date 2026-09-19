// Locality: client -- remoteExecCall'd back by fnc_debug_opcom_ai. The overlay lines' only writer, and unscheduled, so
// the overlay loop never reads them half-written.
if (!hasInterface) exitWith {};
params ["_header", "_rows", "_events", "_seq"];
DUWS_dbgOpcomAiHeader = _header;
DUWS_dbgOpcomAiRows = _rows;
{ DUWS_dbgOpcomAiRecent pushBack [time, _x select 1] } forEach _events;
DUWS_dbgOpcomAiRecent = DUWS_dbgOpcomAiRecent select [(count DUWS_dbgOpcomAiRecent - 4) max 0];
DUWS_dbgOpcomAiSeq = _seq;
