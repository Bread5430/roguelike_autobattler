extends Attack_Base

@onready var visible_time = $visble_time
var show_line : bool = false

func do_attack():
	# Set the line status to draw the line
	show_line = true
	visible_time.start()
	queue_redraw()
	
	# Projectile is purely cosmetic, dmg is done now
	var amount := get_strike_damage()
	target_unit.take_damage(amount)
	unit.add_damage_dealt(amount)
	super()

func _draw():
	if show_line:
		# Draw from Zero since line is spawned on top of the calling unit
		# Would be from position if the UI manager was on parent level
		draw_line(Vector2.ZERO, target_unit.position - unit.position, Color.RED, 2)
		draw_circle(Vector2.ZERO, 5, Color.RED)

func _on_visble_time_timeout():
	show_line = false
	queue_redraw()
