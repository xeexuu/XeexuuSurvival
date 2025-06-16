# scenes/managers/game_manager.gd - CON NUEVO SISTEMA DE ANIMACIONES SIN DUPLICACIONES
extends Node
class_name GameManager

@onready var level_manager = $LevelManager
@onready var player_manager = $PlayerManager
@onready var ui_manager = $UIManager

var current_level: int = 1
var game_state: String = "character_selection"
var player: CharacterBody2D
var mobile_controls: Control
var background_sprite: Sprite2D

# UI FIJA
var fixed_ui_manager: FixedUIManager

# Menú de pausa
var pause_menu: PauseMenu
var mobile_menu_button: MobileMenuButton

# Sistema de paredes
var wall_system: WallSystem

# Variables móviles
var is_mobile: bool = false

# Joysticks móviles
var movement_joystick_base: Control
var movement_joystick_knob: Control
var movement_joystick_area: TouchScreenButton
var movement_joystick_center: Vector2

var current_movement = Vector2.ZERO
var movement_touch_id: int = -1

var shooting_joystick_base: Control
var shooting_joystick_knob: Control
var shooting_joystick_area: TouchScreenButton
var shooting_joystick_center: Vector2

var current_shoot_direction = Vector2.ZERO
var shoot_touch_id: int = -1
var is_shooting: bool = false

var movement_joystick_max_distance: float = 200.0
var movement_joystick_dead_zone: float = 30.0
var shooting_joystick_max_distance: float = 180.0
var shooting_joystick_dead_zone: float = 30.0

# Variables de juego
var selected_character_stats: CharacterStats
var game_started: bool = false

# Sistemas de juego
var enemy_spawner: EnemySpawner
var rounds_manager: RoundsManager
var score_system: ScoreSystem
var enemies_killed: int = 0

# Game Over
var game_over_screen: Control
var is_game_over: bool = false

# Controlador de animaciones
var animation_controller: AnimationController

func _ready():
	add_to_group("game_manager")
	is_mobile = OS.has_feature("mobile") or OS.get_name() == "Android" or OS.get_name() == "iOS"
	
	setup_collision_layers()
	setup_background()
	setup_window()
	setup_pause_menu()
	setup_wall_system()
	setup_fixed_ui()
	
	await get_tree().process_frame
	show_character_selection()

func setup_wall_system():
	"""Configurar sistema de paredes"""
	wall_system = WallSystem.new()
	wall_system.name = "WallSystem"
	add_child(wall_system)

func setup_fixed_ui():
	"""Configurar UI fija"""
	fixed_ui_manager = FixedUIManager.new()
	fixed_ui_manager.name = "FixedUIManager"
	add_child(fixed_ui_manager)

func setup_collision_layers():
	"""Configurar capas de colisión"""
	# Capa 1: Jugador
	# Capa 2: Enemigos  
	# Capa 3: Paredes
	# Capa 4: Proyectiles
	pass

func _input(event):
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.keycode == KEY_ESCAPE):
		if game_started and game_state == "playing" and not is_game_over:
			toggle_pause_menu()
		return
	
	if event is InputEventKey and event.keycode == KEY_BACK:
		if game_started and game_state == "playing" and not is_game_over:
			toggle_pause_menu()
		return
	
	if event.is_action_pressed("toggle_fullscreen"):
		toggle_fullscreen()
	
	# DEBUG: Tecla F1 para depurar animaciones
	if event.is_action_pressed("ui_accept") and Input.is_key_pressed(KEY_F1):
		debug_animation_system()
	
	# DEBUG: Tecla F2 para resetear animaciones
	if event.is_action_pressed("ui_accept") and Input.is_key_pressed(KEY_F2):
		reset_animation_system()
	
	if not is_mobile or not game_started or game_state != "playing":
		return
	
	if event is InputEventScreenTouch:
		handle_touch_event(event)
	elif event is InputEventScreenDrag:
		handle_drag_event(event)

func _physics_process(_delta):
	"""Aplicar movimiento móvil"""
	if is_mobile and player:
		player.mobile_movement_direction = current_movement
		
		if is_shooting:
			player.mobile_shoot_direction = current_shoot_direction
			player.mobile_is_shooting = true
		else:
			player.mobile_is_shooting = false

