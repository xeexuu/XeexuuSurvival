# scenes/managers/game_manager.gd
extends Node
class_name GameManager

@onready var level_manager = $LevelManager
@onready var player_manager = $PlayerManager
@onready var ui_manager = $UIManager

var current_level: int = 1
var game_state: String = "character_selection"
var player: Player
var mobile_controls: Control
var background_sprite: Sprite2D

# MENÚ DE PAUSA
var pause_menu: PauseMenu
var mobile_menu_button: MobileMenuButton

# Variables para controles móviles - JOYSTICKS MEJORADOS
var is_mobile: bool = false

# JOYSTICK DE MOVIMIENTO MEJORADO
var movement_joystick_base: Control
var movement_joystick_knob: Control
var movement_joystick_area: Control
var movement_joystick_center: Vector2
var movement_joystick_max_distance: float = 160.0
var movement_joystick_dead_zone: float = 25.0
var current_movement = Vector2.ZERO
var movement_touch_id: int = -1

# JOYSTICK DE DISPARO MEJORADO
var shooting_joystick_base: Control
var shooting_joystick_knob: Control
var shooting_joystick_area: Control
var shooting_joystick_center: Vector2
var shooting_joystick_max_distance: float = 140.0
var shooting_joystick_dead_zone: float = 20.0
var current_shoot_direction = Vector2.ZERO
var shoot_touch_id: int = -1
var is_shooting: bool = false

# Control de rendimiento
var last_movement_update: float = 0.0
var last_shooting_update: float = 0.0
var joystick_update_interval: float = 1.0 / 60.0

# Variables de selección de personaje
var selected_character_stats: CharacterStats
var game_started: bool = false

# SISTEMA DE ENEMIGOS Y RONDAS - UNIFICADO
var enemy_spawner: EnemySpawner
var rounds_manager: RoundsManager
var enemies_killed: int = 0

var mobile_process_counter: int = 0
var mobile_process_skip: int = 1

func _process(_delta):
	if not game_started:
		return
		
	if is_mobile and player:
		mobile_process_counter += 1
		if mobile_process_counter >= mobile_process_skip:
			mobile_process_counter = 0
			
			if current_movement.length() < 0.1:
				player.mobile_movement_direction = Vector2.ZERO
			else:
				player.mobile_movement_direction = current_movement
			
			if is_shooting and current_shoot_direction.length() > 0:
				player.mobile_shoot(current_shoot_direction)

func _ready():
	is_mobile = OS.has_feature("mobile")
	setup_background()
	setup_window()
	setup_pause_menu()
	
	await get_tree().process_frame
	show_character_selection()

