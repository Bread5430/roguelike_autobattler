# Deployment map geometry — technical summary

## Overview

Prep-phase deployment uses **four spatial zones** on one battlefield: player main board, enemy main board, **player flank strips** (beside the enemy board), and **enemy flank strips** (above/below the player board). Formation CSV coordinates are **authored on the player main board**; `Enemy_Spawner` mirrors them onto the enemy side.

**Invariant:** Player flanks hug the **enemy** main grid column. Enemy flanks hug the **player** main grid column. Do not spawn enemy external flanks from `SideStripTop` / `SideStripBottom` world X (those nodes are for player deployment).

## Scene layout (`Manager/battle_manager.tscn`)

| Node | Role | Default size | `start_offset` | `board_position_offset` |
|------|------|--------------|----------------|-------------------------|
| `BoardUI` | Player main + logical coords | 12×24, cell 50×50 | `(1, 1)` | `(0, 0)` |
| `SideStripTop` | **Player** top flank UI | 12×3, cell 50×50 | `(13, -2)` | `(0, -3)` |
| `SideStripBottom` | **Player** bottom flank UI | 12×3, cell 50×50 | `(13, 25)` | `(0, 24)` |
| `Enemy_Spawner.grid_size` | Horizontal tile gap player → enemy main | `Vector2i(14, 0)` in scene | — | — |

With default exports, **world origins** (top-left of each grid’s painted area):

- **Player main** `BoardUI.global_position`: **(50, 50)** — spans **x ≈ 50…650**, **y ≈ 50…1250** (12×24 cells).
- **Player flank strips** `SideStripTop` / `SideStripBottom`: **x ≈ 650…1250** (12 cells wide), **y ≈ -100…50** (top) and **y ≈ 1250…1400** (bottom). Strips sit at the **right edge of the player board** (column 13 in cell offsets), i.e. beside the **enemy** main column—not above/below the player board in X.

`BoardUI.gd` sets `position = start_offset * cellSize` and assigns each `BoardSlot.board_position` with `board_position_offset` so logical coords stay consistent across main + strips.

## Logical coordinate spaces

Shared constant **`SIDE_ROWS = 3`** (`BoardUI.gd`, `unit_placement.gd`, `enemy_spawner.gd`).

### Player deployment (`UI/unit_placement.gd`)

- **Main board:** `x ∈ [0, width)`, `y ∈ [0, height)`.
- **Top player flank:** `y ∈ [-SIDE_ROWS, -1]` → slots on `SideStripTop`.
- **Bottom player flank:** `y ∈ [height, height + SIDE_ROWS)` → slots on `SideStripBottom`.
- `unit_board_space_map` height = `height + 2 * SIDE_ROWS`; index via `_space_map_y(logical_y) = logical_y + SIDE_ROWS`.

### Formation / enemy authoring (`Data/formations.csv`, `Data/mini_formations.csv`)

- **Main formations:** X,Y on the **player** board. Playable main band (for validation / random main minis): **`y ∈ [SIDE_ROWS, height - SIDE_ROWS)`**, **`x ∈ [0, width)`**.
- **Side-band rows in full formations:** `y < 0` (top external), `y ≥ height` (bottom external), or legacy **`y ≥ height - SIDE_ROWS`** (bottom three rows of the authored grid, still `y < height`).
- **Mini formations (`mini_formations.csv`):**
  - `Surface=main` → anchor random placement in main playable band only; must not land in side bands.
  - `Surface=side` → template coords `y ∈ [0, SIDE_ROWS)`; spawned via `spawn_side_strip_mini_formation_entry` (top or bottom enemy flank, see below).

### Enemy spawn mirror (`enemy_spawner.gd`)

- **Horizontal mirror** (enemy faces player): `mirrored_x = board_width - footprint_w - local_x`; placement vectors mirrored with `_mirror_placement_vectors_x`.
- **Enemy main board tile:** `spawn_pos = Vector2i(mirrored_x, local_y) + grid_size` → world via `_board_grid_to_world` (`BoardUI.global_position + tile * cellSize`).
- **`grid_size.x` (14)** is the horizontal shift in **tile indices** from player-authored columns to enemy main columns (includes gap between 12-wide boards).

## Zone map (who deploys where)

