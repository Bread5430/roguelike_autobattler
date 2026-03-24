# Copilot Instructions for Roguelike Autobattler

## Architecture Overview
This is a Godot 4.4 2D roguelike autobattler game. Core components:
- **GameStateManager** (`Manager/game_state_manager.gd`): Top-level state machine (MAP_EXPLORATION, BATTLE_PREPARATION, BATTLE_ACTIVE, etc.)
- **BattleManager** (`Manager/battle_manager.gd`): Handles battle logic, unit spawning, flow generation
- **MapManager** (`Map_Gen/map_manager.gd`): Generates procedural map graphs of connected battle nodes
- **GUI** (`UI/GUI.gd`): Manages unit placement, inventory, spell bar, and casting mode during battles
- **Units**: `Base_Unit.gd` (CharacterBody2D with FSM), `Base_Squad.gd` (Node2D grouping units)
- **Spells**: `Base_Spell.gd` (preview/cast/clear_preview), spell bar (`UI/spell_bar.gd`), `SpellBarSlot`, spell cards in inventory

## Key Patterns
- **Autoloads**: `ITEM_NAME` and `FORMATION_MAP` load CSV data (`Data/items.csv`, `Data/formations.csv`) into global lookup maps; **`UNIT_GLOSSARY`** (`LookUps/unit_glossary.gd`) loads `Data/units_glossary.csv` (per-template stats: max HP, move speed, damage, display name, blurb)
- **Unit glossary**: Each unit template root sets `@export var unit_glossary_id` on `Base_Unit` to a row id in `units_glossary.csv`. `Base_Unit._ready()` applies CSV values over scene defaults. Outgoing damage uses `Attack_Base.get_strike_damage()` (reads `Base_Unit.get_attack_damage()` × `dmg_dealt_mult` at fire time), not a damage field on the attack node
- **post_ready()**: Custom initialization method called after `_ready()` to ensure scene setup (e.g., `GUI.gd` lines 35-50)
- **Signals**: Inter-component communication (e.g., `battle_ended` from BattleManager to GameStateManager)
- **Item inspection**: Inventory right-click emits inspect requests (`inspect_requested(item_inst, item_name, source_global_pos)`), `GUI` builds payloads via `UI/item_details_builder.gd`, and renders the popup with `UI/ItemDetailsCard.tscn`; this contract is reusable for future shop slots.
- **Grid-based Placement**: Units placed on `BoardUI` (GridContainer of `BoardSlot` panels) using formation vectors from `unit_card.gd`
- **Roles & Bitmasks**: Unit roles (CARRY, SWARM, CLEAR, TANK) as bitflags in `ITEM_NAME.gd` for filtering
- **Unit_Parent and non-units**: `BattleManager`’s `Unit_Parent` can contain non-unit nodes (e.g. spell preview indicators like `SpellPreviewCircle`). All battle logic that iterates `unit_parent.get_children()` must filter to `Base_Unit` (e.g. `if i is Base_Unit`) before using `faction`, `set_start_stop`, or tile updates.

## Data Flow
1. Map exploration: Player selects nodes in `MapManager`
2. Battle prep: `GUI` enables deployment mode; places units from inventory using `FORMATION_MAP`; spells from inventory (click) go to `SpellBar`; right-click spell bar slot returns spell to inventory
   - Inventory right-click opens item details card (unit: glossary stats/blurb + deployment info; spell: cooldown + mana cost)
3. Battle active: `BattleManager` spawns enemies, runs flow simulation, updates units; spell bar click enters casting mode (preview under mouse), click to cast or right-click/Escape to cancel
4. Post-battle: Return to map, update progress

## Conventions
- **File Naming**: PascalCase for scenes (.tscn), snake_case for scripts (.gd)
- **Node Structure**: Managers as Control/Node2D, units as CharacterBody2D
- **Input**: Custom actions in `project.godot` (leftClick, inventory=I, rotatePlacement=R)
- **Debugging**: Dev console (`Testing/dev_console.gd`) toggled with ` key for commands like 'help'

## Workflows
- **Run**: Open in Godot editor, play main scene (`UI/main_menu.tscn`)
- **Export**: Use Godot's built-in export for platforms
- **Testing**: Use `enemy_spawn_test.tscn` for isolated battle testing
- **Data Editing**: Modify CSVs, restart autoloads to reload (including `units_glossary.csv` for unit combat stats and glossary text)

## Examples
- Adding unit: Create scene inheriting `Base_Unit.tscn`, set `unit_glossary_id` and add a row to `Data/units_glossary.csv`, add to `items.csv`, reference in `unit_card` scene
- New formation: Add rows to `formations.csv` with X,Y,W,H,Role,Group
- State transition: Emit signal from manager, connect in `game_state_manager.gd` `_ready()`
- Adding spell: Create scene with script extending `Base_Spell` (implement `preview(world_pos)`, `cast(world_pos)`, `clear_preview()`), create spell card scene with `Spell_Card` and `related_spell_effect`, add to `items.csv`