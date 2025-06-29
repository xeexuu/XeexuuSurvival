# scenes/managers/game_manager.gd - SISTEMA COMPLETO CON GUARDADO ANDROID + SPRINT
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
var fixed_ui_manager: FixedUIManager
var pause_menu: PauseMenu
var mobile_menu_button: MobileMenuButton
var wall_system: WallSystem
var is_mobile: bool = false
var save_file_path: String = "user://game_save.dat"
var auto_save_timer: Timer

# SISTEMA DE GUARDADO COMPLETO ANDROID
var save_state_manager: SaveStateManager

# CONTROLES MÓVILES MEJORADOS
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

# TAMAÑOS MEJORADOS PARA ANDROID
var movement_joystick_max_distance: float = 220.0  # MÁS GRANDE
var movement_joystick_dead_zone: float = 35.0
var shooting_joystick_max_distance: float = 200.0  # MÁS GRANDE
var shooting_joystick_dead_zone: float = 35.0

# BOTONES DE ACCIÓN MEJORADOS
var melee_button: Button
var interact_button: Button
var sprint_button: Button  # NUEVO BOTÓN DE SPRINT
var melee_touch_id: int = -1
var interact_touch_id: int = -1
var sprint_touch_id: int = -1

# SISTEMA DE SPRINT
var is_sprinting: bool = false
var sprint_multiplier: float = 1.5

# SPRITES PARA BOTONES DINÁMICOS
var reload_sprite_texture: Texture2D
var hammer_sprite_texture: Texture2D
var dollar_sprite_texture: Texture2D
var sprint_sprite_texture: Texture2D

# SISTEMA DE INTERACCIONES MEJORADO CON MENSAJES ESPECÍFICOS
var current_interaction_target: Node2D = null
var interaction_type: String = "none"
var is_repairing_barricade: bool = false
var repair_timer: Timer
var interaction_check_timer: Timer

# SISTEMA DE MENSAJES MEJORADO
var interaction_message_label: Label = null
var message_display_timer: Timer = null
var current_message_tween: Tween = null

var selected_character_stats: CharacterStats
var game_started: bool = false
var enemy_spawner: EnemySpawner
var rounds_manager: RoundsManager
var score_system: ScoreSystem
var enemies_killed: int = 0
var game_over_screen: Control
var is_game_over: bool = false
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
	create_interaction_sprites()
	setup_repair_timer()
	setup_interaction_check_timer()
	setup_interaction_message_system()
	
	if is_mobile:
		# VERIFICAR SI HAY PARTIDA GUARDADA
		if save_state_manager and save_state_manager.has_complete_save():
			call_deferred("load_saved_game_android")
		else:
			call_deferred("start_normal_game")
	else:
		await get_tree().process_frame
		if not game_started:
			show_character_selection()

func start_normal_game():
	"""Iniciar juego normal sin carga"""
	await get_tree().process_frame
	if not game_started:
		show_character_selection()

func load_saved_game_android():
	"""Cargar partida guardada en Android y mostrar menú de pausa"""
	if not save_state_manager:
		start_normal_game()
		return
	
	var load_success = save_state_manager.load_complete_game_state(self)
	
	if load_success:
		game_started = true
		game_state = "playing"
		
		# CONFIGURAR CONTROLES MÓVILES
		if is_mobile:
			setup_mobile_controls()
		
		await get_tree().create_timer(0.5).timeout
		
		# **MOSTRAR MENÚ DE PAUSA INMEDIATAMENTE**
		if pause_menu:
			pause_menu.show_menu()
	else:
		start_normal_game()

func setup_android_save_system():
	"""Configurar sistema de guardado automático para Android"""
	if not is_mobile:
		return
	
	# CREAR SAVESTATE MANAGER
	save_state_manager = SaveStateManager.new()
	save_state_manager.name = "SaveStateManager"
	add_child(save_state_manager)
	
	# TIMER DE GUARDADO AUTOMÁTICO
	auto_save_timer = Timer.new()
	auto_save_timer.wait_time = 10.0  # Guardar cada 10 segundos
	auto_save_timer.autostart = true
	auto_save_timer.timeout.connect(auto_save_game_complete)
	add_child(auto_save_timer)


func auto_save_game_complete():
	"""Guardado automático COMPLETO para Android"""
	if is_mobile and game_started and not is_game_over and game_state == "playing":
		if save_state_manager:
			save_state_manager.save_complete_game_state(self)

func setup_interaction_message_system():
	"""Configurar sistema de mensajes de interacción en pantalla"""
	message_display_timer = Timer.new()
	message_display_timer.name = "MessageDisplayTimer"
	message_display_timer.wait_time = 1.5  # MÁS CORTO
	message_display_timer.one_shot = true
	message_display_timer.timeout.connect(_hide_interaction_message)
	add_child(message_display_timer)

func setup_interaction_check_timer():
	"""Timer para verificar constantemente las interacciones disponibles"""
	interaction_check_timer = Timer.new()
	interaction_check_timer.name = "InteractionCheckTimer"
	interaction_check_timer.wait_time = 0.3
	interaction_check_timer.autostart = true
	interaction_check_timer.timeout.connect(_check_available_interactions)
	add_child(interaction_check_timer)

