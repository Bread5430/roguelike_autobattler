# Input Coordination Plan: GUI and Battle Manager

## Problem Summary

The **GUI** (under `UICanvas` CanvasLayer) and the **Battle Manager** (in the default viewport) compete for mouse input. Only one branch can receive `_gui_input` for a given click, and unhandled input does not reliably reach both systems.

## Node Tree (Relevant Parts)

```
GameStateManager (Node)
├── InputCoordinator (Node)        ← dedicated unhandled-input delegator (input_coordinator.gd)
├── BattleManager (Control)        ← default canvas, under camera; mouse_filter IGNORE
│   ├── BoardUI (GridContainer)     ← BoardSlots, mouse_filter IGNORE
│   ├── Unit_Parent (Node)          ← spawned units (CharacterBody2D)
│   └── ...
├── MapManager
├── Viewport (Camera2D)             ← camera + viewport.gd _input (zoom/pan only marked handled)
└── UICanvas (CanvasLayer)          ← drawn ON TOP
    └── Gui (Control)               ← full-screen anchors; root mouse_filter IGNORE (Passthrough_Helper)
        ├── Inventory
        ├── SpellBar
        └── End_Prep (Button)
```

- **UICanvas** is a CanvasLayer, so it draws above the default 2D content. The **root Gui** Control is full-screen.
- **BattleManager** is a Control in the main scene, so it (and BoardUI/BoardSlot) live in the **default canvas**, which is rendered below the CanvasLayer.

## How Input Propagates (Godot)

