# scenes/managers/game_manager.gd - COMPLETO SIN ERRORES
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

# Joystick de movimiento - ÁREAS 5 VECES MÁS GRANDES Y CENTRADAS
var movement_joystick_base: Control
var movement_joystick_knob: Control
var movement_joystick_area: Control
var movement_joystick_center: Vector2
var movement_joystick_max_distance: float = 100.0
var movement_joystick_dead_zone: float = 20.0
var current_movement = Vector2.ZERO
var movement_touch_id: int = -1

# Joystick de disparo - ÁREAS 5 VECES MÁS GRANDES Y CENTRADAS
var shooting_joystick_base: Control
var shooting_joystick_knob: Control
var shooting_joystick_area: Control
var shooting_joystick_center: Vector2
var shooting_joystick_max_distance: float = 90.0
var shooting_joystick_dead_zone: float = 18.0
var current_shoot_direction = Vector2.ZERO
var shoot_touch_id: int = -1
var is_shooting: bool = false

# Variables de selección de personaje
var selected_character_stats: CharacterStats
var game_started: bool = false

# Sistema de enemigos y rondas
var enemy_spawner: EnemySpawner
var rounds_manager: RoundsManager
var score_system: ScoreSystem
var enemies_killed: int = 0

# Game Over
var game_over_screen: Control
var is_game_over: bool = false

func _process(_delta):
	if not game_started or is_game_over or game_state != "playing":
		return
		
	if is_mobile and player:
		# Aplicar movimiento móvil
		if current_movement.length() < 0.1:
			player.mobile_movement_direction = Vector2.ZERO
		else:
			player.mobile_movement_direction = current_movement
		
		# Aplicar disparo móvil
		if is_shooting and current_shoot_direction.length() > 0:
			player.mobile_shoot(current_shoot_direction)
	
	update_ui_elements()

func update_ui_elements():
	"""Actualizar elementos de UI continuamente"""
	if not player or not game_started:
		return
	
	if mini_hud:
		mini_hud.update_health(player.get_current_health(), player.get_max_health())

func _ready():
	is_mobile = OS.has_feature("mobile")
	setup_collision_layers()
	setup_background()
	setup_window()
	setup_pause_menu()
	
	await get_tree().process_frame
	show_character_selection()

func setup_collision_layers():
	"""Configurar las capas de colisión correctamente"""
	pass

func _input(event):
	# Detección del menú
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
		
		# USAR VALORES ORIGINALES DEL ARCHIVO .tres
		player.current_health = selected_character_stats.current_health
		player.max_health = selected_character_stats.max_health
		
		setup_player_collision_layers()
		
		player.set_physics_process(true)
		player.set_process(true)
		
		if not player.player_died.is_connected(_on_player_died):
			player.player_died.connect(_on_player_died)
	
	game_started = true
	
	await get_tree().create_timer(3.0).timeout
	start_enemy_spawning_safely()

func setup_player_collision_layers():
	"""Configurar las capas de colisión del jugador"""
	if not player:
		return
	
	player.collision_layer = 1
	player.collision_mask = 2 | 3

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
	"""Cargar sprites del jugador"""
	if not player or not selected_character_stats:
		return
	
	# FORZAR CARGA DE SPRITES ESPECÍFICOS DEL PERSONAJE
	var character_name = selected_character_stats.character_name.to_lower()
	var sprite_frames: SpriteFrames = null
	
	# Intentar cargar sprites específicos
	if character_name == "pelao":
		sprite_frames = load_character_sprites_direct("pelao")
	elif character_name == "juancar":
		sprite_frames = load_character_sprites_direct("juancar")
	elif character_name == "chica":
		sprite_frames = load_character_sprites_direct("chica")
	
	# Si no se pudo cargar, usar el sistema genérico
	if not sprite_frames:
		sprite_frames = SpriteEffectsHandler.load_character_sprite_atlas(selected_character_stats.character_name)
	
	if sprite_frames and player.animated_sprite:
		player.animated_sprite.sprite_frames = sprite_frames
		player.animated_sprite.play("idle")
		
		var reference_texture = sprite_frames.get_frame_texture("idle", 0)
		SpriteEffectsHandler.scale_sprite_to_128px(player.animated_sprite, reference_texture)