func _check_available_interactions():
	"""Verificar constantemente qué interacciones están disponibles CON MENSAJES ESPECÍFICOS"""
	if not player or not wall_system or not is_mobile:
		return
	
	# Resetear estado
	var previous_target = current_interaction_target
	var previous_type = interaction_type
	current_interaction_target = null
	interaction_type = "none"
	
	# PRIORIDAD 1: Verificar puertas cercanas
	var nearby_door = find_nearby_purchasable_door()
	if nearby_door:
		current_interaction_target = nearby_door
		interaction_type = "door"
		update_interact_button_to_dollar()
		
		# MENSAJE ESPECÍFICO DE PUERTA
		if previous_target != nearby_door or previous_type != "door":
			var cost = nearby_door.get_meta("cost", 3000)
			show_interaction_message("💰 Puerta con coste " + str(cost), Color.GOLD)
		return
	
	# PRIORIDAD 2: Verificar barricadas cercanas
	var nearby_barricade = find_nearby_repairable_barricade()
	if nearby_barricade:
		current_interaction_target = nearby_barricade
		interaction_type = "barricade"
		update_interact_button_to_hammer()
		
		# MENSAJE ESPECÍFICO DE REPARACIÓN
		if previous_target != nearby_barricade or previous_type != "barricade":
			show_interaction_message("🔨 Interacciona para reparar", Color.CYAN)
		return
	
	# SIN INTERACCIÓN: Volver a reload
	if previous_type != "none":
		update_interact_button_to_reload()
		hide_interaction_message()

func show_interaction_message(message_text: String, message_color: Color = Color.WHITE):
	"""Mostrar mensaje de interacción ESPECÍFICO"""
	hide_interaction_message()
	
	interaction_message_label = Label.new()
	interaction_message_label.name = "InteractionMessage"
	interaction_message_label.text = message_text
	interaction_message_label.z_index = 1500
	
	var font_size = 32 if not is_mobile else 36  # MÁS GRANDE
	interaction_message_label.add_theme_font_size_override("font_size", font_size)
	interaction_message_label.add_theme_color_override("font_color", message_color)
	interaction_message_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	interaction_message_label.add_theme_constant_override("shadow_offset_x", 4)
	interaction_message_label.add_theme_constant_override("shadow_offset_y", 4)
	interaction_message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	interaction_message_label.add_theme_constant_override("outline_size", 2)
	
	interaction_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	interaction_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	var viewport_size = get_viewport().get_visible_rect().size
	interaction_message_label.size = Vector2(viewport_size.x * 0.9, 100)
	interaction_message_label.position = Vector2(viewport_size.x * 0.05, 80)  # MÁS ARRIBA
	
	ui_manager.add_child(interaction_message_label)
	
	# ANIMACIÓN DE APARICIÓN
	interaction_message_label.modulate = Color.TRANSPARENT
	interaction_message_label.scale = Vector2(0.5, 0.5)
	
	if current_message_tween:
		current_message_tween.kill()
	
	current_message_tween = create_tween()
	current_message_tween.parallel().tween_property(interaction_message_label, "modulate", Color.WHITE, 0.2)
	current_message_tween.parallel().tween_property(interaction_message_label, "scale", Vector2(1.1, 1.1), 0.1)
	current_message_tween.tween_property(interaction_message_label, "scale", Vector2(1.0, 1.0), 0.1)
	
	# Timer para ocultar automáticamente
	message_display_timer.start()

func _hide_interaction_message():
	"""Ocultar mensaje RÁPIDAMENTE"""
	if not interaction_message_label or not is_instance_valid(interaction_message_label):
		return
	
	if current_message_tween:
		current_message_tween.kill()
	
	current_message_tween = create_tween()
	current_message_tween.parallel().tween_property(interaction_message_label, "modulate", Color.TRANSPARENT, 0.2)  # MÁS RÁPIDO
	current_message_tween.parallel().tween_property(interaction_message_label, "scale", Vector2(0.5, 0.5), 0.2)
	current_message_tween.tween_callback(func():
		if interaction_message_label and is_instance_valid(interaction_message_label):
			interaction_message_label.queue_free()
			interaction_message_label = null
	)

func hide_interaction_message():
	"""Función pública para ocultar mensaje inmediatamente"""
	if message_display_timer:
		message_display_timer.stop()
	_hide_interaction_message()