From [InputEvent — Godot Engine](https://godot-doc.readthedocs.io/en/3.0/tutorials/inputs/inputevent.html):

1. **`_input(event)`** — Any node that overrides it (and has input processing enabled). First to call `set_input_as_handled()` consumes the event.
2. **GUI** — The **Control under the mouse** (from the **topmost** canvas layer downward) gets `_gui_input()`. If it calls `accept_event()`, the event stops. Otherwise the event propagates **up** to that Control’s ancestors (not to other branches or layers).
3. **`_unhandled_input(event)`** — Only if the event was **not** consumed by GUI. Ideal for gameplay so UI can "eat" input when focused.
4. **Physics** — If still unhandled, the viewport can deliver to CollisionObject2D (e.g. Area2D) via `_input_event()` (ray from click).

So:

- The "Control under the mouse" is chosen **per canvas layer**, starting from the **top** layer. Because **UICanvas** is on top, the Gui (or a child) is always the first Control considered. BattleManager/BoardUI are in the default canvas, so they only get input when **no** Control in the GUI layer receives the event (e.g. root Gui has `MOUSE_FILTER_IGNORE` and the click is not on another GUI control).
- If the root Gui has `MOUSE_FILTER_STOP`, it receives every click and can `accept_event()`, so BattleManager **never** gets `_gui_input`.
- If the root Gui has `MOUSE_FILTER_IGNORE`, clicks on "empty" space pass through to the default canvas; then the Control under the mouse there (e.g. BattleManager or BoardSlot) gets `_gui_input`. In that case the **Gui's** `_gui_input` (where placement lives) is **not** called for that click, so placement must be driven from elsewhere.

## Design Goal

- **Clicks on UI** (inventory, spell bar, End Prep): handled by those Controls via `_gui_input` as today.
- **Clicks on game area** (board / units):
  - **BATTLE_PREPARATION**: placement and removal (current GUI logic).
  - **BATTLE_ACTIVE**: unit selection (or other battle actions) in BattleManager.
- Both `_unhandled_input` and `_gui_input` should be usable where appropriate: UI uses `_gui_input`; game-area clicks are funneled through a single path so both GUI and BattleManager can be driven without competing for the same raw event.

## Recommended Approach: Single Coordinator + Passthrough

Use one node that receives **unhandled** clicks for the game area and delegates to GUI or BattleManager. That way:

- No competition: only the coordinator gets the "game area" click.
- GUI keeps handling UI via `_gui_input` on its interactive controls.
- BattleManager gets unit selection only via the coordinator, not by competing for `_gui_input`.

### Step 1: Mouse filters (who receives GUI input)

| Node / area              | `mouse_filter` | Reason |
|--------------------------|----------------|--------|
| **Gui (root)**           | `MOUSE_FILTER_IGNORE` | So clicks on the "game" area are not consumed by the full-screen GUI and can become unhandled. |
| **Inventory, SpellBar, End_Prep, etc.** | `MOUSE_FILTER_STOP` | So they keep receiving `_gui_input` for buttons/slots. |
| **BattleManager**       | `MOUSE_FILTER_IGNORE` | So it does not consume game-area clicks; they stay unhandled and reach the coordinator. |
| **BoardUI / BoardSlot**  | `MOUSE_FILTER_IGNORE` | Same: don't consume; let the coordinator route the click. |

- Passthrough_helper already sets the Gui tree; ensure the **root Gui** is IGNORE and only real UI controls are STOP.
- Set BattleManager (and optionally BoardUI) to IGNORE in code or in the scene (e.g. in `post_ready()` or in the tscn).

### Step 2: Input coordinator (who gets unhandled game-area clicks)

- Use a **dedicated child node** of GameStateManager (not on GameStateManager itself) to run **`_unhandled_input(event)`**.
- When the event is a mouse click (or other game-area action):
  1. **Hit-test UI**: use the same logic as `GUI.is_mouse_over_ui_element(mouse_pos)`. If the click is over a UI element, **do nothing** (the UI Control will have already received it via `_gui_input` if it has STOP; if not, you can optionally forward once — see below).
  2. **If not over UI**:
     - **BATTLE_PREPARATION**: call `gui.handle_game_area_click(event)` (placement/removal).
     - **BATTLE_ACTIVE**: call `battle_manager.handle_unit_click(event)` (e.g. select unit under cursor).
  3. After delegating, call **`get_viewport().set_input_as_handled()`** so the event is not processed again.

This way, **unhandled** input for the game area is centralized in one place and **passed through** to the right system (GUI or BattleManager) without both nodes competing for the same `_gui_input`.

### Step 3: Refactor GUI placement out of `_gui_input`

- Move the placement/removal logic that currently runs in **`GUI._gui_input()`** into a single public method, e.g. **`handle_game_area_click(event: InputEvent)`**.
- That method should:
  - Use the same conditions as today (e.g. `deployment_mode`, left/right button, `curr_unit` / `isValid` for placement, and removal on right-click).
  - Use **event position** (or current mouse position) and existing helpers (`_get_target_cell()`, `get_unit_at_tile()`, etc.) so behavior is unchanged.
- **`GUI._gui_input()`** can be reduced to a no-op for the game area (or removed for that case), since the coordinator will call `handle_game_area_click()` when the click is in the game area and in prep phase.

### Step 4: BattleManager unit click handling

- Add **`battle_manager.handle_unit_click(event: InputEvent)`**.
- Implement:
  - Convert **screen/viewport position** to **world position** (same as GUI: use viewport's canvas transform and camera so it matches the battle view).
  - Determine which unit (if any) is under that world position:
    - Option A: **Physics raycast** from the camera (or viewport) through the click; use collision layers so only battle units are hit.
    - Option B: **Point check** over units in `Unit_Parent` (e.g. compare distance or use a small Area2D/collision).
  - If a unit is found, "select" it: e.g. emit a signal `unit_selected(unit)` or call a method on the unit; update UI or battle state as needed.
- Call this **only** from the coordinator when state is **BATTLE_ACTIVE** and the click is in the game area.

### Step 5: Camera / viewport input

- **viewport.gd** uses **`_input()`** for zoom and pan. For **left/right click** (and other actions used by GUI/BattleManager), **do not** call `get_viewport().set_input_as_handled()` so that those events can still become unhandled and reach the coordinator.
- Only mark as handled for **scroll** and **middle mouse** (and any other camera-only actions) so that gameplay clicks always have a chance to reach `_unhandled_input`.

### Step 6: BoardSlot / BoardUI and "mouse_over"

- Placement logic currently uses **`BoardSlot.mouse_over`** (from `mouse_entered` / `mouse_exited`). Those signals are only emitted when the Control actually receives mouse events. With **BoardSlot** set to **IGNORE**, it may **not** receive enter/exit, so `mouse_over` could stay false.
- **Fix**: Either:
  - **A)** Keep **BoardSlot** (and BoardUI) as **STOP** so they still get enter/exit and `_gui_input`; then in **BoardSlot** (or BoardUI) **do not** call `accept_event()` on the click — so the event propagates up and eventually becomes unhandled and the coordinator still gets it (in Godot, if a Control doesn't accept, the event goes to parent; if the root of that branch doesn't accept, the event can become unhandled).  
    **Or**
  - **B)** Set BoardSlot to IGNORE and **stop relying on `mouse_over`** for placement: in **`gui.handle_game_area_click(event)`**, compute the hovered cell from **event position** (e.g. transform to board space and derive the cell index), and use that instead of `_get_target_cell()` that depends on `mouse_over`. Option B is more robust when using a coordinator.