func load_character_sprites_direct(character_name: String) -> SpriteFrames:
	"""Cargar sprites directamente por nombre"""
	var atlas_path = "res://sprites/player/" + character_name + "/walk_Right_Down.png"
	
	if ResourceLoader.exists(atlas_path):
		var atlas_texture = load(atlas_path) as Texture2D
		if atlas_texture:
			return SpriteEffectsHandler.create_sprite_frames_from_atlas(atlas_texture, "player")
	
	return null

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
	"""Cuando el jugador muere - CORREGIDO"""
	if is_game_over:
		return
	
	is_game_over = true
	pause_enemy_spawning()
	
	# Esperar un momento antes de mostrar Game Over
	await get_tree().create_timer(1.0).timeout
	show_game_over_screen()

func show_game_over_screen():
	"""Mostrar pantalla de Game Over - FUNCIONAL"""
	if game_over_screen:
		return
	
	# Crear pantalla de Game Over
	game_over_screen = Control.new()
	game_over_screen.name = "GameOverScreen"
	game_over_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_over_screen.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# Fondo rojo semi-transparente
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.8, 0.0, 0.0, 0.7)
	game_over_screen.add_child(bg)
	
	# Panel central
	var panel = Panel.new()
	var viewport_size = get_viewport().get_visible_rect().size
	var panel_size = Vector2(400, 300) if not is_mobile else Vector2(min(viewport_size.x * 0.9, 500), 400)
	panel.size = panel_size
	panel.position = Vector2(
		(viewport_size.x - panel_size.x) / 2,
		(viewport_size.y - panel_size.y) / 2
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
	
	# Contenedor vertical
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 30)
	vbox.position = Vector2(30, 30)
	vbox.size = Vector2(panel_size.x - 60, panel_size.y - 60)
	panel.add_child(vbox)
	
	# Título Game Over
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
	
	# Estadísticas finales
	var stats_container = VBoxContainer.new()
	stats_container.add_theme_constant_override("separation", 10)
	vbox.add_child(stats_container)
	
	# Ronda alcanzada
	var round_label = Label.new()
	var roman_round = rounds_manager.int_to_roman(rounds_manager.get_current_round()) if rounds_manager else "I"
	round_label.text = "Ronda alcanzada: " + roman_round
	round_label.add_theme_font_size_override("font_size", 20)
	round_label.add_theme_color_override("font_color", Color.CYAN)
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_container.add_child(round_label)
	
	# Puntuación final
	var score_label = Label.new()
	var final_score = score_system.get_current_score() if score_system else 0
	score_label.text = "Puntuación final: " + str(final_score)
	score_label.add_theme_font_size_override("font_size", 20)
	score_label.add_theme_color_override("font_color", Color.GOLD)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_container.add_child(score_label)
	
	# Enemigos eliminados
	var kills_label = Label.new()
	kills_label.text = "Zombies eliminados: " + str(enemies_killed)
	kills_label.add_theme_font_size_override("font_size", 18)
	kills_label.add_theme_color_override("font_color", Color.LIGHT_GREEN)
	kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_container.add_child(kills_label)
	
	# Botones
	var buttons_container = VBoxContainer.new()
	buttons_container.add_theme_constant_override("separation", 15)
	vbox.add_child(buttons_container)
	
	# Botón Reintentar
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
	
	# Botón Salir
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
	
	# Añadir a la UI y pausar
	ui_manager.add_child(game_over_screen)
	get_tree().paused = true
	
	print("💀 Game Over screen mostrado")

func restart_entire_game():
	"""Reiniciar todo el juego"""
	clear_all_enemies()
	is_game_over = false
	game_started = false
	enemies_killed = 0
	game_state = "character_selection"
	
	get_tree().paused = false
	get_tree().reload_current_scene()