func create_movement_joystick():
	if not mobile_controls:
		return
		
	var viewport_size = get_viewport().get_visible_rect().size
	
	movement_joystick_base = Control.new()
	movement_joystick_base.name = "MovementJoystickBase"
	movement_joystick_base.size = Vector2(400, 400)
	
	var margin_horizontal = 60
	var margin_vertical = 60
	movement_joystick_base.position = Vector2(margin_horizontal, viewport_size.y - margin_vertical - 400)
	movement_joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mobile_controls.add_child(movement_joystick_base)
	
	# Fondo del joystick
	var joystick_bg = ColorRect.new()
	joystick_bg.name = "MovementJoystickBackground"
	joystick_bg.size = Vector2(360, 360)
	joystick_bg.position = Vector2(20, 20)
	joystick_bg.color = Color(0.3, 0.3, 0.3, 0.2)
	joystick_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	movement_joystick_base.add_child(joystick_bg)
	
	# Borde del joystick
	var joystick_border = ColorRect.new()
	joystick_border.name = "MovementJoystickBorder"
	joystick_border.size = Vector2(360, 360)
	joystick_border.position = Vector2(20, 20)
	joystick_border.color = Color.TRANSPARENT
	var border_style = StyleBoxFlat.new()
	border_style.bg_color = Color.TRANSPARENT
	border_style.border_color = Color(0.7, 0.7, 0.7, 0.8)
	border_style.border_width_left = 4
	border_style.border_width_right = 4
	border_style.border_width_top = 4
	border_style.border_width_bottom = 4
	border_style.corner_radius_top_left = 180
	border_style.corner_radius_top_right = 180
	border_style.corner_radius_bottom_left = 180
	border_style.corner_radius_bottom_right = 180
	joystick_border.add_theme_stylebox_override("panel", border_style)
	joystick_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	movement_joystick_base.add_child(joystick_border)
	
	# Área tactil
	movement_joystick_area = Control.new()
	movement_joystick_area.name = "MovementJoystickArea"
	movement_joystick_area.size = Vector2(400, 400)
	movement_joystick_area.position = Vector2.ZERO
	movement_joystick_area.mouse_filter = Control.MOUSE_FILTER_PASS
	movement_joystick_base.add_child(movement_joystick_area)
	
	# Knob del joystick
	movement_joystick_knob = ColorRect.new()
	movement_joystick_knob.name = "MovementJoystickKnob"
	movement_joystick_knob.size = Vector2(120, 120)
	movement_joystick_knob.position = Vector2(140, 140)
	movement_joystick_knob.color = Color(0.2, 0.8, 1.0, 0.9)
	movement_joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var knob_style = StyleBoxFlat.new()
	knob_style.bg_color = Color(0.2, 0.8, 1.0, 0.9)
	knob_style.border_color = Color.WHITE
	knob_style.border_width_left = 2
	knob_style.border_width_right = 2
	knob_style.border_width_top = 2
	knob_style.border_width_bottom = 2
	knob_style.corner_radius_top_left = 60
	knob_style.corner_radius_top_right = 60
	knob_style.corner_radius_bottom_left = 60
	knob_style.corner_radius_bottom_right = 60
	movement_joystick_knob.add_theme_stylebox_override("panel", knob_style)
	
	movement_joystick_base.add_child(movement_joystick_knob)
	
	movement_joystick_center = movement_joystick_base.global_position + Vector2(200, 200)
	movement_joystick_max_distance = 160.0
	movement_joystick_dead_zone = 25.0
	
	# Etiqueta
	var move_label = Label.new()
	move_label.text = "MOVER"
	move_label.position = Vector2(150, 380)
	move_label.add_theme_font_size_override("font_size", 24)
	move_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
	move_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	move_label.add_theme_constant_override("shadow_offset_x", 2)
	move_label.add_theme_constant_override("shadow_offset_y", 2)
	move_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	movement_joystick_base.add_child(move_label)

func create_shooting_joystick():
	if not mobile_controls:
		return
		
	var viewport_size = get_viewport().get_visible_rect().size
	
	shooting_joystick_base = Control.new()
	shooting_joystick_base.name = "ShootingJoystickBase"
	shooting_joystick_base.size = Vector2(400, 400)
	
	var margin_horizontal = 60
	var margin_vertical = 60
	shooting_joystick_base.position = Vector2(viewport_size.x - margin_horizontal - 400, viewport_size.y - margin_vertical - 400)
	shooting_joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mobile_controls.add_child(shooting_joystick_base)
	
	# Fondo del joystick de disparo
	var shooting_bg = ColorRect.new()
	shooting_bg.name = "ShootingJoystickBackground"
	shooting_bg.size = Vector2(360, 360)
	shooting_bg.position = Vector2(20, 20)
	shooting_bg.color = Color(0.8, 0.3, 0.3, 0.2)
	shooting_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shooting_joystick_base.add_child(shooting_bg)
	
	# Borde del joystick de disparo
	var shooting_border = ColorRect.new()
	shooting_border.name = "ShootingJoystickBorder"
	shooting_border.size = Vector2(360, 360)
	shooting_border.position = Vector2(20, 20)
	shooting_border.color = Color.TRANSPARENT
	var border_style = StyleBoxFlat.new()
	border_style.bg_color = Color.TRANSPARENT
	border_style.border_color = Color(1.0, 0.5, 0.5, 0.8)
	border_style.border_width_left = 4
	border_style.border_width_right = 4
	border_style.border_width_top = 4
	border_style.border_width_bottom = 4
	border_style.corner_radius_top_left = 180
	border_style.corner_radius_top_right = 180
	border_style.corner_radius_bottom_left = 180
	border_style.corner_radius_bottom_right = 180
	shooting_border.add_theme_stylebox_override("panel", border_style)
	shooting_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shooting_joystick_base.add_child(shooting_border)
	
	# Área tactil para disparo
	shooting_joystick_area = Control.new()
	shooting_joystick_area.name = "ShootingJoystickArea"
	shooting_joystick_area.size = Vector2(400, 400)
	shooting_joystick_area.position = Vector2.ZERO
	shooting_joystick_area.mouse_filter = Control.MOUSE_FILTER_PASS
	shooting_joystick_base.add_child(shooting_joystick_area)
	
	# Knob de disparo
	shooting_joystick_knob = ColorRect.new()
	shooting_joystick_knob.name = "ShootingJoystickKnob"
	shooting_joystick_knob.size = Vector2(120, 120)
	shooting_joystick_knob.position = Vector2(140, 140)
	shooting_joystick_knob.color = Color(1.0, 0.5, 0.2, 0.9)
	shooting_joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var knob_style = StyleBoxFlat.new()
	knob_style.bg_color = Color(1.0, 0.5, 0.2, 0.9)
	knob_style.border_color = Color.WHITE
	knob_style.border_width_left = 2
	knob_style.border_width_right = 2
	knob_style.border_width_top = 2
	knob_style.border_width_bottom = 2
	knob_style.corner_radius_top_left = 60
	knob_style.corner_radius_top_right = 60
	knob_style.corner_radius_bottom_left = 60
	knob_style.corner_radius_bottom_right = 60
	shooting_joystick_knob.add_theme_stylebox_override("panel", knob_style)
	
	shooting_joystick_base.add_child(shooting_joystick_knob)
	
	shooting_joystick_center = shooting_joystick_base.global_position + Vector2(200, 200)
	shooting_joystick_max_distance = 140.0
	shooting_joystick_dead_zone = 20.0
	
	# Etiqueta
	var shoot_label = Label.new()
	shoot_label.text = "DISPARAR"
	shoot_label.position = Vector2(140, 380)
	shoot_label.add_theme_font_size_override("font_size", 24)
	shoot_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
	shoot_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	shoot_label.add_theme_constant_override("shadow_offset_x", 2)
	shoot_label.add_theme_constant_override("shadow_offset_y", 2)
	shoot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shooting_joystick_base.add_child(shoot_label)

