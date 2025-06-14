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

# SISTEMA DE ENEMIGOS Y RONDAS - UNIFICADO CON PUNTUACIÓN
var enemy_spawner: EnemySpawner
var rounds_manager: RoundsManager
var score_system: ScoreSystem
var enemies_killed: int = 0

var mobile_process_counter: int = 0
var mobile_process_skip: int = 1

# GAME OVER
var game_over_screen: Control
var is_game_over: bool = false

func _process(_delta):
	if not game_started or is_game_over:
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

func _input(event):
	# MEJOR DETECCIÓN DEL MENÚ - FORZAR PARA TODAS LAS PLATAFORMAS
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.keycode == KEY_ESCAPE):
		if game_started and game_state == "playing" and not is_game_over:
			toggle_pause_menu()
		return
	
	# Para Android, detectar el botón de back del sistema
	if event is InputEventKey and event.keycode == KEY_BACK:
		if game_started and game_state == "playing" and not is_game_over:
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
	print("🎮 Botón de menú móvil presionado en GameManager")
	toggle_pause_menu()

func _on_resume_game():
	resume_enemy_spawning()

func _on_restart_game():
	restart_entire_game()

func _on_quit_game():
	clear_all_enemies()
	get_tree().paused = false
	get_tree().quit()

func restart_entire_game():
	# Limpiar estado
	clear_all_enemies()
	is_game_over = false
	game_started = false
	enemies_killed = 0
	
	# Ocultar pantallas
	if game_over_screen:
		game_over_screen.queue_free()
		game_over_screen = null
	
	if pause_menu:
		pause_menu.hide_menu()
	
	# Limpiar controles móviles
	if mobile_controls:
		mobile_controls.queue_free()
		mobile_controls = null
	
	# Despausar
	get_tree().paused = false
	
	# Recargar escena
	get_tree().reload_current_scene()

func setup_pause_menu():
	pause_menu = preload("res://scenes/ui/PauseMenu.tscn").instantiate()
	pause_menu.resume_game.connect(_on_resume_game)
	pause_menu.restart_game.connect(_on_restart_game)
	pause_menu.quit_game.connect(_on_quit_game)
	ui_manager.add_child(pause_menu)
	
	# CREAR BOTÓN DE MENÚ MÓVIL SIEMPRE (PARA TODAS LAS PLATAFORMAS)
	mobile_menu_button = MobileMenuButton.new()
	mobile_menu_button.menu_pressed.connect(_on_mobile_menu_pressed)
	mobile_menu_button.visible = true  # FORZAR VISIBLE
	ui_manager.add_child(mobile_menu_button)
	
	print("🎮 Botón de menú móvil creado y conectado")

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
	setup_unified_cod_system()
	
	if player:
		player.set_physics_process(true)
		player.set_process(true)
		
		# CONECTAR SEÑAL DE MUERTE DEL JUGADOR
		player.player_died.connect(_on_player_died)
	
	game_started = true

func _on_player_died():
	print("💀 JUGADOR HA MUERTO - INICIANDO GAME OVER")
	show_game_over_screen()

func show_game_over_screen():
	if is_game_over:
		return
	
	is_game_over = true
	get_tree().paused = true
	
	# Crear pantalla de Game Over
	game_over_screen = Control.new()
	game_over_screen.name = "GameOverScreen"
	game_over_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_over_screen.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# Fondo
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.1, 0.0, 0.0, 0.9)  # Rojo oscuro
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
	
	var button_hover = StyleBoxFlat.new()
	button_hover.bg_color = color.darkened(0.5)
	button_hover.corner_radius_top_left = 10
	button_hover.corner_radius_top_right = 10
	button_hover.corner_radius_bottom_left = 10
	button_hover.corner_radius_bottom_right = 10
	button_hover.border_color = color.lightened(0.2)
	button_hover.border_width_left = 3
	button_hover.border_width_right = 3
	button_hover.border_width_top = 3
	button_hover.border_width_bottom = 3
	button.add_theme_stylebox_override("hover", button_hover)
	
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_shadow_color", Color.BLACK)
	button.add_theme_constant_override("shadow_offset_x", 2)
	button.add_theme_constant_override("shadow_offset_y", 2)
	
	return button

