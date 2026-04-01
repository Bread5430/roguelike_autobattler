# Key Patterns

- **Autoloads**: `ITEM_NAME` and `FORMATION_MAP` load CSV data (`Data/items.csv`, `Data/formations.csv`) into global lookup maps; **`UNIT_GLOSSARY`** (`LookUps/unit_glossary.gd`) loads `Data/units_glossary.csv` (per-template stats: max HP, move speed, damage, display name, blurb)
- **Unit glossary**: Each unit template root sets `@export var unit_glossary_id` on `Base_Unit` to a row id in `units_glossary.csv`. `Base_Unit._ready()` applies CSV values over scene defaults. Outgoing damage uses `Attack_Base.get_strike_damage()` (reads `Base_Unit.get_attack_damage()` × `dmg_dealt_mult` at fire time), not a damage field on the attack node
- **post_ready()**: Custom initialization after `_ready()` so scene setup completes (e.g. `GUI.gd` lines 35–50)
- **Signals**: Inter-component communication (e.g. `battle_ended` from BattleManager to GameStateManager)
- **Item inspection**: Inventory right-click emits `inspect_requested(item_inst, item_name, source_global_pos)`; `GUI` builds payloads via `UI/item_details_builder.gd` and renders `UI/ItemDetailsCard.tscn`; reusable for future shop slots
- **Grid-based placement**: Units on `BoardUI` (GridContainer of `BoardSlot` panels) using formation vectors from `unit_card.gd`
- **Roles & bitmasks**: Unit roles (CARRY, SWARM, CLEAR, TANK) as bitflags in `ITEM_NAME.gd` for filtering
- **Unit_Parent and non-units**: `BattleManager`’s `Unit_Parent` can contain non-unit nodes (e.g. spell preview indicators like `SpellPreviewCircle`). Any logic iterating `unit_parent.get_children()` must filter to `Base_Unit` (e.g. `if i is Base_Unit`) before using `faction`, `set_start_stop`, or tile updates