func create_interaction_sprites():
	"""Crear texturas para botones dinámicos + SPRINT"""
	# SPRITE DE RELOAD
	var reload_image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	reload_image.fill(Color.TRANSPARENT)
	
	var center = Vector2(32, 32)
	for angle_deg in range(0, 360, 5):
		var angle_rad = deg_to_rad(angle_deg)
		var radius = 24
		var x = int(center.x + cos(angle_rad) * radius)
		var y = int(center.y + sin(angle_rad) * radius)
		
		if x >= 0 and x < 64 and y >= 0 and y < 64:
			for offset_x in range(-2, 3):
				for offset_y in range(-2, 3):
					var px = x + offset_x
					var py = y + offset_y
					if px >= 0 and px < 64 and py >= 0 and py < 64:
						reload_image.set_pixel(px, py, Color.CYAN)
	
	for i in range(8):
		reload_image.set_pixel(56 + i % 4, 15 + i / 4, Color.CYAN)
	
	reload_sprite_texture = ImageTexture.create_from_image(reload_image)
	
	# SPRITE DE MARTILLO
	var hammer_image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	hammer_image.fill(Color.TRANSPARENT)
	
	for x in range(25, 35):
		for y in range(10, 55):
			hammer_image.set_pixel(x, y, Color(0.6, 0.4, 0.2))
	
	for x in range(15, 45):
		for y in range(10, 25):
			hammer_image.set_pixel(x, y, Color.DARK_GRAY)
	
	for x in range(18, 42):
		for y in range(13, 22):
			hammer_image.set_pixel(x, y, Color.GRAY)
	
	hammer_sprite_texture = ImageTexture.create_from_image(hammer_image)
	
	# SPRITE DE DOLLAR
	var dollar_image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	dollar_image.fill(Color.TRANSPARENT)
	
	for x in range(64):
		for y in range(64):
			var dist = Vector2(x - 32, y - 32).length()
			if dist >= 22 and dist <= 28:
				dollar_image.set_pixel(x, y, Color.GOLD)
			elif dist >= 18 and dist <= 22:
				dollar_image.set_pixel(x, y, Color.YELLOW)
	
	for y in range(15, 50):
		dollar_image.set_pixel(32, y, Color.GREEN)
	for x in range(20, 45):
		if x != 32:
			dollar_image.set_pixel(x, 25, Color.GREEN)
			dollar_image.set_pixel(x, 40, Color.GREEN)
	
	dollar_sprite_texture = ImageTexture.create_from_image(dollar_image)
	
	# NUEVO: SPRITE DE SPRINT
	var sprint_image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	sprint_image.fill(Color.TRANSPARENT)
	
	# Crear símbolo de velocidad (rayo/lightning)
	var lightning_points = [
		Vector2(25, 10), Vector2(35, 10), Vector2(28, 25),
		Vector2(40, 25), Vector2(20, 40), Vector2(30, 40),
		Vector2(25, 55), Vector2(35, 45), Vector2(30, 30)
	]
	
	# Dibujar el rayo
	for point in lightning_points:
		for x in range(int(point.x) - 2, int(point.x) + 3):
			for y in range(int(point.y) - 2, int(point.y) + 3):
				if x >= 0 and x < 64 and y >= 0 and y < 64:
					sprint_image.set_pixel(x, y, Color.YELLOW)
	
	# Líneas de velocidad
	for i in range(3):
		var line_x = 45 + i * 5
		for y in range(15 + i * 10, 50 - i * 5):
			if line_x < 64:
				sprint_image.set_pixel(line_x, y, Color.ORANGE)
	
	sprint_sprite_texture = ImageTexture.create_from_image(sprint_image)

func setup_repair_timer():
	"""Configurar timer para reparación continua"""
	repair_timer = Timer.new()
	repair_timer.name = "RepairTimer"
	repair_timer.wait_time = 0.5
	repair_timer.autostart = false
	repair_timer.timeout.connect(_on_repair_timer_timeout)
	add_child(repair_timer)

func _on_repair_timer_timeout():
	"""Reparar tablón continuamente mientras se mantenga presionado"""
	if is_repairing_barricade and current_interaction_target and interaction_type == "barricade":
		if wall_system and score_system:
			var cost = current_interaction_target.get_meta("repair_cost", 10)
			if score_system.get_current_score() >= cost:
				if wall_system.repair_barricade(current_interaction_target):
					# **RESTAR PUNTOS AL REPARAR**
					score_system.add_bonus_points(-cost, current_interaction_target.global_position, "repair_purchase")
					score_system.add_repair_points(current_interaction_target.global_position, 1)
					
					var current_planks = current_interaction_target.get_meta("current_planks", 0)
					var max_planks = current_interaction_target.get_meta("max_planks", 8)
					
					if current_planks >= max_planks:
						stop_repairing()
						show_floating_message_instant("✅ REPARADO", current_interaction_target.global_position, Color.GREEN)
					else:
						var remaining = max_planks - current_planks
						show_floating_message_instant("🔨 +" + str(remaining), current_interaction_target.global_position, Color.CYAN)
						repair_timer.start()
				else:
					stop_repairing()
			else:
				stop_repairing()
				show_floating_message_instant("💰 SIN PUNTOS", current_interaction_target.global_position, Color.RED)