func show_character_selection():
	"""Mostrar selección de personaje"""
	var character_selection = preload("res://scenes/ui/CharacterSelection.tscn").instantiate()
	character_selection.character_selected.connect(_on_character_selected)
	ui_manager.add_child(character_selection)
	
	if player_manager.get_child_count() > 0:
		player = player_manager.get_child(0)
		if player:
			player.set_physics_process(false)
			player.set_process(false)
			player.visible = false

func _on_character_selected(character_stats: CharacterStats):
	"""Cuando se selecciona personaje"""
	selected_character_stats = character_stats
	game_state = "playing"
	
	setup_player_after_selection()
	
	if not player or player.get_current_health() <= 0:
		return
	
	if is_mobile:
		setup_mobile_controls()
	
	await setup_unified_cod_system_safe()
	
	if player:
		player.visible = true
		player.current_health = selected_character_stats.current_health
		player.max_health = selected_character_stats.max_health
		
		setup_player_collision_layers()
		setup_new_animation_system()  # NUEVO SISTEMA
		
		player.set_physics_process(true)
		player.set_process(true)
		
		if not player.player_died.is_connected(_on_player_died):
			player.player_died.connect(_on_player_died)
	
	game_started = true
	
	await get_tree().create_timer(3.0).timeout
	start_enemy_spawning_safely()

func setup_new_animation_system():
	"""CONFIGURAR NUEVO SISTEMA DE ANIMACIONES BASADO EN MOVIMIENTO"""
	if not player or not player.animated_sprite:
		print("❌ No se puede configurar animaciones: falta player o sprite")
		return
	
	print("🎭 Configurando NUEVO sistema de animaciones...")
	
	# CREAR CONTROLADOR DE ANIMACIONES
	animation_controller = AnimationController.new()
	animation_controller.name = "AnimationController"
	player.add_child(animation_controller)
	
	# CONFIGURAR EL CONTROLADOR
	animation_controller.setup(player.animated_sprite, selected_character_stats.character_name)
	
	# ASIGNAR AL JUGADOR
	player.set_animation_controller(animation_controller)
	
	print("✅ NUEVO sistema de animaciones configurado para: ", selected_character_stats.character_name)

func setup_player_collision_layers():
	"""Configurar colisiones del jugador"""
	if not player:
		return
	
	player.collision_layer = 1
	player.collision_mask = 2 | 3

func setup_player_after_selection():
	"""Configurar jugador"""
	if player_manager.get_child_count() > 0:
		player = player_manager.get_child(0)
		if player:
			if selected_character_stats:
				player.update_character_stats(selected_character_stats)
			
			player.global_position = Vector2(0, 0)
			player.z_index = 10
			player.velocity = Vector2.ZERO

func setup_unified_cod_system_safe():
	"""Configurar sistemas COD"""
	if not player:
		return
	
	# ScoreSystem
	score_system = ScoreSystem.new()
	score_system.name = "ScoreSystem"
	add_child(score_system)
	
	# RoundsManager
	rounds_manager = RoundsManager.new()
	rounds_manager.name = "RoundsManager"
	add_child(rounds_manager)
	
	# Conectar con UI fija
	if fixed_ui_manager:
		fixed_ui_manager.set_score_system(score_system)
		fixed_ui_manager.set_rounds_manager(rounds_manager)
		fixed_ui_manager.set_player_reference(player)
	
	# EnemySpawner
	enemy_spawner = EnemySpawner.new()
	enemy_spawner.name = "EnemySpawner"
	enemy_spawner.spawn_radius_min = 400.0
	enemy_spawner.spawn_radius_max = 800.0
	enemy_spawner.despawn_distance = 1200.0
	add_child(enemy_spawner)
	
	# Conectar sistemas
	enemy_spawner.setup(player, rounds_manager)
	rounds_manager.set_enemy_spawner(enemy_spawner)
	
	enemy_spawner.enemy_killed.connect(_on_enemy_killed)
	enemy_spawner.enemy_spawned.connect(_on_enemy_spawned)
	
	rounds_manager.round_changed.connect(_on_round_changed)
	rounds_manager.enemies_remaining_changed.connect(_on_enemies_remaining_changed)
	
	player.set_score_system(score_system)
	
	rounds_manager.start_round(1)

func _on_round_changed(new_round: int):
	"""Actualizar ronda"""
	if score_system:
		score_system.set_current_round(new_round)

