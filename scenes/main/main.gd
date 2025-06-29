extends Node2D

@onready var game_manager = $GameManager

func _ready():
	if has_node("GameManager"):
		game_manager = $GameManager