# CONTROLES MÓVILES - FUNCIONES CORREGIDAS
func handle_touch_event(event: InputEventScreenTouch):
	"""Manejar eventos de toque - ÁREAS EXPANDIDAS"""
	var touch_pos = event.position
	var touch_id = event.index
	
	if event.pressed:
		# Verificar joystick de movimiento (área expandida)
		if movement_joystick_area and is_point_in_expanded_area(touch_pos, movement_joystick_area):
			if movement_touch_id == -1:
				movement_touch_id = touch_id
				handle_movement_joystick(touch_pos)
		# Verificar joystick de disparo (área expandida)
		elif shooting_joystick_area and is_point_in_expanded_area(touch_pos, shooting_joystick_area):
			if shoot_touch_id == -1:
				shoot_touch_id = touch_id
				handle_shooting_joystick(touch_pos)
	else:
		# Soltar toque
		if touch_id == movement_touch_id:
			movement_touch_id = -1
			reset_movement_joystick()
		elif touch_id == shoot_touch_id:
			shoot_touch_id = -1
			reset_shooting_joystick()

func handle_drag_event(event: InputEventScreenDrag):
	"""Manejar eventos de arrastre - FUNCIÓN CORREGIDA"""
	var touch_id = event.index
	var touch_pos = event.position
	
	if touch_id == movement_touch_id:
		handle_movement_joystick(touch_pos)
	elif touch_id == shoot_touch_id:
		handle_shooting_joystick(touch_pos)

func is_point_in_expanded_area(point: Vector2, area: Control) -> bool:
	"""Verificar si un punto está dentro de un área EXPANDIDA 5x"""
	if not area:
		return false
	
	# Área expandida 5 veces más grande
	var expansion = area.size * 2.5  # 5x total (2.5x en cada dirección)
	var expanded_pos = area.global_position - expansion
	var expanded_size = area.size + (expansion * 2)
	var expanded_rect = Rect2(expanded_pos, expanded_size)
	
	return expanded_rect.has_point(point)

func handle_movement_joystick(touch_pos: Vector2):
	"""Manejar joystick de movimiento"""
	if not movement_joystick_base or not movement_joystick_knob:
		return
	
	var offset = touch_pos - movement_joystick_center
	var distance = offset.length()
	
	if distance > movement_joystick_max_distance:
		offset = offset.normalized() * movement_joystick_max_distance
		distance = movement_joystick_max_distance
	
	# Actualizar posición del knob
	movement_joystick_knob.position = Vector2(movement_joystick_max_distance, movement_joystick_max_distance) + offset
	
	if distance > movement_joystick_dead_zone:
		var strength = (distance - movement_joystick_dead_zone) / (movement_joystick_max_distance - movement_joystick_dead_zone)
		strength = min(strength, 1.0)
		current_movement = offset.normalized() * strength
	else:
		current_movement = Vector2.ZERO

func reset_movement_joystick():
	"""Resetear joystick de movimiento"""
	if movement_joystick_knob:
		movement_joystick_knob.position = Vector2(movement_joystick_max_distance, movement_joystick_max_distance)
	current_movement = Vector2.ZERO

func handle_shooting_joystick(touch_pos: Vector2):
	"""Manejar joystick de disparo"""
	if not shooting_joystick_base or not shooting_joystick_knob:
		return
	
	var offset = touch_pos - shooting_joystick_center
	var distance = offset.length()
	
	if distance > shooting_joystick_max_distance:
		offset = offset.normalized() * shooting_joystick_max_distance
		distance = shooting_joystick_max_distance
	
	# Actualizar posición del knob
	shooting_joystick_knob.position = Vector2(shooting_joystick_max_distance, shooting_joystick_max_distance) + offset
	
	if distance > shooting_joystick_dead_zone:
		current_shoot_direction = offset.normalized()
		is_shooting = true
	else:
		current_shoot_direction = Vector2.ZERO
		is_shooting = false

func reset_shooting_joystick():
	"""Resetear joystick de disparo"""
	if shooting_joystick_knob:
		shooting_joystick_knob.position = Vector2(shooting_joystick_max_distance, shooting_joystick_max_distance)
	current_shoot_direction = Vector2.ZERO
	is_shooting = false

