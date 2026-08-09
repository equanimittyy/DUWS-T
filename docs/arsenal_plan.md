# Arsenal: standard issue and captured materiel

The arsenal splits gear by origin. Your own faction's gear is **standard issue** — unlimited, and
resolved at boot exactly the way it is today. Everything foreign is **captured materiel** — scarce,
count-tracked, and stocked only by the enemy gear you carry back and take off. Scarcity lives on the
foreign shelf the way it lives in Army Power ([`economy_second_pass.md`](economy_second_pass.md)): one place in the
system holds the constraint, and the rest is abundant so it stays legible.

The worked example throughout: a US-vs-RU campaign. US gear is derived by the current system and is
unlimited. RU gear exists in the arsenal only up to the count you have captured and banked.

The current arsenal — the unlimited friendly whitelist and the loadout-scan that enforces it — is in
`server/misc/fnc_create_ammo_lists.sqf` (build) and `initPlayerLocal.sqf:140-313` (enforcement). This
plan changes what the scan is enforcing against, not how it hooks the arsenal.

## The two shelves

| Shelf | Source | Quantity | Stocked by |
|---|---|---|---|
| Standard issue | The friendly whitelist `fnc_create_ammo_lists` builds — faction sweep, role keys, basic fallback, ACE | Unlimited | Boot; unchanged |
| Captured materiel | Any class **not** on the friendly whitelist | Per-class count | Foreign gear the player removes from themselves in the arsenal, or carries into a Quick Kit swap |

Standard issue is also the always-available floor, which is why the pool can start empty with no
soft-lock: a player with nothing captured still has their own faction's full kit. That answers the
starter-gear question by construction rather than by seeding the pool.

**Every foreign class is counted individually, attachments included.** A captured optic, laser or
bipod is its own pooled line, not a free rider on the weapon it arrived on — nothing foreign is ever
unlimited. The cost is a larger pool and more per-class diffing on open and close; the payoff is one
rule with no exception to explain. Banking a weapon also banks the attachments mounted on it as their
own lines, so a captured rifle-with-optic deposits both the rifle and the optic.

**Foreign means literally not-friendly.** Enemy, independent, civilian and third-party pickups all
pool, because all are simply absent from the friendly whitelist. There is no per-side lookup and no
in-between category — a class is standard issue or it is materiel.

## Classification needs its own record

The arsenal shelf is the set of `bis_addVirtual*Cargo_cargo` vars in the mission namespace, which
`fnc_create_ammo_lists` fills with friendly gear and which the enforcement scan already reads
(`initPlayerLocal.sqf:141`). "Friendly" cannot be defined as "in the cargo", because the plan adds
foreign-pool items to that same cargo on open — after which the cargo no longer distinguishes the two.

So the friendly set is snapshotted into its own record — `DUWS_friendlyArsenal` — the moment
`fnc_create_ammo_lists` finishes and **before any foreign class ever touches the cargo**. From then
on the test is: in `DUWS_friendlyArsenal` -> standard issue, unlimited; otherwise -> foreign, subject
to the pool. One record, written once, read on every open and close.

## Stocking the pool: the arsenal is the deposit surface

There is **no separate recycle action.** Foreign gear banks to the pool whenever it leaves the
player's body through the arsenal UI, and the arsenal is already the one place gear does that:

- **Remove a foreign item from yourself in the Arsenal** -> it is added to the pool.
- **Carry foreign gear into a Quick Kit swap** -> the kit replaces the whole loadout
  (`fnc_quick_kits_menu.sqf:15`), so the foreign gear it displaces banks to the pool.

A dedicated "recycle at HQ" action was considered and dropped: it is a second surface to build and a
second site the pool can change, when the close-diff below already sees every removal for free. If a
manual deposit is ever wanted it is additive — it feeds the same pool through the same server writer.

**Banking stocks the pool and nothing else** — no CP, AP or intel for a deposit. Recycling gear for
currency is a separate faucet with its own balance cost ([`economy_second_pass.md`](economy_second_pass.md)); the
pool is materiel, not income.

## Spending the pool: withdraw and the overdraw problem

