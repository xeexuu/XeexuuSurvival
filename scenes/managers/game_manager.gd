# scenes/managers/game_manager.gd - PARTE 1/3: INICIALIZACIÓN Y SETUP
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

# SISTEMA DE GUARDADO PARA ANDROID
var save_file_path: String = "user://game_save.dat"
var auto_save_timer: Timer

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

# Botones móviles CORREGIDOS - BOTÓN DÓLAR
var melee_button: Button
var dollar_interact_button: Button  # NUEVO: BOTÓN DÓLAR PARA INTERACTUAR/COMPRAR
var melee_touch_id: int = -1
var dollar_interact_touch_id: int = -1

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
	
	setup_android_save_system()
	setup_collision_layers()
	setup_background()
	setup_window()
	setup_pause_menu()
	setup_wall_system()
	setup_fixed_ui()
	
	# CARGAR PARTIDA GUARDADA EN ANDROID
	if is_mobile:
		load_game_if_exists()
	
	await get_tree().process_frame
	
	# SI NO HAY PARTIDA GUARDADA, EMPEZAR SELECCIÓN
	if not game_started:
		show_character_selection()

func setup_android_save_system():
	"""Configurar sistema de guardado automático para Android"""
	if not is_mobile:
		return
	
	# Auto-guardado cada 30 segundos
	auto_save_timer = Timer.new()
	auto_save_timer.wait_time = 30.0
	auto_save_timer.autostart = true
	auto_save_timer.timeout.connect(auto_save_game)
	add_child(auto_save_timer)
	
	print("💾 Sistema de guardado Android inicializado")

func auto_save_game():
	"""Guardado automático para Android"""
	if is_mobile and game_started and not is_game_over:
		save_game_state()