func _input(event):
	# MEJOR DETECCIÓN DEL MENÚ PARA ANDROID
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.keycode == KEY_ESCAPE):
		if game_started and game_state == "playing":
			toggle_pause_menu()
		return
	
	# Para Android, detectar el botón de back del sistema
	if is_mobile and event is InputEventKey and event.keycode == KEY_BACK:
		if game_started and game_state == "playing":
			toggle_pause_menu()
		return
	
	if event.is_action_pressed("toggle_fullscreen"):
		toggle_fullscreen()
	
	if not is_mobile or not game_started:
		return
	
	if event is InputEventScreenTouch:
		handle_touch_event(event)
	elif event is InputEventScreenDrag:
		handle_drag_event(event)

func handle_touch_event(event: InputEventScreenTouch):
	var touch_pos = event.position
	var touch_id = event.index
	
	if event.pressed:
		if movement_joystick_area and is_point_in_control(touch_pos, movement_joystick_area):
			if movement_touch_id == -1:
				movement_touch_id = touch_id
				handle_movement_joystick(touch_pos, true)
		
		elif shooting_joystick_area and is_point_in_control(touch_pos, shooting_joystick_area):
			if shoot_touch_id == -1:
				shoot_touch_id = touch_id
				handle_shooting_joystick(touch_pos, true)
	else:
		if touch_id == movement_touch_id:
			movement_touch_id = -1
			reset_movement_joystick()
		elif touch_id == shoot_touch_id:
			shoot_touch_id = -1
			reset_shooting_joystick()

func handle_drag_event(event: InputEventScreenDrag):
	var touch_id = event.index
	var touch_pos = event.position
	
	var current_time = Time.get_ticks_msec() / 1000.0
	
	if touch_id == movement_touch_id:
		if current_time - last_movement_update >= joystick_update_interval:
			handle_movement_joystick(touch_pos, true)
			last_movement_update = current_time
	elif touch_id == shoot_touch_id:
		if current_time - last_shooting_update >= joystick_update_interval:
			handle_shooting_joystick(touch_pos, true)
			last_shooting_update = current_time

func is_point_in_control(point: Vector2, control: Control) -> bool:
	if not control:
		return false
	var control_rect = Rect2(control.global_position, control.size)
	return control_rect.has_point(point)

