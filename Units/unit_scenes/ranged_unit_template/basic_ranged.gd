extends Attack_Base

@onready var visible_time = $visble_time
var show_line : bool = false

func do_attack():
	# Set the line status to draw the line
	show_line = true
	visible_time.start()
	queue_redraw()
	
	# Projectile is purely cosmetic, dmg is done now
	var amount = get_strike_damage()
	target_unit.take_damage(amount, true, unit)
	unit.add_damage_dealt(amount)
	_apply_post_hit_effects()
	super()


func _apply_post_hit_effects() -> void:
	if unit == null or unit.get("applies_disrupt_shot") != true:
		return
	if target_unit == null or not is_instance_valid(target_unit):
		return
	target_unit.purge_status_effects_by_polarity(StatusEffectDef.Polarity.BUFF)
	target_unit.apply_status_effect(StatusEffectLibrary.ground_slow(), "disrupt_slow", 1, 2.5)


func _draw():
	if show_line:
		# Draw from Zero since line is spawned on top of the calling unit
		# Would be from position if the UI manager was on parent level
		draw_line(Vector2.ZERO, target_unit.position - unit.position, Color.RED, 2)
		draw_circle(Vector2.ZERO, 5, Color.RED)

func _on_visble_time_timeout():
	show_line = false
	queue_redraw()
