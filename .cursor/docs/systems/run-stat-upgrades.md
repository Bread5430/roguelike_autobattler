# Run stat upgrades — technical summary

## Overview

Repeatable inventory-rail purchases that persist for the run. Bandwidth and Duplicate stay as they are. Four additional buttons spend **per-upgrade component costs** (inspector vars on `GameStateManager`, default 2 each) and add **+10% of base** (not compounding on already-boosted values).

## Components

| Component | Path | Role |
|-----------|------|------|
| `Inventory` UpgradeMenu | `UI/Inventory.gd`, `UI/Inventory.tscn` | Buttons, live cost labels, disable when unaffordable |
| `GUI` | `UI/GUI.gd` | Signals → `try_upgrade_*` |
| `GameStateManager` | `Manager/game_state_manager.gd` | Costs, bonus percents, `scale_stat`, spend, save/load |
| `PlayerHealthManager` | `Manager/player_health_manager.gd` | Fortress max from `BASE_MAX_HEALTH` (100), preserve fraction |
| `BattleManager` | `Manager/battle_manager.gd` | Apply fortress mods on factory spawn; friendly HP/DMG after unit spawn |

## Costs (balance knobs, not save data)

`@export` on GSM: `fortress_upgrade_cost`, `spell_power_upgrade_cost`, `unit_hp_upgrade_cost`, `unit_dmg_upgrade_cost`. Each `try_upgrade_*` spends **that** variable.

## Stored percents

`fortress_bonus_pct`, `spell_power_bonus_pct`, `friendly_hp_bonus_pct`, `friendly_dmg_bonus_pct`. Reset on new campaign. Saved with `player_curr_health`.

`scale_stat(base, pct)` → `maxi(1, round(base * (1 + pct/100)))`.

## Fortress

Purchase: +10 `fortress_bonus_pct`, then `player_health.set_max_health_from_base(100, pct)` keeping HP fraction.

Factory spawn: after glossary `_ready`, scale factory `max_hp` and `base_damage` by fortress percent, then re-apply `initial_health_fraction`. **Do not** apply friendly unit HP/DMG to `FactoryUnit`.

## Spell power

Purchase increments `spell_power_bonus_pct` and calls `apply_spell_power_upgrade()` (`# TODO` — not wired to spells).

## Friendly unit HP / DMG

`apply_friendly_spawn_modifiers` after card upgrades on:

- `add_unit_to_board` (prep)
- `_spawn_runtime_unit_deferred` (reboot, crawler swarm, infested via `spawn_runtime_unit`)

Skips enemies and factory. Boosts `max_hp`/`curr_hp` and/or `base_damage`. Already-placed units are not retroactively scaled.