func save_game_state():
	"""Guardar estado del juego en archivo persistente"""
	if not is_mobile:
		return
	
	var save_data = {
		"version": "1.0",
		"timestamp": Time.get_unix_time_from_system(),
		"game_started": game_started,
		"current_round": get_current_round(),
		"current_score": get_current_score(),
		"enemies_killed": enemies_killed,
		"player_health": player.get_current_health() if player and player.has_method("get_current_health") else 4,
		"player_max_health": player.get_max_health() if player and player.has_method("get_max_health") else 4,
		"character_name": selected_character_stats.character_name if selected_character_stats else "",
		"game_state": game_state
	}
	
	var file = FileAccess.open(save_file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()
		print("💾 Juego guardado automáticamente")
	else:
		print("❌ Error guardando juego")

func load_game_if_exists():
	"""Cargar juego guardado si existe"""
	if not FileAccess.file_exists(save_file_path):
		print("📁 No hay partida guardada")
		return
	
	var file = FileAccess.open(save_file_path, FileAccess.READ)
	if not file:
		print("❌ Error abriendo archivo de guardado")
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		print("❌ Error parseando archivo de guardado")
		return
	
	var save_data = json.data
	
	# VERIFICAR VERSIÓN Y DATOS
	if not save_data.has("version") or not save_data.has("game_started"):
		print("❌ Archivo de guardado inválido")
		return
	
	if not save_data.game_started:
		print("📁 Partida guardada no iniciada")
		return
	
	# RESTAURAR ESTADO DEL JUEGO
	game_started = save_data.get("game_started", false)
	enemies_killed = save_data.get("enemies_killed", 0)
	game_state = save_data.get("game_state", "character_selection")
	
	# CARGAR PERSONAJE
	var character_name = save_data.get("character_name", "")
	if character_name != "":
		selected_character_stats = load_character_by_name(character_name)
	
	print("💾 Partida cargada: Ronda ", save_data.get("current_round", 1), " - Puntos: ", save_data.get("current_score", 0))
	
	# RESTAURAR JUEGO DIRECTAMENTE
	if selected_character_stats:
		await get_tree().process_frame
		restore_game_from_save(save_data)

func load_character_by_name(char_name: String) -> CharacterStats:
	"""Cargar personaje por nombre"""
	var character_paths = {
		"pelao": "res://scenes/characters/pelao_stats.tres",
		"juancar": "res://scenes/characters/juancar_stats.tres",
		"chica": "res://scenes/characters/chica_stats.tres"
	}
	
	var path = character_paths.get(char_name.to_lower(), "")
	if path != "" and ResourceLoader.exists(path):
		return load(path) as CharacterStats
	
	return null

func restore_game_from_save(save_data: Dictionary):
	"""Restaurar juego desde datos guardados"""
	game_state = "playing"
	
	setup_player_after_selection()
	
	if not player or player.get_current_health() <= 0:
		return
	
	# RESTAURAR VIDA DEL JUGADOR
	var saved_health = save_data.get("player_health", 4)
	var saved_max_health = save_data.get("player_max_health", 4)
	player.current_health = saved_health
	player.max_health = saved_max_health
	
	if is_mobile:
		setup_mobile_controls()
	
	# CORREGIDO: llamada más segura para evitar cuelgue en línea 231
	await setup_unified_cod_system_safe_fixed()
	
	if player:
		player.visible = true
		setup_player_collision_layers()
		setup_new_animation_system()
		
		player.set_physics_process(true)
		player.set_process(true)
		if not player.player_died.is_connected(_on_player_died):
			player.player_died.connect(_on_player_died)
	
	# RESTAURAR PUNTUACIÓN Y RONDA
	if score_system:
		score_system.current_score = save_data.get("current_score", 0)
	
	enemies_killed = save_data.get("enemies_killed", 0)
	
	var saved_round = save_data.get("current_round", 1)
	if rounds_manager:
		rounds_manager.current_round = saved_round
	
	print("🎮 Juego restaurado exitosamente")
	
	await get_tree().create_timer(2.0).timeout
	start_enemy_spawning_safely()

func setup_wall_system():
	"""Configurar sistema de paredes CORREGIDO"""
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
	pass

func setup_background():
	"""Configurar fondo PARA ÁREA GIGANTE"""
	background_sprite = Sprite2D.new()
	background_sprite.name = "Background"
	background_sprite.z_index = -100
	
	var jungle_texture = SpriteEffectsHandler.load_texture_safe("res://sprites/background/jungle.png")
	if jungle_texture:
		background_sprite.texture = jungle_texture
		background_sprite.position = Vector2(0, 0)
		
		var texture_size = jungle_texture.get_size()
		# ESCALADO GIGANTE PARA ÁREA 4000x3000
		var scale_factor_x = 20000.0 / float(texture_size.x)
		var scale_factor_y = 15000.0 / float(texture_size.y)
		background_sprite.scale = Vector2(scale_factor_x, scale_factor_y)
		
		add_child(background_sprite)
	else:
		var temp_bg = ColorRect.new()
		temp_bg.color = Color(0.2, 0.4, 0.2)
		temp_bg.size = Vector2(8000, 6000)  # FONDO GIGANTE
		temp_bg.position = Vector2(-4000, -3000)
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

func setup_pause_menu():
	"""Configurar menú de pausa"""
	pause_menu = preload("res://scenes/ui/PauseMenu.tscn").instantiate()
	pause_menu.resume_game.connect(_on_resume_game)
	pause_menu.restart_game.connect(_on_restart_game)
	pause_menu.quit_game.connect(_on_quit_game)
	ui_manager.add_child(pause_menu)
	
	mobile_menu_button = MobileMenuButton.new()
	mobile_menu_button.menu_pressed.connect(_on_mobile_menu_pressed)
	mobile_menu_button.visible = is_mobile
	ui_manager.add_child(mobile_menu_button)
	
	if is_mobile:
		mobile_menu_button.force_show()

# CORREGIDO: función más segura para evitar cuelgue
func setup_unified_cod_system_safe_fixed():
	"""Configurar sistemas COD con verificaciones adicionales"""
	print("🎮 Iniciando setup de sistemas COD...")
	
	if not player:
		print("❌ No hay player para configurar sistemas")
		return
	
	# Crear score system con verificación
	if not score_system:
		score_system = ScoreSystem.new()
		score_system.name = "ScoreSystem"
		add_child(score_system)
		print("✅ ScoreSystem creado")
	
	# Crear rounds manager con verificación
	if not rounds_manager:
		rounds_manager = RoundsManager.new()
		rounds_manager.name = "RoundsManager"
		add_child(rounds_manager)
		print("✅ RoundsManager creado")
	
	# Configurar UI solo si existe
	if fixed_ui_manager:
		fixed_ui_manager.set_score_system(score_system)
		fixed_ui_manager.set_rounds_manager(rounds_manager)
		fixed_ui_manager.set_player_reference(player)
		print("✅ UI configurada")
	
	# Crear enemy spawner con verificación
	if not enemy_spawner:
		enemy_spawner = EnemySpawner.new()
		enemy_spawner.name = "EnemySpawner"
		enemy_spawner.spawn_radius_min = 1200.0  # PARA ÁREA GIGANTE
		enemy_spawner.spawn_radius_max = 2000.0  # PARA ÁREA GIGANTE
		enemy_spawner.despawn_distance = 2800.0
		add_child(enemy_spawner)
		print("✅ EnemySpawner creado")
	
	# Configurar conexiones de forma segura
	if enemy_spawner and rounds_manager:
		enemy_spawner.setup(player, rounds_manager)
		rounds_manager.set_enemy_spawner(enemy_spawner)
		print("✅ Conexiones configuradas")
	
	# Conectar señales de forma segura
	if enemy_spawner:
		if not enemy_spawner.enemy_killed.is_connected(_on_enemy_killed):
			enemy_spawner.enemy_killed.connect(_on_enemy_killed)
		if not enemy_spawner.enemy_spawned.is_connected(_on_enemy_spawned):
			enemy_spawner.enemy_spawned.connect(_on_enemy_spawned)
		print("✅ Señales de enemigos conectadas")
	
	if rounds_manager:
		if not rounds_manager.round_changed.is_connected(_on_round_changed):
			rounds_manager.round_changed.connect(_on_round_changed)
		if not rounds_manager.enemies_remaining_changed.is_connected(_on_enemies_remaining_changed):
			rounds_manager.enemies_remaining_changed.connect(_on_enemies_remaining_changed)
		print("✅ Señales de rondas conectadas")
	
	# Configurar player con verificaciones
	if player and score_system:
		player.set_score_system(score_system)
		print("✅ Player configurado con score system")
	
	# Configurar nombre del personaje en score system
	if selected_character_stats and score_system:
		score_system.set_character_name(selected_character_stats.character_name)
		print("✅ Nombre de personaje configurado")
	
	# Iniciar primera ronda
	if rounds_manager:
		rounds_manager.start_round(1)
		print("✅ Primera ronda iniciada")
	
	print("🎮 Setup de sistemas COD completado")

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
	
	# CORREGIDO: llamada más segura
	await setup_unified_cod_system_safe_fixed()
	
	if player:
		player.visible = true
		player.current_health = selected_character_stats.current_health
		player.max_health = selected_character_stats.max_health
		
		setup_player_collision_layers()
		setup_new_animation_system()
		
		player.set_physics_process(true)
		player.set_process(true)
		if not player.player_died.is_connected(_on_player_died):
			player.player_died.connect(_on_player_died)
	
	game_started = true
	
	# GUARDAR INMEDIATAMENTE DESPUÉS DE SELECCIONAR PERSONAJE
	if is_mobile:
		save_game_state()
	
	await get_tree().create_timer(3.0).timeout
	start_enemy_spawning_safely()

func setup_new_animation_system():
	"""CONFIGURAR SISTEMA DE ANIMACIONES CORREGIDO"""
	if not player or not player.animated_sprite:
		return
	
	animation_controller = AnimationController.new()
	animation_controller.name = "AnimationController"
	player.add_child(animation_controller)
	
	animation_controller.setup(player.animated_sprite, selected_character_stats.character_name)
	player.set_animation_controller(animation_controller)

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

# GAMEMANAGER PARTE 2/3: INPUT Y CONTROLES MÓVILES

func _input(event):
	# MANEJO ESPECIAL DEL BOTÓN BACK EN ANDROID
	if is_mobile and event is InputEventKey and event.keycode == KEY_BACK and event.pressed:
		print("📱 Botón BACK presionado en Android")
		if game_started and game_state == "playing" and not is_game_over:
			# PAUSAR EN LUGAR DE CERRAR
			toggle_pause_menu()
			get_viewport().set_input_as_handled()
			return
		elif pause_menu and pause_menu.is_paused:
			# SI YA ESTÁ PAUSADO, REANUDAR
			pause_menu.hide_menu()
			get_viewport().set_input_as_handled()
			return
		# EN OTROS CASOS, NO HACER NADA (NO CERRAR EL JUEGO)
		get_viewport().set_input_as_handled()
		return
	
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.keycode == KEY_ESCAPE):
		if game_started and game_state == "playing" and not is_game_over:
			toggle_pause_menu()
		return
	
	if event.is_action_pressed("toggle_fullscreen"):
		toggle_fullscreen()
	
	# INTERACCIÓN MEJORADA - E para interactuar o comprar Y R para recargar/interactuar
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.keycode == KEY_E) or event.is_action_pressed("reload"):
		if player and wall_system:
			handle_interaction()
		get_viewport().set_input_as_handled()
		return
	
	if not is_mobile or not game_started or game_state != "playing":
		return
	
	if event is InputEventScreenTouch:
		handle_touch_event(event)
	elif event is InputEventScreenDrag:
		handle_drag_event(event)

