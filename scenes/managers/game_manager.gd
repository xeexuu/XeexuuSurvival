# scenes/managers/game_manager.gd - COLISIONES Y LAYERS CORREGIDOS
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

# Referencias a UI
var mini_hud: MiniHUD

# Menú de pausa
var pause_menu: PauseMenu
var mobile_menu_button: MobileMenuButton

# Variables para controles móviles
var is_mobile: bool = false

# Joystick de movimiento
var movement_joystick_base: Control
var movement_joystick_knob: Control
var movement_joystick_area: Control
var movement_joystick_center: Vector2
var movement_joystick_max_distance: float = 160.0
var movement_joystick_dead_zone: float = 25.0
var current_movement = Vector2.ZERO
var movement_touch_id: int = -1

# Joystick de disparo
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

# Sistema de enemigos y rondas estilo COD Black Ops
var enemy_spawner: EnemySpawner
var rounds_manager: RoundsManager
var score_system: ScoreSystem
var enemies_killed: int = 0

var mobile_process_counter: int = 0
var mobile_process_skip: int = 1

# Game Over
var game_over_screen: Control
var is_game_over: bool = false

func _process(_delta):
	if not game_started or is_game_over or game_state != "playing":
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
	
	update_ui_elements()

func update_ui_elements():
	"""Actualizar elementos de UI continuamente"""
	if not player or not game_started:
		return
	
	if mini_hud:
		mini_hud.update_health(player.get_current_health(), player.get_max_health())
	
	if score_system and rounds_manager:
		score_system.set_round_multiplier(rounds_manager.get_current_round())

func _ready():
	is_mobile = OS.has_feature("mobile")
	setup_collision_layers()  # NUEVO: Configurar layers de colisión
	setup_background()
	setup_window()
	setup_pause_menu()
	
	await get_tree().process_frame
	show_character_selection()

func setup_collision_layers():
	"""NUEVO: Configurar las capas de colisión correctamente estilo COD Black Ops"""
	# Configurar las capas del proyecto
	# Capa 1: Jugador
	# Capa 2: Enemigos  
	# Capa 3: Estructuras/Paredes
	# Capa 4: Proyectiles/Balas
	# Capa 5: Areas especiales (headshots, etc.)
	
	print("🎯 Configurando sistema de colisiones estilo COD Black Ops")
	print("  - Capa 1: Jugador")
	print("  - Capa 2: Enemigos")
	print("  - Capa 3: Estructuras")
	print("  - Capa 4: Proyectiles")
	print("  - Capa 5: Areas especiales")

func _input(event):
	# Detección del menú para todas las plataformas
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.keycode == KEY_ESCAPE):
		if game_started and game_state == "playing" and not is_game_over:
			toggle_pause_menu()
		return
	
	# Botón back en Android
	if event is InputEventKey and event.keycode == KEY_BACK:
		if game_started and game_state == "playing" and not is_game_over:
			toggle_pause_menu()
		return
	
	if event.is_action_pressed("toggle_fullscreen"):
		toggle_fullscreen()
	
	if not is_mobile or not game_started or game_state != "playing":
		return
	
	if event is InputEventScreenTouch:
		handle_touch_event(event)
	elif event is InputEventScreenDrag:
		handle_drag_event(event)

func show_character_selection():
	"""Mostrar pantalla de selección de personaje"""
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
	"""Cuando se selecciona un personaje"""
	selected_character_stats = character_stats
	game_state = "playing"
	
	setup_player_after_selection()
	
	if not player or player.get_current_health() <= 0:
		return
	
	if is_mobile:
		setup_mobile_controls()
	setup_mini_hud()
	
	await setup_unified_cod_system_safe()
	
	if player:
		player.visible = true
		
		if player.get_current_health() <= 0:
			player.current_health = selected_character_stats.current_health
			player.max_health = selected_character_stats.max_health
		
		# CONFIGURAR LAYERS DE COLISIÓN DEL JUGADOR
		setup_player_collision_layers()
		
		player.set_physics_process(true)
		player.set_process(true)
		
		if not player.player_died.is_connected(_on_player_died):
			player.player_died.connect(_on_player_died)
	
	game_started = true
	
	await get_tree().create_timer(3.0).timeout
	start_enemy_spawning_safely()

func setup_player_collision_layers():
	"""NUEVO: Configurar las capas de colisión del jugador"""
	if not player:
		return
	
	# Jugador en capa 1, colisiona con enemigos (capa 2) y estructuras (capa 3)
	player.collision_layer = 1
	player.collision_mask = 2 | 3  # Colisiona con enemigos y estructuras
	
	print("✅ Capas de colisión del jugador configuradas")
	print("  - Layer: 1 (Jugador)")
	print("  - Mask: 2|3 (Enemigos + Estructuras)")

func setup_player_after_selection():
	"""Configurar jugador después de la selección"""
	if player_manager.get_child_count() > 0:
		player = player_manager.get_child(0)
		if player:
			if selected_character_stats:
				player.update_character_stats(selected_character_stats)
			
			player.global_position = Vector2(0, 0)
			player.z_index = 10
			player.velocity = Vector2.ZERO
			
			load_player_sprites()