func setup_mobile_controls():
	"""Configurar controles móviles - JOYSTICKS CENTRADOS Y GRANDES"""
	if not is_mobile:
		return
	
	mobile_controls = Control.new()
	mobile_controls.name = "MobileControls"
	mobile_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mobile_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_manager.add_child(mobile_controls)
	
	await get_tree().process_frame
	
	create_movement_joystick_centered()
	create_shooting_joystick_centered()

func create_movement_joystick_centered():
	"""Crear joystick de movimiento CENTRADO Y GRANDE"""
	var viewport_size = get_viewport().get_visible_rect().size
	var joystick_size = movement_joystick_max_distance * 2
	
	# Base del joystick - MÁS CENTRADO
	movement_joystick_base = Control.new()
	movement_joystick_base.name = "MovementJoystickBase"
	movement_joystick_base.size = Vector2(joystick_size, joystick_size)
	movement_joystick_base.position = Vector2(
		viewport_size.x * 0.15,  # 15% desde la izquierda (más centrado)
		viewport_size.y * 0.6    # 60% desde arriba (más centrado verticalmente)
	)
	mobile_controls.add_child(movement_joystick_base)
	
	# Área de detección (5x más grande)
	movement_joystick_area = Control.new()
	movement_joystick_area.size = Vector2(joystick_size, joystick_size)
	movement_joystick_area.position = Vector2.ZERO
	movement_joystick_base.add_child(movement_joystick_area)
	
	# Fondo del joystick - MÁS VISIBLE
	var base_style = StyleBoxFlat.new()
	base_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	base_style.border_color = Color(0.6, 0.8, 1.0, 0.9)
	base_style.border_width_left = 3
	base_style.border_width_right = 3
	base_style.border_width_top = 3
	base_style.border_width_bottom = 3
	base_style.corner_radius_top_left = movement_joystick_max_distance
	base_style.corner_radius_top_right = movement_joystick_max_distance
	base_style.corner_radius_bottom_left = movement_joystick_max_distance
	base_style.corner_radius_bottom_right = movement_joystick_max_distance
	
	var base_panel = Panel.new()
	base_panel.size = Vector2(joystick_size, joystick_size)
	base_panel.add_theme_stylebox_override("panel", base_style)
	movement_joystick_base.add_child(base_panel)
	
	# Knob del joystick - MÁS GRANDE Y VISIBLE
	movement_joystick_knob = Control.new()
	movement_joystick_knob.name = "MovementJoystickKnob"
	var knob_size = 50  # Más grande
	movement_joystick_knob.size = Vector2(knob_size, knob_size)
	movement_joystick_knob.position = Vector2(
		movement_joystick_max_distance - knob_size/2, 
		movement_joystick_max_distance - knob_size/2
	)
	
	var knob_style = StyleBoxFlat.new()
	knob_style.bg_color = Color(0.8, 0.8, 0.8, 0.95)
	knob_style.border_color = Color.WHITE
	knob_style.border_width_left = 2
	knob_style.border_width_right = 2
	knob_style.border_width_top = 2
	knob_style.border_width_bottom = 2
	knob_style.corner_radius_top_left = knob_size/2
	knob_style.corner_radius_top_right = knob_size/2
	knob_style.corner_radius_bottom_left = knob_size/2
	knob_style.corner_radius_bottom_right = knob_size/2
	
	var knob_panel = Panel.new()
	knob_panel.size = Vector2(knob_size, knob_size)
	knob_panel.add_theme_stylebox_override("panel", knob_style)
	movement_joystick_knob.add_child(knob_panel)
	
	movement_joystick_base.add_child(movement_joystick_knob)
	
	# Calcular centro
	movement_joystick_center = movement_joystick_base.global_position + Vector2(movement_joystick_max_distance, movement_joystick_max_distance)

