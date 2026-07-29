# Unit card upgrades

Run-persistent upgrades chosen at **rest sites** (`REPAIR_SITE` map nodes). Same inventory item IDs throughout the run; a registry records which path was chosen per base card type.

## Data

| File | Role |
|------|------|
| `Data/unit_upgrades.csv` | Per base `item_id`: path labels, blurbs, card sprite paths |
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
- **Spawn:** `BattleManager.add_unit_to_board()` → `Base_Unit.apply_upgrade_from_card(item_name)` before `post_ready()` (2× HP/damage/scrap + animation swap); `_apply_upgrade_abilities()` runs at end of `post_ready()` so status recompute does not wipe path mods
- **Animations:** `FSM` tracks `run_animation`/`die_animation`/`attack_animation` (defaults `walk`/`die`/`""`) and plays those names per state. Upgraded animations are **pre-authored on the unit's `AnimatedSprite2D`**, named `walk_a`/`die_a` (path A) or `walk_b`/`die_b` (path B). `Base_Unit._apply_upgrade_animations()` only calls `FSM.set_animation_names()` for names that actually exist in the `SpriteFrames`, so a missing variant just keeps the base animation. No textures are loaded at runtime.
- **Enemies:** no upgrade (faction-only hook; empty registry path for enemy card ids)

## Adding a new upgradable card

1. Add row to `unit_upgrades.csv` (path labels, blurbs, card sprite paths)
2. Author `walk_a`/`die_a` and/or `walk_b`/`die_b` animations on the unit's `AnimatedSprite2D`
3. Override `_apply_upgrade_abilities()` on the unit root script — short `match upgrade_path` using existing stats/nodes only
4. Ensure card scene has `is_upgradable = true` (default)
5. If the unit's FSM plays animations, it should use `run_animation`/`die_animation`/`attack_animation` (not hardcoded names) so upgrades can swap them

## Exemplars

| Base card | Path A | Path B |
|-----------|--------|--------|
| `four_melee` | Reinforced Plating: Ablative Armor regen every 5s | Assault Doctrine: 2 Ablative stacks + 25% move/attack speed |
| `bruiser_card` | Vampiric Strikes: heal 25% of killed unit max HP | Bloodlust: up to +50% move/attack speed from missing HP |
| `exploder_card` | Cataclysm: larger/more damaging death explosion | Phoenix Core: revive once after 5s |
| `arc_unit` | Executioner: +15% dmg dealt per kill | Iron Guard: flat damage reduction 2 |
| `chaff_swarm` | Infestors: Infested on hit; spawn crawlers on Infested death; +35% speed | Resilient Swarm: 50% chance revive once after 5s |
| `one_ranged` | Longshot: ×3 attack range | Disruptor Rounds: slow on hit + purge BUFF polarity effects |

**Base (non-upgrade) change:** `four_melee` always spawns with 1 stack of Ablative Armor.

Unit scripts: `melee_unit_template.gd`, `bruiser_unit.gd`, `exploder_unit.gd`, `arc_unit_template.gd`, `basic_chaff.gd`, `ranged_unit_template.gd`.

## Save/load

Registry not serialized yet (same gap as inventory). TODO when save system expands.