The load-bearing engine fact: **`BIS_fnc_arsenal` serves an unlimited quantity of anything on its
shelf for the length of a session.** Putting a captured RU rifle on the shelf makes it *available*;
it does nothing to cap *how many* the player takes before closing. Presence and count are different
axes, and only presence is native.

Count is therefore enforced on close, against the loadout diff:

- Per foreign class, `net = current_count - snapshot_count`.
- `net > 0` — withdrew `net`. `grant = min(net, pool_at_open)`; `pool -= grant`; strip the `excess =
  net - grant` off the player. This is the enforcement teeth: overdraw is removed, not tolerated.
- `net < 0` — removed `|net|`; deposit -> `pool += |net|`.

When a class is overdrawn across more than one slot, the granted count stays in the primary slot and
the remainder is stripped.

This is not new machinery. The arsenal handler already snapshots the loadout on open (`_refLoadout`,
`initPlayerLocal.sqf:282`), already diffs it on change (`DUWS_fnc_countLoadoutChanges`, `:290`), and
already strips loadout classes against a whitelist (`:210-251`). The plan makes that scan pool-aware:
the strip's allowed set becomes friendly `∪` (foreign with `count > 0`), and the overdraw clamp above
is a second reason a foreign class is stripped.

**Overdraw enforcement is lenient's opposite by choice.** Letting the pool floor at zero while the
player keeps a session's over-grab makes a count-1 rifle yield ten — the scarcity the shelf exists to
create, defeated in one open. Stripping the excess is what makes the count mean the count.

## The friendly whitelist is unchanged

`fnc_create_ammo_lists` is untouched by this plan. Standard issue stays unlimited and is enforced as
it is today; the only change on the friendly side is that its output is also snapshotted into
`DUWS_friendlyArsenal` for the classifier. Keeping the friendly path exactly as-is is what keeps the
feature bounded — the whole pool system rides on top of an unchanged floor.

## Money is made non-destructive

Separate from the pool, and a genuine bug the arsenal rework has to fix first.

Money is the `Money_roll` **magazine**; a player's balance *is* the count they carry
(`fnc_money_count`, `server/misc/fnc_economy_init.sqf:182-186`). The arsenal handler lists money and
intel in `DUWS_forcedRemoveItems` (`initPlayerLocal.sqf:58-61`) and `DUWS_fnc_remove_money_intel`
(`:80`) deletes them on every loadout change while the arsenal is open (`:298`). So **opening the
arsenal burns the player's cash** — the balance is inventory, and the handler removes inventory.

The fix is snapshot-on-open, restore-on-close:

- **Open** — count each `DUWS_forcedRemoveItems` class on the player, stash the counts, remove them.
  The arsenal is now money-clean, so nothing can be duped or lost through it during editing.
- **Close** (`initPlayerLocal.sqf:311`) — re-add the stashed counts: into inventory where it fits,
  and overflow dropped at the player's feet via the existing `fnc_search_dropItems` helper, which
  already drops `Item_Money_roll` on the ground (`server/misc/fnc_search_claim.sqf:106-108`). Dropped
  campaign cash is exempt from `DUWS_CleanupLifetime`, so a full-inventory player cannot lose it to
  the cleanup timer.

**Inline re-add does not work, which is why it is close-time.** Re-adding to inventory during editing
is re-detected by the 0.2 s poll (`:285`) and stripped again — an infinite strip/re-add loop with
chat spam. The counts have to be held out of the editable loadout for the whole session and returned
once, on close. Net: the player leaves with exactly the balance they entered with, minus only what
would not fit, which is on the floor beside them.

## Full arsenal stays a host option

The arsenal defaults to full today: `DUWS_fnc_arsenal_current` is `DUWS_fnc_arsenal_full`, a no-op
(`initPlayerLocal.sqf:259-263`), and `DUWS_isRestrictedArsenal` defaults false (`:280`,
`client/misc/fnc_duws_Arsenal.sqf:5`). The hybrid (standard-issue-unlimited + captured-tracked)
becomes the new default; the unlimited-everything arsenal is kept as a host setting for a group that
wants it. One setting, read where the mode is chosen.