func _on_enemies_remaining_changed(_remaining: int):
	"""Enemigos restantes cambiados"""
	pass

func start_enemy_spawning_safely():
	"""Iniciar spawning"""
	if not rounds_manager or not enemy_spawner:
		return
	
	if not player or not player.is_alive() or not player.is_fully_initialized:
		return
	
	rounds_manager.manually_start_spawning()

# ===== CONTROLES MÓVILES =====

func handle_touch_event(event: InputEventScreenTouch):
	"""Manejar toques"""
	var touch_pos = event.position
	var touch_id = event.index
	
	if event.pressed:
		if movement_joystick_area and is_point_in_expanded_area(touch_pos, movement_joystick_area):
			if movement_touch_id == -1:
				movement_touch_id = touch_id
				handle_movement_joystick(touch_pos)
		elif shooting_joystick_area and is_point_in_expanded_area(touch_pos, shooting_joystick_area):
			if shoot_touch_id == -1:
				shoot_touch_id = touch_id
				handle_shooting_joystick(touch_pos)
	else:
		if touch_id == movement_touch_id:
			movement_touch_id = -1
			reset_movement_joystick()
		elif touch_id == shoot_touch_id:
			shoot_touch_id = -1
			reset_shooting_joystick()

func handle_drag_event(event: InputEventScreenDrag):
	"""Manejar arrastre"""
	var touch_id = event.index
	var touch_pos = event.position
	
	if touch_id == movement_touch_id:
		handle_movement_joystick(touch_pos)
	elif touch_id == shoot_touch_id:
		handle_shooting_joystick(touch_pos)

func is_point_in_expanded_area(point: Vector2, area: TouchScreenButton) -> bool:
	"""Verificar punto en área"""
	if not area or not area.shape:
		return false
	
	var global_rect = Rect2(area.global_position, area.shape.size)
	return global_rect.has_point(point)

func handle_movement_joystick(touch_pos: Vector2):
	"""Manejar joystick movimiento"""
	if not movement_joystick_base or not movement_joystick_knob:
		return
	
	var offset = touch_pos - movement_joystick_center
	var distance = offset.length()
	
	if distance > movement_joystick_max_distance:
		offset = offset.normalized() * movement_joystick_max_distance
		distance = movement_joystick_max_distance
	
	movement_joystick_knob.position = Vector2(movement_joystick_max_distance, movement_joystick_max_distance) + offset
	
	if distance > movement_joystick_dead_zone:
		var strength = (distance - movement_joystick_dead_zone) / (movement_joystick_max_distance - movement_joystick_dead_zone)
		strength = min(strength, 1.0)
		current_movement = offset.normalized() * strength
	else:
		current_movement = Vector2.ZERO
		if player:
			player.mobile_movement_direction = Vector2.ZERO

func handle_shooting_joystick(touch_pos: Vector2):
	"""Manejar joystick disparo"""
	if not shooting_joystick_base or not shooting_joystick_knob:
		return
	
	var offset = touch_pos - shooting_joystick_center
	var distance = offset.length()
	
	if distance > shooting_joystick_max_distance:
		offset = offset.normalized() * shooting_joystick_max_distance
		distance = shooting_joystick_max_distance
	
	shooting_joystick_knob.position = Vector2(shooting_joystick_max_distance, shooting_joystick_max_distance) + offset
	
	if distance > shooting_joystick_dead_zone:
		current_shoot_direction = offset.normalized()
		is_shooting = true
		if player:
			player.mobile_shoot_direction = current_shoot_direction
			player.mobile_is_shooting = true
	else:
		current_shoot_direction = Vector2.ZERO
		is_shooting = false
		if player:
			player.mobile_is_shooting = false
			player.mobile_shoot_direction = Vector2.ZERO

func reset_movement_joystick():
	"""Reset joystick movimiento"""
	if movement_joystick_knob:
		movement_joystick_knob.position = Vector2(movement_joystick_max_distance, movement_joystick_max_distance)
	current_movement = Vector2.ZERO
	if player:
		player.mobile_movement_direction = Vector2.ZERO
		player.velocity = Vector2.ZERO