func handle_interaction():
	"""Manejar interacción mejorada con elementos del mundo"""
	var interactable = wall_system.can_player_interact()
	if not interactable:
		return
	
	if interactable.name.begins_with("Door_"):
		# Es una puerta
		var cost = interactable.get_meta("cost", 3000)
		if score_system and score_system.get_current_score() >= cost:
			if wall_system.purchase_door(interactable):
				score_system.add_bonus_points(-cost, interactable.global_position, "door_purchase")
				print("🚪 Puerta comprada por ", cost, " puntos")
		else:
			print("💰 Puntos insuficientes para la puerta")
	elif interactable.name.begins_with("Barricade_"):
		# Es una barricada
		var cost = interactable.get_meta("repair_cost", 10)
		if score_system and score_system.get_current_score() >= cost:
			if wall_system.repair_barricade(interactable):
				score_system.add_repair_points(interactable.global_position, 1)
				score_system.add_bonus_points(-cost, interactable.global_position, "repair_purchase")
				print("🔨 Barricada reparada por ", cost, " puntos")
		else:
			print("💰 Puntos insuficientes para reparar")

func _physics_process(_delta):
	"""Aplicar movimiento móvil"""
	if is_mobile and player:
		player.mobile_movement_direction = current_movement
		
		if is_shooting:
			player.mobile_shoot_direction = current_shoot_direction
			player.mobile_is_shooting = true
		else:
			player.mobile_is_shooting = false

