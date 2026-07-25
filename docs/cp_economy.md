# Command-point economy

Command Points (CP, the global `commandpointsblu1`) are the single currency the player
spends — on support unlocks, reinforcements, vehicles, FOBs, operatives, and transport.
Army Power (AP, `WARCOM_blufor_ap`) is a separate war-momentum score the WARCOM director
reads; it is not spent from menus. The two economies meet at one place: the AP→CP
converter (`fnc_convertAPtoCP.sqf`). This doc covers CP: where it comes from, where it
goes, and the balance properties worth knowing. Faction-specific purchase prices live in
the `blufor_RQST_*` variables and `fnc_evalVehicleCost` — see
[`faction_system.md`](faction_system.md).

## Authority: one server-side writer

`commandpointsblu1` is a networked global, so every change routes through a single
server-side function, `fnc_cp_adjust` (`src/duws/init/server_fnc_init.sqf`), invoked as
`[delta] remoteExec ["fnc_cp_adjust", 2]`. Callers send a signed *delta*; nothing else
assigns or `publicVariable`s the pool — bar one inert exception,
`operative/modern/fnc_operator_recruit.sqf:31`, which assigns the pool directly but subtracts
`0` and never broadcasts. It is worth deleting precisely because the next edit to that line
would not be inert. This is a hard concurrency requirement, not a style
choice: mutating a networked global as `x = x - c; publicVariable "x"` from a client drops
concurrent co-op changes and can duplicate CP — see the gotchas entry *"A shared global
mutated as `x = x - c; publicVariable` loses concurrent writes"* in
[`arma_engine_gotchas.md`](arma_engine_gotchas.md). The only absolute assignments left are
the pre-game starting value (`server_var_init.sqf:82`, default 20; campaign menu offers
0–400 in `fnc_process_campaign_menu.sqf:210-218`), which run on the host before play.

## Faucets

| Source | File | Amount |
|---|---|---|
| Zone capture (first time) | `init_zones/fnc_captured.sqf:47` | `round(points/2)` — ≈50 for a 1000 m zone |
| Zone recapture (after loss) | `init_zones/fnc_blufor_cap.sqf:67` | `round(points/3)` — ≈33; intentionally lower |
| Passive territory hold | `misc/fnc_zonesundercontrol.sqf:6,11` | `zones_held × 6`, every 30 min |
| Side-mission reward | `missions/fnc_mission_reward.sqf` | `reward × cp_reward_multiplier` (multiplier default 1) |
| Reputation tick | `misc/fnc_civ_init_Tomata.sqf:234` | `ceil(rep/2)`, every 15 min |
| Recruit rescued civilian | `misc/fnc_recruit_civilian_server.sqf` | +5 (+8 in WBK mode) |
| Intel analysis (terminal) | `misc/fnc_intelAnalysis.sqf` | 1.5–8 per item; `FileTopSecret`/`FilesSecret` = 8 |
| Enemy corpse loot | `misc/fnc_addRandomLoot.sqf` → analysis | ~80% of enemies carry 0–2 of Money/Files/Wallet |
| Corpse search | `misc/fnc_corpse_search_action.sqf` | 20% chance of +1 CP (+1 AP) per corpse |
| Vehicle recycle | `supports/fnc_activateBaseRecycleStation.sqf` | `DUWS_fnc_calculateVehicleValue` per empty vehicle |
| Vehicle-kill / kill-streak | `init/server_init.sqf:336,352` | per-kill points; +1 per 10 kills |
| Killhouse training | `misc/fnc_createKillhouse.sqf:1019` | +0.05 per kill, inside a 180 s window |
| Scorched-earth town razing | `misc/fnc_civ_handler.sqf`, `fnc_civ_handler_wbk.sqf` | +15 (with AP + reputation penalties) |
| Rare-zombie kill (WBK) | `misc/fnc_civ_handler_wbk.sqf:360` | +10, or +30 for the Goliath |
| AP→CP conversion | `dialog/fnc_convertAPtoCP.sqf` | 15 AP → 10 CP, one-way |

The passive-hold loop is spawned exactly once (`warcom/fnc_init_OPFOR_WARCOM.sqf:20`), so
territory income does not stack per zone captured.

## Sinks

| Category | Where | Cost |
|---|---|---|
| Radio-support unlocks | `dialog/fnc_request_support.sqf` | 5–25 (supply 5 … CAS/CAP 25) |
| Reinforcement units | `dialog/fnc_request_unit*.sqf` | 2–4 (from `blufor_RQST_UNIT_*`) |
| Vehicles | `dialog/fnc_request_vehicle*.sqf` | 5–100 (from `fnc_evalVehicleCost`, clamped) |
| Squads | `dialog/fnc_request_squad*.sqf` | per squad table |
| FOB deploy | `supports/fnc_request_fob.sqf` | fixed |
| Operatives | `operative/modern/fnc_operator_recruit.sqf:26` | 8 (re-deploying a healed one is free) |
| Mobile HQ | `dialog/fnc_MHQ_select.sqf` | 10 |
| FOB refortify / reguard | `init_hq/fnc_refortifyFOB.sqf`, `fnc_reguardFOB.sqf` | 5 / 15 |
| Heli / boat taxi | `supports/taxi/` | fixed |
| Base repair, HQ redeploy, sitrep | `supports/fnc_activateBaseRepairStation.sqf`, `misc/fnc_redeployHQUnits.sqf`, `supports/fnc_sitrep_support.sqf` | 2 / 2 / 1 |
| Death | `init/client_init.sqf:186` | `DUWSMP_CP_death_cost` (0–10) |