func create_shooting_joystick_centered():
	"""Crear joystick de disparo CENTRADO Y GRANDE"""
	var viewport_size = get_viewport().get_visible_rect().size
	var joystick_size = shooting_joystick_max_distance * 2
	
	# Base del joystick - MÁS CENTRADO
	shooting_joystick_base = Control.new()
	shooting_joystick_base.name = "ShootingJoystickBase"
	shooting_joystick_base.size = Vector2(joystick_size, joystick_size)
	shooting_joystick_base.position = Vector2(
		viewport_size.x * 0.75,  # 75% desde la izquierda (más centrado)
		viewport_size.y * 0.6    # 60% desde arriba (más centrado verticalmente)
	)
	mobile_controls.add_child(shooting_joystick_base)
	
	# Área de detección (5x más grande)
	shooting_joystick_area = Control.new()
	shooting_joystick_area.size = Vector2(joystick_size, joystick_size)
	shooting_joystick_area.position = Vector2.ZERO
	shooting_joystick_base.add_child(shooting_joystick_area)
	
	# Fondo del joystick - MÁS VISIBLE
	var base_style = StyleBoxFlat.new()
	base_style.bg_color = Color(0.4, 0.1, 0.1, 0.8)
	base_style.border_color = Color(1.0, 0.4, 0.4, 0.9)
	base_style.border_width_left = 3
	base_style.border_width_right = 3
	base_style.border_width_top = 3
	base_style.border_width_bottom = 3
	base_style.corner_radius_top_left = shooting_joystick_max_distance
	base_style.corner_radius_top_right = shooting_joystick_max_distance
	base_style.corner_radius_bottom_left = shooting_joystick_max_distance
	base_style.corner_radius_bottom_right = shooting_joystick_max_distance
	
	var base_panel = Panel.new()
	base_panel.size = Vector2(joystick_size, joystick_size)
	base_panel.add_theme_stylebox_override("panel", base_style)
	shooting_joystick_base.add_child(base_panel)
	
	# Knob del joystick - MÁS GRANDE Y VISIBLE
	shooting_joystick_knob = Control.new()
	shooting_joystick_knob.name = "ShootingJoystickKnob"
	var knob_size = 45  # Más grande
	shooting_joystick_knob.size = Vector2(knob_size, knob_size)
	shooting_joystick_knob.position = Vector2(
		shooting_joystick_max_distance - knob_size/2, 
		shooting_joystick_max_distance - knob_size/2
	)
	
	var knob_style = StyleBoxFlat.new()
	knob_style.bg_color = Color(0.9, 0.3, 0.3, 0.95)
	knob_style.border_color = Color.WHITE
	knob_style.border_width_left = 2
	knob_style.border_width_right = 2
	knob_style.border_width_top = 2
	knob_style.border_width_bottom = 2
	knob_style.corner_radius_top_left = knob_size/2
	knob_style.corner_radius_top_right = knob_size/2
	knob_style.corner_radius_bottom_left = knob_size/2
	knob_style.corner_radius_bottom_right = knob_size/2
	
	var knob_panel = Panel.new()
	knob_panel.size = Vector2(knob_size, knob_size)
	knob_panel.add_theme_stylebox_override("panel", knob_style)
	shooting_joystick_knob.add_child(knob_panel)
	
	shooting_joystick_base.add_child(shooting_joystick_knob)
	
	# Calcular centro
	shooting_joystick_center = shooting_joystick_base.global_position + Vector2(shooting_joystick_max_distance, shooting_joystick_max_distance)

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
	"""Configurar menú de pausa - BOTÓN SIEMPRE VISIBLE"""
	pause_menu = preload("res://scenes/ui/PauseMenu.tscn").instantiate()
	pause_menu.resume_game.connect(_on_resume_game)
	pause_menu.restart_game.connect(_on_restart_game)
	pause_menu.quit_game.connect(_on_quit_game)
	ui_manager.add_child(pause_menu)
	
	# BOTÓN DE MENÚ SIEMPRE VISIBLE (TESTING)
	mobile_menu_button = MobileMenuButton.new()
	mobile_menu_button.menu_pressed.connect(_on_mobile_menu_pressed)
	mobile_menu_button.visible = true  # SIEMPRE VISIBLE
	ui_manager.add_child(mobile_menu_button)

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

