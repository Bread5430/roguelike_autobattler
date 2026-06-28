# Chasing Enemy + Blockade Nodes

Map pressure system: a semi-transparent capsule sweeps left-to-right after each completed map node, converting covered nodes into **BLOCKADE** battles.

## Key files

| Path | Role |
|------|------|
| `Map_Gen/chasing_enemy_controller.gd` | Step math, coverage test, capsule draw, blockade application |
| `Map_Gen/map_manager.gd` | Chaser config exports, draw order, `on_map_node_completed()`, save/load |
| `Map_Gen/map_node.gd` | `ContentType.BLOCKADE`, `chaser_blockaded` on exit nodes |
| `Manager/game_state_manager.gd` | Advance hook, BLOCKADE routing, difficulty/rewards |
| `Manager/battle_manager_components/enemy_spawner.gd` | Heavy + bonus formation for blockade / pressured exit |
| `UI/chaser_hud.gd` + `ChaserHUD.tscn` | Step counter, final X label, per-step markers |

## Flow

1. Map generates; chaser starts at step 0 off the left edge.
2. Player completes any map node (battle, shop, rest, event).
3. `MapManager.on_map_node_completed()` advances chaser one step.
4. Nodes under the leading cap become `BLOCKADE` (hex, label `X`).
5. **Exit node** never changes content type; sets `chaser_blockaded = true` and gets a dark ring overlay.
6. `chaser_step_changed` → `GUI.refresh_chaser_hud()`.

## Combat

- **BLOCKADE**: difficulty bumped one tier; spawner uses `heavy` + extra `light` formation; gold ×1.5, no unit recruit reward.
- **Exit + chaser_blockaded**: forced `heavy` + bonus formation; standard end/campaign rewards. TODO: dedicated boss fight.

## Editor tuning (`MapManager`)

- `chaser_total_steps`, `chaser_half_height` (0 = auto: half map height + node radius), `chaser_capsule_length`, `chaser_fill_color`

## Persistence

`save_map_state` stores `chaser_current_step`, `node_content_types`, `node_chaser_blockaded`.