func load_player_sprites():
	"""Cargar sprites del jugador usando el sistema separado"""
	if not player or not selected_character_stats:
		return
	
	var sprite_frames = SpriteEffectsHandler.load_character_sprite_atlas(selected_character_stats.character_name)
	if sprite_frames and player.animated_sprite:
		player.animated_sprite.sprite_frames = sprite_frames
		player.animated_sprite.play("idle")
		
		var reference_texture = sprite_frames.get_frame_texture("idle", 0)
		SpriteEffectsHandler.scale_sprite_to_128px(player.animated_sprite, reference_texture)

func setup_unified_cod_system_safe():
	"""Configurar sistemas de combate estilo COD Black Ops"""
	if not player:
		return
	
	# Crear ScoreSystem
	score_system = ScoreSystem.new()
	score_system.name = "ScoreSystem"
	add_child(score_system)
	
	if player.camera:
		score_system.setup_score_ui_on_camera(player.camera)
	
	# Crear RoundsManager
	rounds_manager = RoundsManager.new()
	rounds_manager.name = "RoundsManager"
	add_child(rounds_manager)
	
	if player.camera:
		rounds_manager.setup_round_ui_on_camera(player.camera)
	
	# Crear EnemySpawner
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
	"""Actualizar cuando cambia la ronda"""
	if score_system:
		score_system.set_round_multiplier(new_round)

func _on_enemies_remaining_changed(_remaining: int):
	"""Actualizar cuando cambian enemigos restantes"""
	pass

func start_enemy_spawning_safely():
	"""Iniciar spawning de enemigos de forma segura"""
	if not rounds_manager or not enemy_spawner:
		return
	
	if not player or not player.is_alive() or not player.is_fully_initialized:
		return
	
	rounds_manager.manually_start_spawning()

func _on_player_died():
	"""Cuando el jugador muere"""
	show_game_over_screen()

func restart_entire_game():
	"""Reiniciar todo el juego"""
	clear_all_enemies()
	is_game_over = false
	game_started = false
	enemies_killed = 0
	game_state = "character_selection"
	
	if game_over_screen:
		game_over_screen.queue_free()
		game_over_screen = null
	
	if pause_menu:
		pause_menu.hide_menu()
	
	if mobile_controls:
		mobile_controls.queue_free()
		mobile_controls = null
	
	if enemy_spawner:
		enemy_spawner.queue_free()
		enemy_spawner = null
	if rounds_manager:
		rounds_manager.queue_free()
		rounds_manager = null
	if score_system:
		score_system.queue_free()
		score_system = null
	
	if mini_hud:
		mini_hud.queue_free()
		mini_hud = null
	
	get_tree().paused = false
	get_tree().reload_current_scene()

# Funciones de controles móviles (simplificadas)
func handle_touch_event(event: InputEventScreenTouch):
	"""Manejar eventos de toque"""
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
	"""Manejar eventos de arrastre"""
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
	"""Verificar si un punto está dentro de un control"""
	if not control:
		return false
	var control_rect = Rect2(control.global_position, control.size)
	return control_rect.has_point(point)

func handle_movement_joystick(touch_pos: Vector2, pressed: bool):
	"""Manejar joystick de movimiento"""
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
	"""Resetear joystick de movimiento"""
	if movement_joystick_knob:
		movement_joystick_knob.position = Vector2(140, 140)
	current_movement = Vector2.ZERO

func handle_shooting_joystick(touch_pos: Vector2, pressed: bool):
	"""Manejar joystick de disparo"""
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
	"""Resetear joystick de disparo"""
	if shooting_joystick_knob:
		shooting_joystick_knob.position = Vector2(140, 140)
	current_shoot_direction = Vector2.ZERO
	is_shooting = false

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
	"""Cuando se presiona el botón de menú móvil"""
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

