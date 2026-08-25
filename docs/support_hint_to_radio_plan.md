# Plan: move support notifications off the hint box onto the radio

## Goal

Apply the surface rule in
[`info/player_facing_text.md`](info/player_facing_text.md#which-surface-a-message-goes-to-and-never-both):
**a line a callsign could speak goes to the radio net; the hint box is kept for gameplay directives.**
Every hint dropped below is replaced by a dialogue line that carries the same information — where an
existing radio line already says it, that line is reused (and rewritten if it was missing something
the hint had); where none does, a new line is added. No dropped hint loses its content.

Channels follow `fnc_duws_dialogue_channel`: **Overlord speaks on NET**; every support callsign
(Courier, Chalk, Chariot, Mule, the arty callsigns) speaks on **SUB-NET**, the radio log. Callsign
substitution is automatic inside `fnc_duws_dialogue`, so any `Alpha 1-1` below resolves to the host
callsign — do not wrap it. Line numbers drift as files are edited (arty especially); the stringtable
**key** is the stable anchor.

Each line is one change, editable in place. Disposition tags: `new` = add key + dialogue call;
`rewrite` = edit an existing radio line to catch up; `existing` = radio already says it, hint was a
pure duplicate; `decision` = needs a call from you (collected at the end).

## Channel routing prerequisite

`fnc_duws_dialogue_channel` defaults an unlisted speaker to **VOICE** (the loud subtitle), not
SUB-NET. `DUWS_subnetSpeakers` in `src/duws/client/misc/fnc_duws_dialogue.sqf` still lists only
`slingshot` among the arty callsigns; the tier callsigns minted since — `redleg` (tube arty),
`sledge` (mortar HE and smoke), `slingshot_2` (JDAM), `reaper` (cluster), `reaper_2` (napalm) — are
absent, so their lines land on VOICE, the prominent surface the guide reserves for Overlord and
Alpha 1-1. Register all five in `DUWS_subnetSpeakers` before the Arty rewrites below, or those lines
route to the wrong surface whatever text they carry. The lint does not catch this — the router is
kept out of the headless VM on purpose (`localize`/chat/UI), so a missing table entry is silent.

## Arty

- `fqeghaut` (ground) — drop hint "Grid received. Rounds on the way, 60 seconds." → **firing callsign** / SUB-NET: "Grid received. Rounds on the way, sixty seconds." — existing `77l9izur`, unchanged
- `fqeghaut` (air) — drop hint "Grid received. Rounds on the way, 60 seconds." → **firing callsign** / SUB-NET: "Inbound to target. Rounds in sixty seconds." — rewrite: new air-only key `artyair_inbound`, leave laser's `stmeajce` "Inbound to target." untouched
- `moassj3z` (ground) — drop hint "Rounds ready. Splash in 30 seconds." → **firing callsign** / SUB-NET: "Rounds ready. Splash in thirty seconds." — existing `hf9bhgvb`, unchanged
- `moassj3z` (air) — drop hint "Rounds ready. Splash in 30 seconds." → **firing callsign** / SUB-NET: "On final approach, target in sight. Splash in thirty seconds." — rewrite `0jegiaf4` (air-only, safe)
- `9wu0cgea` (air) — drop hint "Attack Plane was shot down. Airstrike failed." → **Overlord** / NET: "Be advised, Alpha 1-1, %1 was shot down. Your strike is off." — existing `jet_down`, unchanged
- `t6y8r92y` — drop hint "Fire mission complete." → **firing callsign** / SUB-NET: "Rounds complete. Fire mission out." — new `artycomplete`

## FOB

- `cp9cw550` (hint copy) — drop hint "Requesting a FOB on my position…" → **Alpha 1-1** / SUB-NET: (text unchanged) — existing radio `cp9cw550`, same beat
- `8zn96920` (hint copy) — drop hint "Request denied. Enemies are too close to this position." → **Overlord** / NET: "Request denied. Enemies are too close to this position." — existing radio `8zn96920`, unchanged

## Supply drop (Courier 1-1)

Supply drop is the closest thing here to a clean reference flow, and the shape the others should copy:
a request on the net, a callsign that works the tasking on SUB-NET, and delivery marked on the player's
own surface. Two gaps keep it from being the model outright:

1. **Request has no answer.** Alpha 1-1 calls the drop up to Overlord, and the next voice on the net is
   already Courier 1-1 — Overlord never acknowledges. A request on NET should draw an Overlord reply on
   NET before the tasking callsign speaks (the `supplydropack` bullet below).
2. **Delivery double-fires.** The crate landing throws both a hint box and an A3 card (green smoke). It
   should be the hint box alone: the A3 card is reserved for important team news, not a routine crate
   marker every player already sees smoke for. Same call for the paradrop / vehicle-drop delivery cards.

- request beat — Alpha 1-1 calls the drop to Overlord; Overlord does not answer today. Add **Overlord** / NET ack before Courier keys up — new `supplydropack` (the reference gap: a net request with no acknowledgement)
- `y91vei53` / `17hh9rx4` — drop hint "Supply Drop Inbound. ETA: 1 min." → **Courier 1-1** / SUB-NET: "This is Courier 1-1, deploying a supply crate to your position. ETA forty seconds." — existing `supplydropcallend` (note: hint said one minute, radio says forty seconds — pick one)
- `zhiugl0g` — drop hint "Supply Drop On Station." → **Courier 1-1** / SUB-NET: "This is Courier 1-1, on station over your position. Crate coming down." — new `supplydroponstation`
- `supplydropfail` — drop hint "The transport was shot down. Supply drop failed." → **Overlord** / NET: "Be advised, Alpha 1-1, Courier 1-1 is down. Your supply drop is off." — new `supplydropdown`
- `wdttb5b8` — delivery beat: keep the hint box, drop the A3 green-smoke card (card reserved for important news). Optionally add a **Courier 1-1** / SUB-NET sign-off: "Crate's on the ground at your position. Courier 1-1 out." — new `supplydropdelivered`

## Paradrop (Chalk 2-1)

- `r8ubc9jy` / `5iciamva` — drop hint "Paradrop Inbound. ETA: 1 minute." → **Chalk 2-1** / SUB-NET: "This is Chalk 2-1, inbound to your grid. ETA one minute." — new `paradropinbound`
- `o4p4grm4` — drop hint "Paradrop On Station." → **Chalk 2-1** / SUB-NET: "This is Chalk 2-1, on station. Stand by for the drop." — new `paradroponstation`
- `zm99dbgu` — drop hint "Paratroopers deployed." → **Chalk 2-1** / SUB-NET: "Chutes away. Troopers on the ground, linking up now." — new `paradropdeployed` (existing `paradropcallend` at this beat says only "LZ in sight", does not cover deployed)
- `0xtit0ht` — drop hint "The paratroopers are now under your command." → **Overlord** / NET: "Be advised, Alpha 1-1, the paratrooper squad is now under your command." — existing `paradropcall` + A3 card cover it (decision: card only, or move this line to the end beat)
- `2bwz0z4w` — drop hint "The transport was shot down. Paradrop failed." → **Overlord** / NET: "Be advised, Alpha 1-1, Chalk 2-1 is down. No paratroopers inbound." — new `paradropdown`

## Vehicle drop (transport callsign — decision)

- `6cwj6h8z` — drop hint "Vehicle Drop Inbound." → **Overlord** / NET: "Request received. Drop ETA forty seconds." — existing `vehdropcallend`
- `9tpm5uf6` — drop hint "Vehicle Drop On Station." → **transport callsign** / SUB-NET: "Transport on station over your position, setting the vehicle down." — new `vehdroponstation` (existing radio only says inbound-ETA and fired before arrival; the real on-station beat has no line)
- `7h0bmzi7` — drop hint "The transport was shot down. Vehicle drop failed." → **Overlord** / NET: "Be advised, Alpha 1-1, the transport is down. Your vehicle drop is off." — new `vehdropdown`
- `iv3s5xlc` — drop hint "A vehicle has been dropped near your location." → **transport callsign** / SUB-NET: "Vehicle's on the ground at your position." — new `vehdropdelivered` (A3 card also fires — decision)

## Helo taxi (Chariot 1-1)

- `helotaxichopperinbound` — drop hint "Transport aircraft is inbound." → **Chariot 1-1** / SUB-NET: "Alpha 1-1, ETA forty seconds. Clear the LZ." — existing radio (L32)

## Helolift

- `helolift_noheli` — drop hint "Heavy transport could not reach your position." → **Overlord** / NET: "Be advised, Alpha 1-1, heavy transport can't reach your position. Tasking aborted." — new `heloliftnoreach`

## UAV recon — decision

- `6u8qilfh` — hint "Coordinates received." → **Allseer** / SUB-NET: "Coordinates received, tasking the UAV overhead." (new `uav_coords`) — or keep as a hint (it is click feedback, not status)

## Keep in the hint box (directives — no change)

`laser_loiter`, `pilotwp`, `helotaxi2wp`, `helotaxiwp_reopen`, the `hint ""` clear · `helolift_notarget`, `helolift_badtarget`, `too_close_enemy`, `nolz`, `boattaxi_noshore`, `7yy0wapp` (750 m rule) · `rjuehu36`, `gu6cbc5f` (access key) · `vehicle_garage_no_vehicle`, `repair_select_pylon` · `veh_drop_none`, `tier_locked_hint`, `SUPPORT_BUSY`, `346eazcm` · buy menu: `inssupport`, `8c1i4vga`, `e95mc4lv`, `SUPPORT_NO_REFUND`, `dvbox9ay`, purchase `_msg`.

Borderline: `liftwp_incomplete` "Route incomplete, tasking aborted" — kept as a hint because the Overlord abort radio (`heloliftabort`) says "aborting" but not the reason; fold the reason into the radio to drop it too, or leave it.

## Side effects (fall out of the drops, no extra work)

- Removing the paradrop and supply inbound hints ends the overwrite flicker where the ETA hint is instantly replaced by a bare "Inbound" hint the same frame.
- Removing `9tpm5uf6` removes the veh-drop "On Station" that printed before the aircraft arrives.

## Open decisions

1. Arty air timing — accept the `artyair_inbound` / `0jegiaf4` rewrites that add the countdown, or let air lose the numbers.
2. Vehicle-drop transport callsign — mint one (parallel to Courier / Chalk / Chariot) for `vehdroponstation`, `vehdropdelivered`, or route them through Overlord.
3. Delivered lines vs the A3 card — **decided:** the A3 card is reserved for important team news, so drop the green-smoke card on routine supply / paradrop / veh-drop delivery and keep the hint box. Still open only: whether to also add the Courier / transport SUB-NET sign-off, or leave the delivery on the hint box alone.
4. Paradrop "under command" — the start radio + card already say it; drop the hint with no new line, or move a confirmation to the end beat.
5. UAV `6u8qilfh` — voice it (Allseer) or keep the hint.
6. Supply ETA wording — hint said one minute, radio says forty seconds; unify.
7. Alpha 1-1's channel — the guide names Overlord and Alpha 1-1 as the NET voices, but `actionteam` currently defaults to VOICE and the FOB `cp9cw550` line above is tagged SUB-NET. Decide whether the team callsign joins `DUWS_netSpeakers` (NET, with squelch) and retag its lines to match, or stays on SUB-NET with only Overlord on NET.

## Task list

- [ ] Settle the seven open decisions.
- [ ] Register the arty tier callsigns (`redleg`, `sledge`, `slingshot_2`, `reaper`, `reaper_2`) in `DUWS_subnetSpeakers` (channel routing prerequisite).
- [ ] Add the `new` / `rewrite` stringtable keys (English real; DE/ES/ZH English placeholders per the localisation-lag convention).
- [ ] Replace each dropped hint with its `fnc_duws_dialogue` call at the same beat.
- [ ] Playtest each support once: no beat goes silent, nothing double-fires.
