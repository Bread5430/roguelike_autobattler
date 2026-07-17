extends GridContainer
class_name SpellBar

@export var MAX_SLOTS := 8
const SLOT_SCENE := preload("res://UI/SpellBarSlot.tscn")

var slots: Array[SpellBarSlot] = []
var battle_manager: Node

signal spell_slot_clicked(slot: SpellBarSlot)
signal spell_slot_right_clicked(slot: SpellBarSlot)

func _ready() -> void:
	columns = MAX_SLOTS
	for i in MAX_SLOTS:
		var slot: SpellBarSlot = SLOT_SCENE.instantiate()
		slot.slot_clicked.connect(_on_slot_clicked)
		slot.slot_right_clicked.connect(_on_slot_right_clicked)
		slots.append(slot)
		add_child(slot)

func _on_slot_clicked(slot: SpellBarSlot) -> void:
	spell_slot_clicked.emit(slot)

func _on_slot_right_clicked(slot: SpellBarSlot) -> void:
	spell_slot_right_clicked.emit(slot)

## Add a spell from inventory (deployment mode). card_inst is the Spell_Card instance, item_name for inventory lookup.
func add_spell(card_inst: Spell_Card, item_name_for_inventory: String) -> bool:
	if not card_inst or not card_inst.related_spell_effect:
		return false
	var spell_scene: PackedScene = card_inst.related_spell_effect
	var spell_node: Node = spell_scene.instantiate()
	if not spell_node is Base_Spell:
		spell_node.queue_free()
		return false
	var spell_inst: Base_Spell = spell_node as Base_Spell
	spell_inst.battle_manager = battle_manager
	for slot in slots:
		if slot.is_empty():
			var tex: Texture2D = card_inst.get_texture() if card_inst.get_texture() else null
			slot.setup(spell_inst, item_name_for_inventory, tex)
			return true
	return false

## Remove spell from a slot (e.g. when returning to inventory). Caller should add_item to inventory.
func remove_spell_at(slot: SpellBarSlot) -> void:
	if not slot or slot.is_empty():
		return
	if is_instance_valid(slot.spell_inst):
		slot.spell_inst.clear_preview()
		slot.spell_inst.queue_free()
	slot.clear_slot()


## Clear slot UI without freeing the spell instance (used when buffering casts during soft pause).
func detach_spell_at(slot: SpellBarSlot) -> Base_Spell:
	if not slot or slot.is_empty():
		return null
	var spell: Base_Spell = slot.spell_inst
	if is_instance_valid(spell):
		spell.clear_preview()
	slot.clear_slot()
	return spell


func get_first_empty_slot() -> SpellBarSlot:
	for slot in slots:
		if slot.is_empty():
			return slot
	return null
