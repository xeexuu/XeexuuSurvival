# scenes/managers/ScoreSystem.gd
extends Node
class_name ScoreSystem

signal score_changed(new_score: int)
signal score_popup(points: int, position: Vector2, type: String)

var current_score: int = 0
var total_kills: int = 0
var headshot_kills: int = 0
var current_kill_streak: int = 0
var best_kill_streak: int = 0

# Puntuaciones estilo COD WAW
var base_kill_points: int = 50
var headshot_bonus: int = 50
var melee_kill_bonus: int = 130
var max_window_repair_points: int = 200

# Multiplicadores de ronda
var round_multiplier: float = 1.0

# UI de puntuación
var score_ui: Control
var player_camera: Camera2D

# Efectos de puntuación
var score_popup_scene: PackedScene

func _ready():
	# Intentar cargar escena de popup si existe
	if ResourceLoader.exists("res://scenes/ui/ScorePopup.tscn"):
		score_popup_scene = load("res://scenes/ui/ScorePopup.tscn")

func setup_score_ui_on_camera(camera: Camera2D):
	"""Configurar la UI de puntuación en la esquina superior izquierda"""
	player_camera = camera
	if not player_camera:
		return
	
	score_ui = Control.new()
	score_ui.name = "ScoreUI"
	score_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	
	var is_mobile = OS.has_feature("mobile")
	var ui_size = Vector2(200, 60) if not is_mobile else Vector2(250, 80)
	score_ui.size = ui_size
	
	# Contenedor horizontal para el score
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.position = Vector2(10, 10)
	hbox.size = Vector2(ui_size.x - 20, ui_size.y - 20)
	score_ui.add_child(hbox)
	
	# Icono de puntuación
	var score_icon = Label.new()
	score_icon.name = "ScoreIcon"
	score_icon.text = "💀"
	var icon_size = 28 if not is_mobile else 36
	score_icon.add_theme_font_size_override("font_size", icon_size)
	score_icon.add_theme_color_override("font_color", Color.ORANGE)
	score_icon.add_theme_color_override("font_shadow_color", Color.BLACK)
	score_icon.add_theme_constant_override("shadow_offset_x", 2)
	score_icon.add_theme_constant_override("shadow_offset_y", 2)
	score_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(score_icon)
	
	# Etiqueta de puntuación
	var score_label = Label.new()
	score_label.name = "ScoreLabel"
	score_label.text = "0"
	var score_font_size = 24 if not is_mobile else 32
	score_label.add_theme_font_size_override("font_size", score_font_size)
	score_label.add_theme_color_override("font_color", Color.WHITE)
	score_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	score_label.add_theme_constant_override("shadow_offset_x", 2)
	score_label.add_theme_constant_override("shadow_offset_y", 2)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(score_label)
	
	# Añadir a la cámara
	player_camera.add_child(score_ui)

func _process(_delta):
	"""Actualizar posición de la UI relativa a la cámara - SUPERIOR IZQUIERDA"""
	if score_ui and player_camera:
		var viewport_size = get_viewport().get_visible_rect().size
		var camera_zoom = player_camera.zoom
		
		# Calcular posición en la esquina SUPERIOR IZQUIERDA
		var ui_offset = Vector2(
			-(viewport_size.x / camera_zoom.x) / 2 + 20,  # Izquierda + margen
			-(viewport_size.y / camera_zoom.y) / 2 + 20   # Arriba + margen
		)
		
		score_ui.position = ui_offset

func add_kill_points(enemy_position: Vector2, is_headshot: bool = false, is_melee: bool = false):
	"""Añadir puntos por matar enemigo estilo COD WAW"""
	var points = base_kill_points
	var popup_type = "kill"
	
	# Bonus por headshot
	if is_headshot:
		points += headshot_bonus
		popup_type = "headshot"
		headshot_kills += 1
	
	# Bonus por melee kill
	if is_melee:
		points += melee_kill_bonus
		popup_type = "melee"
	
	# Aplicar multiplicador de ronda
	points = int(float(points) * round_multiplier)
	
	# Añadir puntos
	current_score += points
	total_kills += 1
	current_kill_streak += 1
	
	if current_kill_streak > best_kill_streak:
		best_kill_streak = current_kill_streak
	
	# Actualizar UI
	update_score_ui()
	
	# Mostrar popup de puntuación
	show_score_popup(points, enemy_position, popup_type)
	
	# Emitir señales
	score_changed.emit(current_score)
	score_popup.emit(points, enemy_position, popup_type)
	
	print("💀 +", points, " puntos | Score total: ", current_score)