func show_floating_message_instant(text: String, world_pos: Vector2, color: Color):
	"""Mostrar mensaje flotante que desaparece CASI AL INSTANTE"""
	var message_label = Label.new()
	message_label.text = text
	message_label.add_theme_font_size_override("font_size", 20)
	message_label.add_theme_color_override("font_color", color)
	message_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	message_label.add_theme_constant_override("shadow_offset_x", 3)
	message_label.add_theme_constant_override("shadow_offset_y", 3)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	message_label.global_position = world_pos + Vector2(-100, -50)
	message_label.size = Vector2(200, 40)
	
	get_tree().current_scene.add_child(message_label)
	
	# DESAPARECE CASI AL INSTANTE (0.8 segundos)
	var tween = create_tween()
	tween.parallel().tween_property(message_label, "global_position", 
		message_label.global_position + Vector2(0, -60), 0.8)
	tween.parallel().tween_property(message_label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(func(): message_label.queue_free())

func stop_repairing():
	"""Detener reparación continua"""
	is_repairing_barricade = false
	if repair_timer:
		repair_timer.stop()

func update_interact_button_to_reload():
	"""Cambiar botón a sprite de reload"""
	if not interact_button:
		return
	
	interact_button.text = ""
	
	for child in interact_button.get_children():
		if child.name == "SpriteRect":
			child.queue_free()
	
	var sprite_rect = TextureRect.new()
	sprite_rect.name = "SpriteRect"
	sprite_rect.texture = reload_sprite_texture
	sprite_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sprite_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interact_button.add_child(sprite_rect)
	
	var reload_style = interact_button.get_theme_stylebox("normal")
	if reload_style:
		reload_style.bg_color = Color(0.0, 0.4, 0.6, 0.9)

func update_interact_button_to_hammer():
	"""Cambiar botón a sprite de martillo"""
	if not interact_button:
		return
	
	interact_button.text = ""
	
	for child in interact_button.get_children():
		if child.name == "SpriteRect":
			child.queue_free()
	
	var sprite_rect = TextureRect.new()
	sprite_rect.name = "SpriteRect"
	sprite_rect.texture = hammer_sprite_texture
	sprite_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sprite_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interact_button.add_child(sprite_rect)
	
	var hammer_style = interact_button.get_theme_stylebox("normal")
	if hammer_style:
		hammer_style.bg_color = Color(0.6, 0.4, 0.1, 0.9)

func update_interact_button_to_dollar():
	"""Cambiar botón a sprite de dollar"""
	if not interact_button:
		return
	
	interact_button.text = ""
	
	for child in interact_button.get_children():
		if child.name == "SpriteRect":
			child.queue_free()
	
	var sprite_rect = TextureRect.new()
	sprite_rect.name = "SpriteRect"
	sprite_rect.texture = dollar_sprite_texture
	sprite_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sprite_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interact_button.add_child(sprite_rect)
	
	var dollar_style = interact_button.get_theme_stylebox("normal")
	if dollar_style:
		dollar_style.bg_color = Color(0.8, 0.6, 0.0, 0.9)

func find_nearby_purchasable_door() -> Node2D:
	"""Buscar puerta cercana que se puede comprar"""
	if not player or not wall_system:
		return null
	
	var player_pos = player.global_position
	var interaction_range = 220.0  # AUMENTADO
	
	for door in wall_system.get_all_doors():
		if not is_instance_valid(door):
			continue
		
		var is_open = door.get_meta("is_open", false)
		if is_open:
			continue
		
		var distance = player_pos.distance_to(door.global_position)
		if distance <= interaction_range:
			return door
	
	return null

func find_nearby_repairable_barricade() -> Node2D:
	"""Buscar barricada cercana que se puede reparar"""
	if not player or not wall_system:
		return null
	
	var player_pos = player.global_position
	var interaction_range = 190.0  # AUMENTADO
	
	for barricade in wall_system.get_all_barricades():
		if not is_instance_valid(barricade):
			continue
		
		var current_planks = barricade.get_meta("current_planks", 0)
		var max_planks = barricade.get_meta("max_planks", 8)
		
		if current_planks >= max_planks:
			continue
		
		var distance = player_pos.distance_to(barricade.global_position)
		if distance <= interaction_range:
			return barricade
	
	return null

func handle_interact_press():
	"""MANEJAR PRESIÓN DE INTERACT - SISTEMA UNIFICADO"""
	if not player or not wall_system:
		return
	
	# PRIORIDAD 1: VERIFICAR PUERTAS CERCANAS
	var nearby_door = find_nearby_purchasable_door()
	if nearby_door:
		attempt_door_purchase(nearby_door)
		return
	
	# PRIORIDAD 2: VERIFICAR BARRICADAS PARA REPARAR
	var nearby_barricade = find_nearby_repairable_barricade()
	if nearby_barricade:
		start_barricade_repair(nearby_barricade)
		return
	
	# PRIORIDAD 3: RELOAD NORMAL SI NO HAY INTERACCIONES
	if player and player.has_method("start_manual_reload"):
		var reload_success = player.start_manual_reload()
		if reload_success:
			show_interaction_message("🔄 Recargando...", Color.CYAN)
		else:
			show_interaction_message("❌ No necesario", Color.ORANGE)

func attempt_door_purchase(door: Node2D):
	"""Intentar comprar puerta"""
	if not door or not score_system:
		return
	
	var cost = door.get_meta("cost", 3000)
	var target_room = door.get_meta("target_room", "área exterior")
	var current_score = score_system.get_current_score()
	
	if current_score >= cost:
		if wall_system.purchase_door(door):
			score_system.add_bonus_points(-cost, door.global_position, "door_purchase")
			show_floating_message_instant("🚪 " + target_room.to_upper(), door.global_position, Color.GREEN)
			show_interaction_message("✅ " + target_room.to_upper() + " desbloqueada!", Color.GREEN)
		else:
			show_floating_message_instant("❌ ERROR", door.global_position, Color.RED)
	else:
		var needed = cost - current_score
		show_floating_message_instant("💰 -" + str(needed), door.global_position, Color.ORANGE)
		show_interaction_message("💰 Necesitas " + str(needed) + " puntos más", Color.ORANGE)

func start_barricade_repair(barricade: Node2D):
	"""Iniciar reparación de barricada"""
	if not barricade or not wall_system or not score_system:
		return
	
	var cost = barricade.get_meta("repair_cost", 10)
	var current_score = score_system.get_current_score()
	
	if current_score < cost:
		show_floating_message_instant("💰 SIN PUNTOS", barricade.global_position, Color.ORANGE)
		return
	
	current_interaction_target = barricade
	interaction_type = "barricade"
	is_repairing_barricade = true
	
	# Reparar inmediatamente una vez
	if wall_system.repair_barricade(barricade):
		# **RESTAR PUNTOS INMEDIATAMENTE**
		score_system.add_bonus_points(-cost, barricade.global_position, "repair_purchase")
		score_system.add_repair_points(barricade.global_position, 1)
		
		show_floating_message_instant("🔨 REPARADO", barricade.global_position, Color.CYAN)
		
		var current_planks = barricade.get_meta("current_planks", 0)
		var max_planks = barricade.get_meta("max_planks", 8)
		var remaining = max_planks - current_planks
		
		if remaining > 0:
			show_interaction_message("🔨 Faltan " + str(remaining) + " tablones", Color.CYAN)
		else:
			show_interaction_message("✅ Barricada completa!", Color.GREEN)
		
		if current_planks < max_planks and score_system.get_current_score() >= cost:
			repair_timer.start()
		else:
			stop_repairing()
	else:
		stop_repairing()
		show_floating_message_instant("❌ ERROR", barricade.global_position, Color.RED)

func handle_interact_release():
	"""MANEJAR LIBERACIÓN DE INTERACT"""
	if is_repairing_barricade:
		stop_repairing()

# ==========================================
# SISTEMA DE SPRINT
# ==========================================

func handle_sprint_press():
	"""Manejar presión del botón de sprint"""
	if not player:
		return
	
	is_sprinting = true
	apply_sprint_to_player()
	
	# Efectos visuales del botón
	if sprint_button:
		var tween = create_tween()
		tween.tween_property(sprint_button, "scale", Vector2(0.9, 0.9), 0.1)
		tween.tween_property(sprint_button, "modulate", Color(1.5, 1.5, 0.8), 0.1)

func handle_sprint_release():
	"""Manejar liberación del botón de sprint"""
	if not player:
		return
	
	is_sprinting = false
	remove_sprint_from_player()
	
	# Efectos visuales del botón
	if sprint_button:
		var tween = create_tween()
		tween.tween_property(sprint_button, "scale", Vector2(1.0, 1.0), 0.1)
		tween.tween_property(sprint_button, "modulate", Color.WHITE, 0.2)

func apply_sprint_to_player():
	"""Aplicar sprint al jugador - VELOCIDAD x1.5"""
	if player and "move_speed" in player:
		if not player.has_meta("original_speed"):
			player.set_meta("original_speed", player.move_speed)
		
		player.move_speed = player.get_meta("original_speed") * sprint_multiplier

func remove_sprint_from_player():
	"""Quitar sprint del jugador - VELOCIDAD NORMAL"""
	if player and player.has_meta("original_speed"):
		player.move_speed = player.get_meta("original_speed")

func _input(event):
	if is_mobile and event is InputEventKey and event.keycode == KEY_BACK and event.pressed:
		if game_started and game_state == "playing" and not is_game_over:
			toggle_pause_menu()
			get_viewport().set_input_as_handled()
			return
		elif pause_menu and pause_menu.is_paused:
			pause_menu.hide_menu()
			get_viewport().set_input_as_handled()
			return
		get_viewport().set_input_as_handled()
		return
	
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.keycode == KEY_ESCAPE):
		if game_started and game_state == "playing" and not is_game_over:
			toggle_pause_menu()
		return
	
	if event.is_action_pressed("toggle_fullscreen"):
		toggle_fullscreen()
	
	# MANEJO DE SPRINT DESDE TECLADO
	if event.is_action_pressed("sprint"):
		handle_sprint_press()
		get_viewport().set_input_as_handled()
		return
	
	if event.is_action_released("sprint"):
		handle_sprint_release()
		get_viewport().set_input_as_handled()
		return
	
	# SISTEMA DE INTERACT
	if (event.is_action_pressed("ui_accept") or 
		(event is InputEventKey and event.keycode == KEY_E) or 
		event.is_action_pressed("reload") or
		event.is_action_pressed("interact")):
		handle_interact_press()
		get_viewport().set_input_as_handled()
		return
	
	if (event.is_action_released("ui_accept") or 
		(event is InputEventKey and event.keycode == KEY_E and not event.pressed) or 
		event.is_action_released("reload") or
		event.is_action_released("interact")):
		handle_interact_release()
		get_viewport().set_input_as_handled()
		return
	
	if not is_mobile or not game_started or game_state != "playing":
		return
	
	if event is InputEventScreenTouch:
		handle_touch_event(event)
	elif event is InputEventScreenDrag:
		handle_drag_event(event)

