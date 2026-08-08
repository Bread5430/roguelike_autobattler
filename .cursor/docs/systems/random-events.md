# Random Events — technical summary

## Overview

Data-driven random events on map `RANDOM_EVENT` nodes. CSV defines event flavor + choice buttons; `RandomEventControl` picks an event, validates exchanges, and applies costs/rewards. `RandomEventUI` shows image (left), flavor text (top-right), choice buttons (bottom-right).

## Components

| Component | Path | Role |
|-----------|------|------|
| `RANDOM_EVENT_DATA` | `LookUps/random_event_data.gd` (autoload) | Loads `Data/random_events.csv` + `Data/random_event_choices.csv` |
| `RandomEventControl` | `Manager/random_event_control.gd` | Weighted event pick, payload build, `try_resolve_choice` |
| `RandomEventUI` | `UI/random_event_ui.gd`, `UI/RandomEventUI.tscn` | Modal layout + dynamic choice buttons |
| `GameStateManager` | `Manager/game_state_manager.gd` | `event_visit_active`, `open_event_visit` / `end_event_visit` |
| `GUI` | `UI/GUI.gd` | `open_random_event` / `close_random_event`, toggle button, input blocking |

## Control flow

1. Player selects `RANDOM_EVENT` map node → `_enter_random_event_node` → `open_event_visit()`.
2. `RandomEventControl.build_event_payload(node)` — weighted pick among events with `min_stage <= node.stage`.
3. `GUI.open_random_event(payload)` — inventory disabled, map input blocked, event UI shown.
4. Player picks a choice → `try_resolve_choice` — cost then reward.
5. On success → `end_event_visit()` — complete node, close UI, return to map exploration.
6. While deliberating: **Hide Event** / **Show Event** toggle (panel only); map and other UI stay non-interactive until a choice is made.

## CSV schema

**`Data/random_events.csv`:** `event_id`, `title`, `flavor_text`, `image_path`, `weight`, `min_stage`, `event_type` (`exchange` \| `quest` \| `encounter`)

**`Data/random_event_choices.csv`:** `event_id`, `choice_id`, `label`, `cost_kind`, `cost_amount`, `cost_filter`, `reward_kind`, `reward_amount`, `reward_item_id`, `reward_pool`

Quest-specific CSVs and mark lifecycle: `.cursor/docs/systems/quest-events.md`.

### Cost kinds (v1)

| kind | Notes |
|------|-------|
| `none` | Free choice |
| `gold`, `components` | Run currency via GSM |
| `health` | `cost_amount` = percent of max HP (e.g. 25 = 25%) |
| `inventory_random` | Remove 1 random owned item; `cost_filter`: `unit`, `spell`, `any` |

### Reward kinds (v1)

| kind | Notes |
|------|-------|
| `none` | No reward (e.g. walk away) |
| `gold`, `components`, `health` | Same units as costs |
| `item` | Fixed `reward_item_id` |
| `item_random` | `reward_pool`: `shop_units` or `shop_spells` (uses `ShopControl` pools) |

Buttons disable when the player cannot afford the cost.

## Runtime payload

```gdscript
{
  "event_id": "scrap_dealer",
  "title": "Scrap Dealer",
  "flavor_text": "...",
  "image_path": "res://...",
  "choices": [
    {
      "choice_id": "pay_gold",
      "label": "Pay 75 gold for a random spell",
      "cost_kind": "gold", "cost_amount": 75,
      "reward_kind": "item_random", "reward_pool": "shop_spells",
      "enabled": true
    }
  ]
}
```

## Adding a new event

1. Add row to `Data/random_events.csv`.
2. Add one or more rows to `Data/random_event_choices.csv`.
3. Restart game (autoload reload).

## Input / UX

- Map node switching blocked while `event_visit_active` (must resolve event first).
- Unlike shop/rest, hiding the event panel does **not** re-enable map clicks — `_sync_event_map_input` always blocks map input during the visit.
- Leaving a random event without a trade/reward is only possible when the event defines a neutral choice (`cost_kind=none`, `reward_kind=none`, e.g. blood_altar "Walk away"). Events without such a choice require picking one of the offered options.
- Shop and rest allow leaving without purchases/repairs via **Leave** or by clicking another map node; map input stays enabled during those visits.
- Extend `GUI.is_mouse_over_ui_element` for event UI + toggle button (same pattern as shop/rest).

## Follow-ups (not v1)

- `inventory_pick` cost — player chooses which item to trade (Rest craft overlay pattern).
- Event dedup / prerequisites / chains across a run.
- `{cost}` / `{reward}` label placeholder expansion.
- Save/load in-progress event state.

## Related docs

- `.cursor/docs/systems/quest-events.md` — quest marks, encounters, exclusive siblings
- `.cursor/docs/data-flow.md` — map exploration
- `.cursor/docs/systems/battle-rewards-ui.md` — modal payload pattern
- `.cursor/docs/input-coordination-plan.md` — mouse_filter, Passthrough_Helper
