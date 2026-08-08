# Quest Events — technical summary

## Overview

Quest events are a `event_type=quest` variant of random events. Visiting a quest giver previews up to 3 marked map nodes, then **Accept** commits the marks or **Decline** reverts them. Visiting a marked node later opens an `event_type=encounter` reward UI (same `RandomEventUI` layout). Battle marks resolve **after** victory (and after normal battle rewards).

## Components

| Component | Path | Role |
|-----------|------|------|
| Quest CSVs | `Data/quest_defs.csv`, `Data/quest_targets.csv` | Quest flags + per-slot targeting |
| Event CSV | `Data/random_events.csv` (`event_type`) | `exchange` / `quest` / `encounter` |
| `RANDOM_EVENT_DATA` | `LookUps/random_event_data.gd` | Loads events + quest defs/targets |
| `QuestControl` | `Manager/quest_control.gd` | Preview/commit/revert, placement, complete, follow-up stub |
| `MapNode.special_mark` | `Map_Gen/map_node.gd` | Runtime mark payload |
| `MapManager` | `Map_Gen/map_manager.gd` | Quest ring + `map_label`, graph distance, save/load |
| `GameStateManager` | `Manager/game_state_manager.gd` | Encounter visit lifecycle, difficulty override, after-battle hook |

## Control flow

```
RANDOM_EVENT node
  → pick exchange or placeable quest
  → if quest: preview marks on map, show Accept/Decline
  → Accept commits marks; Decline reverts; giver node completes

Visit marked node
  → battle/blockade: fight (optional difficulty_override) → battle rewards → encounter UI
  → shop/rest/event with on_visit: encounter UI first → then normal visit
  → Collect reward → complete_mark (exclusive clears siblings) → try_spawn_followup_marks stub
```

## CSV schema

### `random_events.csv`

Adds `event_type`: `exchange` | `quest` | `encounter`

- `encounter` rows are never randomly picked (`weight` 0).
- Quest givers use Accept/Decline in code (not choice CSV rows).

### `quest_defs.csv`

| column | purpose |
|--------|---------|
| `quest_id` | matches giver `event_id` |
| `exclusive_on_complete` | clear sibling marks when one completes |
| `max_targets` | 1–3 |

### `quest_targets.csv`

| column | purpose |
|--------|---------|
| `quest_id` | parent quest |
| `slot_id` | `0`..`2` |
| `target_content` | `battle` / `shop` / `repair` / `event` / `any` |
| `min_separation` | min graph hops from other selected targets |
| `encounter_id` | encounter event shown on resolve |
| `map_label` | optional map text (e.g. `+50 Comp`) |
| `difficulty_override` | empty or `light`/`medium`/`heavy` |
| `trigger_mode` | `after_battle` \| `on_visit` |

Combat nodes always wait until after victory for the encounter UI, even if `trigger_mode` is `on_visit`.

## Seeded examples

| Quest | Behavior |
|-------|----------|
| **Depot Assault** | 1 battle → `heavy`, after win → 40 components |
| **Locked Cache** | 2 marks, labels `+50 Comp` / `+100 Gold`, exclusive |
| **Hidden Supplies** | 3 marks, on-visit 15 components each, non-exclusive, no content change |

## Placement rules

Candidates must be incomplete, not start/end, **not already blockaded** (`ContentType.BLOCKADE` or `chaser_blockaded`), not already marked, matching `target_content`, and satisfying pairwise `min_separation` (BFS hops via `MapManager.graph_distance`). Quests that cannot place all slots are excluded from the weighted pick.

Marked nodes **may** later be swept by the chaser into `BLOCKADE`; `special_mark` is kept. Combat routing then uses the after-battle encounter path so the reward UI still fires.

## Follow-up stub

`QuestControl.try_spawn_followup_marks(quest_id, completed_slot_id)` is intentionally empty so later quests can spawn additional tied marks after completion.

## Persistence

Committed marks (not previews) save in `map_state.node_special_marks` with `node_difficulties`. Mid-Accept/Decline preview is not saved.

## Related docs

- `.cursor/docs/systems/random-events.md` — exchange events + shared UI
- `.cursor/docs/data-flow.md` — map exploration / battle completion
