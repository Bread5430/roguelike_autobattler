# Architecture Overview

Godot 4.4 2D roguelike autobattler. Core components:

- **GameStateManager** (`Manager/game_state_manager.gd`): Top-level state machine (MAP_EXPLORATION, BATTLE_PREPARATION, BATTLE_ACTIVE, etc.)
- **BattleManager** (`Manager/battle_manager.gd`): Battle logic, unit spawning, flow generation
- **MapManager** (`Map_Gen/map_manager.gd`): Procedural map graphs of connected battle nodes
- **GUI** (`UI/GUI.gd`): Unit placement, inventory, spell bar, and casting mode during battles
- **Units**: `Base_Unit.gd` (CharacterBody2D with FSM), `Base_Squad.gd` (Node2D grouping units)
- **Spells**: `Base_Spell.gd` (preview/cast/clear_preview), spell bar (`UI/spell_bar.gd`), `SpellBarSlot`, spell cards in inventory