func add_repair_points(repair_position: Vector2, repair_amount: int):
	"""Añadir puntos por reparar ventanas/barricadas"""
	var points = min(repair_amount * 10, max_window_repair_points)
	points = int(float(points) * round_multiplier)
	
	current_score += points
	update_score_ui()
	show_score_popup(points, repair_position, "repair")
	score_changed.emit(current_score)

func add_bonus_points(amount: int, position: Vector2, reason: String = "bonus"):
	"""Añadir puntos bonus por diversas razones"""
	var points = int(float(amount) * round_multiplier)
	current_score += points
	update_score_ui()
	show_score_popup(points, position, reason)
	score_changed.emit(current_score)

func reset_kill_streak():
	"""Resetear racha de kills (cuando el jugador recibe daño)"""
	current_kill_streak = 0

func set_round_multiplier(round_number: int):
	"""Establecer multiplicador basado en la ronda"""
	if round_number <= 5:
		round_multiplier = 1.0
	elif round_number <= 10:
		round_multiplier = 1.2
	elif round_number <= 15:
		round_multiplier = 1.5
	else:
		round_multiplier = 2.0

func show_score_popup(points: int, world_position: Vector2, popup_type: String):
	"""Mostrar popup de puntuación en la posición del mundo"""
	var popup = create_score_popup(points, popup_type)
	
	# Añadir al mundo
	var main_scene = get_tree().current_scene
	if main_scene:
		main_scene.add_child(popup)
		popup.global_position = world_position
		animate_score_popup(popup)

func create_score_popup(points: int, popup_type: String) -> Control:
	"""Crear popup de puntuación visual"""
	var popup = Control.new()
	popup.size = Vector2(120, 40)
	popup.z_index = 100
	
	var label = Label.new()
	label.text = "+" + str(points)
	
	# Color y tamaño según tipo
	var color = Color.WHITE
	var font_size = 24
	
	match popup_type:
		"headshot":
			color = Color.YELLOW
			font_size = 28
			label.text = "HEADSHOT! +" + str(points)
		"melee":
			color = Color.RED
			font_size = 28
			label.text = "MELEE! +" + str(points)
		"repair":
			color = Color.CYAN
			font_size = 20
		"bonus":
			color = Color.GREEN
			font_size = 22
		_:  # kill normal
			color = Color.WHITE
			font_size = 24
	
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	popup.add_child(label)
	return popup

func animate_score_popup(popup: Control):
	"""Animar el popup de puntuación"""
	# Animación de movimiento hacia arriba y desvanecimiento
	var tween = popup.create_tween()
	
	# Mover hacia arriba
	var end_position = popup.global_position + Vector2(0, -80)
	tween.parallel().tween_property(popup, "global_position", end_position, 1.5)
	
	# Escala de aparición
	popup.scale = Vector2.ZERO
	tween.parallel().tween_property(popup, "scale", Vector2(1.2, 1.2), 0.2)
	tween.parallel().tween_property(popup, "scale", Vector2(1.0, 1.0), 0.3)
	
	# Desvanecimiento
	tween.parallel().tween_property(popup, "modulate:a", 0.0, 1.0)
	
	# Destruir al final
	tween.tween_callback(func(): popup.queue_free())

func update_score_ui():
	"""Actualizar la UI de puntuación"""
	if not score_ui:
		return
	
	var score_label = score_ui.find_child("ScoreLabel")
	if score_label:
		score_label.text = str(current_score)
		
		# Efecto de parpadeo cuando se añaden puntos
		var flash_tween = score_ui.create_tween()
		score_label.add_theme_color_override("font_color", Color.YELLOW)
		flash_tween.tween_property(score_label, "modulate", Color.WHITE, 0.1)
		flash_tween.tween_callback(func(): 
			score_label.add_theme_color_override("font_color", Color.WHITE)
		)

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

func get_stats_summary() -> Dictionary:
	"""Obtener resumen de estadísticas"""
	return {
		"score": current_score,
		"total_kills": total_kills,
		"headshot_kills": headshot_kills,
		"headshot_percentage": get_headshot_percentage(),
		"current_streak": current_kill_streak,
		"best_streak": best_kill_streak,
		"round_multiplier": round_multiplier
	}