func handle_movement_joystick(touch_pos: Vector2, pressed: bool):
	if not movement_joystick_base or not movement_joystick_knob:
		return
	
	if pressed:
		var offset = touch_pos - movement_joystick_center
		var distance = offset.length()
		
		if distance > movement_joystick_max_distance:
			offset = offset.normalized() * movement_joystick_max_distance
			distance = movement_joystick_max_distance
		
		movement_joystick_knob.position = Vector2(140, 140) + offset
		
		if distance > movement_joystick_dead_zone:
			var strength = (distance - movement_joystick_dead_zone) / (movement_joystick_max_distance - movement_joystick_dead_zone)
			strength = min(strength, 1.0)
			current_movement = offset.normalized() * strength
		else:
			current_movement = Vector2.ZERO

func reset_movement_joystick():
	if movement_joystick_knob:
		movement_joystick_knob.position = Vector2(140, 140)
	current_movement = Vector2.ZERO

func handle_shooting_joystick(touch_pos: Vector2, pressed: bool):
	if not shooting_joystick_base or not shooting_joystick_knob:
		return
	
	if pressed:
		var offset = touch_pos - shooting_joystick_center
		var distance = offset.length()
		
		if distance > shooting_joystick_max_distance:
			offset = offset.normalized() * shooting_joystick_max_distance
			distance = shooting_joystick_max_distance
		
		shooting_joystick_knob.position = Vector2(140, 140) + offset
		
		if distance > shooting_joystick_dead_zone:
			var strength = (distance - shooting_joystick_dead_zone) / (shooting_joystick_max_distance - shooting_joystick_dead_zone)
			strength = min(strength, 1.0)
			current_shoot_direction = offset.normalized()
			is_shooting = true
		else:
			current_shoot_direction = Vector2.ZERO
			is_shooting = false
	else:
		reset_shooting_joystick()

func reset_shooting_joystick():
	if shooting_joystick_knob:
		shooting_joystick_knob.position = Vector2(140, 140)
	current_shoot_direction = Vector2.ZERO
	is_shooting = false

func toggle_fullscreen():
	var current_mode = DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func toggle_pause_menu():
	if pause_menu.is_paused:
		pause_menu.hide_menu()
	else:
		pause_menu.show_menu()

func _on_mobile_menu_pressed():
	toggle_pause_menu()

func _on_resume_game():
	resume_enemy_spawning()

func _on_restart_game():
	clear_all_enemies()
	enemies_killed = 0
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_quit_game():
	clear_all_enemies()
	get_tree().paused = false
	get_tree().quit()

func setup_pause_menu():
	pause_menu = preload("res://scenes/ui/PauseMenu.tscn").instantiate()
	pause_menu.resume_game.connect(_on_resume_game)
	pause_menu.restart_game.connect(_on_restart_game)
	pause_menu.quit_game.connect(_on_quit_game)
	ui_manager.add_child(pause_menu)
	
	# SIEMPRE CREAR EL BOTÓN DE MENÚ MÓVIL, INDEPENDIENTEMENTE DE LA PLATAFORMA
	if is_mobile:
		mobile_menu_button = MobileMenuButton.new()
		mobile_menu_button.menu_pressed.connect(_on_mobile_menu_pressed)
		ui_manager.add_child(mobile_menu_button)

func show_character_selection():
	var character_selection = preload("res://scenes/ui/CharacterSelection.tscn").instantiate()
	character_selection.character_selected.connect(_on_character_selected)
	ui_manager.add_child(character_selection)
	
	if player_manager.get_child_count() > 0:
		player = player_manager.get_child(0) as Player
		if player:
			player.set_physics_process(false)
			player.set_process(false)

func _on_character_selected(character_stats: CharacterStats):
	selected_character_stats = character_stats
	game_state = "playing"
	
	setup_player()
	if is_mobile:
		setup_mobile_controls()
	
	setup_mini_hud()
	setup_unified_cod_system()  # NUEVO: Sistema unificado COD
	
	if player:
		player.set_physics_process(true)
		player.set_process(true)
	
	game_started = true

func setup_background():
	background_sprite = Sprite2D.new()
	background_sprite.name = "Background"
	background_sprite.z_index = -100
	
	var jungle_texture = load("res://sprites/background/jungle.png")
	if jungle_texture:
		background_sprite.texture = jungle_texture
		background_sprite.position = Vector2(0, 0)
		
		var texture_size = jungle_texture.get_size()
		var scale_factor_x = 1600.0 / float(texture_size.x)
		var scale_factor_y = 1600.0 / float(texture_size.y)
		background_sprite.scale = Vector2(scale_factor_x, scale_factor_y)
		
		add_child(background_sprite)
	else:
		var temp_bg = ColorRect.new()
		temp_bg.color = Color(0.2, 0.4, 0.2)
		temp_bg.size = Vector2(1600, 1600)
		temp_bg.position = Vector2(-800, -800)
		temp_bg.z_index = -100
		add_child(temp_bg)

