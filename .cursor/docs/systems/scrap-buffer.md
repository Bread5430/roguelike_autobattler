# Scrap buffer — technical summary

## Overview

Combat prep/combat resource bar derived from enemy scrap totals. Player spends scrap when placing unit cards; can go negative (soft limit). Negative balance at battle end causes repair damage (min HP 1); positive balance grants bonus gold via a separate rewards button.

## Components

| Component | Path | Role |
|-----------|------|------|
| `ScrapBufferManager` | `Manager/scrap_buffer_manager.gd` | Bar state: max/current, prep spend tracking, combat refill, death drain, settlement |
| `ScrapBufferBar` | `UI/scrap_buffer_bar.gd`, `UI/ScrapBufferBar.tscn` | Progress bar + `current / max` label; red text when negative |
| `UNIT_GLOSSARY` | `Data/units_glossary.csv` column `scrap_cost` | Per-unit scrap cost |
| `Unit_Card.get_total_scrap_cost()` | `Utilities/unit_card.gd` | `scrap_cost × num_units` for card spend/display |
| `PlayerHealthManager` | `Manager/player_health_manager.gd` | `apply_damage_capped`, `get_repair_damage_taken_this_battle()` |

## Flow

1. **Prep start** — After `setup_battle`, sum `scrap_cost` on enemy `Base_Unit` nodes; `begin_prep(int(total × enemy_scrap_multiplier))` (default multiplier `0.8`, export on manager).
2. **Placement** — `GUI._place_unit` / right-click remove → `spend_scrap` / `refund_scrap` with card total.
3. **Combat start** — `on_combat_start()` adds `floor(prep_scrap_spent × 0.5)`.
4. **Friendly death** — `Base_Unit.died` → `BattleManager.friendly_unit_died` → `on_friendly_unit_died(unit.scrap_cost)` subtracts `floor(scrap × 0.5)`. Factory excluded.
5. **Battle end** — `settle_battle()`: negative → repair damage via `apply_damage_capped(..., 1)`; positive → `get_bonus_gold()` for rewards payload `scrap_bonus` instant entry.

## UI

- Bar visible with spell bar during prep and combat; hidden on map (`enter_map_exploration`).
- Position: right of `SpellBar` in `GUI.tscn` (~offset 328px).
- Inventory unit cards: blue scrap total bottom-left on `InventorySlot.ScrapCostLabel`.

## Distinction from shop scrap

Shop `ShopControl.process_scrap` converts inventory items to run **components** — unrelated to combat scrap buffer.