```text
                    [ Enemy flank — top ]
                    (player BoardUI x-span)
                    y < BoardUI.top
                              |
    [Player main 12w]         |         [Enemy main 12w]
    x 50..650                 |         x ~ 750.. (grid_size)
    BoardUI                   |         mirrored + grid_size
                              |
    [SideStripTop 12w] --------+-------- (enemy column flank)
    x 650..1250  PLAYER only   |         y above enemy field
                              |
                    [ Enemy flank — bottom ]
                    (player BoardUI x-span)
                    y below BoardUI bottom
```

| Zone | Who | Grid / nodes | World X (typical) | World Y (typical) |
|------|-----|--------------|-------------------|-------------------|
| Player main | Player | `BoardUI` | 50…650 | 50…1250 |
| Player top/bottom flank | Player | `SideStripTop` / `SideStripBottom` | 650…1250 | -100…50 / 1250…1400 |
| Enemy main | Enemy (spawned) | `BoardUI` coords + `grid_size` | enemy column | same row band as authoring |
| Enemy top/bottom flank | Enemy (spawned) | **Not** side-strip nodes for X | **50…650** (player `BoardUI`) | above/below player main |

## Enemy flank world math (`_side_strip_grid_to_world`)

**External flank** (authored `local_y < 0` or `local_y ≥ board_height`, including side mini formations):

- `world_x = BoardUI.global_position.x + local_x * cell_w` (mirrored column index).
- **Top:** `world_y = board_origin.y - (SIDE_ROWS - strip_local_y) * cell_h`.
- **Bottom:** `world_y = board_origin.y + board_height * cell_h + strip_local_y * cell_h`.

**Legacy side-band on main grid** (`height - SIDE_ROWS ≤ local_y < height`): enemy **main-board X** (`board.global_position.x + (local_x + grid_size.x) * cell_w`), **Y** from `SideStripTop` / `SideStripBottom` at `strip_local_y` (used for formation rows in the bottom playable band).

**Side mini formations:** Authored strip-local `y ∈ [0, SIDE_ROWS)`; top strip flips Y and mirrors placement vectors so units face inward. Random placement picks top or bottom enemy flank; occupancy key `Vector3i(on_top ? 1 : 0, x, y)`.

## Player placement world math

- Anchors use selected `BoardSlot.global_position` (`unit_placement.gd`, `battle_manager._deployment_footprint_origin_global`).
- Logical `top_corner.y < 0` → `SideStripTop` children; `y ≥ board.height` → `SideStripBottom`; else main `BoardUI`.

## Side-tile combat debuff

At battle start, **friendly** units whose position lies in the **player** flank strip rects (`side_strip_top_tiles` / `side_strip_bottom_tiles` global AABB) receive short stun + damage vulnerability (`battle_manager.gd` `_apply_side_tile_debuffs_to_player_units`). Enemy flank over the player board is separate world space and is not those rects.

## Key files

| File | Responsibility |
|------|----------------|
| `Manager/battle_manager.tscn` | Node positions, `grid_size`, strip offsets |
| `Manager/battle_manager_components/BoardUI.gd` | Grid build, `start_offset`, `board_position_offset`, `SIDE_ROWS` |
| `UI/unit_placement.gd` | Player logical coords, strip slot lookup, space map |
| `Manager/battle_manager_components/enemy_spawner.gd` | Mirror, world spawn, mini formations, `_side_strip_grid_to_world` |
| `LookUps/FORMATION_MAP.gd` | CSV load, `SURFACE_MAIN` / `SURFACE_SIDE`, mini template bounds |
| `Data/formations.csv`, `Data/mini_formations.csv` | Authoring data |

## Gotchas

- **Do not** place enemy external flanks at `SideStripTop.global_position.x` (650+); that is the **player** flank column beside the enemy board.
- **`placement_surface=side`** rows in full formations must go through `spawn_side_strip_mini_formation_entry`, not `spawn_single_formation_entry`.
- **`placement_surface=main`** random minis are rejected in side bands; **side** minis never anchor on the main playable grid.
- Changing `BoardUI` width/height, `start_offset`, or `Enemy_Spawner.grid_size` requires revisiting mirror math and world flank formulas together.
- Flow field / map border behavior: `start_offset (1,1)` keeps units off the battle space world origin edge (`BoardUI.gd` comment).

## Related docs

- Placement input routing: `.cursor/docs/input-coordination-plan.md`, `.cursor/docs/patterns.md` (grid placement).
- Bandwidth on deploy: `.cursor/docs/systems/bandwidth.md`.