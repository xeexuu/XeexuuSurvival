# scenes/managers/ScoreSystem.gd - SISTEMA DE PUNTUACIÓN CALL OF DUTY BLACK OPS 1 ZOMBIES
extends Node
class_name ScoreSystem

signal score_changed(new_score: int)
signal score_popup(points: int, position: Vector2, type: String)

var current_score: int = 0
var total_kills: int = 0
var headshot_kills: int = 0
var current_kill_streak: int = 0
var best_kill_streak: int = 0

# PUNTUACIÓN EXACTA COD BLACK OPS 1 ZOMBIES
var base_kill_points: int = 50        # Puntos por kill básico
var headshot_bonus: int = 50          # Bonus adicional por headshot (50 + 50 = 100 total)
var melee_kill_bonus: int = 130       # Bonus por kill cuerpo a cuerpo
var max_window_repair_points: int = 100
var insta_kill_points: int = 50       # Puntos durante insta-kill
var carpenter_points: int = 200       # Puntos por power-up carpenter
var max_ammo_points: int = 400        # Puntos por power-up max ammo

# MULTIPLICADORES POR RONDA (BLACK OPS 1)
var round_multipliers: Array[int] = [
	1,   # Ronda 1
	1,   # Ronda 2
	1,   # Ronda 3
	1,   # Ronda 4
	1,   # Ronda 5
	1,   # Ronda 6
	1,   # Ronda 7
	1,   # Ronda 8
	1,   # Ronda 9
	2,   # Ronda 10+
]

var current_round_multiplier: int = 1
var current_round: int = 1

# Efectos de puntuación
var score_popup_scene: PackedScene

func _ready():
	if ResourceLoader.exists("res://scenes/ui/ScorePopup.tscn"):
		score_popup_scene = load("res://scenes/ui/ScorePopup.tscn")

func set_current_round(round_number: int):
	"""Establecer la ronda actual para ajustar multiplicadores"""
	current_round = round_number
	
	if round_number >= 10:
		current_round_multiplier = 2
	else:
		current_round_multiplier = 1

func add_kill_points(hit_position: Vector2, is_headshot: bool = false, is_melee: bool = false):
	"""SISTEMA COD BO1: Puntos por kill con multiplicadores de ronda"""
	var points = base_kill_points
	var popup_type = "kill"
	
	# Aplicar bonus por headshot
	if is_headshot:
		points += headshot_bonus  # 50 + 50 = 100 total
		popup_type = "headshot"
		headshot_kills += 1
	
	# Aplicar bonus por melee
	if is_melee:
		points += melee_kill_bonus  # +130 adicional
		popup_type = "melee"
	
	# APLICAR MULTIPLICADOR DE RONDA (BLACK OPS 1)
	points *= current_round_multiplier
	
	current_score += points
	current_kill_streak += 1
	total_kills += 1
	
	if current_kill_streak > best_kill_streak:
		best_kill_streak = current_kill_streak
	
	show_score_popup(points, hit_position, popup_type)
	score_changed.emit(current_score)
	score_popup.emit(points, hit_position, popup_type)

func add_damage_points(hit_position: Vector2, _damage_dealt: int, is_headshot: bool = false):
	"""SISTEMA COD BO1: Puntos por daño sin kill (10 puntos por hit)"""
	var points = 10  # Black Ops 1 da 10 puntos por hit sin kill
	var popup_type = "damage"
	
	if is_headshot:
		points = 20  # Doble puntos por headshot sin kill
		popup_type = "headshot_damage"
	
	# APLICAR MULTIPLICADOR DE RONDA
	points *= current_round_multiplier
	
	current_score += points
	
	show_score_popup(points, hit_position, popup_type)
	score_changed.emit(current_score)
	score_popup.emit(points, hit_position, popup_type)

func add_insta_kill_points(hit_position: Vector2):
	"""Puntos durante power-up insta-kill"""
	var points = insta_kill_points * current_round_multiplier
	
	current_score += points
	current_kill_streak += 1
	total_kills += 1
	
	if current_kill_streak > best_kill_streak:
		best_kill_streak = current_kill_streak
	
	show_score_popup(points, hit_position, "insta_kill")
	score_changed.emit(current_score)
	score_popup.emit(points, hit_position, "insta_kill")

func add_repair_points(repair_position: Vector2, repair_amount: int):
	"""Añadir puntos por reparar ventanas/barricadas estilo Black Ops 1"""
	var points = min(repair_amount * 10, max_window_repair_points)
	
	current_score += points
	show_score_popup(points, repair_position, "repair")
	score_changed.emit(current_score)

func add_power_up_points(power_up_type: String, position: Vector2):
	"""Añadir puntos por power-ups"""
	var points = 0
	
	match power_up_type:
		"carpenter":
			points = carpenter_points
		"max_ammo":
			points = max_ammo_points
		"double_points":
			points = 0  # Double points no da puntos por sí mismo
		"insta_kill":
			points = 0  # Insta-kill no da puntos por sí mismo
		_:
			points = 100  # Power-up genérico
	
	if points > 0:
		current_score += points
		show_score_popup(points, position, power_up_type)
		score_changed.emit(current_score)

func add_bonus_points(amount: int, position: Vector2, reason: String = "bonus"):
	"""Añadir puntos bonus por diversas razones"""
	var final_amount = amount * current_round_multiplier
	
	current_score += final_amount
	show_score_popup(final_amount, position, reason)
	score_changed.emit(current_score)

func reset_kill_streak():
	"""Resetear racha de kills (cuando el jugador recibe daño)"""
	current_kill_streak = 0

