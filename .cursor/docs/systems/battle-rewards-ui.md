# Battle Rewards UI — technical summary

## Project overview

- **Goal:** Modal post-victory rewards window after battle win; player claims rewards before returning to map.
- **Constraints:** Top-level UI must block clicks from reaching lower layers; instant rewards (gold) vs submenu rewards (pick 1 of 3 units); repair-damage display with unresolved value as TODO stub.
- **Stack:** Godot 4.4; `GameStateManager` state machine; `GUI` on `UICanvas` CanvasLayer; existing `Passthrough_Helper`, `InputCoordinator`, `Inventory`, `ITEM_NAME`, `UNIT_GLOSSARY`.

## Final architecture

**Components**

| Component | Path | Role |
|-----------|------|------|
| `BattleRewardsUI` | `UI/battle_rewards_ui.gd`, `UI/BattleRewardsUI.tscn` | Modal UI: victory header, repair line, reward buttons, unit-choice submenu |
| `GUI` | `UI/GUI.gd` | `show_battle_rewards(payload)` async facade; wires gold/unit callbacks; hit-test for input coordinator |
| `GameStateManager` | `Manager/game_state_manager.gd` | Builds payload, `await gui.show_battle_rewards`, then `MAP_EXPLORATION` or `CAMPAIGN_COMPLETE` |
| `PlayerHealthManager` | `Manager/player_health_manager.gd` | Battle-start health snapshot; `get_repair_damage_taken_this_battle()` stub |

**Control flow**

1. `BattleManager.battle_ended(true)` → `GameStateManager._on_battle_ended` → `change_state(BATTLE_COMPLETE)`.
2. `handle_battle_completion()`: `map_generator.complete_current_battle()` → `calculate_battle_rewards()` → `await gui.show_battle_rewards(payload)`.
3. `BattleRewardsUI.open(payload)`: show modal, `Passthrough_Helper.block_input()`, `await rewards_closed`.
4. Player claims rewards (instant gold and/or unit submenu) or skips unclaimed entries.
5. **Continue** → `close()` → `rewards_closed` → GSM nulls `current_battle_node` → map or campaign-complete state.

**Scene tree (under `Gui`)**

```
BattleRewardsUI (Control, full-screen, MOUSE_FILTER_STOP)
├── Backdrop (ColorRect, STOP, accept_event on click)
├── MainPanel (PanelContainer, centered)
│   └── VictoryLabel, RepairDamageLabel, RewardList (dynamic), CloseButton
└── SubmenuOverlay (Control, full-screen, STOP)
    ├── SubmenuBackdrop (STOP, accept_event)
    └── SubmenuPanel → UnitOptions (3 buttons), SubmenuCloseButton ("Back")
```

## Key decisions & rationale

- **Await UI close instead of 2s timer:** Map transition gated on player dismissing rewards; supports optional/unclaimed rewards without auto-skipping interaction.
- **Payload `entries` array with `kind`:** Extensible model — `"instant"` (one-click gold) vs `"unit_choice"` (submenu); each entry has `id`, `label`, `claimed`.
- **Gold applied via signal, not in GSM at build time:** `instant_gold_claimed` → `GUI._on_battle_reward_gold_claimed` → `GameStateManager.add_gold`; only claimed gold counts toward `run_gold`.
- **Unit pool from `ITEM_NAME.unit_role_map`:** Exclude paths containing `"Spells/"`; also skip `Unit_Card.enemy_formation_only` cards. Shuffle, take 3; pad with duplicates if pool &lt; 3.
- **Display names via `ItemDetailsBuilder`:** Unit submenu labels use same glossary path as inventory inspection (`Unit_Card` → glossary display name).
- **Dual click blocking:** Full-screen `MOUSE_FILTER_STOP` on root/backdrops/panels + `Passthrough_Helper.block_input()` on open / `unblock_input()` on close; `GUI.is_mouse_over_ui_element` includes rewards rect so `InputCoordinator` skips game-area delegation.
- **Repair damage stub on `PlayerHealthManager`:** Factory HP syncs to player health via `FactoryUnit.take_damage`; snapshot at battle start reserved for future repair-cost formula; UI shows `0` until implemented.

## Implemented features / progress

- Victory modal with "Victory!" blurb and "Repair damage: N" line.
- Dynamic reward list from payload `entries`.
- Instant gold reward: button disables, label suffix `(claimed)`, increments `run_gold`.
- Unit choice submenu: 3 random recruitable units, pick adds to `Inventory`, Back returns to main menu without claiming.
- Main **Continue** closes modal and resumes campaign flow.
- `run_gold` on `GameStateManager`; reset on `start_new_campaign()`.
- `snapshot_health_for_battle()` called in `start_battle_sequence()`.
- Inventory blocked while modal open (`toggle_inventory(false)`); re-enabled in `enter_map_exploration()`.
- Dev test: `GameStateManager.force_battle_victory()` during `BATTLE_ACTIVE`.

## Open problems / TODOs

- **`PlayerHealthManager.get_repair_damage_taken_this_battle()`:** Returns `0`; `_health_snapshot_at_battle_start` stored but unused — implement factory/repair damage math.
- **No run-gold HUD:** Gold accumulates in `run_gold` only; no UI display yet.
- **`award_battle_rewards()`:** Deprecated no-op; safe to remove later.
- **Campaign end:** Rewards UI shows before `CAMPAIGN_COMPLETE`; dedicated campaign victory screen still TODO elsewhere.
- **Experience reward:** Removed from old flat dict; not in current payload.

## Important context for continuation

- Rewards UI lives on `UICanvas/Gui`; must stay last or high in tree for draw/input priority.
- Unclaimed rewards are forfeited on **Continue** — by design.
- Submenu **Back** does not mark unit reward claimed; player can reopen until they pick or close main window.
- `BATTLE_COMPLETE` runs `handle_battle_completion()` synchronously from `change_state`; async `await gui.show_battle_rewards` blocks until modal closes.
- Battlefield cleared before rewards show (`_on_battle_ended` calls `clear_battlefield`); modal backdrop still required for any residual input paths.
- Adding new reward kinds: extend `BattleRewardsUI._on_reward_button_pressed` match + payload schema in `calculate_battle_rewards()`.

## Useful snippets / patterns

**Reward payload shape**

```gdscript
{
  "entries": [
    { "id": "gold", "kind": "instant", "label": "Collect gold (+150)", "gold": 150, "claimed": false },
    { "id": "unit_pick", "kind": "unit_choice", "label": "Recruit a unit", "options": ["sniper_card", ...], "claimed": false }
  ]
}
```

**Public API**

- `GUI.show_battle_rewards(payload: Dictionary) -> void` — async; awaits close.
- `BattleRewardsUI.open(payload)` / `close()` — signals: `rewards_closed`, `instant_gold_claimed(amount)`, `unit_picked(item_id)`.
- `GameStateManager.add_gold(amount)`, `calculate_battle_rewards()`, `run_gold`.

**Gold scaling** (`calculate_battle_rewards`): base 100; ×1 / ×1.5 / ×2 by difficulty; `+ stage * 10`.

**Input:** Extend `GUI.is_mouse_over_ui_element` when adding other full-screen modals; mirror `block_input` / `unblock_input` pattern from `ItemDetailsCard` / `Passthrough_Helper`.

**Related docs:** `.cursor/docs/data-flow.md` (post-battle), `.cursor/docs/input-coordination-plan.md` (mouse_filter, coordinator).