func setup_background():
	background_sprite = Sprite2D.new()
	background_sprite.name = "Background"
	background_sprite.z_index = -100
	
	var jungle_texture = try_load_texture_safe("res://sprites/background/jungle.png")
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
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
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
			
			# FORZAR CARGA CORRECTA DE ANIMACIONES DESDE ATLAS
			fix_player_animations()

func fix_player_animations():
	if not player or not player.character_stats:
		return
	
	print("🎮 Forzando carga de animaciones para: ", player.character_stats.character_name)
	
	# Obtener folder del personaje
	var char_name = player.character_stats.character_name.to_lower().replace(" ", "")
	var folder_name = get_folder_name_from_character_name(char_name)
	
	# Crear SpriteFrames desde cero
	var sprite_frames = SpriteFrames.new()
	
	# Cargar atlas walk_Right_Down (1024x128, 8 frames)
	var atlas_path = "res://sprites/player/" + folder_name + "/walk_Right_Down.png"
	var atlas_texture = try_load_texture_safe(atlas_path)
	
	if not atlas_texture:
		# Fallback a chica
		atlas_path = "res://sprites/player/chica/walk_Right_Down.png"
		atlas_texture = try_load_texture_safe(atlas_path)
	
	if atlas_texture:
		print("✅ Atlas cargado: ", atlas_path, " - Tamaño: ", atlas_texture.get_size())
		
		# Crear animación idle desde el primer frame
		sprite_frames.add_animation("idle")
		sprite_frames.set_animation_speed("idle", 2.0)
		sprite_frames.set_animation_loop("idle", true)
		
		var first_frame = extract_first_frame_from_atlas_1024x128(atlas_texture)
		sprite_frames.add_frame("idle", first_frame)
		
		# Crear animación de caminar
		sprite_frames.add_animation("walk_Right_Down")
		sprite_frames.set_animation_speed("walk_Right_Down", 8.0)
		sprite_frames.set_animation_loop("walk_Right_Down", true)
		
		# Cargar todos los 8 frames del atlas
		for frame_idx in range(8):
			var frame = extract_frame_from_atlas_1024x128(atlas_texture, frame_idx)
			sprite_frames.add_frame("walk_Right_Down", frame)
		
		# Crear otras animaciones básicas usando los frames existentes
		var basic_animations = ["walk_Up", "walk_Down", "walk_Left_Down", "walk_Right_Up", "walk_Left_Up"]
		
		for anim_name in basic_animations:
			sprite_frames.add_animation(anim_name)
			sprite_frames.set_animation_speed(anim_name, 8.0)
			sprite_frames.set_animation_loop(anim_name, true)
			
			# Usar los frames de walk_Right_Down como base
			for frame_idx in range(8):
				var frame = sprite_frames.get_frame_texture("walk_Right_Down", frame_idx)
				sprite_frames.add_frame(anim_name, frame)
		
		# Asignar SpriteFrames al jugador
		if player.animated_sprite:
			player.animated_sprite.sprite_frames = sprite_frames
			player.animated_sprite.scale = Vector2(2.0, 2.0)  # Escalar para 128px
			player.animated_sprite.play("idle")
			print("✅ Animaciones del jugador configuradas correctamente")
		else:
			print("❌ No se encontró AnimatedSprite2D en el jugador")
	else:
		print("❌ No se pudo cargar ningún atlas para el personaje")

func get_folder_name_from_character_name(char_name: String) -> String:
	var name_mappings = {
		"pelao": "pelao",
		"juancar": "juancar", 
		"juan_car": "juancar",
		"chica": "chica",
		"guerrerobásico": "pelao",
		"guerrerobasico": "pelao"
	}
	return name_mappings.get(char_name, char_name)

