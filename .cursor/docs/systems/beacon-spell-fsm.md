# Beacon Spell FSM — technical summary

## 1. Project overview

- Goal: add a 3-click beacon spell that assigns nearby allies to follow a path while preserving combat behavior.
- Constraints: beacon path must persist through battle; assignment gate is selected ally near path start; movement must pause under panic proximity.
- Stack/tools: Godot 4.4 GDScript; `Base_Spell`, `BeaconController`, `TargetManager`, unit `FSM`, `Base_Unit` status system.

## 2. Final architecture

- `Spells/spell_cards/beacon/beacon_spell.gd` owns cast staging (`_confirmed`) and commits after exactly 3 clicks.
- `Manager/battle_manager_components/beacon_controller.gd` owns beacon runtime data: per-beacon path, per-unit assignment, waypoint index, panic cache, steering cache, preview line.
- `Utilities/status_effects/beacon_following_def.gd` marks beacon-following as a buff status.
- `Utilities/Base_Unit.gd` emits `beacon_status_changed(active)` when `beacon_following` first appears or fully disappears.
- `Utilities/Entity_Components/FSM.gd` listens to unit beacon signal and drives beacon state transitions event-first; also shares cached `beacon_move_vec`.
- Unit FSM templates (`melee`, `ranged`; `arc` path variant [assumed]) include dedicated `beaconed` state where units attack and move via `beacon_move_vec`.

Control/data flow:
1. Player selects spell and clicks 3 points.
2. `BeaconSpell` validates selected tactical unit + start-radius gate; gathers allies in radius.
3. `BeaconController.register_beacon(...)` applies `beacon_following` status and records path/indices.
4. `Base_Unit.apply_status_effect(...)` emits `beacon_status_changed(true)` on first beacon status.
5. FSM enters `beaconed`; each physics tick reads cached `beacon_move_vec` from targeting/beacon controller.
6. On remove/expiry (`remove_status_effect`, timed expiration, purge), `Base_Unit` emits `beacon_status_changed(false)`; FSM returns to march.

## 3. Key decisions & rationale

- Event-driven beacon FSM entry/exit over per-frame “is beaconed?” polling to reduce transition overhead and edge-case churn.
- Dedicated `beaconed` state instead of mixing branch logic into `march`/`attack`, making behavior easier to reason about.
- Steering and panic checks cached by physics frame and `target_iter` respectively to reduce repeated calculations.
- `TargetManager.get_targets(..., max_range=panic_radius)` used for panic checks to leverage existing tile/BFS caching.
- Beacon ownership modeled through status effects so removal/expiry semantics stay aligned with existing status infrastructure.

## 4. Implemented features / progress

- 3-click staged casting contract implemented through `Base_Spell` staged input hooks and beacon-specific click accumulation.
- Beacon path preview delegated to `BeaconController` (no direct preview ownership in spell script).
- Beacon registration/removal wired to `beacon_following` status application/removal.
- Panic-radius suppression integrated; `beacon_move_vec` collapses to zero when panic condition holds.
- Melee and ranged template FSMs include `beaconed` state and corresponding animations.

## 5. Open problems / TODOs

- `BeaconController.preview_path(...)` currently uses `self.to_local(...)`; if controller is not guaranteed to be `Node2D` in scene topology, convert using `battle_manager.unit_parent.to_local(...)` for consistency with AoE previews.
- Arc unit FSM template path appears absent in current workspace layout [assumed]; verify arc units inherit beaconed-state behavior.
- No explicit player cancel UX for active beacon route yet (only removal via status/clear paths).

## 6. Important context for continuation

- Invariant: FSM beacon transitions should remain signal-driven (`beacon_status_changed`) to avoid reintroducing per-frame assignment polling.
- Invariant: `beacon_move_vec` is shared cache data refreshed in base `FSM._physics_process`; per-state logic should consume, not recompute.
- Invariant: only emit `beacon_status_changed(true)` when beacon effect count transitions 0->1, and `false` on 1->0.
- Gotcha: status removal occurs from multiple paths (`remove_status_effect`, expiry loop, purge by polarity); all must preserve signal correctness.
- Gotcha: selected-unit gate in `beacon_spell.gd` uses tactical cursor; spell silently fails when no valid selection is present.

## 7. Useful snippets / patterns

- Event-driven status->FSM transition:
  - `Utilities/Base_Unit.gd`: `signal beacon_status_changed(active: bool)` + emits in status add/remove paths.
  - `Utilities/Entity_Components/FSM.gd`: connect in `_ready()`, switch states in `_on_beacon_status_changed`.
- Staged spell cast pattern:
  - `Utilities/Base_Spell.gd`: `handles_casting_input`, `on_casting_click`, `on_casting_cancel`.
  - `Spells/spell_cards/beacon/beacon_spell.gd`: append click points and commit only at size 3.
- Cached steering/panic:
  - `Utilities/Entity_Components/targetting_cmp.gd`: `begin_physics_tick()` and `get_cached_beacon_move_vec()`.
  - `Manager/battle_manager_components/beacon_controller.gd`: `_steer_cache_by_uid`, `_panic_cache_by_uid`, `_panic_cache_target_iter`.
