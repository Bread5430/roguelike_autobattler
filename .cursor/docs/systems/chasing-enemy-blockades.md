# Chasing Enemy + Blockade Nodes

Map pressure system: a semi-transparent capsule sweeps left-to-right after each completed map node, converting covered nodes into **BLOCKADE** battles.

## Key files

| Path | Role |
|------|------|
| `Map_Gen/chasing_enemy_controller.gd` | Step math, coverage test, capsule draw, future-step preview arcs |
| `Map_Gen/map_manager.gd` | Chaser config exports, draw order, `on_map_node_completed()`, save/load |
| `Map_Gen/map_node.gd` | `ContentType.BLOCKADE`, `chaser_blockaded` on exit nodes |
| `Manager/game_state_manager.gd` | Advance hook, BLOCKADE routing, difficulty/rewards |

## Flow

1. Map generates; chaser starts at step 0 off the left edge.
2. Player completes any map node (battle, shop, rest, event).
3. `MapManager.on_map_node_completed()` advances chaser one step and `queue_redraw()`.
4. Nodes under the leading cap become `BLOCKADE` (hex, label `X`).
5. **Exit node** never changes content type; sets `chaser_blockaded = true` and gets a dark ring overlay.

## On-map step previews

Future chaser positions are drawn directly on the map (no separate HUD panel):

- For each step `current_step + 1` … `total_steps`, draw the leading semicircle at that step’s X.
- Label each arc with **moves remaining** (`step - current_step`). Final step label appends `!`.
- Active filled capsule draws on top of preview arcs; nodes draw on top of both.

`ChasingEnemyController.draw_step_preview_curves()`; toggled via `MapManager.chaser_draw_step_previews`.

## Combat

- **BLOCKADE**: difficulty bumped one tier; spawner uses `heavy` + extra `light` formation; gold ×1.5, no unit recruit reward.
- **Exit + chaser_blockaded**: forced `heavy` + bonus formation; standard end/campaign rewards. TODO: dedicated boss fight.

## Editor tuning (`MapManager`)

- `chaser_total_steps` — step size `(map_width - cap_radius + one_cell) / steps` per node completion
- Step 0 starts one grid cell left of the map (`x = -cell_width`); at step `total_steps` the cap's right edge reaches `x = map_width` (`front.x = map_width - half_height`)
- `chaser_half_height` (0 = auto), `chaser_capsule_length` (0 = auto: map width + one cell), `chaser_fill_color`
- `chaser_draw_step_previews`, `chaser_preview_color`, `chaser_preview_line_width`, `chaser_preview_label_color`

## Persistence

`save_map_state` stores `chaser_current_step`, `node_content_types`, `node_chaser_blockaded`.
