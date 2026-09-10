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
