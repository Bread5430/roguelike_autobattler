extends Button
class_name ShopSlot

signal slot_pressed(slot_data: Dictionary)

var slot_data: Dictionary = {}
var _item_details_builder := ItemDetailsBuilder.new()

@onready var _icon: TextureRect = $Margin/VBox/Icon
@onready var _name_label: Label = $Margin/VBox/NameLabel
@onready var _price_label: Label = $Margin/VBox/PriceLabel
@onready var _sale_label: Label = $Margin/VBox/SaleLabel


func _ready() -> void:
	pressed.connect(_on_pressed)
	mouse_filter = Control.MOUSE_FILTER_STOP


func configure(data: Dictionary) -> void:
	slot_data = data.duplicate(true)
	if is_node_ready():
		_refresh_display()
	else:
		call_deferred("_refresh_display")


func _refresh_display() -> void:
	if not is_node_ready():
		return
	var kind: String = str(slot_data.get("kind", ""))
	var sold: bool = slot_data.get("sold", false)
	var on_sale: bool = slot_data.get("on_sale", false)
	var base_price: int = int(slot_data.get("base_price", 0))
	var item_id: String = str(slot_data.get("item_id", ""))

	if kind == "relic":
		_icon.texture = null
		_name_label.text = "Relic (TODO)"
		_price_label.text = "—"
		_sale_label.visible = on_sale
		if on_sale:
			_sale_label.text = "SALE"
		disabled = true
		return

	var purchased: bool = slot_data.get("purchased", false)
	if kind == "upgrade":
		disabled = purchased or item_id.is_empty()
		_sale_label.visible = on_sale and not purchased and not item_id.is_empty()
		if on_sale:
			_sale_label.text = "SALE"
		if purchased:
			_name_label.text = "Upgrade purchased"
			_price_label.text = "Purchased"
			modulate = Color(0.55, 0.55, 0.55, 1.0)
		elif item_id.is_empty():
			modulate = Color(0.55, 0.55, 0.55, 1.0)
			_name_label.text = "No upgrade"
			_price_label.text = "—"
			_icon.texture = null
		else:
			modulate = Color.WHITE
			_name_label.text = "Upgrade: %s" % _display_name_for_item(item_id)
			var price := _effective_price(base_price, on_sale)
			var suffix := _price_suffix()
			if on_sale:
				_price_label.text = "%d%s  (%d%s)" % [price, suffix, base_price, suffix]
			else:
				_price_label.text = "%d%s" % [price, suffix]
			_set_icon_for_item(item_id, kind)
		return

	disabled = sold
	_sale_label.visible = on_sale and not sold
	if on_sale:
		_sale_label.text = "SALE"

	if sold:
		_name_label.text = _display_name_for_item(item_id)
		_price_label.text = "Sold"
		modulate = Color(0.55, 0.55, 0.55, 1.0)
	else:
		modulate = Color.WHITE
		_name_label.text = _display_name_for_item(item_id)
		var price := _effective_price(base_price, on_sale)
		var suffix := _price_suffix()
		if on_sale:
			_price_label.text = "%d%s  (%d%s)" % [price, suffix, base_price, suffix]
		else:
			_price_label.text = "%d%s" % [price, suffix]

	_set_icon_for_item(item_id, kind)


func _effective_price(base_price: int, on_sale: bool) -> int:
	if on_sale:
		return int(floor(float(base_price) * 0.5))
	return base_price


func get_effective_price() -> int:
	if slot_data.get("sold", false) or slot_data.get("purchased", false):
		return 0
	var kind := str(slot_data.get("kind", ""))
	if kind == "relic":
		return 0
	return _effective_price(int(slot_data.get("base_price", 0)), slot_data.get("on_sale", false))


func _price_suffix() -> String:
	if str(slot_data.get("currency", "")) == "components":
		return "c"
	return "g"


func mark_sold() -> void:
	slot_data["sold"] = true
	_refresh_display()


func mark_purchased() -> void:
	slot_data["purchased"] = true
	_refresh_display()


func reroll(new_data: Dictionary) -> void:
	if slot_data.get("sold", false) or slot_data.get("purchased", false):
		return
	slot_data = new_data.duplicate(true)
	_refresh_display()


func _set_icon_for_item(item_id: String, kind: String) -> void:
	var scene: PackedScene = ITEM_NAME.item_lookup(item_id)
	if scene == null:
		_icon.texture = null
		return
	var inst = scene.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	if inst is Unit_Card:
		(inst as Unit_Card).setup_unit()
	elif inst is Spell_Card:
		(inst as Spell_Card).setup_spell()
	if inst and inst.has_method("get_texture"):
		_icon.texture = inst.get_texture()
	inst.queue_free()


func _display_name_for_item(item_id: String) -> String:
	if item_id.is_empty():
		return "Unknown"
	var scene: PackedScene = ITEM_NAME.item_lookup(item_id)
	if scene == null:
		return item_id
	var inst = scene.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	if inst is Unit_Card:
		var payload := _item_details_builder.build_payload(inst as Unit_Card, item_id)
		inst.queue_free()
		return str(payload.get("display_name", item_id))
	if inst is Spell_Card:
		(inst as Spell_Card).setup_spell()
		if "item_name" in inst:
			var name := str(inst.item_name)
			inst.queue_free()
			return name
	if inst and "item_name" in inst:
		var name := str(inst.item_name)
		inst.queue_free()
		return name
	if inst:
		inst.queue_free()
	return item_id


func _on_pressed() -> void:
	if slot_data.get("sold", false) or slot_data.get("purchased", false):
		return
	if str(slot_data.get("kind", "")) == "relic":
		return
	slot_pressed.emit(slot_data)
