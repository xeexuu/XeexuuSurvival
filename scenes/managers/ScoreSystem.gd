# scenes/managers/ScoreSystem.gd - COD BLACK OPS 2 ZOMBIES SCORING EXACTO
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
var base_hit_points: int = 50     # Cada impacto = 50 puntos
var headshot_hit_points: int = 100  # Cada headshot = 100 puntos
var melee_kill_bonus: int = 130   # Bonus por melee kill
var max_window_repair_points: int = 200

# UI de puntuación - ESQUINA INFERIOR DERECHA
var score_ui: Control
var player_camera: Camera2D
var score_label: Label

# Efectos de puntuación
var score_popup_scene: PackedScene

func _ready():
	# Intentar cargar escena de popup si existe
	if ResourceLoader.exists("res://scenes/ui/ScorePopup.tscn"):
		score_popup_scene = load("res://scenes/ui/ScorePopup.tscn")

func setup_score_ui_on_camera(camera: Camera2D):
	"""Configurar la UI de puntuación estilo COD Black Ops"""
	player_camera = camera
	if not player_camera:
		return
	
	score_ui = Control.new()
	score_ui.name = "ScoreUI"
	score_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	
	var is_mobile = OS.has_feature("mobile")
	var ui_size = Vector2(220, 80) if not is_mobile else Vector2(280, 100)
	score_ui.size = ui_size
	
	# Fondo estilo Black Ops
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.05, 0.05, 0.1, 0.85)
	bg_style.border_color = Color(0.8, 0.6, 0.0, 0.9)
	bg_style.border_width_left = 2
	bg_style.border_width_right = 2
	bg_style.border_width_top = 2
	bg_style.border_width_bottom = 2
	bg_style.corner_radius_top_left = 8
	bg_style.corner_radius_top_right = 8
	bg_style.corner_radius_bottom_left = 8
	bg_style.corner_radius_bottom_right = 8
	
	var bg_panel = Panel.new()
	bg_panel.size = ui_size
	bg_panel.add_theme_stylebox_override("panel", bg_style)
	score_ui.add_child(bg_panel)
	
	# Contenedor principal
	var main_container = VBoxContainer.new()
	main_container.add_theme_constant_override("separation", 5)
	main_container.position = Vector2(15, 10)
	main_container.size = Vector2(ui_size.x - 30, ui_size.y - 20)
	score_ui.add_child(main_container)
	
	# Título "PUNTOS" estilo Black Ops
	var title_label = Label.new()
	title_label.text = "PUNTOS"
	var title_size = 16 if not is_mobile else 20
	title_label.add_theme_font_size_override("font_size", title_size)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.0, 1.0))
	title_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	title_label.add_theme_constant_override("shadow_offset_x", 2)
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(title_label)
	
	# Etiqueta de puntuación grande
	score_label = Label.new()
	score_label.name = "ScoreLabel"
	score_label.text = "0"
	var score_font_size = 32 if not is_mobile else 40
	score_label.add_theme_font_size_override("font_size", score_font_size)
	score_label.add_theme_color_override("font_color", Color.WHITE)
	score_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	score_label.add_theme_constant_override("shadow_offset_x", 3)
	score_label.add_theme_constant_override("shadow_offset_y", 3)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(score_label)
	
	# Añadir a la cámara
	player_camera.add_child(score_ui)

func _process(_delta):
	"""Actualizar posición de la UI relativa a la cámara - INFERIOR DERECHA"""
	if score_ui and player_camera:
		var viewport_size = get_viewport().get_visible_rect().size
		var camera_zoom = player_camera.zoom
		
		# Calcular posición en la esquina INFERIOR DERECHA
		var ui_offset = Vector2(
			(viewport_size.x / camera_zoom.x) / 2 - score_ui.size.x - 20,
			(viewport_size.y / camera_zoom.y) / 2 - score_ui.size.y - 20
		)
		
		score_ui.position = ui_offset

