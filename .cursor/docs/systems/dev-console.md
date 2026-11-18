# Dev console — technical summary

## 1. Project overview

- **Goal:** In-game developer console for cheats, map/formation tooling, and diagnostics without leaving play mode.
- **Constraints:** Must not use `get_tree().paused` (reserved for PauseMenu / loss). While the terminal LineEdit is focused, block gameplay input; Escape deselects without closing; `` ` `` toggles visibility. Keep focus after command submit.
- **Stack:** Godot 4.4; `Testing/dev_console.gd` (`class_name DevConsole`) + `Testing/dev_console.tscn`; child of `GameStateManager` at CanvasLayer `layer = 100`.

## 2. Final architecture

### Components

| Piece | Responsibility |
|-------|----------------|
| `DevConsole` (`Testing/dev_console.gd`) | Builds UI at runtime; command parse/execute; focus / input-block state; `DevConsole.log()` static helper |
| `InputBlocker` (ColorRect, full-screen, alpha 0) | Mouse sink while terminal selected; sits behind `ConsolePanel` |
| `ConsolePanel` / `LineEdit` / `RichTextLabel` | Visible console chrome; LineEdit is the “terminal” |
| `MapManager` | `goto_node` / `enable_debug_teleport_on_click`, availability refresh after debug teleport |
| `GameStateManager` | `force_battle_victory()`, `add_gold`, `add_components` |
| `GUI` / `Inventory` / `ScrapBufferManager` | Formation editor + scrap cost-tracking; inventory card grants |
| Game `_input` / `_process` callers | Early-out via `DevConsole.is_blocking_game_input()` |

### Visibility vs selection

| State | Console visible | LineEdit focused | Game input blocked |
|-------|-----------------|------------------|--------------------|
| Closed | no | no | no |
| Open + selected | yes | yes | **yes** |
| Open + deselected (Escape) | yes | no | no |

### Control flow — open / select / deselect / close

1. `` ` `` (`KEY_QUOTELEFT`) → `toggle_console()` → `show_console()` / `hide_console()`.
2. `show_console()`: show panel, `input_line.grab_focus()`, `_refresh_input_block_state()`.
3. While selected: `_blocking_game_input = true`; show `InputBlocker`; swallow mouse outside panel in `_input` (`process_priority = 1000`); eat leftover actions in `_unhandled_input`.
4. Escape / `ui_cancel` while focused: `_allow_terminal_unfocus = true`, `release_focus()`, stop blocking; console stays open.
5. Accidental focus loss (click on FOCUS_NONE output/blocker): deferred reclaim via `_on_terminal_focus_exited_deferred` unless `_allow_terminal_unfocus`.
6. After `text_submitted`: clear line, `grab_focus()` again, refresh block state (terminal stays selected).
7. `` ` `` while open → `hide_console()`: hide panel, intentional unfocus, clear block flag.

### Input gating (who checks the flag)

Callers of `DevConsole.is_blocking_game_input()`:

- `Manager/input_coordinator.gd` — game-area clicks
- `Manager/viewport.gd` — zoom/pan `_input` + WASD `_process`
- `Map_Gen/map_manager.gd` — map node clicks
- `UI/GUI.gd` — casting `_input`, rotate `_unhandled_input`
- `UI/Inventory.gd` — inventory hotkey `_process`
- `UI/battle_speed_bar.gd` — speed hotkeys
- `UI/Menus/pause_menu.gd` — Escape / pause (so Escape deselects terminal first)

Keys still reach the focused `LineEdit` (not marked handled in `_input`); mouse over the console panel is not swallowed so caret/selection work.

## 3. Key decisions & rationale

- **Static `_blocking_game_input` + `is_blocking_game_input()`** — Camera WASD and inventory use polled `Input.is_action_*` in `_process`; event swallowing alone is insufficient. Flag is cheap and explicit.
- **Do not `get_tree().paused`** — Same reason as battle soft-pause: would freeze unrelated UI and fight PauseMenu ownership.
- **Escape deselect ≠ close** — Lets the console stay on-screen for reading logs while playing; `` ` `` remains the close/toggle.
- **Reclaim focus on accidental unfocus** — Godot clears focus when clicking FOCUS_NONE controls; without reclaim, outside clicks would silently stop blocking.
- **`complete_node` → `force_battle_victory()`** — Ends battle via `battle_manager.end_battle(true)` in prep or combat so normal victory flow (rewards, map) runs; does not call map `complete_node` directly.
- **`goto_node` one-shot click** — Arms `debug_teleport_on_click`; on arrival sets `_debug_bypass_availability`, then `update_node_availability()` so neighbors of the landed (possibly uncompleted) node become available.

## 4. Implemented features / progress

### UX

- Toggle `` ` ``; Escape deselects terminal; submit keeps focus.
- Command history via Up/Down.
- Colored BBCode log; `help` lists commands.

### Commands (high-signal)

| Command | Behavior |
|---------|----------|
| `goto_node` / `go_node` | Next map click moves player ignoring availability; then refresh neighbor availability |
| `complete_node` | `GameStateManager.force_battle_victory()` in `BATTLE_PREPARATION` or `BATTLE_ACTIVE` |
| `add_card <id> <count>` | Inventory grant via `ITEM_NAME` lookup |
| `add_gold <n>` | `gsm.add_gold` (run scrap) |
| `add_components <n>` | `gsm.add_components` |
| `formation_editor on\|off …` | `GUI.enter_enemy_formation_editor_mode` / exit |
| `formation_load <name>` | Load formation onto player board (editor) or enemy side (prep) |
| `timescale` / `teleport` / `zoom` / `regen_map` / `node_info` / `save` | Diagnostics / camera / map |

### Related tooling touched by console workflows

- Formation editor: static routers via `UnitPlacement.respawn_static_routers()`; scrap cost-tracking `ScrapBufferManager.begin_formation_cost_tracking()` (0 / 100000, increments, no enemy discount).
- Clear Battlefield button (deployment + editor): `UnitPlacement.return_placed_units_to_inventory()` — not a console command; same session tooling.

## 5. Open problems / TODOs

- `god_mode` / `godmode` stub only.
- `timescale` can fight `BattleSpeedController` if used during `BATTLE_ACTIVE` [assumed].
- No dedicated doc cross-link from formation-editor scrap mode beyond this + scrap-buffer notes [assumed if `scrap-buffer.md` exists].

## 6. Important context for continuation

- **Invariant:** While `is_blocking_game_input()` is true, gameplay must not react to mouse/hotkeys; add the same early-out when introducing new `_input` / polled input.
- **Invariant:** Intentional unfocus must set `_allow_terminal_unfocus` before `release_focus()` (Escape / hide).
- Console is above UI (`layer = 100`); `InputBlocker` does not replace flag checks for nodes that handle `_input` before GUI.
- `unit_board_space_map` Y uses `SIDE_ROWS` offset — formation CSV save must iterate `map_y` and convert to logical Y (see `GUI._save_editor_formation_to_new_csv`).
- Static routers are not in `unit_board_space_map`; Clear Battlefield / save must not treat them as player-placed cards.

## 7. Useful snippets / patterns

```gdscript
# Gate new gameplay input:
if DevConsole.is_blocking_game_input():
	return

# Log from anywhere:
DevConsole.log("message", "green")

# Map debug teleport arm:
map_manager.enable_debug_teleport_on_click()
```

- Scene: `Manager/game_state_manager.tscn` → child `DevConsole`.
- See also: `.cursor/docs/input-coordination-plan.md`, `.cursor/docs/systems/battle-speed-control.md` (do not pause tree), `.cursor/docs/conventions-workflows.md`.
