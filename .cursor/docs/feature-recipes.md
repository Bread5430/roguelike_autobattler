# Feature Recipes (Examples)

- **Adding a unit**: Create scene inheriting `Base_Unit.tscn`, set `unit_glossary_id` and add a row to `Data/units_glossary.csv`, add to `items.csv`, reference in `unit_card` scene
- **New formation**: Add rows to `formations.csv` with X,Y,W,H,Role,Group
- **State transition**: Emit signal from manager; connect in `game_state_manager.gd` `_ready()`
- **Adding a spell**: Create scene with script extending `Base_Spell` (implement `preview(world_pos)`, `cast(world_pos)`, `clear_preview()`), create spell card scene with `Spell_Card` and `related_spell_effect`, add to `items.csv`
