# Tactical cursor & unit stats — technical summary

## 1. Project overview

- **Goal:** Surface unit combat stats without per-frame hover queries; support selection in deployment and combat; show damage dealt and optional world health bars; show **active status effects** (icons + duration + stacks) for the selected unit.
- **Stack:** Godot 4.4, `Base_Unit`, `BattleManager`, `GUI` (`UICanvas/Gui`), `InputCoordinator`, `TacticalCursor` scene, `StatusEffectBox`.

## 2. Final architecture

- **`UI/TacticalCursor.tscn` + `UI/tactical_cursor.gd`**
  - Root `Control` full-screen; bottom-right **`TacticalCursorStack`** (`VBoxContainer`): **top** = **`StatusEffectsRow`** (`HBoxContainer`, right-aligned), **below** = **selected-unit panel** (`PanelContainer`).
  - **Selected-unit panel:** sprite (`TextureRect` from `AnimatedSprite2D` current frame) + labels (HP, damage/shot, reload, movement, damage dealt).
  - **Status effects row:** For each active effect on the selected unit, one **`StatusEffectBox`** (`UI/StatusEffectBox.tscn` + `UI/status_effect_box.gd`): effect icon, bottom-anchored semi-transparent **duration overlay** (`duration_fraction`), optional **stack label** (`xN` if stacks > 1). Boxes are keyed by `instance_key` from `Base_Unit.get_active_status_effects_for_ui()`; row updates every `_process` while a unit is selected (add/remove/sync).
  - No hover tooltip; no `show_unit()` API.
- **`Manager/battle_manager.gd`**
  - `UNIT_PICK_RADIUS` proximity pick in `get_unit_under_cursor(world_pos)`.
  - `handle_unit_click(event)` uses **only** `get_unit_under_cursor` (no duplicate loop).
  - Signals: `unit_selected(unit: Base_Unit)`, `battle_ended(victory)`.
- **`UI/GUI.gd`**
  - `battle_manager.unit_selected` → `tactical_cursor.set_selected_unit(unit)`.
  - `battle_manager.battle_ended` → `tactical_cursor.set_selected_unit(null)`.
  - `_update_tactical_cursor()`: if `not battle_manager.visible`, `set_selected_unit(null)` (map screen).
  - **Deployment:** `handle_game_area_click`: on **left click**, if `get_unit_under_cursor(world_pos)` returns a unit → `set_selected_unit(unit)` and **return** (no placement); else normal board placement/removal.
- **`Utilities/Base_Unit.gd`**
  - `total_damage_dealt`, `add_damage_dealt(amount)`, `get_attack_stats()` (first `Attack_Base` child + `Attack_CD.wait_time`).
  - Status system: `apply_status_effect`, `get_active_status_effects_for_ui()` → array of dicts (`instance_key`, `display_name`, `stacks`, `remaining`, `duration_fraction`, `icon`) for the tactical row. See `.cursor/docs/systems/status-effects.md`.
- **Damage attribution:** `Units/.../basic_ranged.gd`, `basic_melee.gd`, `Utilities/Base_projectile.gd` call `add_damage_dealt` when applying damage.
- **Health bar:** `Utilities/unit_health_bar.gd` child on `Utilities/Base_Unit.tscn` (`HealthBar` `Node2D`); `_draw` bar; `visible` only when `curr_hp < max_hp`.

## 3. Key decisions & rationale

- **No hover + no per-frame `get_unit_under_cursor` in GUI** — pick cost only on click (deployment left-click or `handle_unit_click` in battle).
- **Selected panel updates:** selection changes on click / unit death / battle end / leaving battle view; label refresh each `_process` while a unit is selected so HP, damage dealt, and **status effect row** stay live.
- **Status UI:** Icon row driven by polled `get_active_status_effects_for_ui()` (not a separate popup signal) so the tactical window always mirrors current buff/debuff state.
- **Deployment selection before cell logic** — avoids placing when clicking an existing unit.
- **End prep button** — anchored top-right (`GUI.tscn` `End_Prep`) so it stays out of the board area.

## 4. Implemented features / progress

- Selected-unit stats panel with sprite and five stat lines.
- **Status effects strip:** dynamic `StatusEffectBox` instances above the panel when the unit has active effects.
- Deployment-phase unit selection for stats (left-click placed unit).
- Combat-phase unit selection via existing `handle_unit_click` → `unit_selected`.
- Cumulative `total_damage_dealt` with tracking on direct attacks and projectiles.
- World-space health bars after first damage.

## 5. Open problems / TODOs

- **N/A** from this thread (no explicit backlog).

## 6. Important context for continuation

- `InputCoordinator` still routes `BATTLE_PREPARATION` → `GUI.handle_game_area_click`, `BATTLE_ACTIVE` → `BattleManager.handle_unit_click`; UI blocking uses `GUI.is_mouse_over_ui_element`.
- `get_unit_under_cursor` is the single proximity query; keep call sites limited to click paths unless a new feature needs hover again.
- `curr_hp` can become non-integer after `take_damage` (multipliers); health bar uses `float` ratio.
- **`set_selected_unit(null)`** clears the status-effect boxes (`_clear_status_effect_boxes`).

## 7. Useful snippets / patterns

- **Pick unit (world space):** `battle_manager.get_unit_under_cursor(vp.get_canvas_transform().affine_inverse() * event.position)` — see `battle_manager.gd` `handle_unit_click`, `GUI.gd` `handle_game_area_click`.
- **Sprite for panel:** `sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)` — `tactical_cursor.gd` `_get_unit_sprite_texture`.
- **Attack stats:** `Base_Unit.get_attack_stats()` → `damage`, `reload_time` from `Attack_Base` child.
- **Status row data:** `Base_Unit.get_active_status_effects_for_ui()` → `tactical_cursor._refresh_status_effect_boxes`; **`StatusEffectBox.set_effect(data)`** — `UI/status_effect_box.gd`.