func reset_shooting_joystick():
	"""Reset joystick disparo"""
	if shooting_joystick_knob:
		shooting_joystick_knob.position = Vector2(shooting_joystick_max_distance, shooting_joystick_max_distance)
	current_shoot_direction = Vector2.ZERO
	is_shooting = false
	if player:
		player.mobile_is_shooting = false
		player.mobile_shoot_direction = Vector2.ZERO

func setup_mobile_controls():
	"""Configurar controles móviles"""
	if not is_mobile:
		return
	
	mobile_controls = Control.new()
	mobile_controls.name = "MobileControls"
	mobile_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mobile_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mobile_controls.z_index = 100
	ui_manager.add_child(mobile_controls)
	
	await get_tree().process_frame
	
	create_movement_joystick_large()
	create_shooting_joystick_large()
	
	if movement_joystick_base:
		movement_joystick_base.visible = true
		movement_joystick_base.modulate = Color.WHITE
	
	if shooting_joystick_base:
		shooting_joystick_base.visible = true  
		shooting_joystick_base.modulate = Color.WHITE

func create_movement_joystick_large():
	"""Crear joystick movimiento"""
	var viewport_size = get_viewport().get_visible_rect().size
	var joystick_size = movement_joystick_max_distance * 2
	
	movement_joystick_base = Control.new()
	movement_joystick_base.name = "MovementJoystickBase"
	movement_joystick_base.size = Vector2(joystick_size, joystick_size)
	movement_joystick_base.position = Vector2(
		viewport_size.x * 0.08,
		viewport_size.y * 0.45
	)
	mobile_controls.add_child(movement_joystick_base)
	
	movement_joystick_area = TouchScreenButton.new()
	movement_joystick_area.name = "MovementJoystickArea"
	movement_joystick_area.shape = RectangleShape2D.new()
	movement_joystick_area.shape.size = Vector2(joystick_size, joystick_size)
	movement_joystick_area.position = Vector2.ZERO
	movement_joystick_area.visibility_mode = TouchScreenButton.VISIBILITY_TOUCHSCREEN_ONLY
	movement_joystick_base.add_child(movement_joystick_area)
	
	var base_style = StyleBoxFlat.new()
	base_style.bg_color = Color(0.2, 0.2, 0.2, 0.7)
	base_style.border_color = Color(0.6, 0.8, 1.0, 1.0)
	base_style.border_width_left = 5
	base_style.border_width_right = 5
	base_style.border_width_top = 5
	base_style.border_width_bottom = 5
	base_style.corner_radius_top_left = int(movement_joystick_max_distance)
	base_style.corner_radius_top_right = int(movement_joystick_max_distance)
	base_style.corner_radius_bottom_left = int(movement_joystick_max_distance)
	base_style.corner_radius_bottom_right = int(movement_joystick_max_distance)
	
	var base_panel = Panel.new()
	base_panel.size = Vector2(joystick_size, joystick_size)
	base_panel.add_theme_stylebox_override("panel", base_style)
	base_panel.z_index = 1
	movement_joystick_base.add_child(base_panel)
	
	movement_joystick_knob = Control.new()
	movement_joystick_knob.name = "MovementJoystickKnob"
	var knob_size = 90
	movement_joystick_knob.size = Vector2(knob_size, knob_size)
	movement_joystick_knob.position = Vector2(
		movement_joystick_max_distance - float(knob_size)/2.0,
		movement_joystick_max_distance - float(knob_size)/2.0
	)
	movement_joystick_knob.z_index = 2
	
	var knob_style = StyleBoxFlat.new()
	knob_style.bg_color = Color(0.9, 0.9, 0.9, 1.0)
	knob_style.border_color = Color.CYAN
	knob_style.border_width_left = 4
	knob_style.border_width_right = 4
	knob_style.border_width_top = 4
	knob_style.border_width_bottom = 4
	knob_style.corner_radius_top_left = int(knob_size)/2
	knob_style.corner_radius_top_right = int(knob_size)/2
	knob_style.corner_radius_bottom_left = int(knob_size)/2
	knob_style.corner_radius_bottom_right = int(knob_size)/2
	
	var knob_panel = Panel.new()
	knob_panel.size = Vector2(knob_size, knob_size)
	knob_panel.add_theme_stylebox_override("panel", knob_style)
	movement_joystick_knob.add_child(knob_panel)
	
	movement_joystick_base.add_child(movement_joystick_knob)
	movement_joystick_center = movement_joystick_base.global_position + Vector2(movement_joystick_max_distance, movement_joystick_max_distance)

