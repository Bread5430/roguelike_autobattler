extends RefCounted
class_name ItemDetailsBuilder

const KIND_UNIT := "unit"
const KIND_SPELL := "spell"
const KIND_UNKNOWN := "unknown"

func build_payload(item_inst: Item, item_name: String) -> Dictionary:
	if item_inst == null:
		return {
			"kind": KIND_UNKNOWN,
			"display_name": item_name,
			"icon": null,
			"lines": []
		}
	if item_inst is Unit_Card:
		return _build_unit_payload(item_inst as Unit_Card, item_name)
	if item_inst is Spell_Card:
		return _build_spell_payload(item_inst as Spell_Card, item_name)
	return {
		"kind": KIND_UNKNOWN,
		"display_name": item_name,
		"icon": item_inst.get_texture(),
		"lines": []
	}

func _build_unit_payload(unit_card: Unit_Card, item_name: String) -> Dictionary:
	var unit_scene := unit_card.related_unit
	var unit_glossary_id := ""
	var fallback_hp := 0
	var fallback_speed := 0
	var fallback_damage := 0
	if unit_scene:
		var unit_inst = unit_scene.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
		if unit_inst is Base_Unit:
			var base_unit := unit_inst as Base_Unit
			unit_glossary_id = base_unit.unit_glossary_id
			fallback_hp = base_unit.max_hp
			fallback_speed = int(base_unit.base_speed)
			fallback_damage = int(base_unit.base_damage)
		unit_inst.queue_free()

	var display_name := item_name
	var hp := fallback_hp
	var speed := fallback_speed
	var damage := fallback_damage
	var blurb := ""
	if unit_glossary_id != "" and UNIT_GLOSSARY.has_entry(unit_glossary_id):
		var entry := UNIT_GLOSSARY.get_entry(unit_glossary_id)
		display_name = str(entry.get("display_name", display_name))
		hp = int(entry.get("max_hp", hp))
		speed = int(entry.get("movement_speed", speed))
		damage = int(entry.get("damage", damage))
		blurb = str(entry.get("explanation_blurb", ""))

	var lines := [
		{"label": "Max HP", "value": str(hp)},
		{"label": "Movement Speed", "value": str(speed)},
		{"label": "Damage", "value": str(damage)},
		{
			"label": "Deployment Size",
			"value": "%d x %d" % [int(unit_card.placement_size.x), int(unit_card.placement_size.y)]
		},
		{"label": "Units Per Card", "value": str(unit_card.num_units)}
	]
	if blurb != "":
		lines.append({"label": "Info", "value": blurb})

	return {
		"kind": KIND_UNIT,
		"display_name": display_name,
		"icon": unit_card.get_texture(),
		"lines": lines
	}

func _build_spell_payload(spell_card: Spell_Card, item_name: String) -> Dictionary:
	var display_name := item_name
	var lines := [
		{"label": "Cooldown", "value": str(spell_card.cooldown)},
		{"label": "Mana Cost", "value": str(spell_card.mana_cost)}
	]
	return {
		"kind": KIND_SPELL,
		"display_name": display_name,
		"icon": spell_card.get_texture(),
		"lines": lines
	}