func toggle_fullscreen():
	"""Alternar pantalla completa"""
	var current_mode = DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func toggle_pause_menu():
	"""Alternar menú de pausa CON GUARDADO AUTOMÁTICO"""
	if pause_menu.is_paused:
		pause_menu.hide_menu()
	else:
		# GUARDAR ANTES DE PAUSAR
		if is_mobile:
			save_game_state()
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
	"""Salir del juego CORRECTAMENTE CON GUARDADO"""
	# GUARDAR ANTES DE SALIR
	if is_mobile:
		save_game_state()
	
	cleanup_before_exit()
	get_tree().quit()

# ===== CONTROLES MÓVILES CON BOTÓN DÓLAR MEJORADO =====

func handle_touch_event(event: InputEventScreenTouch):
	"""Manejar toques CON BOTÓN DÓLAR MEJORADO"""
	var touch_pos = event.position
	var touch_id = event.index
	
	if event.pressed:
		# PRIORIDAD 1: BOTONES DE ACCIÓN (MELEE Y DÓLAR)
		if melee_button and is_point_in_button_area(touch_pos, melee_button) and melee_touch_id == -1:
			melee_touch_id = touch_id
			handle_melee_button_press()
			return
		
		if dollar_interact_button and is_point_in_button_area(touch_pos, dollar_interact_button) and dollar_interact_touch_id == -1:
			dollar_interact_touch_id = touch_id
			handle_dollar_interact_button_press()
			return
		
		# PRIORIDAD 2: JOYSTICKS
		if movement_joystick_area and is_point_in_expanded_area(touch_pos, movement_joystick_area):
			if movement_touch_id == -1:
				movement_touch_id = touch_id
				handle_movement_joystick(touch_pos)
		elif shooting_joystick_area and is_point_in_expanded_area(touch_pos, shooting_joystick_area):
			if shoot_touch_id == -1:
				shoot_touch_id = touch_id
				handle_shooting_joystick(touch_pos)
	else:
		# SOLTAR TOQUES
		if touch_id == movement_touch_id:
			movement_touch_id = -1
			reset_movement_joystick()
		elif touch_id == shoot_touch_id:
			shoot_touch_id = -1
			reset_shooting_joystick()
		elif touch_id == melee_touch_id:
			melee_touch_id = -1
			handle_melee_button_release()
		elif touch_id == dollar_interact_touch_id:
			dollar_interact_touch_id = -1
			handle_dollar_interact_button_release()

