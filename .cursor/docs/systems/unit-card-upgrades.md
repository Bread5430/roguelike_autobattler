# Unit card upgrades

Run-persistent upgrades chosen at **rest sites** (`REPAIR_SITE` map nodes). Same inventory item IDs throughout the run; a registry records which path was chosen per base card type.

## Data

| File | Role |
|------|------|
| `Data/unit_upgrades.csv` | Per base `item_id`: path labels, blurbs, card sprite paths, unit sprite paths |
| `LookUps/unit_upgrades.gd` | Autoload `UNIT_UPGRADES` — CSV loader, `PATH_A` / `PATH_B` constants |
| `Manager/unit_upgrade_registry.gd` | Autoload `UnitUpgradeRegistry` — `base_item_id → path_a \| path_b` for current run |

Only rows in the CSV are offered at rest. Reset on `GameStateManager.start_new_campaign()` via `UnitUpgradeRegistry.reset_for_new_campaign()`.

## Card flags

`Unit_Card.is_upgradable` (default `true`). `router_card` sets `false`. Rest pool = CSV entries ∩ upgradable cards ∩ not already upgraded.

## Rest flow

1. `RestControl.generate_offers()` — 4 random upgrade slots from pool
2. Click slot → `RestUI` **UpgradePathOverlay** (path A / B + blurbs); no cost yet
3. Pick path → `RestControl.try_finalize_upgrade()` spends components, `UnitUpgradeRegistry.apply_path()`, decrements action
4. `Inventory.refresh_unit_card_icons()` updates card textures and scrap labels

## Runtime behavior

- **Inventory:** item ID unchanged (e.g. always `four_melee`)
- **`Unit_Card.setup_unit()`:** swaps card texture from CSV when registry has a path; `get_total_scrap_cost()` doubles when upgraded
- **Spawn:** `BattleManager.add_unit_to_board()` → `Base_Unit.apply_upgrade_from_card(item_name)` before `post_ready()` (2× HP/damage/scrap + unit sprite); `_apply_upgrade_abilities()` runs at end of `post_ready()` so status recompute does not wipe path mods
- **Enemies:** no upgrade (faction-only hook; empty registry path for enemy card ids)

## Adding a new upgradable card

1. Add row to `unit_upgrades.csv` (sprites optional but recommended)
2. Override `_apply_upgrade_abilities()` on the unit root script — short `match upgrade_path` using existing stats/nodes only
3. Ensure card scene has `is_upgradable = true` (default)

## Exemplars

| Base card | Path A | Path B |
|-----------|--------|--------|
| `four_melee` | Berserker: +25% move speed | Shield Wall: `dmg_taken_mult = 0.75` |
| `one_ranged` | Marksman: `dmg_dealt_mult = 1.3` | Volley: −30% ranged attack cooldown |

Unit scripts: `melee_unit_template.gd`, `ranged_unit_template.gd`.

## Save/load

Registry not serialized yet (same gap as inventory). TODO when save system expands.
