# Changelog

Changes made in this repo, newest first. Inherited DUWS / DUWS_X behaviour is not covered —
see [`README.md`](README.md) for the fork lineage. `git log` has the detail.

## Supports and transports

- Heli-lift aircraft moved to server ownership; the support works for non-host players again
- One failure handler per transport, replacing 9 and 6 copies that had drifted apart
- One cooldown scheme: 10s rejected, 120s completed, 300s destroyed — every timer spoken
- Fixed callsigns per support, replacing a random name and two random digits per call
- Boat taxi and both route pickers localised; the boat taxi had been English-only
- FOB refortify/reguard rebuilt server-side and gated on Squad_Leaders

## Multiplayer authority

- CP, AP and reputation changes made server-authoritative; pools floored at zero
- The server decides a purchase, not the buying client
- Zone capture and loss applied as one server-side transition
- High Command squads spawn on the server
- Two silent WARCOM multiplayer bugs repaired
- Sabotage-laptop completion decided on the server; its prop cleanup no longer dies with the hacker
- Locality stated on line 1 of every load-bearing function

## Source layout

- `duws/` reorganised into `server/`, `client/` and `shared/` by execution locality
- `src/` split into `modules/` (vendored, frozen) and `duws/` (owned)
- Subfolder names normalised to `lower_snake_case`
- Stringtable deduplicated; orphaned keys dropped

## Runtime logging

- `fnc_log` — tagged, level-gated lines that identify which machine emitted them
- `fnc_waitLogged` — a `waitUntil` that names what it is blocked on instead of hanging silently
- Function registry self-checks for entries that compiled empty from an unresolved path
- Zone generation reports progress on the map layer

## Campaign setup

- Preset row above the environment parameters; Classic is the shipped defaults, and editing any option drops the row to Custom
- Squad-callsign screen, threaded through the radio dialogue
- Back navigation through the setup screens; faction and HQ re-pickable
- Custom-faction paste split per side, with every required key and class validated
- AutoDetect faction picker moved into setup rather than after START
- Hardcore mode forces random zones
- Civilian system gained an OFF option; more starting-CP and death-penalty options
- Campaign ends on full capture; Domination mode dropped

## Player-facing

- HQ and FOB interactions route through one reusable list menu with CP costs and cooldowns
- Both disguise modes front a panel menu; civ-disguised players may use binoculars
- Diary manual reworked into a single subject with a numbered outline
- Killhouse reworked into waves, with free enemy movement and see-through contact markers
- Searching an arrested civilian no longer arms them and turns them on the player
- Earplugs always available
- Two full passes over user-facing prose, radio dialogue and notifications

## Tooling and docs

- `unpack.cmd` / `repack.cmd` wrap the vendored PBO Manager; `src/` is the source of truth
- `duws_eden.ps1` imports Eden compositions by marker comment; all fifteen share one row format
- `tests/run.sh` — SQF syntax, static path resolution, sqf-vm unit layer
- Reference docs in `docs/info/`; `docs/` holds feature plans
- [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md) tracks open defects and untested surface
