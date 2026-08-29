# Testables

Playtest checklist. Keep it short. Check a box only once verified in a real
session, not by reading code. Note SP (single-player) vs MP (client on a
dedicated/hosted server) where it matters — a thing can pass on the host and
still be broken for a joining client.

## HQ

- [ ] Side-mission board hands out missions and rewards pay out (SP + MP client)
- [ ] Purchasing (units, supports, FOB) charges correctly and refunds on the same terms (SP + MP client)

## Side missions

- [ ] Every side-mission thread playtested for dialogue and task UX — markers, hints, task states, clean end

  deny_armor, destroy_cache, destroy_hardpoint, destroy_patrol_camp,
  destroy_radar, destroy_tower, informant, protect_civ, recon, rescue_pilot,
  rescue_squad, sabotage_laptop, steal_builder, steal_supply, target_armor,
  target_hvt, target_recon, target_sniper, transport_idap

## Supports

- [ ] Every support fires and completes for a joining MP client, not just the host

  arty, CAS, attack heli, UAV scan, paradrop, vehicle drop, ammo box, helo
  lift, taxi, FOB deploy, recycle station, repair station

## Campaign loop

- [ ] Zone capture registers, marker flips, holds across save/load (SP)
- [ ] Economy: CP/AP income, capture bounty, and support/unit costs stay in balance
- [ ] Economy gates hold for an MP client: no unearned support-tier buy, captured-gear settle credits honestly. Known gap — the *open* loadout is still client-sent, so a faked-rich open can over-credit; deferred to [economy_second_pass.md](docs/plans/economy_second_pass.md)

## AI opposition

- [ ] Garrison strength + reserves top-up and hardpoint stream behave as intended after a capture
- [ ] A role spelled off-pattern still fields OPFOR-side (auto-detect publishes from the schema key list)

## Multiplayer

- [ ] JIP: client joining mid-campaign sees correct zone state, economy, and owned supports
- [ ] Client-caused building damage raises escalation on a dedicated host, not only SP/hosted
