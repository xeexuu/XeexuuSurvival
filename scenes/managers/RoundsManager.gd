# scenes/managers/RoundsManager.gd
extends Node
class_name RoundsManager

signal round_changed(new_round: int)
signal enemies_remaining_changed(remaining: int)

var current_round: int = 1
var enemies_remaining_in_round: int = 0
var total_enemies_spawned: int = 0
var enemies_killed_in_round: int = 0

# Variables de configuración estilo COD zombies
var base_enemies_per_round: int = 6
var enemies_multiplier_per_round: float = 1.25

# Sistema de salud de enemigos estilo COD
var base_enemy_health: int = 150

# UI de rondas - AHORA EN CÁMARA
var round_ui: Control
var player_camera: Camera2D

# Referencias
var enemy_spawner: EnemySpawner

func _ready():
	pass

func setup_round_ui_on_camera(camera: Camera2D):
	"""Configurar la UI de rondas en la esquina de la cámara del personaje"""
	player_camera = camera
	if not player_camera:
		return
	
	round_ui = Control.new()
	round_ui.name = "RoundUI"
	round_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	
	var is_mobile = OS.has_feature("mobile")
	var ui_size = Vector2(240, 100) if not is_mobile else Vector2(320, 130)
	round_ui.size = ui_size
	
	# Posición relativa a la cámara (esquina superior derecha)
	round_ui.position = Vector2(0, 0)  # Será actualizada en _process
	
	# Fondo semi-transparente
	var bg = ColorRect.new()
	bg.size = ui_size
	bg.color = Color(0.0, 0.0, 0.0, 0.8)
	var style = create_round_panel_style()
	bg.add_theme_stylebox_override("panel", style)
	round_ui.add_child(bg)
	
	# Contenedor vertical
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.position = Vector2(15, 10)
	vbox.size = Vector2(ui_size.x - 30, ui_size.y - 20)
	round_ui.add_child(vbox)
	
	# Etiqueta de ronda
	var round_label = Label.new()
	round_label.name = "RoundLabel"
	round_label.text = "RONDA 1"
	var round_font_size = 28 if not is_mobile else 36
	round_label.add_theme_font_size_override("font_size", round_font_size)
	round_label.add_theme_color_override("font_color", Color.ORANGE)
	round_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	round_label.add_theme_constant_override("shadow_offset_x", 2)
	round_label.add_theme_constant_override("shadow_offset_y", 2)
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(round_label)
	
	# Etiqueta de enemigos restantes
	var enemies_label = Label.new()
	enemies_label.name = "EnemiesLabel"
	enemies_label.text = "Zombies: 6"
	var enemies_font_size = 20 if not is_mobile else 26
	enemies_label.add_theme_font_size_override("font_size", enemies_font_size)
	enemies_label.add_theme_color_override("font_color", Color.RED)
	enemies_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	enemies_label.add_theme_constant_override("shadow_offset_x", 1)
	enemies_label.add_theme_constant_override("shadow_offset_y", 1)
	enemies_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(enemies_label)
	
	# Añadir a la cámara
	player_camera.add_child(round_ui)

func _process(_delta):
	"""Actualizar posición de la UI relativa a la cámara"""
	if round_ui and player_camera:
		var viewport_size = get_viewport().get_visible_rect().size
		var camera_zoom = player_camera.zoom
		
		# Calcular posición en la esquina superior derecha de la cámara
		var ui_offset = Vector2(
			(viewport_size.x / camera_zoom.x) / 2 - round_ui.size.x - 20,
			-(viewport_size.y / camera_zoom.y) / 2 + 20
		)
		
		round_ui.position = ui_offset

func create_round_panel_style() -> StyleBoxFlat:
	"""Crear estilo para el panel de ronda"""
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_color = Color(1.0, 0.5, 0.0, 0.9)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	return style

func set_enemy_spawner(spawner: EnemySpawner):
	"""Establecer referencia al spawner de enemigos"""
	enemy_spawner = spawner
	if enemy_spawner:
		enemy_spawner.round_complete.connect(_on_round_complete)

func start_round(round_number: int):
	"""Iniciar una nueva ronda"""
	current_round = round_number
	
	# Calcular número de enemigos para esta ronda
	var enemies_this_round = calculate_enemies_for_round(current_round)
	enemies_remaining_in_round = enemies_this_round
	total_enemies_spawned = 0
	enemies_killed_in_round = 0
	
	# Actualizar UI
	update_round_ui()
	
	# Mostrar mensaje de nueva ronda
	show_round_start_message()
	
	# Emitir señal
	round_changed.emit(current_round)
	
	# Iniciar spawn de enemigos
	if enemy_spawner:
		var enemy_health = calculate_enemy_health_for_round(current_round)
		enemy_spawner.start_round(enemies_this_round, enemy_health)

