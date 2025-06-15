# scenes/managers/ScoreSystem.gd - CORREGIDO: parameter no usado prefijado
extends Node
class_name ScoreSystem

signal score_changed(new_score: int)
signal score_popup(points: int, position: Vector2, type: String)

var current_score: int = 0
var total_kills: int = 0
var headshot_kills: int = 0
var current_kill_streak: int = 0
var best_kill_streak: int = 0

# PUNTUACIÓN EXACTA COD BLACK OPS 2 ZOMBIES
var base_hit_points: int = 50
var headshot_hit_points: int = 100
var melee_kill_bonus: int = 130
var max_window_repair_points: int = 200

# Efectos de puntuación
var score_popup_scene: PackedScene

func _ready():
	if ResourceLoader.exists("res://scenes/ui/ScorePopup.tscn"):
		score_popup_scene = load("res://scenes/ui/ScorePopup.tscn")

func add_kill_points(hit_position: Vector2, is_headshot: bool = false, is_melee: bool = false):
	"""SISTEMA COD BO2: 50 puntos por hit, 100 por headshot, +130 por melee kill"""
	var points = 0
	var popup_type = "hit"
	
	if is_headshot:
		points = headshot_hit_points
		popup_type = "headshot"
		headshot_kills += 1
	else:
		points = base_hit_points
		popup_type = "hit"
	
	if is_melee:
		points += melee_kill_bonus
		popup_type = "melee"
	
	current_score += points
	current_kill_streak += 1
	
	if current_kill_streak > best_kill_streak:
		best_kill_streak = current_kill_streak
	
	show_score_popup(points, hit_position, popup_type)
	score_changed.emit(current_score)
	score_popup.emit(points, hit_position, popup_type)

func add_enemy_kill():
	"""Registrar kill de enemigo (solo para estadísticas)"""
	total_kills += 1

func add_repair_points(repair_position: Vector2, repair_amount: int):
	"""Añadir puntos por reparar ventanas/barricadas"""
	var points = min(repair_amount * 10, max_window_repair_points)
	
	current_score += points
	show_score_popup(points, repair_position, "repair")
	score_changed.emit(current_score)

func add_bonus_points(amount: int, position: Vector2, reason: String = "bonus"):
	"""Añadir puntos bonus por diversas razones"""
	current_score += amount
	show_score_popup(amount, position, reason)
	score_changed.emit(current_score)

func reset_kill_streak():
	"""Resetear racha de kills (cuando el jugador recibe daño)"""
	current_kill_streak = 0

func show_score_popup(points: int, world_position: Vector2, popup_type: String):
	"""Mostrar popup de puntuación estilo Black Ops"""
	var popup = create_score_popup(points, popup_type)
	
	var main_scene = get_tree().current_scene
	if main_scene:
		main_scene.add_child(popup)
		popup.global_position = world_position
		animate_score_popup(popup)

func create_score_popup(points: int, popup_type: String) -> Control:
	"""Crear popup de puntuación visual estilo Black Ops"""
	var popup = Control.new()
	popup.size = Vector2(150, 50)
	popup.z_index = 100
	
	var label = Label.new()
	label.text = "+" + str(points)
	
	var color = Color.WHITE
	var font_size = 28
	
	match popup_type:
		"headshot":
			color = Color(1.0, 0.8, 0.0, 1.0)
			font_size = 32
			label.text = "+" + str(points)
		"melee":
			color = Color(1.0, 0.2, 0.2, 1.0)
			font_size = 32
			label.text = "+" + str(points)
		"repair":
			color = Color(0.0, 0.8, 1.0, 1.0)
			font_size = 24
		"bonus":
			color = Color(0.2, 1.0, 0.2, 1.0)
			font_size = 26
		_:
			color = Color.WHITE
			font_size = 28
	
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 3)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	popup.add_child(label)
	return popup

func animate_score_popup(popup: Control):
	"""Animar el popup de puntuación estilo Black Ops"""
	var tween = popup.create_tween()
	
	var end_position = popup.global_position + Vector2(randf_range(-20, 20), -100)
	tween.parallel().tween_property(popup, "global_position", end_position, 1.8)
	
	popup.scale = Vector2.ZERO
	tween.parallel().tween_property(popup, "scale", Vector2(1.4, 1.4), 0.3)
	tween.parallel().tween_property(popup, "scale", Vector2(1.0, 1.0), 0.4)
	
	tween.parallel().tween_property(popup, "modulate:a", 0.0, 1.2)
	
	tween.tween_callback(func(): popup.queue_free())

func format_score(score: int) -> String:
	"""Formatear puntuación con separadores de miles estilo Black Ops"""
	var score_str = str(score)
	var formatted = ""
	var count = 0
	
	for i in range(score_str.length() - 1, -1, -1):
		if count == 3:
			formatted = "," + formatted
			count = 0
		formatted = score_str[i] + formatted
		count += 1
	
	return formatted

func get_current_score() -> int:
	"""Obtener puntuación actual"""
	return current_score

func get_total_kills() -> int:
	"""Obtener total de kills"""
	return total_kills

func get_headshot_kills() -> int:
	"""Obtener kills por headshot"""
	return headshot_kills

func get_current_kill_streak() -> int:
	"""Obtener racha actual"""
	return current_kill_streak

func get_best_kill_streak() -> int:
	"""Obtener mejor racha"""
	return best_kill_streak

func get_headshot_percentage() -> float:
	"""Obtener porcentaje de headshots"""
	if total_kills == 0:
		return 0.0
	return (float(headshot_kills) / float(total_kills)) * 100.0

func set_round_multiplier(_round_number: int):  # CORREGIDO: parameter prefijado con _
	"""Establecer multiplicador basado en la ronda (función de compatibilidad)"""
	# En COD BO2 no hay multiplicador de ronda para puntos de impacto
	# Esta función existe solo para compatibilidad
	pass

func get_stats_summary() -> Dictionary:
	"""Obtener resumen de estadísticas"""
	return {
		"score": current_score,
		"total_kills": total_kills,
		"headshot_kills": headshot_kills,
		"headshot_percentage": get_headshot_percentage(),
		"current_streak": current_kill_streak,
		"best_streak": best_kill_streak
	}