Recommendation: **Option B** — compute cell from event position in `handle_game_area_click()` so placement works even when BoardSlots use IGNORE and never receive mouse enter/exit.

## Summary Checklist

- [x] Set root **Gui** to `MOUSE_FILTER_IGNORE`; keep Inventory, SpellBar, End_Prep, etc. as **STOP** (verify Passthrough_Helper or scene).
- [x] Set **BattleManager** (and BoardUI/BoardSlot if needed) to **IGNORE** so game-area clicks are not consumed.
- [x] Add **Input Coordinator** as dedicated child of **GameStateManager**: **`_unhandled_input(event)`** → if not over UI, call `gui.handle_game_area_click(event)` in prep or `battle_manager.handle_unit_click(event)` in battle; then `set_input_as_handled()`.
- [x] Refactor **GUI**: move placement/removal from **`_gui_input()`** into **`handle_game_area_click(event)`**; use event position and board-to-world math instead of relying on `mouse_over` if BoardSlots are IGNORE.
- [x] Implement **BattleManager.handle_unit_click(event)** (screen → world, find unit, select).
- [x] In **viewport.gd**, only mark zoom/pan as handled; leave left/right click unhandled so coordinator can see it.
- [ ] Test: UI buttons/slots still work; placement and removal work in prep; unit selection works in battle; camera zoom/pan still work.

This gives a single path for game-area input and lets both GUI (placement) and BattleManager (unit selection) be driven without competing for `_gui_input` or `_unhandled_input`.

---

## Implementation Results (Refactor Summary)

### 1. InputCoordinator (dedicated child node)

- **Scene**: `Manager/game_state_manager.tscn` — added node **InputCoordinator** as first child of GameStateManager.
- **Script**: `Manager/input_coordinator.gd`
  - Gets `gui` and `battle_manager` from parent (`UICanvas/Gui`, `BattleManager`). Uses parent's `current_state` and `GameState` enum.
  - **`_unhandled_input(event)`**: only handles `InputEventMouseButton` (pressed). Uses `gui.is_mouse_over_ui_element(mouse_pos)` to skip UI; then delegates by state: **BATTLE_PREPARATION** → `gui.handle_game_area_click(event)`; **BATTLE_ACTIVE** → `battle_manager.handle_unit_click(event)`. Calls `get_viewport().set_input_as_handled()` after delegating.

### 2. GUI refactor (Fix B — transformed coordinates)

- **`handle_game_area_click(event)`** (new): entry for game-area clicks from the coordinator. Converts **event.position** to **world** via `get_viewport().get_canvas_transform().affine_inverse() * event.position` so placement/removal work with **pan and zoom**. Gets the cell under the click with **`_get_cell_at_world_position(world_pos)`** (no `mouse_over`).
- **`_get_cell_at_world_position(world_pos: Vector2) -> BoardSlot`** (new): board-local position from `world_pos - unit_board.global_position`, then tile index `(tile_x, tile_y)` and child index `tile_x + tile_y * width`; returns that BoardSlot or null. All math in world space so it respects camera transform.
- **`_get_object_cells_for_anchor(anchor_cell: BoardSlot) -> Array`** (new): returns cells covered by the current unit placement with top-left at `anchor_cell`, using **world-space rect** (`anchor_cell.global_position` + placement size in cell size). Cells sorted so **objectCells[0]** is top-left (for `_place_unit()`).
- **`check_cell()`**: now uses **`_get_world_mouse_position()`** and **`_get_cell_at_world_position(world_mouse)`** instead of `DisplayServer.mouse_get_position()` and `_get_target_cell()` (mouse_over). Hover preview is correct with pan/zoom.
- **`_get_object_cells()`**: now returns `_get_object_cells_for_anchor(targetCell)` when `targetCell` is set, so existing preview logic still works.
- **`_gui_input()`**: no longer does placement/removal; left as no-op (coordinator calls `handle_game_area_click`).

### 3. Mouse filters

- **BattleManager** (`Manager/battle_manager.gd`): in **`post_ready()`**, `set_mouse_filter(Control.MOUSE_FILTER_IGNORE)`.
- **BoardUI** (`Manager/battle_manager_components/BoardUI.gd`): in **`post_ready()`**, `set_mouse_filter(Control.MOUSE_FILTER_IGNORE)`.
- **BoardSlot** (`Manager/battle_manager_components/BoardSlot.gd`): in **`_ready()`**, `set_mouse_filter(Control.MOUSE_FILTER_IGNORE)`.
- **Gui root**: continues to use **Passthrough_Helper** (target = Gui); root Control is generic so it gets **MOUSE_FILTER_IGNORE**; Inventory, SpellBar, End_Prep, etc. remain **STOP** via the helper.