func create_shooting_joystick_large():
	"""Crear joystick disparo"""
	var viewport_size = get_viewport().get_visible_rect().size
	var joystick_size = shooting_joystick_max_distance * 2
	
	shooting_joystick_base = Control.new()
	shooting_joystick_base.name = "ShootingJoystickBase"
	shooting_joystick_base.size = Vector2(joystick_size, joystick_size)
	shooting_joystick_base.position = Vector2(
		viewport_size.x * 0.78,
		viewport_size.y * 0.45
	)
	mobile_controls.add_child(shooting_joystick_base)
	
	shooting_joystick_area = TouchScreenButton.new()
	shooting_joystick_area.name = "ShootingJoystickArea"
	shooting_joystick_area.shape = RectangleShape2D.new()
	shooting_joystick_area.shape.size = Vector2(joystick_size, joystick_size)
	shooting_joystick_area.position = Vector2.ZERO
	shooting_joystick_area.visibility_mode = TouchScreenButton.VISIBILITY_TOUCHSCREEN_ONLY
	shooting_joystick_base.add_child(shooting_joystick_area)
	
	var base_style = StyleBoxFlat.new()
	base_style.bg_color = Color(0.4, 0.1, 0.1, 0.7)
	base_style.border_color = Color(1.0, 0.4, 0.4, 1.0)
	base_style.border_width_left = 5
	base_style.border_width_right = 5
	base_style.border_width_top = 5
	base_style.border_width_bottom = 5
	base_style.corner_radius_top_left = int(shooting_joystick_max_distance)
	base_style.corner_radius_top_right = int(shooting_joystick_max_distance)
	base_style.corner_radius_bottom_left = int(shooting_joystick_max_distance)
	base_style.corner_radius_bottom_right = int(shooting_joystick_max_distance)
	
	var base_panel = Panel.new()
	base_panel.size = Vector2(joystick_size, joystick_size)
	base_panel.add_theme_stylebox_override("panel", base_style)
	base_panel.z_index = 1
	shooting_joystick_base.add_child(base_panel)
	
	shooting_joystick_knob = Control.new()
	shooting_joystick_knob.name = "ShootingJoystickKnob"
	var knob_size = 80
	shooting_joystick_knob.size = Vector2(knob_size, knob_size)
	shooting_joystick_knob.position = Vector2(
		shooting_joystick_max_distance - float(knob_size)/2.0,
		shooting_joystick_max_distance - float(knob_size)/2.0
	)
	shooting_joystick_knob.z_index = 2
	
	var knob_style = StyleBoxFlat.new()
	knob_style.bg_color = Color(1.0, 0.3, 0.3, 1.0)
	knob_style.border_color = Color.YELLOW
	knob_style.border_width_left = 4
	knob_style.border_width_right = 4
	knob_style.border_width_top = 4
	knob_style.border_width_bottom = 4
	knob_style.corner_radius_top_left = int(knob_size)/2
	knob_style.corner_radius_top_right = int(knob_size)/2
	knob_style.corner_radius_bottom_left = int(knob_size)/2
	knob_style.corner_radius_bottom_right = int(knob_size)/2
	
	var knob_panel = Panel.new()
	knob_panel.size = Vector2(knob_size, knob_size)
	knob_panel.add_theme_stylebox_override("panel", knob_style)
	shooting_joystick_knob.add_child(knob_panel)
	
	shooting_joystick_base.add_child(shooting_joystick_knob)
	shooting_joystick_center = shooting_joystick_base.global_position + Vector2(shooting_joystick_max_distance, shooting_joystick_max_distance)

# ===== FUNCIONES DE DEPURACIÓN PARA ANIMACIONES =====

func debug_animation_system():
	"""Depurar sistema de animaciones"""
	print("🎭 [DEBUG GAME_MANAGER] Depurando sistema de animaciones...")
	
	if not player:
		print("❌ No hay jugador")
		return
	
	if not animation_controller:
		print("❌ No hay animation_controller")
		return
	
	print("🎭 [DEBUG] Player y AnimationController encontrados")
	player.debug_animation_state()

func reset_animation_system():
	"""Resetear sistema de animaciones"""
	print("🎭 [DEBUG GAME_MANAGER] Reseteando sistema de animaciones...")
	
	if player:
		player.reset_animation_system()
	
	if animation_controller:
		animation_controller.reset_animation_state()

