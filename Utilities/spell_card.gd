extends Item
class_name Spell_Card

@export var related_spell_effect : PackedScene
@export var mana_cost : int
@export var cooldown : int

func setup_spell():
	item_type = TYPE.spell_card