### 4. BattleManager unit click handling

- **`handle_unit_click(event: InputEvent)`** (new): converts **event.position** to world with `get_viewport().get_canvas_transform().affine_inverse() * event.position`. Finds units in `Unit_Parent` within **UNIT_PICK_RADIUS** (80 px) of that world position; picks closest. Emits **`unit_selected(unit: Base_Unit)`**.
- **Signal**: `signal unit_selected(unit: Base_Unit)` added for other systems (e.g. UI) to react to selection.

### 5. Viewport

- **`Manager/viewport.gd`**: **`_input()`** now calls **`get_viewport().set_input_as_handled()`** only for: scroll_up/scroll_down, middle_mouse press/release, and **InputEventMouseMotion** while panning. Left/right click are never marked handled so they reach the coordinator as unhandled.

### 6. BoardSlot and mouse_over

- **Fix B** used: BoardSlots use **MOUSE_FILTER_IGNORE** and no longer drive placement via `mouse_over`. Cell under cursor is computed from **event position → world position → board tile** in `_get_cell_at_world_position()` and `handle_game_area_click()`. `mouse_entered` / `mouse_exited` on BoardSlot remain for any future use but are not required for placement.

---

## Evaluation: Is Passthrough_Helper Still Necessary?

**Short answer: No.** The new input framework only *requires* that the root Gui and any full‑coverage containers (Inventory panel, SpellBar) use `MOUSE_FILTER_IGNORE` so game-area clicks reach the InputCoordinator. That can be done with a few explicit lines; the helper is no longer strictly necessary.

### What the coordinator needs

- For **unhandled** clicks to reach the InputCoordinator, no Control on the GUI canvas layer must consume the event when the click is in the "game" area.
- So the **root Gui** (full-screen Control) must be **IGNORE**. (Godot's default for Control is **STOP**, which would block all clicks.)
- Clicks on real UI (buttons, slots) should still be received by those controls (**STOP** on them is fine).

### What Passthrough_Helper does today

- Recursively sets **mouse_filter** on the Gui and every descendant:
  - Root Gui (generic Control) → **IGNORE**
  - Buttons, etc. → **STOP**
  - Containers, Panel, Label, etc. → **IGNORE**
- So it both makes the root pass-through and forces a consistent policy for the whole tree.

### What is actually required

| Node | Required filter | Why |
|------|------------------|-----|
| **Gui (root)** | IGNORE | So clicks on "empty" screen are not consumed and reach `_unhandled_input` (coordinator). |
| **Inventory (Panel)** | IGNORE | So when the inventory is open, clicks on panel background (not on a slot) pass through; slots set their own STOP/IGNORE in code. |
| **SpellBar (GridContainer)** | IGNORE | So clicks on empty spell-bar area pass through; individual slots receive their own input. |
| **End_Prep (Button)** | STOP | Default for Button; no change needed. |
| **InventorySlot** | Set in script | Already sets STOP/IGNORE in `InventorySlot.gd` by state. |

So the *minimum* needed for the new framework is:

1. **Root Gui** → IGNORE (e.g. in `GUI.gd` `_ready()`).
2. **Inventory** (Panel) → IGNORE (e.g. in `Inventory.gd` `_ready()`).
3. **SpellBar** (GridContainer) → IGNORE (e.g. in `spell_bar.gd` `_ready()`).

No recursive tree walk is required.

### Recommendation

- **Option A — Keep Passthrough_Helper**  
  Keeps one place that defines "pass-through policy" for the whole GUI tree. Helpful if you add more panels/containers later and want them to default to IGNORE without touching each script. Slight cost: extra node, recursive setup, and debug prints.

- **Option B — Remove Passthrough_Helper**  
  Set the three filters above explicitly in `GUI.gd`, `Inventory.gd`, and `spell_bar.gd`. Simpler, no helper node, and the intent is local to each scene. When adding new UI, remember to set IGNORE on any new full‑coverage container so it doesn't block game-area clicks.

**Verdict:** Passthrough_Helper is **not necessary** for the new framework. You can remove it and set root Gui + Inventory + SpellBar to IGNORE in code, or keep it as a centralized, defensive policy for the whole GUI tree.