## Balance concerns

Open observations from an economy review. Each is a design or correctness property, not a
crash; none is currently scheduled.

**Territory income snowballs with no upkeep.** Passive hold pays `zones_held × 6` every
30 min (`fnc_zonesundercontrol.sqf:11`) on top of lump capture rewards, and holding a zone
costs nothing thereafter. That is a positive feedback loop — hold → CP → buy → hold more —
with no attrition pulling the other way, so late-game CP outruns anything to spend it on.
This is the central design lever, not a bug: if a demanding economy is the goal, the levers
are per-zone/garrison upkeep, diminishing per-zone passive scale, or a CP cap.

**Enemy-loot → intel-analysis is an unbounded, cooldown-free faucet.**
`fnc_addRandomLoot.sqf` puts `Files` (2 CP) / `Wallet_ID` (1.5 CP) on ~80% of spawned
enemies, and terminal analysis (`fnc_intelAnalysis.sqf`) converts them with no cap and no
cooldown; HVT missions add `FileTopSecret` at 8 CP each. Because enemies respawn via QRF and
patrols, this taps ≈1 CP per kill scaling with playtime rather than difficulty. A per-visit
cap or a cooldown on the terminal action bounds it.

**Recycle pays for vehicles the player never bought.**
`fnc_activateBaseRecycleStation.sqf:88-101` deletes every empty, non-excluded vehicle near
the HQ pad and credits its computed value with no ownership check — captured or found
vehicles convert to free CP. It is *not* a buy-then-recycle loop: purchase cost
(`fn_factionAutoDetect.sqf:161`, clamped `[5,100]`) always exceeds recycle value
(`DUWS_fnc_calculateVehicleValue`, small and uncapped), so buying to recycle always loses.
The two formulas are simply not on the same scale, and recycle has no floor tying reward to
what a vehicle cost.

**Fractional CP leaks into an integer economy.** `floor _cost / 2` parses as
`(floor _cost) / 2` — the unary `floor` binds tighter than `/` — so odd support costs refund
half-points: CAS/CAP at 25 refund 12.5 (`fnc_request_support.sqf:508,544,634`). Killhouse
training also adds 0.05 per kill (`fnc_createKillhouse.sqf:1019`). Neither is exploitable
(the refund is still a net loss on cancel), but the pool and HUD then show values like
`32.05`. Wrapping the refund in `floor(...)` and rounding the training reward keeps CP
integer.

**Client-side affordability checks allow a co-op overdraft.** Purchase paths read the pool
from the buying client's own copy and apply the effect unconditionally — ~45 comparisons
across 22 files, with `fnc_pylon_set_with_cost` (`init/server_fnc_init.sqf:770-773`) the only
server-side check. Two players buying inside one network round-trip against a pool that funds
a single purchase therefore both succeed, leaving it negative by the overspend. This is an
overdraft, not a leak: both deltas are debited in full, so unlike the read-modify-write hazard
above no CP is created, and the player must earn back to zero before buying again. Nor is it
reliably in the player's favour — a one-shot unlock gated on its own flag
(`dialog/fnc_request_support.sqf:12-19`) charges both buyers for one unlock. Closing it means
the server gating the *effect* rather than the deduction, and `remoteExec` returns no value,
so every site would need a hand-rolled reply channel and an async wait. Not worth it for an
overdraft in a pool `client_init.sqf:186` can already drive negative on its own.

**Death cost can drive CP negative.** `client_init.sqf:186` subtracts
`DUWSMP_CP_death_cost` (up to 10) with no lower bound. Functionally harmless — the `>= cost`
purchase gates still hold at negative values — but it reads oddly. Clamping the floor at 0
inside `fnc_cp_adjust` would prevent it if undesired (note that would also affect any future
intentional negative delta).

**AP→CP merges the two economies.** `fnc_convertAPtoCP.sqf` trades 15 AP → 10 CP,
repeatable with no cooldown. It is one-way (there is no CP→AP path), so it cannot loop, but
it means any AP income route — mission rewards, corpse search — ultimately feeds CP. Note
also that `WARCOM_blufor_ap` is still mutated with the non-atomic `x = x + n;
publicVariable` pattern that CP was moved off of, so the AP pool carries the co-op
lost-update hazard CP no longer has; the plan to give AP the same server authority — one
`fnc_ap_adjust` delta writer, mirroring CP — is in
[`army_power_remediation.md`](army_power_remediation.md).