func show_score_popup(points: int, world_position: Vector2, popup_type: String):
	"""Mostrar popup de puntuación estilo Black Ops 1"""
	var popup = create_score_popup(points, popup_type)
	
	var main_scene = get_tree().current_scene
	if main_scene:
		main_scene.add_child(popup)
		popup.global_position = world_position
		animate_score_popup(popup)

func create_score_popup(points: int, popup_type: String) -> Control:
	"""Crear popup de puntuación visual estilo Black Ops 1"""
	var popup = Control.new()
	popup.size = Vector2(150, 50)
	popup.z_index = 100
	
	var label = Label.new()
	label.text = "+" + str(points)
	
	var color = Color.WHITE
	var font_size = 28
	
	match popup_type:
		"headshot":
			color = Color(1.0, 0.8, 0.0, 1.0)  # Dorado
			font_size = 32
			label.text = "HEADSHOT! +" + str(points)
		"melee":
			color = Color(1.0, 0.2, 0.2, 1.0)  # Rojo
			font_size = 32
			label.text = "MELEE! +" + str(points)
		"headshot_damage":
			color = Color(1.0, 0.6, 0.0, 1.0)  # Naranja
			font_size = 24
			label.text = "+" + str(points)
		"damage":
			color = Color(0.8, 0.8, 0.8, 1.0)  # Gris claro
			font_size = 22
		"insta_kill":
			color = Color(1.0, 0.0, 1.0, 1.0)  # Magenta
			font_size = 30
			label.text = "INSTA-KILL! +" + str(points)
		"repair":
			color = Color(0.0, 0.8, 1.0, 1.0)  # Cian
			font_size = 24
		"carpenter":
			color = Color(0.6, 0.4, 0.0, 1.0)  # Marrón
			font_size = 26
			label.text = "CARPENTER! +" + str(points)
		"max_ammo":
			color = Color(0.0, 1.0, 0.0, 1.0)  # Verde
			font_size = 26
			label.text = "MAX AMMO! +" + str(points)
		"bonus":
			color = Color(0.2, 1.0, 0.2, 1.0)  # Verde claro
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
	"""Animar el popup de puntuación estilo Black Ops 1"""
	var tween = popup.create_tween()
	
	var end_position = popup.global_position + Vector2(randf_range(-20, 20), -120)
	tween.parallel().tween_property(popup, "global_position", end_position, 2.0)
	
	popup.scale = Vector2.ZERO
	tween.parallel().tween_property(popup, "scale", Vector2(1.5, 1.5), 0.2)
	tween.parallel().tween_property(popup, "scale", Vector2(1.0, 1.0), 0.3)
	
	tween.parallel().tween_property(popup, "modulate:a", 0.0, 1.5)
	
	tween.tween_callback(func(): popup.queue_free())

func format_score(score: int) -> String:
	"""Formatear puntuación con separadores de miles estilo Black Ops 1"""
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

func get_round_multiplier() -> int:
	"""Obtener multiplicador actual de ronda"""
	return current_round_multiplier

func calculate_points_per_round(round_number: int) -> Dictionary:
	"""Calcular información de puntos para una ronda específica"""
	var multiplier = 1
	if round_number >= 10:
		multiplier = 2
	
	return {
		"base_kill": base_kill_points * multiplier,
		"headshot_kill": (base_kill_points + headshot_bonus) * multiplier,
		"melee_kill": (base_kill_points + melee_kill_bonus) * multiplier,
		"damage_hit": 10 * multiplier,
		"headshot_damage": 20 * multiplier,
		"multiplier": multiplier
	}

func get_stats_summary() -> Dictionary:
	"""Obtener resumen de estadísticas"""
	return {
		"score": current_score,
		"total_kills": total_kills,
		"headshot_kills": headshot_kills,
		"headshot_percentage": get_headshot_percentage(),
		"current_streak": current_kill_streak,
		"best_streak": best_kill_streak,
		"round_multiplier": current_round_multiplier,
		"current_round": current_round
	}

func get_score_breakdown_for_ui() -> Dictionary:
	"""Obtener desglose de puntuación para la UI"""
	var multiplier_info = calculate_points_per_round(current_round)
	
	return {
		"current_score": format_score(current_score),
		"kills": total_kills,
		"headshots": headshot_kills,
		"headshot_percent": get_headshot_percentage(),
		"kill_streak": current_kill_streak,
		"best_streak": best_kill_streak,
		"points_per_kill": multiplier_info.base_kill,
		"points_per_headshot": multiplier_info.headshot_kill,
		"points_per_melee": multiplier_info.melee_kill,
		"round_multiplier": "x" + str(current_round_multiplier),
		"round": current_round
	}

# FUNCIONES ESPECIALES PARA POWER-UPS (FUTURO)
func enable_double_points(_duration: float = 30.0):
	"""Habilitar doble puntos temporalmente"""
	# TODO: Implementar cuando se añadan power-ups
	pass

func enable_insta_kill(_duration: float = 30.0):
	"""Habilitar insta-kill temporalmente"""
	# TODO: Implementar cuando se añadan power-ups
	pass

func trigger_max_ammo():
	"""Activar max ammo power-up"""
	# TODO: Implementar cuando se añadan power-ups
	pass

func trigger_carpenter():
	"""Activar carpenter power-up"""
	# TODO: Implementar cuando se añadan power-ups
	pass

# SISTEMA DE LOGROS (FUTURO)
func check_achievements():
	"""Verificar logros basados en puntuación y estadísticas"""
	# TODO: Implementar sistema de logros
	pass

func save_high_score():
	"""Guardar puntuación máxima"""
	# TODO: Implementar guardado de puntuaciones
	pass

func load_high_score() -> int:
	"""Cargar puntuación máxima guardada"""
	# TODO: Implementar carga de puntuaciones
	return 0
