# Copilot Instructions for Roguelike Autobattler

## Architecture Overview
This is a Godot 4.4 2D roguelike autobattler game. Core components:
- **GameStateManager** (`Manager/game_state_manager.gd`): Top-level state machine (MAP_EXPLORATION, BATTLE_PREPARATION, BATTLE_ACTIVE, etc.)
- **BattleManager** (`Manager/battle_manager.gd`): Handles battle logic, unit spawning, flow generation
- **MapManager** (`Map_Gen/map_manager.gd`): Generates procedural map graphs of connected battle nodes
- **GUI** (`UI/GUI.gd`): Manages unit placement, inventory, spell bar during battles
- **Units**: `Base_Unit.gd` (CharacterBody2D with FSM), `Base_Squad.gd` (Node2D grouping units)

## Key Patterns
- **Autoloads**: `ITEM_NAME` and `FORMATION_MAP` load CSV data (`Data/items.csv`, `Data/formations.csv`) into global lookup maps
- **post_ready()**: Custom initialization method called after `_ready()` to ensure scene setup (e.g., `GUI.gd` lines 35-50)
- **Signals**: Inter-component communication (e.g., `battle_ended` from BattleManager to GameStateManager)
- **Grid-based Placement**: Units placed on `BoardUI` (GridContainer of `BoardSlot` panels) using formation vectors from `unit_card.gd`
- **Roles & Bitmasks**: Unit roles (CARRY, SWARM, CLEAR, TANK) as bitflags in `ITEM_NAME.gd` for filtering

## Data Flow
1. Map exploration: Player selects nodes in `MapManager`
2. Battle prep: `GUI` enables deployment mode, places units from inventory using `FORMATION_MAP`
3. Battle active: `BattleManager` spawns enemies, runs flow simulation, updates units
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
- **Data Editing**: Modify CSVs, restart autoloads to reload

## Examples
- Adding unit: Create scene inheriting `Base_Unit.tscn`, add to `items.csv`, reference in `unit_card` scene
- New formation: Add rows to `formations.csv` with X,Y,W,H,Role,Group
- State transition: Emit signal from manager, connect in `game_state_manager.gd` `_ready()`</content>
<parameter name="filePath">c:\Users\wange\Documents\Godot\roguelike_autobattler\.github\copilot-instructions.md