# Bandwidth — technical summary

## Overview

Combat prep/combat resource bar. Player spends **bandwidth** when placing unit cards; can go negative (soft limit). Negative balance at battle end causes repair damage (min HP 1); leftover bandwidth grants bonus **scrap** (`run_gold`) via a separate rewards button.

Max bandwidth is a **run-persistent fixed cap** (start 50). Inventory upgrades add +10 for 2 components. It is not derived from enemy totals each battle.

## Components

| Component | Path | Role |
|-----------|------|------|
| `BandwidthManager` | `Manager/bandwidth_manager.gd` | Bar state: max/current, prep spend tracking, combat refill, death drain, settlement, cap upgrades |
| `BandwidthBar` | `UI/bandwidth_bar.gd`, `UI/BandwidthBar.tscn` | Progress bar + `current / max` label; red text when negative |
| `UNIT_GLOSSARY` | `Data/units_glossary.csv` column `bandwidth_cost` | Per-unit deploy/death cost |
| `Unit_Card.get_total_bandwidth_cost()` | `Utilities/unit_card.gd` | `bandwidth_cost × num_units` for card spend/display |
| `PlayerHealthManager` | `Manager/player_health_manager.gd` | `apply_damage_capped`, `get_repair_damage_taken_this_battle()` |

## Flow

1. **Prep start** — After `setup_battle`, `begin_prep()` sets `current_bandwidth = max_bandwidth` (persisted cap, default 50).
2. **Placement** — `UnitPlacement` place / right-click remove → `spend_bandwidth` / `refund_bandwidth` with card total.
3. **Combat start** — `on_combat_start()` adds `floor(prep_bandwidth_spent × 0.5)`.
4. **Friendly death** — `Base_Unit.died` → `BattleManager.friendly_unit_died` → `on_friendly_unit_died(unit.bandwidth_cost)` subtracts `floor(cost × 0.5)`. Factory excluded.
5. **Battle end** — `settle_battle()`: negative → repair damage via `apply_damage_capped(..., 1)`; positive → `get_bonus_gold()` for rewards payload `scrap_bonus` instant entry (UI: scrap).
6. **Inventory** — Upgrade Bandwidth (+10 max, 2 components); Duplicate Unit spends components + scrap from `Unit_Card.get_duplicate_cost()`.

## Relic TODO

`BandwidthManager.bandwidth_from_enemy_total(enemy_total)` and `GameStateManager._sum_enemy_bandwidth_on_board()` keep the old enemy-total × `enemy_bandwidth_multiplier` (0.8) formula. **Do not call from prep.** Future relic hook.

## UI

- Bar visible with spell bar during prep and combat; hidden on map (`enter_map_exploration`).
- Position: right of `SpellBar` in `GUI.tscn` (~offset 328px).
- Inventory unit cards: blue bandwidth total bottom-left on `InventorySlot.ScrapCostLabel`; tier (`T1`) top-left.
- Run HUD / shop: **Scrap** is `run_gold`; **Components** unchanged.

## Distinction from shop deconstruct

Shop `ShopControl.process_deconstruct` converts inventory items to run **components** — unrelated to combat bandwidth.
