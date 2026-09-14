// True once the campaign clock has passed an absolute target built by fnc_time_deadline. The single
// place mission deadlines are tested, so a rest (which advances the campaign clock, not `time`) trips
// them -- see fnc_campaign_now.
params ["_t"];
(call fnc_campaign_now) > _t