func add_kill_points(hit_position: Vector2, is_headshot: bool = false, is_melee: bool = false):
	"""SISTEMA COD BO2: 50 puntos por hit, 100 por headshot, +130 por melee kill"""
	var points = 0
	var popup_type = "hit"
	
	# PUNTOS POR IMPACTO (NO POR KILL)
	if is_headshot:
		points = headshot_hit_points  # 100 puntos por headshot
		popup_type = "headshot"
		headshot_kills += 1
	else:
		points = base_hit_points      # 50 puntos por hit normal
		popup_type = "hit"
	
	# Bonus por melee kill (adicional a los puntos de impacto)
	if is_melee:
		points += melee_kill_bonus  # +130 puntos extra por melee
		popup_type = "melee"
	
	# Añadir puntos
	current_score += points
	current_kill_streak += 1
	
	if current_kill_streak > best_kill_streak:
		best_kill_streak = current_kill_streak
	
	# Actualizar UI
	update_score_ui()
	
	# Mostrar popup de puntuación
	show_score_popup(points, hit_position, popup_type)
	
	# Emitir señales
	score_changed.emit(current_score)
	score_popup.emit(points, hit_position, popup_type)

func add_enemy_kill():
	"""Registrar kill de enemigo (solo para estadísticas)"""
	total_kills += 1

func add_repair_points(repair_position: Vector2, repair_amount: int):
	"""Añadir puntos por reparar ventanas/barricadas"""
	var points = min(repair_amount * 10, max_window_repair_points)
	
	current_score += points
	update_score_ui()
	show_score_popup(points, repair_position, "repair")
	score_changed.emit(current_score)

func add_bonus_points(amount: int, position: Vector2, reason: String = "bonus"):
	"""Añadir puntos bonus por diversas razones"""
	current_score += amount
	update_score_ui()
	show_score_popup(amount, position, reason)
	score_changed.emit(current_score)

func reset_kill_streak():
	"""Resetear racha de kills (cuando el jugador recibe daño)"""
	current_kill_streak = 0

func show_score_popup(points: int, world_position: Vector2, popup_type: String):
	"""Mostrar popup de puntuación estilo Black Ops"""
	var popup = create_score_popup(points, popup_type)
	
	# Añadir al mundo
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
	
	# Color y tamaño según tipo estilo Black Ops
	var color = Color.WHITE
	var font_size = 28
	
	match popup_type:
		"headshot":
			color = Color(1.0, 0.8, 0.0, 1.0)  # Dorado brillante
			font_size = 32
			label.text = "+" + str(points)
		"melee":
			color = Color(1.0, 0.2, 0.2, 1.0)  # Rojo intenso
			font_size = 32
			label.text = "+" + str(points)
		"repair":
			color = Color(0.0, 0.8, 1.0, 1.0)  # Azul cyan
			font_size = 24
		"bonus":
			color = Color(0.2, 1.0, 0.2, 1.0)  # Verde brillante
			font_size = 26
		_:  # hit normal
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
	# Animación más dramática estilo Black Ops
	var tween = popup.create_tween()
	
	# Mover hacia arriba con curva
	var end_position = popup.global_position + Vector2(randf_range(-20, 20), -100)
	tween.parallel().tween_property(popup, "global_position", end_position, 1.8)
	
	# Escala de aparición más dramática
	popup.scale = Vector2.ZERO
	tween.parallel().tween_property(popup, "scale", Vector2(1.4, 1.4), 0.3)
	tween.parallel().tween_property(popup, "scale", Vector2(1.0, 1.0), 0.4)
	
	# Desvanecimiento gradual
	tween.parallel().tween_property(popup, "modulate:a", 0.0, 1.2)
	
	# Destruir al final
	tween.tween_callback(func(): popup.queue_free())

func update_score_ui():
	"""Actualizar la UI de puntuación estilo Black Ops"""
	if not score_label:
		return
	
	# Formatear puntuación con separadores de miles
	var formatted_score = format_score(current_score)
	score_label.text = formatted_score
	
	# Efecto de parpadeo dorado cuando se añaden puntos
	var flash_tween = score_ui.create_tween()
	score_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0, 1.0))  # Dorado
	flash_tween.tween_property(score_label, "modulate", Color.WHITE, 0.15)
	flash_tween.tween_callback(func(): 
		score_label.add_theme_color_override("font_color", Color.WHITE)
	)

func format_score(score: int) -> String:
	"""Formatear puntuación con separadores de miles estilo Black Ops"""
	var score_str = str(score)
	var formatted = ""
	var count = 0
	
	# Agregar comas cada 3 dígitos desde la derecha
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

func set_round_multiplier(round_number: int):
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
