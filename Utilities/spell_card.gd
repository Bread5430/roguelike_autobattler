extends Item
class_name Spell_Card

@export var related_spell_effect : PackedScene
@export var mana_cost : int
@export var cooldown : int

func setup_spell():
	item_type = TYPE.spell_card
	if SPELL_GLOSSARY.has_entry(item_name):
		var entry = SPELL_GLOSSARY.get_entry(item_name)
		mana_cost = int(entry.get("mana_cost", mana_cost))
		cooldown = int(entry.get("cooldown", cooldown))
