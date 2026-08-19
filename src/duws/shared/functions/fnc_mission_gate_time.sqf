// Locality: any -- broadcast. Sibling of fnc_mission_gate_left: that returns the wait remaining,
// this turns it into the in-game clock time the gate opens, so the hint can name the hour the
// player watches for rather than a duration they have to count down.
//
// Time-of-day, "HH:MM", zero-padded 24h. The gate opens `daytime + gate_left` hours from now;
// daytime is a synced global, so every machine formats the same clock. Wraps past midnight -- the
// campaign clock is what the player reads, so a gate that opens at 00:40 reads "00:40", not "24:40".

private _open = (daytime + ([] call fnc_mission_gate_left)) % 24;

// Round to the minute off a single total-minutes value, not hours and minutes apart: rounding each
// leg can carry a 59.6m up to 60 and print "11:60".
private _mins = (round (_open * 60)) % 1440;
private _hh = floor (_mins / 60);
private _mm = _mins % 60;

format ["%1:%2",
    if (_hh < 10) then { "0" + str _hh } else { str _hh },
    if (_mm < 10) then { "0" + str _mm } else { str _mm }]
