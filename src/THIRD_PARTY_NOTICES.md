# Third-party notices

Bundled third-party components and their licenses. The corresponding source for the
GPL-licensed components below is the DUWS_T source repository.

## [R3F] Logistics — `modules/R3F_LOG/`

Copyright (C) 2014 Team ~R3F~ (team-r3f.org). Licensed under the GNU General Public
License, version 3 or later. The original notice and full terms ship in
`modules/R3F_LOG/README.txt`.

Modified for DUWS_T:

- `modules/R3F_LOG/systeme_protection_blessures.sqf` (2026-09-11): the carry injury shield
  was widened from the host player's group to all local units, so a hand-carried vehicle
  cannot ram and kill unshielded AI. The change is also marked in that file's header, per
  GPLv3 §5(a).

## A3 Wounding System (AIS) — `modules/AIS/`

Copyright (C) Psychobastard. Licensed under the Creative Commons
Attribution-NonCommercial-ShareAlike 3.0 Unported license (CC BY-NC-SA 3.0). The author's own
notice and the full terms are in section 4.3 of
`modules/AIS/A3 Wounding System - Documentation & ReadMe.pdf`, which ships with the module.

Modified for DUWS_T:

- `modules/AIS/Core/fn_postinit.sqf`: AIS starts only when the mission's `Revive` parameter
  selects it, so a mission that runs no revive or hands wounding to ACE does not load AIS.
- `modules/AIS/System/fn_postinit.sqf` (2026-08-03): the same gate, which this half lacked. It
  registered its player actions against an `AIS_Core_realPlayer` that the gated Core half never
  set, and wrote ninety-eight undefined-variable errors on every boot.

Both changes are marked in their files' headers.
