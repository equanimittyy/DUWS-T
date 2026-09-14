// Campaign clock (seconds): engine `time` plus every second a rest has skipped (DUWS_timeSkew).
// `skiptime` moves the calendar and daytime but never `time`, so deadlines built on raw `time`
// ignore a rest; building and checking them on this clock lets a rest expire a live mission and
// keeps the baked wall-clock correct (daytime and this move 1:1). Any new skiptime must bump the skew.
time + (missionNamespace getVariable ["DUWS_timeSkew", 0])
