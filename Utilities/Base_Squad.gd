extends Node2D

@onready var engage_range # When an enemy enters this range disable squad movement and enter manual control
var in_engagement_range = false
var units