func handle_touch_event(event: InputEventScreenTouch):
	"""Manejar toques CON SPRINT INCLUIDO"""
	var touch_pos = event.position
	var touch_id = event.index
	
	if event.pressed:
		if melee_button and is_point_in_button_area(touch_pos, melee_button) and melee_touch_id == -1:
			melee_touch_id = touch_id
			handle_melee_button_press()
			return
		
		if interact_button and is_point_in_button_area(touch_pos, interact_button) and interact_touch_id == -1:
			interact_touch_id = touch_id
			handle_interact_button_press()
			return
		
		# NUEVO: BOTÓN DE SPRINT
		if sprint_button and is_point_in_button_area(touch_pos, sprint_button) and sprint_touch_id == -1:
			sprint_touch_id = touch_id
			handle_sprint_press()
			return
		
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
		elif touch_id == melee_touch_id:
			melee_touch_id = -1
			handle_melee_button_release()
		elif touch_id == interact_touch_id:
			interact_touch_id = -1
			handle_interact_button_release()
		elif touch_id == sprint_touch_id:  # NUEVO: LIBERACIÓN DE SPRINT
			sprint_touch_id = -1
			handle_sprint_release()

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

func handle_melee_button_press():
	"""Manejar presión de botón melee"""
	if player and player.has_method("perform_melee_attack_enhanced"):
		player.perform_melee_attack_enhanced()
	
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