**The mission-reward loot arsenals stock the pool instead of opening a full one.** `destroy_cache`
(`server/missions/mission_threads/destroy_cache/fnc_destroy_cache_mission.sqf:96,131`) and
`steal_supply` (`.../steal_supply/fnc_steal_supply_mission.sqf:57`) open `["Open", true]` today — the
whole game's items, which is a free unlimited enemy arsenal and the largest hole in the scarcity
model. The `["Open", true]` call is dropped; a cleared cache instead deposits a fixed shape drawn from the
OPFOR gear list — **3 random weapons, 2 random wearables, and 2 random attachments, each at a
rand(3-10) count** — into the foreign pool. Spread wide and shallow on purpose: more kinds of gear,
fewer of each, so a cache broadens the shelf rather than stockpiling one item. That makes caches the
main way the pool fills and keeps the reward inside the scarcity rule rather than around it. The
figures are opening values ([open](#open-questions)).

## Authority: the pool is server-side

The pool is shared team state and server-authoritative — one `class -> count` map the whole team draws
on. The arsenal handler is client-side (`initPlayerLocal.sqf`), so the client's shelf is a *view*:
on open it adds its copy of the pool to its local cargo; on close it computes the deposit/withdraw
deltas and `remoteExec`s them to the server, which applies them to the one authoritative map and
broadcasts the result.

Co-op draws on one pool race exactly as currency spends do, and take the same answer: the read and the
decrement are adjacent statements on the one machine that owns the pool, the pattern
`fnc_money_spend` already uses for `Money_roll`
([`info/economy.md`](info/economy.md#authority-the-server-decides-a-purchase-not-the-buyer)). A
client that over-grabs against a stale view has its excess stripped when the server-confirmed count
comes back, so two players cannot both bank the last captured rifle.

## Persistence is deferred

Split by the same rule the rest of the campaign follows
([`campaign_persistence_plan.md`](campaign_persistence_plan.md)):

- **The friendly shelf is never stored.** `fnc_create_ammo_lists` re-resolves it at boot against
  whatever mods are loaded, so storing its classnames would pin the campaign to a mod set — the
  no-hard-dependency rule.
- **The captured pool will be stored**, and is the one arsenal state that persists. It is
  player-earned and scarce, so losing it on reload loses progress — the same argument that persists
  the vehicle stockpile rather than the friendly cargo. It is one `class -> count` hashmap, one
  snapshot key, and it pins to the enemy mod that produced the classnames: restore validates each
  class and discards the unknown, so a removed enemy mod drops those counts rather than restoring a
  name that resolves to nothing.

Deferred for now by decision. The save group lands when the arsenal work does; the persistence plan's
[arsenal section](campaign_persistence_plan.md#the-friendly-arsenal-is-not-stored-the-captured-pool-will-be)
already records the split so the group is expected rather than discovered.

## Build order

Each phase is independently shippable; the money fix is first because it is independent of the pool
and fixes a live bug.

| Phase | Contains | Why here |
|---|---|---|
| **Money** | Snapshot money/intel on open, restore on close, ground-drop overflow; drop the per-change delete | Independent of the pool; fixes cash being burned by opening the arsenal |
| **Pool + classify** | `DUWS_friendlyArsenal` snapshot after build; the server-authoritative `class -> count` pool and its writer; the classifier | No player-visible change yet; the substrate everything else reads |
| **Arsenal integration** | Open: add foreign-pool items to the client cargo, snapshot loadout; Close: diff -> deposit removed foreign, withdraw added foreign with overdraw strip; make the enforcement scan pool-aware; clear foreign from cargo | The core loop; deltas `remoteExec`'d to the server |
| **Quick-kit deposit** | Diff carried foreign before applying the kit; bank to the pool | The second deposit path |
| **Full-arsenal setting** | Host toggle: full (current everything) vs hybrid (new default) | The new default needs an escape hatch |
| **Loot caches** | `destroy_cache` and `steal_supply` drop `["Open", true]`; a cleared cache deposits 3 random OPFOR weapons, 2 wearables and 2 attachments, each at rand(3-10), into the pool | Depends on the pool writer; closes the biggest scarcity hole |
| **Persistence** (deferred) | The pool joins the campaign snapshot; validate-and-drop unknown classes on restore | Waits on the campaign-save work; [`campaign_persistence_plan.md`](campaign_persistence_plan.md) |

## Files touched

| File | Change |
|---|---|
| `server/misc/fnc_create_ammo_lists.sqf` | Snapshot the friendly cargo into `DUWS_friendlyArsenal` once the build completes, before any foreign class is added |
| `initPlayerLocal.sqf` | Money snapshot/restore on open/close; make `DUWS_fnc_arsenal_restricted` pool-aware (allowed = friendly `∪` foreign-in-pool, overdraw strip); compute and send deposit/withdraw deltas on close |
| `client/misc/fnc_duws_Arsenal.sqf` | On open, add the client's view of the foreign pool to the local cargo; select hybrid vs full from the host setting |
| `client/misc/fnc_quick_kits_menu.sqf` | Diff carried foreign before `setUnitLoadout`; bank the displaced foreign to the pool |
| `server/misc/` (new) | The pool writer: applies validated deposit/withdraw deltas to the one authoritative `class -> count` map and broadcasts |
| `server/server_var_init.sqf` | The pool global's default; the full/hybrid host setting default |
| `shared/includes/params_modern.hpp` | The full-vs-hybrid arsenal parameter |
| `server/missions/mission_threads/destroy_cache/fnc_destroy_cache_mission.sqf:96,131` | Drop `["Open", true]`; deposit a batch of enemy materiel into the pool on clear |
| `server/missions/mission_threads/steal_supply/fnc_steal_supply_mission.sqf:57` | Same: replace the full arsenal with a pool deposit |
| `docs/campaign_persistence_plan.md` | Already updated: the friendly/captured split in the arsenal section |

## Open questions

- **The cache deposit figures.** 3 weapons, 2 wearables and 2 attachments, each at rand(3-10), is the
  opening shape; the counts and the mix want play-test against how fast the foreign shelf should fill
  and how many caches a campaign clears.

## Task list

- [ ] Money non-destructive: snapshot on open, restore on close, ground-drop overflow; remove the
  per-change delete. Verify: open the arsenal carrying N `Money_roll`, change loadout, close ->
  balance is still N; fill inventory, open/close -> the remainder is on the ground, none lost; no
  strip/re-add chat loop while open.
- [ ] `DUWS_friendlyArsenal` snapshot + the pool global and its server writer. Verify: after boot the
  snapshot holds exactly the friendly classes and no foreign; the writer applies a delta and
  broadcasts, and a second concurrent delta serialises instead of racing.
- [ ] Arsenal open adds foreign-pool items to the client cargo; the scan permits friendly `∪`
  foreign-in-pool. Verify: a captured RU class with count>0 appears on the shelf and is not stripped;
  a foreign class with count 0 does not appear and is stripped if equipped.
- [ ] Arsenal close diff: deposit removed foreign, withdraw added foreign, strip overdraw. Verify:
  remove a carried RU rifle in the arsenal -> pool +1; take 3 of a count-1 RU rifle -> keep 1, 2
  stripped, pool 0; a friendly class taken in any quantity is never stripped; a captured RU optic is
  tracked and stripped as its own line, and banking a rifle with a mounted optic deposits both.
- [ ] Quick-kit deposit. Verify: carry RU gear, apply a Quick Kit -> the RU gear is gone from the
  player and the pool rose by what was displaced.
- [ ] Full-vs-hybrid host setting. Verify: hybrid is default and enforces the pool; full restores the
  unlimited-everything arsenal; the setting round-trips the lobby.
- [ ] Loot caches deposit to the pool. Verify: clearing a `destroy_cache` no longer opens a full
  arsenal; the pool gains 3 OPFOR weapons, 2 wearables and 2 attachments, each at rand(3-10), and
  those classes then appear on the shelf up to that count.
- [ ] Co-op: two clients drawing one pool. Verify on a dedicated server
  ([`info/testing.md`](info/testing.md#running-a-dedicated-server)) that the last captured item cannot
  be banked by both, and an over-grab against a stale view is corrected on close.