func handle_drag_event(event: InputEventScreenDrag):
	"""Manejar arrastre"""
	var touch_id = event.index
	var touch_pos = event.position
	
	if touch_id == movement_touch_id:
		handle_movement_joystick(touch_pos)
	elif touch_id == shoot_touch_id:
		handle_shooting_joystick(touch_pos)

func is_point_in_button_area(point: Vector2, button: Button) -> bool:
	"""Verificar si punto está en área del botón"""
	if not button:
		return false
	
	var button_rect = Rect2(button.global_position, button.size)
	return button_rect.has_point(point)

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

# FUNCIONES PARA BOTÓN DÓLAR MEJORADO

func handle_melee_button_press():
	"""Manejar presión de botón melee"""
	if player and player.has_method("perform_melee_attack"):
		player.perform_melee_attack()
	
	if melee_button:
		var tween = create_tween()
		tween.tween_property(melee_button, "scale", Vector2(0.9, 0.9), 0.1)
		tween.tween_property(melee_button, "modulate", Color(1.2, 0.8, 0.8), 0.1)

func handle_melee_button_release():
	"""Manejar liberación de botón melee"""
	if melee_button:
		var tween = create_tween()
		tween.tween_property(melee_button, "scale", Vector2(1.0, 1.0), 0.1)
		tween.tween_property(melee_button, "modulate", Color.WHITE, 0.2)

func handle_dollar_interact_button_press():
	"""Manejar presión del botón DÓLAR - INTERACTUAR/COMPRAR Y RECARGAR"""
	# PRIORIDAD 1: INTERACCIÓN/COMPRA
	if wall_system:
		var interactable = wall_system.can_player_interact()
		if interactable:
			handle_interaction()
			
			if dollar_interact_button:
				var tween = create_tween()
				tween.tween_property(dollar_interact_button, "modulate", Color.GOLD, 0.2)
				tween.tween_property(dollar_interact_button, "scale", Vector2(0.9, 0.9), 0.1)
			return
	
	# PRIORIDAD 2: RECARGAR ARMA
	if player and player.has_method("start_manual_reload"):
		var reload_success = player.start_manual_reload()
		
		if reload_success and dollar_interact_button:
			var tween = create_tween()
			tween.tween_property(dollar_interact_button, "modulate", Color.CYAN, 0.2)
			tween.tween_property(dollar_interact_button, "scale", Vector2(0.9, 0.9), 0.1)
			return
	
	# SI NO HAY ACCIÓN, FEEDBACK VISUAL NEGATIVO
	if dollar_interact_button:
		var tween = create_tween()
		tween.tween_property(dollar_interact_button, "modulate", Color.RED, 0.1)
		tween.tween_property(dollar_interact_button, "scale", Vector2(0.9, 0.9), 0.1)

func handle_dollar_interact_button_release():
	"""Manejar liberación del botón dólar"""
	if dollar_interact_button:
		var tween = create_tween()
		tween.tween_property(dollar_interact_button, "scale", Vector2(1.0, 1.0), 0.1)
		tween.tween_property(dollar_interact_button, "modulate", Color.WHITE, 0.2)

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
	"""Configurar controles móviles CON BOTÓN DÓLAR MEJORADO"""
	if not is_mobile:
		return
	
	mobile_controls = Control.new()
	mobile_controls.name = "MobileControls"
	mobile_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mobile_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mobile_controls.z_index = 50
	ui_manager.add_child(mobile_controls)
	
	await get_tree().process_frame
	
	create_movement_joystick_large()
	create_shooting_joystick_large()
	create_mobile_action_buttons_with_dollar_improved()
	
	if movement_joystick_base:
		movement_joystick_base.visible = true
		movement_joystick_base.modulate = Color.WHITE
	
	if shooting_joystick_base:
		shooting_joystick_base.visible = true  
		shooting_joystick_base.modulate = Color.WHITE

