# Battle speed control & soft pause — technical summary

## 1. Project overview

- **Goal:** Battle-phase UI with four modes — soft pause, 1×, 2×, 4× — that scales all combat simulation (units, Timers/cooldowns, status durations, animations) while leaving UI fully interactive.
- **Constraints:** Must not reuse `PauseMenu` / `get_tree().paused` (full pause). Soft pause freezes combat only; spell casting UX must still work and buffer world effects until resume. Reset speed on battle exit.
- **Stack:** Godot 4.4; existing `Engine.time_scale` already exposed via `Testing/dev_console.gd` (`timescale`); combat uses `_physics_process(delta)`, `Timer` (`Attack_CD`, projectile `Lifetime`, etc.), `AnimationPlayer`, status ticks on `Base_Unit`.

## 2. Final architecture

### Components

| Piece | Responsibility |
|-------|----------------|
| `BattleSpeedController` (`Manager/battle_manager_components/battle_speed_controller.gd`, child of `BattleManager`) | Owns combat rate (`0` / `1` / `2` / `4`), applies/restores `Engine.time_scale`, soft-pause query, **spell effect buffer**, `combat_speed_changed(rate)`. |
| `BattleSpeedBar` (`UI/BattleSpeedBar.tscn`, under `GUI`) | Four mutually exclusive controls (pause / 1× / 2× / 4×) + Space/comma/period hotkeys. Visible only in `BATTLE_ACTIVE`. |
| `GUI` casting path | Soft-paused confirm: consume SpellBar slot; enqueue world `cast()` until resume (`_commit_spell_cast`). |
| `PauseMenu` (existing) | Unchanged: `get_tree().paused = true` + `PROCESS_MODE_ALWAYS`. Orthogonal to soft pause. |

### Control flow — speed change

1. Player presses a speed button (or optional hotkeys).
2. `BattleSpeedController.set_combat_speed(rate)` stores `rate`, sets `Engine.time_scale = rate` (use `1.0` when leaving battle even if last rate was 0).
3. Listeners refresh button pressed state via `combat_speed_changed`.
4. On `BattleManager.end_battle`: `reset()` → `Engine.time_scale = 1.0`, clear spell buffer **without flush**.

### Control flow — soft pause vs full pause

| | Soft pause (speed bar) | Full pause (`PauseMenu`) |
|--|------------------------|---------------------------|
| Mechanism | `Engine.time_scale = 0` | `get_tree().paused = true` |
| Combat (units, Timers, status `remaining_time`, animations) | Frozen (delta/Timers stop) | Frozen |
| Battle UI (spell bar, tactical cursor, speed bar) | Fully interactive | Frozen unless `PROCESS_MODE_ALWAYS` (PauseMenu only) |
| Esc / PauseMenu | Still opens full pause on top | Closes and unpauses tree; soft-pause rate remains 0 if it was set |

Invariant: never set `get_tree().paused` from the speed bar.

### Why `Engine.time_scale` (not a custom combat delta)

Combat already advances via scaled engine time:

- `Base_Unit._physics_process` → `_process_status_effects(delta)` (`remaining_time`, DoT ticks).
- `Attack_Base` / projectiles / hitboxes: `Timer` nodes (`Attack_CD`, `Lifetime`, `HitboxActiveTimer`, `visble_time`).
- FSM: `AnimationPlayer` playback.
- `BattleManager._physics_process`: target snapshot refresh while `manager_timer` runs.
- Spell field nodes (aura/slow) that tick in `_process` / `_physics_process`.

`Engine.time_scale` scales all of the above without per-system multipliers. Dev console `timescale` proves the path; battle UI should own the value during `BATTLE_ACTIVE` and reset on exit so map/prep are never left at 2×/4×/0.

**Avoid** driving soft pause via `get_tree().paused` — that is reserved for PauseMenu / loss screen and would require `PROCESS_MODE_ALWAYS` on all battle UI + InputCoordinator.

### Spell casting while soft-paused

Existing path (`UI/GUI.gd` `_input` in casting mode):

1. Preview still runs in `_process` (works at `time_scale == 0`; mouse-follow only).
2. Confirm click:
   - Staged spells (`handles_casting_input()` → `on_casting_click`): honor `consume_spell` / `exit_casting` for **UI**.
   - Simple spells: today call `spell_inst.cast(world_pos)` then `spell_bar.remove_spell_at`.
3. **When soft-paused:** do **not** apply world side effects yet.

**Buffer contract:**

```
BufferedCast = {
  spell_ref or Callable to apply,  # prefer capturing spell instance + args before free
  world_pos: Vector2,
  kind: "simple" | "staged_commit",
  # staged: any extra payload the spell needs if cast() alone is insufficient
}
```

Recommended wiring:

1. Add `BattleSpeedController.is_soft_paused() -> bool` (`combat_speed <= 0.0`).
2. Add `queue_spell_effect(callable)` / typed buffer entry; on resume (`set_combat_speed` from 0 → >0), **flush FIFO** before or after raising `time_scale` (flush **after** setting scale > 0 so effect `_ready`/Timers start at the new rate).
3. In `GUI` confirm path:
   - Always perform UI: `remove_spell_at`, `_exit_casting_mode`, staged consume flags.
   - If soft-paused: wrap the world apply (`cast` / final staged commit body) into the buffer; spell instance must stay alive until flush **or** buffer stores enough data to re-apply without the node (prefer keep instance reparented/hidden under a buffer holder so `battle_manager` refs remain valid).