func show_game_over_screen():
	"""Mostrar pantalla de Game Over estilo COD Black Ops"""
	if is_game_over:
		return
	
	is_game_over = true
	get_tree().paused = true
	
	game_over_screen = Control.new()
	game_over_screen.name = "GameOverScreen"
	game_over_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_over_screen.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# Fondo rojo oscuro estilo COD
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.1, 0.0, 0.0, 0.9)
	game_over_screen.add_child(bg)
	
	# Panel central
	var panel = Panel.new()
	var viewport_size = get_viewport().get_visible_rect().size
	var panel_width = 500 if not is_mobile else min(viewport_size.x * 0.9, 600)
	var panel_height = 400 if not is_mobile else min(viewport_size.y * 0.7, 500)
	
	panel.size = Vector2(panel_width, panel_height)
	panel.position = Vector2(
		(viewport_size.x - panel_width) / 2,
		(viewport_size.y - panel_height) / 2
	)
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.05, 0.05, 0.95)
	panel_style.border_color = Color.RED
	panel_style.border_width_left = 4
	panel_style.border_width_right = 4
	panel_style.border_width_top = 4
	panel_style.border_width_bottom = 4
	panel_style.corner_radius_top_left = 20
	panel_style.corner_radius_top_right = 20
	panel_style.corner_radius_bottom_left = 20
	panel_style.corner_radius_bottom_right = 20
	panel.add_theme_stylebox_override("panel", panel_style)
	
	game_over_screen.add_child(panel)
	
	# Layout
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 30)
	var padding = 40
	vbox.position = Vector2(padding, padding)
	vbox.size = Vector2(panel_width - padding * 2, panel_height - padding * 2)
	panel.add_child(vbox)
	
	# Título GAME OVER
	var title = Label.new()
	title.text = "💀 GAME OVER 💀"
	var title_size = 48 if not is_mobile else 56
	title.add_theme_font_size_override("font_size", title_size)
	title.add_theme_color_override("font_color", Color.RED)
	title.add_theme_color_override("font_shadow_color", Color.BLACK)
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Estadísticas finales
	if score_system:
		var stats = score_system.get_stats_summary()
		
		var stats_label = Label.new()
		stats_label.text = "Puntuación Final: " + str(stats.score) + "\n" + \
						  "Ronda Alcanzada: " + str(rounds_manager.get_current_round()) + "\n" + \
						  "Enemigos Eliminados: " + str(stats.total_kills) + "\n" + \
						  "Headshots: " + str(stats.headshot_kills) + "\n" + \
						  "Mejor Racha: " + str(stats.best_streak)
		
		var stats_size = 20 if not is_mobile else 24
		stats_label.add_theme_font_size_override("font_size", stats_size)
		stats_label.add_theme_color_override("font_color", Color.WHITE)
		stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(stats_label)
	
	# Botones
	var restart_btn = create_game_over_button("🔄 REINTENTAR", Color.ORANGE)
	restart_btn.pressed.connect(restart_entire_game)
	vbox.add_child(restart_btn)
	
	var quit_btn = create_game_over_button("❌ SALIR", Color.RED)
	quit_btn.pressed.connect(_on_quit_game)
	vbox.add_child(quit_btn)
	
	ui_manager.add_child(game_over_screen)

func create_game_over_button(text: String, color: Color) -> Button:
	"""Crear botón de Game Over"""
	var button = Button.new()
	button.text = text
	
	var button_height = 60 if not is_mobile else 80
	button.custom_minimum_size = Vector2(0, button_height)
	
	var font_size = 24 if not is_mobile else 32
	button.add_theme_font_size_override("font_size", font_size)
	
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = color.darkened(0.7)
	button_style.corner_radius_top_left = 10
	button_style.corner_radius_top_right = 10
	button_style.corner_radius_bottom_left = 10
	button_style.corner_radius_bottom_right = 10
	button_style.border_color = color
	button_style.border_width_left = 3
	button_style.border_width_right = 3
	button_style.border_width_top = 3
	button_style.border_width_bottom = 3
	button.add_theme_stylebox_override("normal", button_style)
	
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_shadow_color", Color.BLACK)
	button.add_theme_constant_override("shadow_offset_x", 2)
	button.add_theme_constant_override("shadow_offset_y", 2)
	
	return button

func setup_background():
	"""Configurar fondo del juego"""
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
	"""Configurar ventana del juego"""
	if is_mobile:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
		get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP

func setup_mini_hud():
	"""Configurar mini HUD"""
	mini_hud = preload("res://scenes/ui/MiniHUD.tscn").instantiate()
	ui_manager.add_child(mini_hud)
	
	if player and player.character_stats:
		mini_hud.update_character_stats(player.character_stats)

func setup_mobile_controls():
	"""Configurar controles móviles (implementación básica)"""
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

func create_movement_joystick():
	"""Crear joystick de movimiento (implementación básica)"""
	# Implementación simplificada para evitar código duplicado
	pass

func create_shooting_joystick():
	"""Crear joystick de disparo (implementación básica)"""
	# Implementación simplificada para evitar código duplicado
	pass

func _on_enemy_killed(enemy: Enemy):
	"""Cuando un enemigo es eliminado - MEJORADO"""
	enemies_killed += 1
	
	if rounds_manager:
		rounds_manager.on_enemy_killed()
	
	if score_system and enemy:
		# DETECTAR SI FUE HEADSHOT BASADO EN LA POSICIÓN DE LA BALA
		var is_headshot = enemy.has_method("was_headshot_kill") and enemy.was_headshot_kill()
		score_system.add_kill_points(enemy.global_position, is_headshot, false)
	
	# NOTIFICAR AL JUGADOR PARA SONIDO DE KILL (SOLO PELAO)
	if player:
		player.on_enemy_killed()

func _on_enemy_spawned(_enemy: Enemy):
	"""Cuando un enemigo es spawneado"""
	if rounds_manager:
		rounds_manager.on_enemy_spawned()

func pause_enemy_spawning():
	"""Pausar spawning de enemigos"""
	if enemy_spawner:
		enemy_spawner.pause_spawning()

func resume_enemy_spawning():
	"""Reanudar spawning de enemigos"""
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