func setup_window():
	if is_mobile:
		# PERMITIR ROTACIÓN EN MÓVIL
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		# Permitir ambas orientaciones
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
		get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	
	get_viewport().size_changed.connect(_on_viewport_resized)

func _on_viewport_resized():
	await get_tree().process_frame
	update_mobile_controls_position()

func update_mobile_controls_position():
	if mobile_controls and is_mobile:
		var viewport_size = get_viewport().get_visible_rect().size
		mobile_controls.size = viewport_size
		mobile_controls.position = Vector2.ZERO
		
		var margin_horizontal = 60
		var margin_vertical = 60
		
		if movement_joystick_base:
			movement_joystick_base.position = Vector2(margin_horizontal, viewport_size.y - margin_vertical - 400)
			movement_joystick_center = movement_joystick_base.global_position + Vector2(200, 200)
		
		if shooting_joystick_base:
			shooting_joystick_base.position = Vector2(viewport_size.x - margin_horizontal - 400, viewport_size.y - margin_vertical - 400)
			shooting_joystick_center = shooting_joystick_base.global_position + Vector2(200, 200)

func setup_player():
	if player_manager.get_child_count() > 0:
		player = player_manager.get_child(0) as Player
		if player:
			if selected_character_stats:
				player.update_character_stats(selected_character_stats)
			
			player.global_position = Vector2(0, 0)
			player.z_index = 10

func setup_mini_hud():
	var mini_hud = preload("res://scenes/ui/MiniHUD.tscn").instantiate()
	ui_manager.add_child(mini_hud)
	
	if player and player.character_stats:
		mini_hud.update_character_stats(player.character_stats)

func setup_mobile_controls():
	if not is_mobile:
		return
	
	mobile_controls = Control.new()
	mobile_controls.name = "MobileControls"
	mobile_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mobile_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_manager.add_child(mobile_controls)
	
	await get_tree().process_frame
	
	create_movement_joystick()
	create_shooting_joystick()

# SISTEMA UNIFICADO COD ZOMBIES
func setup_unified_cod_system():
	"""Configurar el sistema completo estilo COD Zombies"""
	if not player:
		return
	
	# 1. Crear RoundsManager
	rounds_manager = RoundsManager.new()
	rounds_manager.name = "RoundsManager"
	add_child(rounds_manager)
	
	# 2. Configurar UI de rondas en la cámara del jugador
	if player.camera:
		rounds_manager.setup_round_ui_on_camera(player.camera)
	
	# 3. Crear EnemySpawner
	enemy_spawner = EnemySpawner.new()
	enemy_spawner.name = "EnemySpawner"
	enemy_spawner.spawn_radius_min = 400.0
	enemy_spawner.spawn_radius_max = 800.0
	enemy_spawner.despawn_distance = 1200.0
	add_child(enemy_spawner)
	
	# 4. Conectar sistemas
	enemy_spawner.setup(player, rounds_manager)
	rounds_manager.set_enemy_spawner(enemy_spawner)
	
	# 5. Conectar señales
	enemy_spawner.enemy_killed.connect(_on_enemy_killed)
	enemy_spawner.enemy_spawned.connect(_on_enemy_spawned)
	
	# 6. Iniciar primera ronda
	rounds_manager.start_round(1)

func _on_enemy_killed(_enemy: Enemy):
	"""Cuando se mata un enemigo"""
	enemies_killed += 1
	
	# Notificar al rounds manager
	rounds_manager.on_enemy_killed()

func _on_enemy_spawned(_enemy: Enemy):
	"""Cuando se spawnea un enemigo"""
	# Notificar al rounds manager
	rounds_manager.on_enemy_spawned()

func pause_enemy_spawning():
	"""Pausar el spawn de enemigos"""
	if enemy_spawner:
		enemy_spawner.pause_spawning()

func resume_enemy_spawning():
	"""Reanudar el spawn de enemigos"""
	if enemy_spawner:
		enemy_spawner.resume_spawning()

func clear_all_enemies():
	"""Limpiar todos los enemigos"""
	if enemy_spawner:
		enemy_spawner.clear_all_enemies()

func get_active_enemy_count() -> int:
	"""Obtener número de enemigos activos"""
	if enemy_spawner:
		return enemy_spawner.get_active_enemy_count()
	return 0
