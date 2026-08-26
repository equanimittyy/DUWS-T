# Plan: move support notifications off the hint box onto the radio

## Goal

Apply the surface rule in
[`info/player_facing_text.md`](../info/gameplay/player_facing_text.md#which-surface-a-message-goes-to-and-never-both):
**a line a callsign could speak goes to the radio net; the hint box is kept for gameplay directives.**
Every hint dropped below is replaced by a dialogue line that carries the same information — where an
existing radio line already says it, that line is reused (and rewritten if it was missing something
the hint had); where none does, a new line is added. No dropped hint loses its content.

Channels follow `fnc_duws_dialogue_channel`, which sorts a speaker to one of three surfaces:
**NET** (prominent subtitle, radio squelch) for **Overlord**; **SUB-NET** (bottom-left radio log,
squelch) for every support callsign (Courier, Chalk, Chariot, Mule, the arty callsigns); **VOICE**
(loud subtitle, no squelch) for **Alpha 1-1 (the player callsign)**. Alpha 1-1 is on VOICE, not the
radio: the team speaks co-located, in the room, so its lines carry no squelch tone and never route to
SUB-NET. VOICE is also the router's default for any unlisted speaker, so Alpha 1-1 needs no table
entry — leaving `STR_DUWS_T_actionteam` out of both `DUWS_netSpeakers` and `DUWS_subnetSpeakers` is
what puts it on VOICE. Every support flow opens with an Alpha 1-1 request — already its speaker in each
support fn — and the tasking callsign answers on SUB-NET. Callsign substitution is automatic
inside `fnc_duws_dialogue`, so any `Alpha 1-1` below resolves to the host callsign — do not wrap it.
The team callsign also renders with the requesting player's name — `Alpha 1-1 ({player who called})` —
which is strictly the caller: captured at each support call site and passed to `fnc_duws_dialogue` as
its 4th arg (`_caller`). Alpha 1-1 lines with no caller (mission chatter, the intro) pass nothing and
fall back to the team senior. Line numbers drift as files are edited (arty especially); the
stringtable **key** is the stable anchor.

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

Alpha 1-1 needs the opposite of the arty fix: no list entry at all. Every support opens with an
Alpha 1-1 request voiced by the `STR_DUWS_T_actionteam` speaker — `fnc_request_fob` (FOB),
`fnc_ammobox` (supply), `fnc_arty`, `fnc_veh_drop`, `fnc_helolift`, `fnc_helotaxi`, `fnc_uav_scanner`.
`STR_DUWS_T_actionteam` is in neither `DUWS_netSpeakers` nor `DUWS_subnetSpeakers`, so the router
defaults every one of those request lines to VOICE — the loud subtitle with no squelch, which is
exactly right: the team speaks in the room, not over the radio. Leave the speaker unlisted; that is
the whole change for Alpha 1-1. The `Alpha 1-1 ({player who called})` suffix is the caller, passed as
the 4th arg (`_caller`) to `fnc_duws_dialogue` at each support call site (client fns pass
`name player`; the server-side UAV passes `name _caller`); non-support Alpha 1-1 lines fall back to
the team senior.

## Arty

- `fqeghaut` (ground) — drop hint "Grid received. Rounds on the way, 60 seconds." → **firing callsign** / SUB-NET: "Grid received. Rounds on the way, sixty seconds." — existing `77l9izur`, unchanged
- `fqeghaut` (air) — drop hint "Grid received. Rounds on the way, 60 seconds." → **firing callsign** / SUB-NET: "Inbound to target. Rounds in sixty seconds." — rewrite: new air-only key `artyair_inbound`, leave laser's `stmeajce` "Inbound to target." untouched
- `moassj3z` (ground) — drop hint "Rounds ready. Splash in 30 seconds." → **firing callsign** / SUB-NET: "Rounds ready. Splash in thirty seconds." — existing `hf9bhgvb`, unchanged
- `moassj3z` (air) — drop hint "Rounds ready. Splash in 30 seconds." → **firing callsign** / SUB-NET: "Target in sight. Splash in thirty seconds." — rewrite `0jegiaf4` (air-only, safe)
- `9wu0cgea` (air) — drop hint "Attack Plane was shot down. Airstrike failed." → **Overlord** / NET: "Be advised, Alpha 1-1, %1 was shot down. Your strike is off." — existing `jet_down`, unchanged
- `t6y8r92y` — drop hint "Fire mission complete." → **firing callsign** / SUB-NET: "Rounds complete. Fire mission out." — new `artycomplete`

## FOB

- `cp9cw550` (hint copy) — drop hint "Requesting a FOB on my position…" → **Alpha 1-1 ({player who called})** / VOICE: (text unchanged) — existing radio `cp9cw550`, same beat (VOICE, not NET: the team keys up in the room, no squelch)
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
- `y91vei53` / `17hh9rx4` — drop hint "Supply Drop Inbound. ETA: 1 min." → **Courier 1-1** / SUB-NET: "This is Courier 1-1, deploying a supply crate to your position. ETA forty seconds." — existing `supplydropcallend` (**decided:** forty seconds — the surviving radio value; it fits the code's timeline better than "one minute" — Courier keys up at `fnc_ammobox.sqf:60` and the on-station beat follows `sleep 30` plus the crate's descent — and the "one minute" hint is dropped anyway)
- `zhiugl0g` — drop hint "Supply Drop On Station." → **Courier 1-1** / SUB-NET: "This is Courier 1-1, on station over your position. Crate away." — new `supplydroponstation`
- `supplydropfail` — drop hint "The transport was shot down. Supply drop failed." → **Overlord** / NET: "Be advised, Alpha 1-1, Courier 1-1 was shot down with the supply drop." — new `supplydropdown`
- `wdttb5b8` — delivery beat: **decided** — keep the hint box **and** add a **Courier 1-1** / SUB-NET sign-off "Crate's on the ground at your position. Courier 1-1 out." (new `supplydropdelivered`); drop the A3 card. Split of surfaces is deliberate: the hint is the gameplay marker (the crate is here), the sign-off is flavour. They land on different audiences — `hint` is local and `fnc_ammobox` runs on the caller, so the hint shows the caller only, while the sign-off must `remoteExec ["fnc_duws_dialogue", 0]` so every player hears it globally. The `bis_fnc_showNotification` green-card at `fnc_ammobox.sqf:104` is what gets dropped; the green smoke itself stays (physical crate marker, not a notification)

## Paradrop (Chalk 2-1)

- `r8ubc9jy` / `5iciamva` — drop hint "Paradrop Inbound. ETA: 1 minute." → **Chalk 2-1** / SUB-NET: "This is Chalk 2-1, inbound to your grid. ETA one minute." — new `paradropinbound`
- `o4p4grm4` — drop hint "Paradrop On Station." → **Chalk 2-1** / SUB-NET: "This is Chalk 2-1, on station." — new `paradroponstation`
- `zm99dbgu` — drop hint "Paratroopers deployed." → **Chalk 2-1** / SUB-NET: "Chutes away." — new `paradropdeployed` (existing `paradropcallend` at this beat says only "LZ in sight", does not cover deployed)
- `0xtit0ht` — **decided: dialogue only.** Drop both the hint (`fnc_paradrop.sqf:171`) and the A3 card (`:173`) at this beat. No new line: the existing `paradropcall` (Overlord / NET) opener already tasks the squad, and the twelve paratroopers visibly `joinSilent player` at `:170` — a new AI squad under command is self-evident on screen
- `2bwz0z4w` — drop hint "The transport was shot down. Paradrop failed." → **Overlord** / NET: "Be advised, Chalk 2-1 is down. No paratroopers are inbound. You're on your own Alpha 1-1." — new `paradropdown`

## Vehicle drop (Courier 2-1)

**Decided:** the transport is **Courier 2-1** — the supply drop is Courier 1-1, so the sister flow reads
as the same courier detachment. New key `STR_DUWS_T_courier2` ("Courier 2-1"), registered in
`DUWS_subnetSpeakers` alongside `courier` / `courier3`.

- `6cwj6h8z` — drop hint "Vehicle Drop Inbound." → **Overlord** / NET: "Request received. Drop ETA forty seconds." — existing `vehdropcallend`
- `9tpm5uf6` — drop hint "Vehicle Drop On Station." → **Courier 2-1** / SUB-NET: "Transport on station over your position, cargo away." — new `vehdroponstation` (existing radio only says inbound-ETA and fired before arrival; the real on-station beat has no line)
- `7h0bmzi7` — drop hint "The transport was shot down. Vehicle drop failed." → **Overlord** / NET: "Be advised, Alpha 1-1, the transport is down. Your vehicle drop is off." — new `vehdropdown`
- `iv3s5xlc` — delivery beat, mirrors the supply drop exactly: **decided** — keep the hint box **and** add a **Courier 2-1** / SUB-NET sign-off "Vehicle's on the ground at your position. Courier 2-1 out." (new `vehdropdelivered`); drop the A3 card (`fnc_veh_drop.sqf:115`). Hint stays caller-local; sign-off `remoteExec`s to `0`

## Helo taxi (Chariot 1-1)

- `helotaxichopperinbound` — drop hint "Transport aircraft is inbound." → **Chariot 1-1** / SUB-NET: "Alpha 1-1, ETA forty seconds. Clear the LZ." — existing radio (L32)

## Helolift

- `helolift_noheli` — drop hint "Heavy transport could not reach your position." → **Overlord** / NET: "Be advised, Alpha 1-1, heavy transport can't reach your position. Tasking aborted." — new `heloliftnoreach`
- `liftwp_incomplete` "Route incomplete, tasking aborted." — **decided: convert to radio, and fix a state-contradicting line on the way.** The `count _waypoints < 3` exit at `fnc_helolift.sqf:218` is reached only *after* the helo has flown to the hook, slung the load, lifted to 60 m, and the player pressed takeoff (`:213`) — the aircraft is airborne and healthy. But it calls the shared `_abort` (`:62`), which speaks `heloliftabort` "Mule 1-1 is out of action and aborting the tasking." — false on this path. Split `_abort` into a `_teardown` (marker cleanup + the `fnc_helolift_ropes "abort"` remoteExec that drops the load and RTBs) and the radio line. The six `_check_damage` exits (`:104, :112, :192, :199, :211, :215`) keep `_teardown` + `heloliftabort` (genuinely out of action). The `:218` path gets `_teardown` + a new honest line — the lift pilot (`STR_DUWS_T_crane`, renders "Mule 1-1") / SUB-NET: "No route received. Tasking cancelled." (new `liftnoroute`). Then the hint drops; its content lives on the correct surface.
- no callsign fix: `heloliftabort` says "Mule 1-1", and the lift pilot's speaker key `STR_DUWS_T_crane` also renders "Mule 1-1" — the key name is "crane" but its stringtable value is "Mule 1-1", so the two already agree. Nothing to reconcile.

**Taxi abort audit (result: no change to helo taxi or boat taxi).** The same failure class was checked in both taxis and neither has the helolift defect. Every `_abort` in `fnc_helotaxi.sqf` and `fnc_boatTaxi.sqf` is gated on damage (`_check_damage` / `getdammage > 0.7 or !alive _pilot`), so their "out of action" lines (`helotaxidamaged`, `boattaxi_damaged`) are only ever spoken when the aircraft really is down — honest. Their route/destination feedback is already voiced and already honest, as re-prompts rather than cancellations: helo taxi's Chariot line `helotaxiwp_nolz` "No clear LZ at that grid. Send another, over.", boat taxi's Swordfish lines `boattaxiwp_bad` "We cannot reach that grid…" and `boattaxiwp_close` "That grid is too close…". Structurally, neither taxi can reach helolift's broken state: both refuse to depart until a valid destination is set (`fnc_mapclickhelo.sqf`, `fnc_mapclickboat.sqf` loop until a `BIS_fnc_findSafePos` hit), so a "No route received. Tasking cancelled." line there would be unreachable — do not add it.

## UAV recon (Allseer)

- `6u8qilfh` — **decided:** voice it. Drop hint "Coordinates received." → **Allseer** / SUB-NET: "Coordinates received, tasking the UAV overhead." — new `uav_coords`

## Keep in the hint box (directives — no change)

`laser_loiter`, `pilotwp`, `helotaxi2wp`, `helotaxiwp_reopen`, the `hint ""` clear · `helolift_notarget`, `helolift_badtarget`, `too_close_enemy`, `nolz`, `boattaxi_noshore`, `7yy0wapp` (750 m rule) · `rjuehu36`, `gu6cbc5f` (access key) · `vehicle_garage_no_vehicle`, `repair_select_pylon` · `veh_drop_none`, `tier_locked_hint`, `SUPPORT_BUSY`, `346eazcm` · buy menu: `inssupport`, `8c1i4vga`, `e95mc4lv`, `SUPPORT_NO_REFUND`, `dvbox9ay`, purchase `_msg`.

(`liftwp_incomplete` was the borderline here; now decided — see the Helolift section: converted to radio and the shared abort line fixed.)

## Side effects (fall out of the drops, no extra work)

- Removing the paradrop and supply inbound hints ends the overwrite flicker where the ETA hint is instantly replaced by a bare "Inbound" hint the same frame.
- Removing `9tpm5uf6` removes the veh-drop "On Station" that printed before the aircraft arrives.

## Decisions (settled)

1. **Arty air timing** — keep the countdown in dialogue: accept the `artyair_inbound` / `0jegiaf4` rewrites that carry the "sixty seconds" / "thirty seconds" numbers.
2. **Vehicle-drop transport callsign** — **Courier 2-1** (new `STR_DUWS_T_courier2`), sister to the supply drop's Courier 1-1. Used for `vehdroponstation` and `vehdropdelivered`; register in `DUWS_subnetSpeakers`.
3. **Delivered lines vs the A3 card** — hint box **and** SUB-NET sign-off, **no** A3 card. The hint is the gameplay marker (caller-only, since `hint` is local to the caller's client), the sign-off is flavour (global, `remoteExec` to `0`); the green-smoke `bis_fnc_showNotification` card is dropped on supply / veh-drop delivery. Applies to supply (`supplydropdelivered`) and veh drop (`vehdropdelivered`).
4. **Paradrop "under command"** — dialogue only. Drop both the hint and the A3 card at the join beat; the `paradropcall` opener plus the visible squad joining cover it. No new line.
5. **UAV `6u8qilfh`** — voice it as **Allseer** / SUB-NET (`uav_coords`); drop the hint.
6. **Supply ETA wording** — unify on **forty seconds**, the value already in the radio line and the closer match to the code's timeline; drop the "one minute" hint.
7. **Alpha 1-1's channel** — **VOICE**, never NET or SUB-NET. The team speaks co-located, so its lines get no squelch tone; VOICE is the loud subtitle with none. VOICE is the router's default for unlisted speakers, so the change is to **leave `STR_DUWS_T_actionteam` out of both speaker tables** — no registration at all. The speaker still renders `Alpha 1-1 ({player who called})` — strictly the caller, passed to `fnc_duws_dialogue` (`_caller` arg); the team senior is the fallback for Alpha 1-1 lines with no caller.

8. **Helolift `liftwp_incomplete` + shared abort line** — convert the hint to a Mule 1-1 (`STR_DUWS_T_crane`) / SUB-NET line "No route received. Tasking cancelled." (`liftnoroute`), and split `_abort` so the healthy-aircraft cancel no longer speaks the "out of action" `heloliftabort`. No callsign fix: `heloliftabort`'s "Mule 1-1" already matches the pilot speaker key's rendered value. Helo taxi and boat taxi audited alongside: already honest, no change. Detail in the Helolift section.

## Task list

- [ ] Register the arty tier callsigns (`redleg`, `sledge`, `slingshot_2`, `reaper`, `reaper_2`) and the new `STR_DUWS_T_courier2` (Courier 2-1) in `DUWS_subnetSpeakers` (channel routing prerequisite). Leave `STR_DUWS_T_actionteam` unlisted so Alpha 1-1 defaults to VOICE.
- [ ] Add the `new` / `rewrite` stringtable keys, incl. `STR_DUWS_T_courier2` and `liftnoroute` (English real; DE/ES/ZH English placeholders per the localisation-lag convention).
- [ ] Helolift: split `_abort` into `_teardown` + line; route the `:218` WP-incomplete exit to `_teardown` + `liftnoroute` (speaker `STR_DUWS_T_crane`); leave the six `_check_damage` exits on `heloliftabort`. No change to helo taxi / boat taxi (already honest).
- [ ] Replace each dropped hint with its `fnc_duws_dialogue` call at the same beat. On delivery beats keep the hint (caller-local) and add the sign-off `remoteExec`'d to `0` (global); drop the `bis_fnc_showNotification` green card.
- [ ] Playtest each support once: no beat goes silent, nothing double-fires, Alpha 1-1 reads on VOICE with no squelch.
