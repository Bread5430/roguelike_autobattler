# Status effects — technical summary

## 1. Project overview

- **Goal:** Duration-based buffs/debuffs on `Base_Unit`; stacking by `(effect_id, stack_key)`; stat aggregation (`dmg_taken_mult`, `move_speed`, `Attack_CD.wait_time`); DoT via scripted ticks; tactical UI shows active effects with icons.
- **Stack:** Godot 4.4; `StatusEffectDef` / `StatusEffectInstance`; autoload `STATUS_EFFECT_DATA` (`Data/status_effects.csv`); `StatusEffectTune.apply_csv`; `StatusEffectLibrary` factory; `StatusEffectBox` in `UI/TacticalCursor.tscn`.

## 2. Final architecture

1. **Definitions:** `Utilities/status_effects/*_def.gd` extend `StatusEffectDef` (Resource). Non-trivial behavior stays in script (`DotDamageRampDef.process_instance`).
2. **Shared data:** `Data/status_effects.csv` columns only: `effect_id`, `display_name`, `icon_path`, `default_duration`, `max_stacks`. Loaded by `LookUps/status_effect_data.gd` (`STATUS_EFFECT_DATA`); `StatusEffectTune.apply_csv(def, effect_id)` merges into def at end of each `_init()` after script defaults.
3. **Per-effect tunables:** `@export` on each def (e.g. `dmg_taken_mult_per_stack`, `attack_speed_multiplier`, `tick_interval`) — not in CSV.
4. **Host:** `Base_Unit` holds `_status_effect_instances`, ticks in `_physics_process`, recomputes stats, exposes `get_active_status_effects_for_ui()` → array of dicts (`instance_key`, `display_name`, `stacks`, `remaining`, `duration_fraction`, `icon`).
5. **Apply path:** `apply_status_effect(def, stack_key, …)` from attacks (`Attack_Base` / projectiles), spells (aura/slow field nodes, DoT cast).
6. **Tactical UI:** `UI/tactical_cursor.gd` reads `get_active_status_effects_for_ui()` each `_process` when selected; `StatusEffectsRow` (HBox) instantiates/updates `StatusEffectBox` per instance key; boxes show icon, bottom-anchored duration overlay, optional `xN` stacks.

## 3. Key decisions & rationale

- **Two-layer defs:** scripted subclass + CSV for shared presentation/duration avoids a single wide master CSV; mechanics stay in code.
- **Stack key** for vulnerability: attacker `unit_glossary_id` (similar unit types stack together).
- **Silent refresh** on reapply when stacks do not increase (avoids spam when aura/slow fields refresh duration every frame).
- **DoT damage:** `take_damage(..., false)` so DoT ignores `dmg_taken_mult`.
- **UI:** Persistent icon row (`StatusEffectBox` in `StatusEffectsRow`) driven by `get_active_status_effects_for_ui()` for at-a-glance state.

## 4. Implemented features / progress

- Built-in effects: damage vulnerability, attack speed aura, ground slow, DoT ramp, **stun**, **aegis**, **ablative armor**, **infested**; spell scenes under `Spells/spell_cards/status_effects/`.
- CSV-driven shared fields; `STATUS_EFFECT_DATA.get_display_name` for display strings.
- `UI/StatusEffectBox.tscn` + `status_effect_box.gd` (`StatusEffectBox`).

## 5. Open problems / TODOs

- CSV reload at runtime not implemented (data loaded once at `STATUS_EFFECT_DATA._ready`).

## 6. Important context for continuation

- New effect **type:** add `StatusEffectDef` subclass, row in `status_effects.csv`, extend `StatusEffectTune` only if new **shared** columns are added (prefer keeping shared columns stable).
- **`StatusEffectDef` hooks:** `get_polarity()` (`NEUTRAL` / `BUFF` / `DEBUFF`) for dispel/suppression; `restricts_movement()`, `restricts_basic_attacks()`, `restricts_special_abilities()` OR’d on the host; `suppresses_buff_application()` / `suppresses_debuff_application()` gate **new** instances in `apply_status_effect` (existing instance keys still refresh duration/stacks); `on_applied(host)` runs before inserting a **new** instance (purge/dispel pattern); `modify_incoming_damage(...)` for absorb/reduce before `dmg_taken_mult`; `on_host_death(...)` when host first hits 0 HP.
- **`Base_Unit`:** `purge_status_effects_by_polarity(p)`; `_dispatch_incoming_damage_hooks` / `_dispatch_death_hooks` walk active instances; `is_basic_attacks_restricted()` is enforced in `Attack_Base.check_can_attack()`. Special abilities must call `is_special_abilities_restricted()` at entry when added.
- **Ablative Armor:** `AblativeArmorDef.modify_incoming_damage` consumes one stack and returns 0; used by Standard Melee.
- **Infested:** `InfestedDef.on_host_death` spawns `basic_chaff` × host `scrap_cost` for infector faction; Crawler Path A (`chaff_swarm`).
- **Stun:** `StunnedDef` — move mult `0`, all three restrictions `true`, debuff polarity. Optional UX: play idle while `is_movement_restricted()` in FSMs if sprites support it.
- `Unit_Parent` children: filter `Base_Unit` when iterating (spell previews may be non-units).
- `instance_key` format: `"effect_id::stack_key"`.

## 7. Useful snippets / patterns

- **Factory:** `StatusEffectLibrary.damage_vulnerability()` etc. → `DamageVulnerabilityDef.new()` (merge runs in `_init`).
- **UI row:** `Base_Unit.get_active_status_effects_for_ui()` → `tactical_cursor._refresh_status_effect_boxes`.
- **Icons:** `Base_Unit._get_status_effect_icon(inst)` prefers `inst.def.icon`, else `STATUS_EFFECT_DATA` row `icon_path` (`Utilities/Base_Unit.gd`).