# ===== RESTO DE FUNCIONES =====

func toggle_fullscreen():
	"""Alternar pantalla completa"""
	var current_mode = DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func toggle_pause_menu():
	"""Alternar menú de pausa"""
	if pause_menu.is_paused:
		pause_menu.hide_menu()
	else:
		pause_menu.show_menu()

func _on_mobile_menu_pressed():
	"""Botón menú móvil"""
	toggle_pause_menu()

func _on_resume_game():
	"""Reanudar juego"""
	resume_enemy_spawning()

func _on_restart_game():
	"""Reiniciar juego"""
	restart_entire_game()

func _on_quit_game():
	"""Salir del juego"""
	clear_all_enemies()
	get_tree().paused = false
	get_tree().quit()

func setup_pause_menu():
	"""Configurar menú de pausa"""
	pause_menu = preload("res://scenes/ui/PauseMenu.tscn").instantiate()
	pause_menu.resume_game.connect(_on_resume_game)
	pause_menu.restart_game.connect(_on_restart_game)
	pause_menu.quit_game.connect(_on_quit_game)
	ui_manager.add_child(pause_menu)
	
	mobile_menu_button = MobileMenuButton.new()
	mobile_menu_button.menu_pressed.connect(_on_mobile_menu_pressed)
	mobile_menu_button.visible = true
	ui_manager.add_child(mobile_menu_button)

func setup_background():
	"""Configurar fondo"""
	background_sprite = Sprite2D.new()
	background_sprite.name = "Background"
	background_sprite.z_index = -100
	
	var jungle_texture = SpriteEffectsHandler.load_texture_safe("res://sprites/background/jungle.png")
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
	"""Configurar ventana"""
	if is_mobile:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		
		if OS.get_name() == "Android":
			DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
			
		get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		
		var window = get_window()
		if window:
			window.borderless = true
			
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP

func _on_player_died():
	"""Cuando muere el jugador"""
	if is_game_over:
		return
	
	is_game_over = true
	pause_enemy_spawning()
	
	await get_tree().create_timer(1.0).timeout
	show_game_over_screen()

