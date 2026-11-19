# Bandwidth — technical summary

## Overview

Combat prep/combat resource bar. Starts **full** and shrinks as units are deployed. Placement spend is capped by **deploy cost** vs remaining budget. A separate **loss** overlay grows from the shrinking edge toward the original full end. Negative remaining at battle end causes repair damage (min HP 1); leftover remaining grants bonus **scrap** (`run_gold`).

Max bandwidth is a **run-persistent fixed cap** (start 50). Inventory upgrades add +10 for 2 components.

## Components

| Component | Path | Role |
|-----------|------|------|
| `BandwidthManager` | `Manager/bandwidth_manager.gd` | Remaining, deploy spent, loss potential, death drain, settlement |
| `BandwidthBar` | `UI/bandwidth_bar.gd`, `UI/BandwidthBar.tscn` | Remaining fill (shrinks from full) + loss overlay at the decreasing edge |
| `UNIT_GLOSSARY` | `Data/units_glossary.csv` | `bandwidth_deploy_cost`, `bandwidth_loss_cost` (equal for now) |
| `Unit_Card.get_total_bandwidth_cost()` / `get_total_loss_cost()` | `Utilities/unit_card.gd` | Card totals × `num_units` (doubled if upgraded) |
| `PlayerHealthManager` | `Manager/player_health_manager.gd` | `apply_damage_capped`, `get_repair_damage_taken_this_battle()` |

## Flow

1. **Prep start** — `begin_prep()` sets remaining = `max_bandwidth` (full bar).
2. **Placement** — spend deploy cost (cannot exceed remaining); add card loss cost to potential-loss overlay. Right-click refunds both.
3. **Combat start** — no 50% refund.
4. **Friendly death** — subtract that unit's `bandwidth_loss_cost` from remaining and from the loss overlay. Factory excluded.
5. **Battle end** — negative remaining → repair damage; positive → scrap surplus reward.
6. **Inventory** — Upgrade Bandwidth (+10 max, 2 components); Duplicate Unit uses component + scrap costs. Fortress / spell power / unit HP / unit DMG upgrades sit on the same rail — see `run-stat-upgrades.md`.

## Relic TODO

`BandwidthManager.bandwidth_from_enemy_total(enemy_total)` and `GameStateManager._sum_enemy_bandwidth_on_board()` keep the old enemy-total formula. **Do not call from prep.**

## UI

- Remaining bar starts full and decreases. Loss overlay is anchored to the remaining bar's shrinking (right) edge and grows toward the track's original max end.
- Inventory slots show deploy cost; item details show Deploy Cost and Loss Cost.
- Run HUD / shop: **Scrap** is `run_gold`; **Components** unchanged.

## Distinction from shop deconstruct

Shop `ShopControl.process_deconstruct` converts inventory items to run **components** — unrelated to combat bandwidth.