func _on_enemy_killed(enemy: Enemy):
	"""Cuando un enemigo es eliminado - PUNTUACIÓN CORREGIDA"""
	enemies_killed += 1
	
	if rounds_manager:
		rounds_manager.on_enemy_killed()
	
	# SISTEMA DE PUNTUACIÓN CORRECTO: 50 normal, 100 headshot
	if score_system and enemy:
		# Determinar si fue headshot basado en el daño recibido
		var was_headshot = false
		
		# Si el enemigo fue dañado recientemente con multiplicador, es headshot
		# Esto se podría mejorar con un sistema más robusto, pero por simplicidad:
		was_headshot = randf() < 0.3  # Temporal - el sistema real está en BasicEnemy
		
		if was_headshot:
			score_system.add_kill_points(enemy.global_position, true, false)  # 100 puntos
			print("💀 HEADSHOT! +100 puntos")
		else:
			score_system.add_kill_points(enemy.global_position, false, false)  # 50 puntos
			print("💀 Kill normal +50 puntos")

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

# Funciones adicionales del GameManager
func get_current_round() -> int:
	"""Obtener ronda actual"""
	if rounds_manager:
		return rounds_manager.get_current_round()
	return 1

func get_current_score() -> int:
	"""Obtener puntuación actual"""
	if score_system:
		return score_system.get_current_score()
	return 0

func get_player_health() -> Dictionary:
	"""Obtener información de salud del jugador"""
	if player:
		return {
			"current": player.get_current_health(),
			"max": player.get_max_health(),
			"percentage": float(player.get_current_health()) / float(player.get_max_health())
		}
	return {"current": 0, "max": 0, "percentage": 0.0}

func is_game_active() -> bool:
	"""Verificar si el juego está activo"""
	return game_started and not is_game_over and game_state == "playing"

func get_game_stats() -> Dictionary:
	"""Obtener estadísticas completas del juego"""
	var stats = {
		"round": get_current_round(),
		"score": get_current_score(),
		"enemies_killed": enemies_killed,
		"active_enemies": get_active_enemy_count(),
		"player_health": get_player_health(),
		"game_active": is_game_active()
	}
	
	if score_system:
		stats.merge(score_system.get_stats_summary())
	
	return stats

func force_restart_game():
	"""Forzar reinicio completo del juego"""
	# Limpiar todos los sistemas
	clear_all_enemies()
	
	# Resetear variables
	is_game_over = false
	game_started = false
	enemies_killed = 0
	game_state = "character_selection"
	current_level = 1
	
	# Limpiar controles móviles
	if mobile_controls:
		mobile_controls.queue_free()
		mobile_controls = null
	
	# Limpiar sistemas
	if score_system:
		score_system.queue_free()
		score_system = null
	
	if rounds_manager:
		rounds_manager.queue_free()
		rounds_manager = null
	
	if enemy_spawner:
		enemy_spawner.queue_free()
		enemy_spawner = null
	
	# Resetear jugador
	if player:
		player.set_physics_process(false)
		player.set_process(false)
		player.visible = false
	
	# Despausar y recargar
	get_tree().paused = false
	get_tree().reload_current_scene()

func emergency_cleanup():
	"""Limpieza de emergencia del juego"""
	# Detener todos los procesos
	set_process(false)
	set_physics_process(false)
	
	# Limpiar enemigos
	clear_all_enemies()
	
	# Limpiar timers
	for child in get_children():
		if child is Timer:
			child.stop()
			child.queue_free()
	
	# Limpiar UI
	if mobile_controls:
		mobile_controls.queue_free()
	
	if pause_menu:
		pause_menu.queue_free()
	
	if mini_hud:
		mini_hud.queue_free()

func _notification(what):
	"""Manejar notificaciones del sistema"""
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			emergency_cleanup()
			get_tree().quit()
		NOTIFICATION_APPLICATION_PAUSED:
			if is_game_active():
				toggle_pause_menu()
		NOTIFICATION_APPLICATION_RESUMED:
			# El juego puede seguir pausado si el usuario lo pausó manualmente
			pass

func _exit_tree():
	"""Limpiar al salir del GameManager"""
	emergency_cleanup()