4. Staged spells (see `.cursor/docs/systems/beacon-spell-fsm.md`): clicks 1–2 and preview stay live during soft pause; only the **final commit** (`consume_spell` / path that calls `BeaconController.register_beacon` / status apply) is buffered. Partial click state stays on the spell until commit or cancel.
5. Cancel (`rightClick` / `ui_cancel`) during soft pause: clear preview via existing `_exit_casting_mode` / `on_casting_cancel`; do not enqueue.

Visual “spell has been cast”: slot already removed from `SpellBar` (current consume behavior). Optional: brief cast VFX on UI layer that uses unscaled time (`AnimationPlayer` with custom process or CanvasItem shader) — not required for v1 if bar removal is enough.

### Audio (future — not implemented yet)

When SFX/music exist for combat:

- Prefer tying playback rate to the same source of truth as visuals: on `combat_speed_changed`, set `AudioStreamPlayer.pitch_scale` (and/or bus effect) to `max(combat_speed, ε)` for combat voices; **mute or pause** combat audio when soft-paused (`speed == 0`) instead of pitch 0.
- Do **not** rely on `Engine.time_scale` alone for audio — Godot does not globally pitch all audio with `time_scale`; each player (or a small `CombatAudio` helper subscribed to `BattleSpeedController`) must apply pitch/pause.
- UI/menu sounds should ignore combat speed (leave pitch at 1.0; they already sit under PauseMenu / UICanvas).
- Reset pitch scales in `BattleSpeedController.reset()` with `Engine.time_scale`.

## 3. Key decisions & rationale

- **`Engine.time_scale` for 1×/2×/4×/0** — one lever covers Timers, physics delta, AnimationPlayers; matches existing console tooling; avoids hunting every `delta`/`wait_time` site.
- **Soft pause ≠ `get_tree().paused`** — preserves spell bar, casting `_input`, tactical cursor, speed bar, and InputCoordinator without blanket `PROCESS_MODE_ALWAYS`.
- **Spell world effects buffered; UI commit immediate** — satisfies “show cast, delay effect” without keeping false-full spell slots.
- **Speed bar only in `BATTLE_ACTIVE`** — prep/map stay at 1.0; no accidental slowed map camera tweens.
- **PauseMenu stacks above soft pause** — Esc still opens options/save; closing full pause returns to whatever soft rate was selected (often still paused at 0).

## 4. Implemented features / progress

- `BattleSpeedController` on `BattleManager` (`Manager/battle_manager_components/battle_speed_controller.gd`): rates `0/1/2/4`, soft-pause helpers, spell retain/buffer/flush, `reset()` clears without flush.
- `BattleSpeedBar` (`UI/BattleSpeedBar.tscn`): pause / 1× / 2× / 4× buttons; shown only in `BATTLE_ACTIVE` via `GUI.show_battle_speed_bar()` / `hide_battle_speed_bar()`.
- Hotkeys: `battle_speed_pause` (Space), `battle_speed_slower` (comma), `battle_speed_faster` (period) — handled on the bar when visible; skipped when `get_tree().paused`.
- Soft-pause cast path: `SpellBar.detach_spell_at` + `GUI._commit_spell_cast` buffers `cast()` until resume.
- Beacon: final world apply moved to `cast()` via `_pending_path`; `on_casting_click` only validates/stores.

## 5. Open problems / TODOs

- Future: combat audio pitch/pause hook (section 2).
- Console `timescale` mid-battle does not sync bar pressed state (bar listens only to controller signal).
- UI tweens that feel wrong at 4× are rare; address case-by-case if needed.

## 6. Important context for continuation

- **Invariant:** Speed bar never calls `get_tree().paused`.
- **Invariant:** Leaving battle always restores `Engine.time_scale = 1.0` and clears controller state (`end_battle` → `reset()`).
- **Invariant:** Soft-paused casts update SpellBar immediately; world `cast` / status / damage / beacon register only on flush.
- **Invariant:** Comma never soft-pauses (floor 1×); period from soft pause resumes at 1×; Space restores `_rate_before_pause`.
- **Gotcha:** `PauseMenu.open()` sets tree paused — soft-pause rate is preserved but UI under tree pause will not run until full pause closes.
- **Gotcha:** Buffered spells are reparented under `BattleSpeedController`’s holder; battle `reset()` frees them without flush.
- **Gotcha:** Staged beacon commits must go through `cast()` so soft-pause buffering stays unified with simple spells.
- **Refs:** `UI/GUI.gd` `_commit_spell_cast`; `UI/spell_bar.gd` `detach_spell_at`; `Spells/spell_cards/beacon/beacon_spell.gd`; input actions in `project.godot`.

## 7. Useful snippets / patterns

**Controller helpers:** `set_combat_speed`, `toggle_soft_pause`, `step_slower`, `step_faster`, `retain_spell`, `queue_spell_effect`, `reset`.

**GUI soft-pause commit:** `GUI._commit_spell_cast` — retain + detach + queue when soft-paused; else `cast` + `remove_spell_at`.

**UI placement:** `GUI` child bottom-right; show on `GameStateManager.start_battle_sequence`; hide on prep/map/battle end.