func handle_interact_button_press():
	"""Manejar presión del botón dinámico"""
	if interact_button:
		var tween = create_tween()
		tween.tween_property(interact_button, "scale", Vector2(0.9, 0.9), 0.1)
		match interaction_type:
			"door":
				tween.tween_property(interact_button, "modulate", Color.GOLD, 0.2)
			"barricade":
				tween.tween_property(interact_button, "modulate", Color(1.0, 0.8, 0.5), 0.2)
			_:
				tween.tween_property(interact_button, "modulate", Color.CYAN, 0.2)
	
	handle_interact_press()

func handle_interact_button_release():
	"""Manejar liberación del botón dinámico"""
	if interact_button:
		var tween = create_tween()
		tween.tween_property(interact_button, "scale", Vector2(1.0, 1.0), 0.1)
		tween.tween_property(interact_button, "modulate", Color.WHITE, 0.2)
	
	handle_interact_release()

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
	"""Configurar controles móviles MEJORADOS con SPRINT"""
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
	create_mobile_action_buttons_with_sprint()  # INCLUYE SPRINT
	
	if movement_joystick_base:
		movement_joystick_base.visible = true
		movement_joystick_base.modulate = Color.WHITE
	
	if shooting_joystick_base:
		shooting_joystick_base.visible = true  
		shooting_joystick_base.modulate = Color.WHITE

func create_mobile_action_buttons_with_sprint():
	"""Crear botones CON SPRINT incluido - MÁS GRANDES Y MÁS ARRIBA"""
	if not is_mobile or not mobile_controls:
		return
	
	var viewport_size = get_viewport().get_visible_rect().size
	var joystick_shooting_x = viewport_size.x * 0.78
	var buttons_x = joystick_shooting_x - 200  # MÁS SEPARADO
	
	# TAMAÑOS MÁS GRANDES
	var button_size = Vector2(140, 140)  # MUCHO MÁS GRANDE
	var button_spacing = 20
	
	# POSICIÓN MÁS ARRIBA
	var base_y = viewport_size.y - 320  # MÁS ARRIBA
	
	# BOTÓN MELEE - ARRIBA
	melee_button = Button.new()
	melee_button.text = "⚔"
	melee_button.size = button_size
	melee_button.position = Vector2(buttons_x, base_y)
	melee_button.add_theme_font_size_override("font_size", 70)  # FUENTE MÁS GRANDE
	
	var melee_style = StyleBoxFlat.new()
	melee_style.bg_color = Color(0.8, 0.1, 0.1, 0.9)
	melee_style.corner_radius_top_left = 70
	melee_style.corner_radius_top_right = 70
	melee_style.corner_radius_bottom_left = 70
	melee_style.corner_radius_bottom_right = 70
	melee_style.border_color = Color.YELLOW
	melee_style.border_width_left = 5
	melee_style.border_width_right = 5
	melee_style.border_width_top = 5
	melee_style.border_width_bottom = 5
	melee_button.add_theme_stylebox_override("normal", melee_style)
	mobile_controls.add_child(melee_button)
	
	# BOTÓN DINÁMICO RELOAD/MARTILLO/DOLLAR - CENTRO
	interact_button = Button.new()
	interact_button.text = ""
	interact_button.size = button_size
	interact_button.position = Vector2(buttons_x, base_y + button_size.y + button_spacing)
	
	var interact_style = StyleBoxFlat.new()
	interact_style.bg_color = Color(0.0, 0.4, 0.6, 0.9)
	interact_style.corner_radius_top_left = 70
	interact_style.corner_radius_top_right = 70
	interact_style.corner_radius_bottom_left = 70
	interact_style.corner_radius_bottom_right = 70
	interact_style.border_color = Color.CYAN
	interact_style.border_width_left = 6
	interact_style.border_width_right = 6
	interact_style.border_width_top = 6
	interact_style.border_width_bottom = 6
	interact_button.add_theme_stylebox_override("normal", interact_style)
	mobile_controls.add_child(interact_button)
	
	# NUEVO: BOTÓN DE SPRINT - ABAJO
	sprint_button = Button.new()
	sprint_button.text = ""  # Usaremos sprite
	sprint_button.size = button_size
	sprint_button.position = Vector2(buttons_x, base_y + (button_size.y + button_spacing) * 2)
	
	var sprint_style = StyleBoxFlat.new()
	sprint_style.bg_color = Color(0.8, 0.6, 0.0, 0.9)  # Dorado
	sprint_style.corner_radius_top_left = 70
	sprint_style.corner_radius_top_right = 70
	sprint_style.corner_radius_bottom_left = 70
	sprint_style.corner_radius_bottom_right = 70
	sprint_style.border_color = Color.YELLOW
	sprint_style.border_width_left = 6
	sprint_style.border_width_right = 6
	sprint_style.border_width_top = 6
	sprint_style.border_width_bottom = 6
	sprint_button.add_theme_stylebox_override("normal", sprint_style)
	
	# AÑADIR SPRITE DE SPRINT AL BOTÓN
	var sprint_sprite_rect = TextureRect.new()
	sprint_sprite_rect.name = "SprintSpriteRect"
	sprint_sprite_rect.texture = sprint_sprite_texture
	sprint_sprite_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	sprint_sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprint_sprite_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sprint_sprite_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprint_button.add_child(sprint_sprite_rect)
	
	mobile_controls.add_child(sprint_button)
	
	# Inicializar interact button con sprite de reload
	update_interact_button_to_reload()