func calculate_enemies_for_round(round_num: int) -> int:
	"""Calcular número de enemigos para una ronda específica"""
	if round_num == 1:
		return base_enemies_per_round
	
	var enemies = int(float(base_enemies_per_round) * pow(enemies_multiplier_per_round, round_num - 1))
	return min(enemies, 50)  # Máximo 50 enemigos por ronda

func calculate_enemy_health_for_round(round_num: int) -> int:
	"""Calcular la salud de los enemigos para una ronda específica - Estilo COD"""
	if round_num <= 9:
		# Rondas 1-9: Empezar en 150 y ganar 100 por ronda
		return base_enemy_health + ((round_num - 1) * 100)
	else:
		# Ronda 10+: Multiplicar por 1.1 por cada ronda adicional
		var round_9_health = base_enemy_health + (8 * 100)  # 950 de salud en ronda 9
		var additional_rounds = round_num - 9
		return int(float(round_9_health) * pow(1.1, additional_rounds))

func on_enemy_killed():
	"""Llamar cuando un enemigo es eliminado"""
	enemies_killed_in_round += 1
	enemies_remaining_in_round = max(0, enemies_remaining_in_round - 1)
	
	# Actualizar UI INMEDIATAMENTE
	call_deferred("update_enemies_ui")
	
	enemies_remaining_changed.emit(enemies_remaining_in_round)

func on_enemy_spawned():
	"""Llamar cuando un enemigo es spawneado"""
	total_enemies_spawned += 1
	# Actualizar UI cuando se spawnea
	call_deferred("update_enemies_ui")

func _on_round_complete():
	"""Cuando el spawner confirma que la ronda está completa"""
	await get_tree().create_timer(2.0).timeout
	
	# Mostrar mensaje de ronda completada
	show_round_complete_message()
	
	await get_tree().create_timer(3.0).timeout
	
	# Iniciar siguiente ronda
	start_round(current_round + 1)

func show_round_start_message():
	"""Mostrar mensaje de inicio de ronda"""
	var message = create_round_message("RONDA " + str(current_round), Color.ORANGE, 3.0)
	show_message(message)

func show_round_complete_message():
	"""Mostrar mensaje de ronda completada"""
	var message = create_round_message("RONDA " + str(current_round) + " COMPLETADA", Color.GREEN, 2.0)
	show_message(message)

func create_round_message(text: String, color: Color, duration: float) -> Control:
	"""Crear mensaje de ronda centrado en pantalla"""
	var message_container = Control.new()
	message_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	message_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var message_label = Label.new()
	message_label.text = text
	message_label.add_theme_font_size_override("font_size", 48 if not OS.has_feature("mobile") else 64)
	message_label.add_theme_color_override("font_color", color)
	message_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	message_label.add_theme_constant_override("shadow_offset_x", 4)
	message_label.add_theme_constant_override("shadow_offset_y", 4)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	message_container.add_child(message_label)
	
	# Animación de aparición
	message_label.modulate = Color.TRANSPARENT
	var tween = message_container.create_tween()
	tween.tween_property(message_label, "modulate", Color.WHITE, 0.5)
	tween.tween_interval(duration - 1.0)
	tween.tween_property(message_label, "modulate", Color.TRANSPARENT, 0.5)
	tween.tween_callback(func(): message_container.queue_free())
	
	return message_container

func show_message(message: Control):
	"""Mostrar mensaje en pantalla"""
	get_tree().current_scene.add_child(message)

func update_round_ui():
	"""Actualizar toda la UI de ronda"""
	if not round_ui:
		return
	
	var round_label = round_ui.find_child("RoundLabel")
	if round_label:
		round_label.text = "RONDA " + str(current_round)
	
	update_enemies_ui()

func update_enemies_ui():
	"""Actualizar solo la UI de enemigos restantes"""
	if not round_ui:
		return
	
	var enemies_label = round_ui.find_child("EnemiesLabel")
	if enemies_label:
		# Mostrar enemigos vivos + enemigos por spawnear
		var active_count = enemy_spawner.get_active_enemy_count() if enemy_spawner else 0
		var to_spawn = enemy_spawner.get_enemies_remaining_to_spawn() if enemy_spawner else 0
		var total_remaining = active_count + to_spawn
		
		enemies_label.text = "Zombies: " + str(total_remaining)
		
		# Cambiar color según enemigos restantes
		if total_remaining <= 1:
			enemies_label.add_theme_color_override("font_color", Color.GREEN)
		elif total_remaining <= 5:
			enemies_label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			enemies_label.add_theme_color_override("font_color", Color.RED)

func get_current_round() -> int:
	"""Obtener la ronda actual"""
	return current_round

func get_enemies_remaining() -> int:
	"""Obtener enemigos restantes en la ronda"""
	if enemy_spawner:
		return enemy_spawner.get_active_enemy_count() + enemy_spawner.get_enemies_remaining_to_spawn()
	return enemies_remaining_in_round

func get_enemy_health_for_current_round() -> int:
	"""Obtener la salud de enemigos para la ronda actual"""
	return calculate_enemy_health_for_round(current_round)