func create_mobile_action_buttons_with_dollar_improved():
	"""Crear botones con BOTÓN DÓLAR MEJORADO - ICONO DE DÓLAR"""
	if not is_mobile or not mobile_controls:
		return
	
	var viewport_size = get_viewport().get_visible_rect().size
	
	# POSICIÓN BASE A LA IZQUIERDA DEL JOYSTICK DE DISPARO
	var joystick_shooting_x = viewport_size.x * 0.78
	var buttons_x = joystick_shooting_x - 200
	
	# BOTÓN MELEE - ARRIBA
	melee_button = Button.new()
	melee_button.text = "⚔"
	melee_button.size = Vector2(150, 150)
	melee_button.position = Vector2(
		buttons_x,
		viewport_size.y * 0.25
	)
	melee_button.add_theme_font_size_override("font_size", 70)
	
	var melee_style = StyleBoxFlat.new()
	melee_style.bg_color = Color(0.8, 0.1, 0.1, 0.9)
	melee_style.corner_radius_top_left = 75
	melee_style.corner_radius_top_right = 75
	melee_style.corner_radius_bottom_left = 75
	melee_style.corner_radius_bottom_right = 75
	melee_style.border_color = Color.YELLOW
	melee_style.border_width_left = 4
	melee_style.border_width_right = 4
	melee_style.border_width_top = 4
	melee_style.border_width_bottom = 4
	melee_button.add_theme_stylebox_override("normal", melee_style)
	
	mobile_controls.add_child(melee_button)
	
	# BOTÓN DÓLAR MEJORADO - INTERACTUAR/COMPRAR/RECARGAR - ABAJO
	dollar_interact_button = Button.new()
	dollar_interact_button.text = "$"  # SÍMBOLO DE DÓLAR CLARO
	dollar_interact_button.size = Vector2(150, 150)
	dollar_interact_button.position = Vector2(
		buttons_x,
		viewport_size.y * 0.55
	)
	dollar_interact_button.add_theme_font_size_override("font_size", 80)  # MÁS GRANDE
	
	var dollar_style = StyleBoxFlat.new()
	dollar_style.bg_color = Color(0.1, 0.6, 0.1, 0.9)  # VERDE PARA DINERO
	dollar_style.corner_radius_top_left = 75
	dollar_style.corner_radius_top_right = 75
	dollar_style.corner_radius_bottom_left = 75
	dollar_style.corner_radius_bottom_right = 75
	dollar_style.border_color = Color.GOLD
	dollar_style.border_width_left = 6  # BORDE MÁS GRUESO
	dollar_style.border_width_right = 6
	dollar_style.border_width_top = 6
	dollar_style.border_width_bottom = 6
	dollar_interact_button.add_theme_stylebox_override("normal", dollar_style)
	
	# COLOR DEL TEXTO DEL DÓLAR
	dollar_interact_button.add_theme_color_override("font_color", Color.GOLD)
	dollar_interact_button.add_theme_color_override("font_shadow_color", Color.BLACK)
	dollar_interact_button.add_theme_constant_override("shadow_offset_x", 3)
	dollar_interact_button.add_theme_constant_override("shadow_offset_y", 3)
	
	mobile_controls.add_child(dollar_interact_button)

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
	
# GAMEMANAGER PARTE 3/3: GAME OVER Y FUNCIONES FINALES

func _on_round_changed(new_round: int):
	"""Actualizar ronda"""
	if score_system:
		score_system.set_current_round(new_round)
	
	# GUARDAR CUANDO CAMBIE DE RONDA
	if is_mobile:
		save_game_state()

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

