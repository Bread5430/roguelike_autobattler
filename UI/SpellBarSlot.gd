extends Button
class_name SpellBarSlot

## The spell effect instance (Base_Spell). Used for casting and preview.
var spell_inst : Base_Spell
## Item name for returning to inventory when right-clicked in deployment.
var item_name : String = ""

signal slot_clicked(slot: SpellBarSlot)
signal slot_right_clicked(slot: SpellBarSlot)

@onready var icon_rect: TextureRect = $TextureRect

func setup(spell_instance: Base_Spell, spell_item_name: String, icon_texture: Texture2D) -> void:
	spell_inst = spell_instance
	item_name = spell_item_name
	if icon_rect and icon_texture:
		icon_rect.texture = icon_texture
		icon_rect.visible = true
		var max_dim = maxf(icon_texture.get_width(), icon_texture.get_height())
		if max_dim > 0:
			var s = minf(size.x / max_dim, size.y / max_dim)
			icon_rect.scale = Vector2(s, s)

func clear_slot() -> void:
	spell_inst = null
	item_name = ""
	if icon_rect:
		icon_rect.texture = null
		icon_rect.visible = false

func is_empty() -> bool:
	return spell_inst == null

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			slot_clicked.emit(self)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			slot_right_clicked.emit(self)
			accept_event()