func show_game_over_screen():
	"""Mostrar pantalla Game Over"""
	if game_over_screen:
		return
	
	game_over_screen = Control.new()
	game_over_screen.name = "GameOverScreen"
	game_over_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_over_screen.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.8, 0.0, 0.0, 0.7)
	game_over_screen.add_child(bg)
	
	var panel = Panel.new()
	var viewport_size = get_viewport().get_visible_rect().size
	var panel_size = Vector2(400, 300) if not is_mobile else Vector2(min(viewport_size.x * 0.9, 500), 400)
	panel.size = panel_size
	panel.position = Vector2(
		(viewport_size.x - panel_size.x) / 2.0,
		(viewport_size.y - panel_size.y) / 2.0
	)
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.2, 0.95)
	panel_style.border_color = Color.RED
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.corner_radius_top_left = 15
	panel_style.corner_radius_top_right = 15
	panel_style.corner_radius_bottom_left = 15
	panel_style.corner_radius_bottom_right = 15
	panel.add_theme_stylebox_override("panel", panel_style)
	game_over_screen.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 30)
	vbox.position = Vector2(30, 30)
	vbox.size = Vector2(panel_size.x - 60, panel_size.y - 60)
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "💀 GAME OVER 💀"
	var title_size = 36 if not is_mobile else 42
	title.add_theme_font_size_override("font_size", title_size)
	title.add_theme_color_override("font_color", Color.RED)
	title.add_theme_color_override("font_shadow_color", Color.BLACK)
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var stats_container = VBoxContainer.new()
	stats_container.add_theme_constant_override("separation", 10)
	vbox.add_child(stats_container)
	
	var round_label = Label.new()
	var roman_round = rounds_manager.int_to_roman(rounds_manager.get_current_round()) if rounds_manager else "I"
	round_label.text = "Ronda alcanzada: " + roman_round
	round_label.add_theme_font_size_override("font_size", 20)
	round_label.add_theme_color_override("font_color", Color.CYAN)
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_container.add_child(round_label)
	
	var score_label = Label.new()
	var final_score = score_system.get_current_score() if score_system else 0
	score_label.text = "Puntuación final: " + str(final_score)
	score_label.add_theme_font_size_override("font_size", 20)
	score_label.add_theme_color_override("font_color", Color.GOLD)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_container.add_child(score_label)
	
	var kills_label = Label.new()
	kills_label.text = "Zombies eliminados: " + str(enemies_killed)
	kills_label.add_theme_font_size_override("font_size", 18)
	kills_label.add_theme_color_override("font_color", Color.LIGHT_GREEN)
	kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_container.add_child(kills_label)
	
	var buttons_container = VBoxContainer.new()
	buttons_container.add_theme_constant_override("separation", 15)
	vbox.add_child(buttons_container)
	
	var retry_btn = Button.new()
	retry_btn.text = "🔄 REINTENTAR"
	retry_btn.custom_minimum_size = Vector2(300, 50) if not is_mobile else Vector2(350, 60)
	retry_btn.add_theme_font_size_override("font_size", 20)
	retry_btn.add_theme_color_override("font_color", Color.WHITE)
	
	var retry_style = StyleBoxFlat.new()
	retry_style.bg_color = Color.DARK_GREEN
	retry_style.corner_radius_top_left = 8
	retry_style.corner_radius_top_right = 8
	retry_style.corner_radius_bottom_left = 8
	retry_style.corner_radius_bottom_right = 8
	retry_btn.add_theme_stylebox_override("normal", retry_style)
	
	retry_btn.pressed.connect(func():
		restart_entire_game()
	)
	buttons_container.add_child(retry_btn)
	
	var quit_btn = Button.new()
	quit_btn.text = "❌ SALIR"
	quit_btn.custom_minimum_size = Vector2(300, 50) if not is_mobile else Vector2(350, 60)
	quit_btn.add_theme_font_size_override("font_size", 20)
	quit_btn.add_theme_color_override("font_color", Color.WHITE)
	
	var quit_style = StyleBoxFlat.new()
	quit_style.bg_color = Color.DARK_RED
	quit_style.corner_radius_top_left = 8
	quit_style.corner_radius_top_right = 8
	quit_style.corner_radius_bottom_left = 8
	quit_style.corner_radius_bottom_right = 8
	quit_btn.add_theme_stylebox_override("normal", quit_style)
	
	quit_btn.pressed.connect(func():
		get_tree().quit()
	)
	buttons_container.add_child(quit_btn)
	
	ui_manager.add_child(game_over_screen)
	get_tree().paused = true

func restart_entire_game():
	"""Reiniciar juego completo"""
	clear_all_enemies()
	is_game_over = false
	game_started = false
	enemies_killed = 0
	game_state = "character_selection"
	
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_enemy_killed(_enemy: Enemy):
	"""Registrar kill de enemigo"""
	enemies_killed += 1
	
	if rounds_manager:
		rounds_manager.on_enemy_killed()

func _on_enemy_spawned(_enemy: Enemy):
	"""Enemigo spawneado"""
	if rounds_manager:
		rounds_manager.on_enemy_spawned()

func pause_enemy_spawning():
	"""Pausar spawning"""
	if enemy_spawner:
		enemy_spawner.pause_spawning()

func resume_enemy_spawning():
	"""Reanudar spawning"""
	if enemy_spawner:
		enemy_spawner.resume_spawning()

func clear_all_enemies():
	"""Limpiar enemigos"""
	if enemy_spawner:
		enemy_spawner.clear_all_enemies()

func get_active_enemy_count() -> int:
	"""Número de enemigos activos"""
	if enemy_spawner:
		return enemy_spawner.get_active_enemy_count()
	return 0

func get_current_round() -> int:
	"""Ronda actual"""
	if rounds_manager:
		return rounds_manager.get_current_round()
	return 1

func get_current_score() -> int:
	"""Puntuación actual"""
	if score_system:
		return score_system.get_current_score()
	return 0

func is_game_active() -> bool:
	"""Verificar si juego activo"""
	return game_started and not is_game_over and game_state == "playing"

func _notification(what):
	"""Manejar notificaciones del sistema"""
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			get_tree().quit()
		NOTIFICATION_APPLICATION_PAUSED:
			if is_game_active():
				toggle_pause_menu()

func _exit_tree():
	"""Limpiar al salir"""
	set_process(false)
	set_physics_process(false)
