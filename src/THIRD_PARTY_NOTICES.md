# Third-party notices

Bundled third-party components and their licenses. The corresponding source for the
GPL-licensed components below is the DUWS_T source repository.

## [R3F] Logistics — `modules/R3F_LOG/`

Copyright (C) 2014 Team ~R3F~ (team-r3f.org). Licensed under the GNU General Public
License, version 3 or later. The original notice and full terms ship in
`modules/R3F_LOG/README.txt`.

Modified for DUWS_T:

- `modules/R3F_LOG/addons_config/A3_vanilla/Building.sqf` (2026-09-07): `FlagCarrierCore` is
  no longer vehicle cargo, so a zone's flagpole cannot leave its zone in a vehicle.
- `modules/R3F_LOG/config.sqf` (2026-08-13, 2026-09-27): logistics is off by default, so each
  object opts in; the creation factory condition refuses the captured builder vehicle inside an
  HQ or FOB ring.
- `modules/R3F_LOG/config_creation_factory.sqf` (2026-09-27): the sell-back rate is 1 instead
  of 0.75.
- `modules/R3F_LOG/objet_deplacable/deplacer.sqf` (2026-09-27): each object that settles after
  a drop is reported to the server, which holds a factory build within reach of its site and a
  builder-vehicle build out of every base ring.
- `modules/R3F_LOG/surveiller_conditions_actions_menu.sqf` and
  `modules/R3F_LOG/usine_creation/revendre_direct.sqf` (2026-09-27): the direct sale of a zone,
  HQ or FOB build accepts only the factory that made it, from anywhere in its site, instead of
  the nearest factory within 20 m.
- `modules/R3F_LOG/usine_creation/revendre_direct.sqf` and
  `modules/R3F_LOG/usine_creation/revendre_selection.sqf` (2026-09-28): a sale reads a factory
  without cargo, such as a zone flag, as holding nothing, so the sale completes instead of leaving
  the build marked as in transit.
- `modules/R3F_LOG/systeme_protection_blessures.sqf` (2026-09-11): the carry injury shield
  was widened from the host player's group to all local units, so a hand-carried vehicle
  cannot ram and kill unshielded AI.
- `modules/R3F_LOG/usine_creation/creer_objet.sqf` (2026-09-27): each new build is reported to
  the server, which files it under its factory for the campaign save.

Each change is also marked in its file's header, per GPLv3 §5(a).

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