func try_load_texture_safe(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var resource = load(path)
	if resource is Texture2D:
		return resource as Texture2D
	return null

func extract_first_frame_from_atlas_1024x128(atlas_texture: Texture2D) -> Texture2D:
	var texture_size = atlas_texture.get_size()
	var frame_width = float(texture_size.x) / 8.0  # 1024/8 = 128
	var frame_height = float(texture_size.y)        # 128
	
	var first_frame = AtlasTexture.new()
	first_frame.atlas = atlas_texture
	first_frame.region = Rect2(0, 0, frame_width, frame_height)
	
	return first_frame

func extract_frame_from_atlas_1024x128(atlas_texture: Texture2D, frame_index: int) -> Texture2D:
	var texture_size = atlas_texture.get_size()
	var frame_width = float(texture_size.x) / 8.0  # 128px por frame
	var frame_height = float(texture_size.y)        # 128px de alto
	
	var x = float(frame_index) * frame_width
	var y = 0.0
	
	var frame = AtlasTexture.new()
	frame.atlas = atlas_texture
	frame.region = Rect2(x, y, frame_width, frame_height)
	
	return frame

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

# SISTEMA UNIFICADO COD ZOMBIES CON PUNTUACIÓN
func setup_unified_cod_system():
	if not player:
		return
	
	# 1. Crear ScoreSystem PRIMERO
	score_system = ScoreSystem.new()
	score_system.name = "ScoreSystem"
	add_child(score_system)
	
	# 2. Configurar UI de puntuación en la cámara
	if player.camera:
		score_system.setup_score_ui_on_camera(player.camera)
	
	# 3. Crear RoundsManager
	rounds_manager = RoundsManager.new()
	rounds_manager.name = "RoundsManager"
	add_child(rounds_manager)
	
	# 4. Configurar UI de rondas en la cámara
	if player.camera:
		rounds_manager.setup_round_ui_on_camera(player.camera)
	
	# 5. Crear EnemySpawner
	enemy_spawner = EnemySpawner.new()
	enemy_spawner.name = "EnemySpawner"
	enemy_spawner.spawn_radius_min = 400.0
	enemy_spawner.spawn_radius_max = 800.0
	enemy_spawner.despawn_distance = 1200.0
	add_child(enemy_spawner)
	
	# 6. Conectar sistemas
	enemy_spawner.setup(player, rounds_manager)
	rounds_manager.set_enemy_spawner(enemy_spawner)
	
	# 7. Conectar señales
	enemy_spawner.enemy_killed.connect(_on_enemy_killed)
	enemy_spawner.enemy_spawned.connect(_on_enemy_spawned)
	
	# 8. Conectar jugador con score system
	player.set_score_system(score_system)
	
	# 9. Iniciar primera ronda
	rounds_manager.start_round(1)

func _on_enemy_killed(enemy: Enemy):
	enemies_killed += 1
	
	# Notificar al rounds manager
	rounds_manager.on_enemy_killed()
	
	# Añadir puntos en el score system
	if score_system and enemy:
		score_system.add_kill_points(enemy.global_position, false, false)
	
	# Notificar al jugador para sonido de kill
	if player:
		player.on_enemy_killed()

func _on_enemy_spawned(_enemy: Enemy):
	rounds_manager.on_enemy_spawned()

func pause_enemy_spawning():
	if enemy_spawner:
		enemy_spawner.pause_spawning()

func resume_enemy_spawning():
	if enemy_spawner:
		enemy_spawner.resume_spawning()

func clear_all_enemies():
	if enemy_spawner:
		enemy_spawner.clear_all_enemies()

func get_active_enemy_count() -> int:
	if enemy_spawner:
		return enemy_spawner.get_active_enemy_count()
	return 0