func create_movement_joystick_large():
	"""Crear joystick movimiento MÁS GRANDE"""
	var viewport_size = get_viewport().get_visible_rect().size
	var joystick_size = movement_joystick_max_distance * 2
	
	movement_joystick_base = Control.new()
	movement_joystick_base.name = "MovementJoystickBase"
	movement_joystick_base.size = Vector2(joystick_size, joystick_size)
	movement_joystick_base.position = Vector2(
		viewport_size.x * 0.06,  # MÁS SEPARADO DEL BORDE
		viewport_size.y * 0.40   # MÁS ARRIBA
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
	base_style.border_width_left = 6  # BORDES MÁS GRUESOS
	base_style.border_width_right = 6
	base_style.border_width_top = 6
	base_style.border_width_bottom = 6
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
	var knob_size = 100  # MÁS GRANDE
	movement_joystick_knob.size = Vector2(knob_size, knob_size)
	movement_joystick_knob.position = Vector2(
		movement_joystick_max_distance - float(knob_size)/2.0,
		movement_joystick_max_distance - float(knob_size)/2.0
	)
	movement_joystick_knob.z_index = 2
	
	var knob_style = StyleBoxFlat.new()
	knob_style.bg_color = Color(0.9, 0.9, 0.9, 1.0)
	knob_style.border_color = Color.CYAN
	knob_style.border_width_left = 5
	knob_style.border_width_right = 5
	knob_style.border_width_top = 5
	knob_style.border_width_bottom = 5
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
	"""Crear joystick disparo MÁS GRANDE"""
	var viewport_size = get_viewport().get_visible_rect().size
	var joystick_size = shooting_joystick_max_distance * 2
	
	shooting_joystick_base = Control.new()
	shooting_joystick_base.name = "ShootingJoystickBase"
	shooting_joystick_base.size = Vector2(joystick_size, joystick_size)
	shooting_joystick_base.position = Vector2(
		viewport_size.x * 0.76,  # MÁS SEPARADO
		viewport_size.y * 0.40   # MÁS ARRIBA
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
	base_style.border_width_left = 6
	base_style.border_width_right = 6
	base_style.border_width_top = 6
	base_style.border_width_bottom = 6
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
	var knob_size = 90  # MÁS GRANDE
	shooting_joystick_knob.size = Vector2(knob_size, knob_size)
	shooting_joystick_knob.position = Vector2(
		shooting_joystick_max_distance - float(knob_size)/2.0,
		shooting_joystick_max_distance - float(knob_size)/2.0
	)
	shooting_joystick_knob.z_index = 2
	
	var knob_style = StyleBoxFlat.new()
	knob_style.bg_color = Color(1.0, 0.3, 0.3, 1.0)
	knob_style.border_color = Color.YELLOW
	knob_style.border_width_left = 5
	knob_style.border_width_right = 5
	knob_style.border_width_top = 5
	knob_style.border_width_bottom = 5
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

func _physics_process(_delta):
	"""Aplicar movimiento móvil CON SPRINT"""
	if is_mobile and player:
		player.mobile_movement_direction = current_movement
		
		if is_shooting:
			player.mobile_shoot_direction = current_shoot_direction
			player.mobile_is_shooting = true
		else:
			player.mobile_is_shooting = false

# ==========================================
# RESTO DE FUNCIONES DEL GAMEMANAGER
# (Las funciones que no cambiaron las mantengo igual)
# ==========================================

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
	pass

func setup_background():
	"""Configurar fondo para área gigante"""
	background_sprite = Sprite2D.new()
	background_sprite.name = "Background"
	background_sprite.z_index = -100
	
	var jungle_texture = SpriteEffectsHandler.load_texture_safe("res://sprites/background/fondo.png")
	if jungle_texture:
		background_sprite.texture = jungle_texture
		background_sprite.position = Vector2(0, 0)
		
		var texture_size = jungle_texture.get_size()
		var scale_factor_x = 20000.0 / float(texture_size.x)
		var scale_factor_y = 15000.0 / float(texture_size.y)
		background_sprite.scale = Vector2(scale_factor_x, scale_factor_y)
		
		add_child(background_sprite)
	else:
		var temp_bg = ColorRect.new()
		temp_bg.color = Color(0.2, 0.4, 0.2)
		temp_bg.size = Vector2(8000, 6000)
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

func setup_unified_cod_system_safe_fixed():
	"""Configurar sistemas COD con verificaciones adicionales"""
	if not player:
		return
	
	if not score_system:
		score_system = ScoreSystem.new()
		score_system.name = "ScoreSystem"
		add_child(score_system)
	
	if not rounds_manager:
		rounds_manager = RoundsManager.new()
		rounds_manager.name = "RoundsManager"
		add_child(rounds_manager)
	
	if fixed_ui_manager:
		fixed_ui_manager.set_score_system(score_system)
		fixed_ui_manager.set_rounds_manager(rounds_manager)
		fixed_ui_manager.set_player_reference(player)
	
	if not enemy_spawner:
		enemy_spawner = EnemySpawner.new()
		enemy_spawner.name = "EnemySpawner"
		enemy_spawner.spawn_radius_min = 1200.0
		enemy_spawner.spawn_radius_max = 2000.0
		enemy_spawner.despawn_distance = 2800.0
		add_child(enemy_spawner)
	
	if enemy_spawner and rounds_manager:
		enemy_spawner.setup(player, rounds_manager)
		rounds_manager.set_enemy_spawner(enemy_spawner)
	
	if enemy_spawner:
		if not enemy_spawner.enemy_killed.is_connected(_on_enemy_killed):
			enemy_spawner.enemy_killed.connect(_on_enemy_killed)
		if not enemy_spawner.enemy_spawned.is_connected(_on_enemy_spawned):
			enemy_spawner.enemy_spawned.connect(_on_enemy_spawned)
	
	if rounds_manager:
		if not rounds_manager.round_changed.is_connected(_on_round_changed):
			rounds_manager.round_changed.connect(_on_round_changed)
		if not rounds_manager.enemies_remaining_changed.is_connected(_on_enemies_remaining_changed):
			rounds_manager.enemies_remaining_changed.connect(_on_enemies_remaining_changed)
	
	if player and score_system:
		player.set_score_system(score_system)
	
	if selected_character_stats and score_system:
		score_system.set_character_name(selected_character_stats.character_name)
	
	if rounds_manager:
		rounds_manager.start_round(1)

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
	
	if is_mobile:
		auto_save_game_complete()
	
	await get_tree().create_timer(3.0).timeout
	start_enemy_spawning_safely()

func setup_new_animation_system():
	"""Configurar sistema de animaciones"""
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
	player.collision_mask = 2 | 3 | 16

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
		if is_mobile:
			auto_save_game_complete()
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
	if is_mobile:
		auto_save_game_complete()
	
	cleanup_before_exit()
	get_tree().quit()

func _on_round_changed(new_round: int):
	"""Actualizar ronda"""
	if score_system:
		score_system.set_current_round(new_round)
	if is_mobile:
		auto_save_game_complete()

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
	"""Cuando muere el jugador - NO GUARDAR PARTIDA"""
	if is_game_over:
		return
	
	is_game_over = true
	pause_enemy_spawning()
	
	# **NO GUARDAR PARTIDA AL MORIR**
	if is_mobile and save_state_manager:
		save_state_manager.delete_save()
	
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
	title.custom_minimum_size = Vector2(0, 60)
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
	
	if is_mobile:
		var save_info = Label.new()
		save_info.text = "❌ Partida no guardada (Game Over)"
		save_info.add_theme_font_size_override("font_size", 16)
		save_info.add_theme_color_override("font_color", Color.RED)
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
	quit_btn.text = "❌ SALIR DEL JUEGO" if not is_mobile else "🏠 MENÚ PRINCIPAL"
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
			restart_entire_game()
		else:
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
	
	# Limpiar interacciones y mensajes
	current_interaction_target = null
	interaction_type = "none"
	stop_repairing()
	hide_interaction_message()
	
	# LIMPIAR SPRINT
	is_sprinting = false
	if player:
		remove_sprint_from_player()
	
	# ELIMINAR PARTIDA GUARDADA AL REINICIAR
	if is_mobile and save_state_manager:
		save_state_manager.delete_save()
	
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_enemy_killed(_enemy: Enemy):
	"""Registrar kill de enemigo"""
	enemies_killed += 1
	if rounds_manager:
		rounds_manager.on_enemy_killed()
	if is_mobile and enemies_killed % 5 == 0:  # Guardar cada 5 kills
		auto_save_game_complete()

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
			if is_mobile:
				auto_save_game_complete()
			cleanup_before_exit()
			get_tree().quit()
		NOTIFICATION_APPLICATION_PAUSED:
			if is_mobile and is_game_active():
				auto_save_game_complete()
				if not pause_menu.is_paused:
					toggle_pause_menu()
		NOTIFICATION_APPLICATION_RESUMED:
			if is_mobile:
				pass

func cleanup_before_exit():
	"""Limpiar todo antes de salir"""
	set_process(false)
	set_physics_process(false)
	
	# Detener sprint
	is_sprinting = false
	if player:
		remove_sprint_from_player()
	
	# Detener reparación y limpiar mensajes
	stop_repairing()
	current_interaction_target = null
	interaction_type = "none"
	hide_interaction_message()
	
	if is_mobile:
		auto_save_game_complete()
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