func _on_player_died():
	"""Cuando muere el jugador CON GUARDADO"""
	if is_game_over:
		return
	
	is_game_over = true
	pause_enemy_spawning()
	
	# GUARDAR ESTADO FINAL
	if is_mobile:
		save_game_state()
	
	await get_tree().create_timer(1.0).timeout
	show_game_over_screen()

func show_game_over_screen():
	"""Mostrar pantalla Game Over MEJORADA"""
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
	var panel_size = Vector2(400, 350) if not is_mobile else Vector2(min(viewport_size.x * 0.9, 500), 450)
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
	vbox.add_theme_constant_override("separation", 25)
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
	
	# MENSAJE ESPECIAL PARA ANDROID
	if is_mobile:
		var save_info = Label.new()
		save_info.text = "💾 Partida guardada automáticamente"
		save_info.add_theme_font_size_override("font_size", 16)
		save_info.add_theme_color_override("font_color", Color.GREEN)
		save_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats_container.add_child(save_info)
	
	var buttons_container = VBoxContainer.new()
	buttons_container.add_theme_constant_override("separation", 15)
	vbox.add_child(buttons_container)
	
	var retry_btn = Button.new()
	retry_btn.text = "🔄 REINTENTAR"
	retry_btn.custom_minimum_size = Vector2(300,50) if not is_mobile else Vector2(350, 60)
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
	quit_btn.text = "❌ SALIR" if not is_mobile else "🏠 MENÚ PRINCIPAL"
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
		if is_mobile:
			# EN MÓVIL: VOLVER AL MENÚ PRINCIPAL
			restart_entire_game()
		else:
			# EN PC: SALIR COMPLETAMENTE
			get_tree().quit()
	)
	buttons_container.add_child(quit_btn)
	
	ui_manager.add_child(game_over_screen)
	get_tree().paused = true

func restart_entire_game():
	"""Reiniciar juego completo CON LIMPIEZA DE GUARDADO"""
	clear_all_enemies()
	is_game_over = false
	game_started = false
	enemies_killed = 0
	game_state = "character_selection"
	
	# LIMPIAR ARCHIVO DE GUARDADO EN MÓVIL
	if is_mobile and FileAccess.file_exists(save_file_path):
		var file = FileAccess.open(save_file_path, FileAccess.WRITE)
		if file:
			file.store_string("")  # LIMPIAR ARCHIVO
			file.close()
		print("💾 Archivo de guardado limpiado")
	
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_enemy_killed(enemy: Enemy):
	"""Registrar kill de enemigo CON GUARDADO PERIÓDICO"""
	enemies_killed += 1
	
	if rounds_manager:
		rounds_manager.on_enemy_killed()
	
	# GUARDAR CADA 10 KILLS EN MÓVIL
	if is_mobile and enemies_killed % 10 == 0:
		save_game_state()

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
	"""Manejar notificaciones del sistema CON GUARDADO"""
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			# GUARDAR ANTES DE CERRAR
			if is_mobile:
				save_game_state()
			cleanup_before_exit()
			get_tree().quit()
		NOTIFICATION_APPLICATION_PAUSED:
			# GUARDAR CUANDO LA APP SE PAUSA
			if is_mobile and is_game_active():
				save_game_state()
				if not pause_menu.is_paused:
					toggle_pause_menu()
		NOTIFICATION_APPLICATION_RESUMED:
			# CUANDO LA APP SE REANUDA
			if is_mobile:
				print("📱 Aplicación reanudada")

func cleanup_before_exit():
	"""Limpiar todo antes de salir"""
	set_process(false)
	set_physics_process(false)
	
	# GUARDAR FINAL EN MÓVIL
	if is_mobile:
		save_game_state()
	
	if enemy_spawner:
		enemy_spawner.clear_all_enemies()
		enemy_spawner.pause_spawning()
	
	if rounds_manager:
		rounds_manager.set_process(false)
		rounds_manager.set_physics_process(false)
	
	if score_system:
		score_system.set_process(false)
		score_system.set_physics_process(false)
	
	if player:
		player.set_process(false)
		player.set_physics_process(false)
	
	if is_mobile:
		set_process_input(false)
	
	get_tree().paused = false

func _exit_tree():
	"""Limpiar al salir del árbol de nodos"""
	cleanup_before_exit()
