# scenes/player/player.gd - ANIMACIONES CORREGIDAS: MOVIMIENTO + DISPARO SEPARADOS Y SINCRONIZADOS
extends CharacterBody2D
class_name Player

signal player_died

@export var character_stats: CharacterStats
@onready var animated_sprite = $AnimatedSprite2D
@onready var collision_shape = $CollisionShape2D
@onready var shooting_component = $ShootingComponent
@onready var camera = $Camera2D

# Variables básicas
var current_health: int = 4
var max_health: int = 4
var move_speed: float = 300.0
var is_mobile: bool = false

# Control móvil
var mobile_movement_direction: Vector2 = Vector2.ZERO
var mobile_shoot_direction: Vector2 = Vector2.ZERO
var mobile_is_shooting: bool = false

# Variables de movimiento y animación - SISTEMA CORREGIDO Y SINCRONIZADO
var current_movement_direction: Vector2 = Vector2.ZERO
var current_aim_direction: Vector2 = Vector2.RIGHT
var last_shoot_direction: Vector2 = Vector2.RIGHT
var last_movement_direction: Vector2 = Vector2.ZERO

# Melee attack - SIN AUDIO
var melee_cooldown: float = 1.5
var last_melee_time: float = 0.0
var is_performing_melee: bool = false
var melee_knife_sprite: Sprite2D

# Referencias
var score_system: ScoreSystem
var weapon_renderer: WeaponRenderer
var animation_controller: AnimationController
var mini_hud: MiniHUD

# Estado
var is_fully_initialized: bool = false
var is_invulnerable: bool = false
var invulnerability_duration: float = 2.0

# Límites del mapa - PARA ÁREA GIGANTE (1600x1200 habitación + márgenes)
var map_bounds: Rect2 = Rect2(-2000, -1500, 4000, 3000)

func _ready():
	is_mobile = OS.has_feature("mobile")
	setup_camera()
	setup_weapon_renderer()
	setup_melee_knife()
	
	collision_layer = 1
	collision_mask = 2 | 3

func setup_camera():
	"""Configurar cámara para área gigante"""
	if camera:
		camera.enabled = true
		camera.zoom = Vector2(0.75, 0.75)  # ZOOM REDUCIDO PARA ÁREA GIGANTE
		camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
		camera.position_smoothing_enabled = true
		camera.position_smoothing_speed = 8.0

func setup_weapon_renderer():
	"""Configurar renderer del arma"""
	weapon_renderer = WeaponRenderer.new()
	weapon_renderer.name = "WeaponRenderer"
	weapon_renderer.set_player_reference(self)
	add_child(weapon_renderer)

func setup_melee_knife():
	"""Crear sprite del cuchillo para melee"""
	melee_knife_sprite = Sprite2D.new()
	melee_knife_sprite.name = "MeleeKnife"
	melee_knife_sprite.visible = false
	melee_knife_sprite.z_index = 15
	
	var knife_image = Image.create(48, 12, false, Image.FORMAT_RGBA8)
	knife_image.fill(Color.TRANSPARENT)
	
	# HOJA DEL CUCHILLO
	for x in range(28, 48):
		for y in range(3, 9):
			knife_image.set_pixel(x, y, Color.LIGHT_GRAY)
	
	# MANGO DEL CUCHILLO
	for x in range(0, 28):
		for y in range(2, 10):
			knife_image.set_pixel(x, y, Color(0.6, 0.4, 0.2))
	
	# FILO DEL CUCHILLO
	for x in range(28, 48):
		knife_image.set_pixel(x, 2, Color.WHITE)
		knife_image.set_pixel(x, 9, Color.WHITE)
	
	# PUNTA DEL CUCHILLO
	for y in range(4, 8):
		knife_image.set_pixel(47, y, Color.WHITE)
	
	# DETALLES DEL MANGO
	for x in range(5, 25):
		if x % 4 == 0:
			for y in range(3, 9):
				knife_image.set_pixel(x, y, Color(0.4, 0.2, 0.1))
	
	melee_knife_sprite.texture = ImageTexture.create_from_image(knife_image)
	add_child(melee_knife_sprite)

func update_character_stats(new_stats: CharacterStats):
	"""Actualizar estadísticas desde el archivo .tres"""
	character_stats = new_stats
	apply_character_stats()
	
	call_deferred("setup_mini_hud_with_stats")

func setup_mini_hud_with_stats():
	"""Crear y configurar mini HUD"""
	if mini_hud:
		mini_hud.queue_free()
		mini_hud = null
	
	mini_hud = MiniHUD.new()
	mini_hud.name = "MiniHUD"
	
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_node("UIManager"):
		var ui_manager = game_manager.get_node("UIManager")
		ui_manager.add_child(mini_hud)
		
		if character_stats:
			mini_hud.update_character_stats(character_stats)
	else:
		get_tree().current_scene.add_child(mini_hud)
		
		if character_stats:
			mini_hud.update_character_stats(character_stats)

func apply_character_stats():
	"""Aplicar estadísticas respetando el .tres"""
	if not character_stats:
		return
	
	max_health = character_stats.max_health
	current_health = character_stats.current_health
	move_speed = float(character_stats.movement_speed)
	
	if shooting_component:
		shooting_component.update_stats_from_player()
	
	if weapon_renderer and character_stats.equipped_weapon:
		weapon_renderer.set_weapon_stats(character_stats.equipped_weapon)
	
	is_fully_initialized = true

func set_animation_controller(controller: AnimationController):
	"""Establecer controlador de animaciones CORREGIDO"""
	animation_controller = controller
	print("✅ AnimationController asignado al Player")

func set_score_system(score_sys: ScoreSystem):
	"""Establecer sistema de puntuación"""
	score_system = score_sys

func _physics_process(delta):
	if not is_fully_initialized:
		return
		
	handle_movement(delta)
	handle_shooting()
	update_weapon_position()
	update_melee_knife_position_improved()
	
	# ACTUALIZAR ANIMACIONES CON SISTEMA CORREGIDO Y SINCRONIZADO
	update_animations_combined_and_synchronized()
	
	move_and_slide()

func _input(event):
	"""Manejar inputs incluyendo melee y reload"""
	if not is_fully_initialized:
		return
	
	# MELEE ATTACK - Espacio o X
	if event.is_action_pressed("melee_attack"):
		perform_melee_attack()
		get_viewport().set_input_as_handled()
	
	# RELOAD - R
	if event.is_action_pressed("reload"):
		start_manual_reload()
		get_viewport().set_input_as_handled()
	
	# Fullscreen toggle
	if event.is_action_pressed("toggle_fullscreen"):
		toggle_fullscreen()

func toggle_fullscreen():
	"""Alternar pantalla completa"""
	var current_mode = DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func handle_movement(_delta):
	"""Manejar movimiento CON TRACKING MEJORADO"""
	var input_direction = Vector2.ZERO
	
	if is_mobile:
		input_direction = mobile_movement_direction
	else:
		input_direction.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		input_direction.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	
	if input_direction.length() > 1.0:
		input_direction = input_direction.normalized()
	
	# ACTUALIZAR DIRECCIONES CON SMOOTHING
	if input_direction.length() > 0.1:
		current_movement_direction = input_direction
		last_movement_direction = input_direction
	else:
		current_movement_direction = Vector2.ZERO
	
	velocity = input_direction * move_speed
	apply_map_bounds()

func handle_shooting():
	"""Manejar disparo CON TRACKING MEJORADO DE AIM"""
	if not shooting_component:
		return
	
	var shoot_direction = Vector2.ZERO
	
	if is_mobile:
		if mobile_is_shooting and mobile_shoot_direction.length() > 0:
			shoot_direction = mobile_shoot_direction
	else:
		shoot_direction.x = Input.get_action_strength("shoot_right") - Input.get_action_strength("shoot_left")
		shoot_direction.y = Input.get_action_strength("shoot_down") - Input.get_action_strength("shoot_up")
	
	# ACTUALIZAR DIRECCIÓN DE AIM
	if shoot_direction.length() > 0:
		current_aim_direction = shoot_direction.normalized()
		last_shoot_direction = current_aim_direction
		perform_shoot(current_aim_direction)
	else:
		# Si no está disparando, mantener última dirección de aim para animaciones
		# pero resetear current_aim_direction para que las animaciones se basen en movimiento
		current_aim_direction = Vector2.ZERO

func update_animations_combined_and_synchronized():
	"""ACTUALIZAR ANIMACIONES CON SISTEMA CORREGIDO Y SINCRONIZADO"""
	if not animation_controller:
		return
	
	# DETERMINAR DIRECCIÓN PARA ANIMACIONES
	var animation_direction = Vector2.ZERO
	
	# PRIORIDAD 1: Si está apuntando/disparando
	if current_aim_direction.length() > 0.1:
		animation_direction = current_aim_direction
	# PRIORIDAD 2: Si se está moviendo
	elif current_movement_direction.length() > 0.1:
		animation_direction = current_movement_direction
	# PRIORIDAD 3: Mantener última dirección conocida
	else:
		animation_direction = last_shoot_direction
	
	# USAR SISTEMA CORREGIDO QUE MANEJA MOVIMIENTO Y AIM COMBINADOS
	animation_controller.update_animation_combined(current_movement_direction, animation_direction)

func apply_map_bounds():
	"""Aplicar límites del mapa PARA ÁREA GIGANTE"""
	var next_pos = global_position + velocity * get_physics_process_delta_time()
	
	if next_pos.x < map_bounds.position.x:
		velocity.x = max(0, velocity.x)
		global_position.x = map_bounds.position.x
	elif next_pos.x > map_bounds.position.x + map_bounds.size.x:
		velocity.x = min(0, velocity.x)
		global_position.x = map_bounds.position.x + map_bounds.size.x
	
	if next_pos.y < map_bounds.position.y:
		velocity.y = max(0, velocity.y)
		global_position.y = map_bounds.position.y
	elif next_pos.y > map_bounds.position.y + map_bounds.size.y:
		velocity.y = min(0, velocity.y)
		global_position.y = map_bounds.position.y + map_bounds.size.y

func perform_shoot(direction: Vector2):
	"""Realizar disparo con posición corregida"""
	if not shooting_component:
		return
	
	current_aim_direction = direction
	last_shoot_direction = direction
	
	var shoot_pos = get_corrected_bullet_spawn_position(direction)
	
	var shot_fired = shooting_component.try_shoot(direction, shoot_pos)
	
	if shot_fired and weapon_renderer:
		weapon_renderer.start_shooting_animation()

func get_corrected_bullet_spawn_position(direction: Vector2) -> Vector2:
	"""Obtener posición corregida para spawn de balas"""
	var base_offset = Vector2(0, -15)
	
	var angle = direction.angle()
	var rotated_offset = base_offset.rotated(angle)
	
	if abs(angle) < PI/4:  # Derecha
		rotated_offset += Vector2(25, 0)
	elif abs(angle) > 3*PI/4:  # Izquierda
		rotated_offset += Vector2(-25, 0)
	elif angle > PI/4 and angle < 3*PI/4:  # Abajo
		rotated_offset += Vector2(0, 15)
	elif angle < -PI/4 and angle > -3*PI/4:  # Arriba
		rotated_offset += Vector2(0, -25)
	
	if weapon_renderer:
		var muzzle_pos = weapon_renderer.get_muzzle_world_position()
		if muzzle_pos != global_position:
			return muzzle_pos
	
	return global_position + rotated_offset

func update_weapon_position():
	"""Actualizar posición del arma"""
	if not weapon_renderer:
		return
	
	var aim_direction = current_aim_direction
	if aim_direction.length() < 0.1:
		aim_direction = last_shoot_direction
	
	weapon_renderer.update_weapon_position_and_rotation(aim_direction)

func update_melee_knife_position_improved():
	"""Actualizar posición del cuchillo"""
	if not melee_knife_sprite:
		return
	
	if is_performing_melee:
		var knife_direction = Vector2.ZERO
		
		if current_aim_direction.length() > 0.1:
			knife_direction = current_aim_direction.normalized()
		elif last_shoot_direction.length() > 0.1:
			knife_direction = last_shoot_direction.normalized()
		elif current_movement_direction.length() > 0.1:
			knife_direction = current_movement_direction.normalized()
		else:
			knife_direction = Vector2.RIGHT
		
		var knife_distance = 50.0
		var knife_offset = knife_direction * knife_distance
		
		melee_knife_sprite.global_position = global_position + knife_offset
		melee_knife_sprite.rotation = knife_direction.angle()
		
		if knife_direction.x < 0:
			melee_knife_sprite.flip_v = true
		else:
			melee_knife_sprite.flip_v = false

func perform_melee_attack():
	"""Melee attack sin audio - solo efectos visuales CON ANIMACIÓN MEJORADA"""
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_melee_time < melee_cooldown:
		return
	
	if is_performing_melee:
		return
	
	last_melee_time = current_time
	is_performing_melee = true
	
	# DETERMINAR DIRECCIÓN DE ATAQUE
	var attack_direction = Vector2.ZERO
	
	if current_aim_direction.length() > 0.1:
		attack_direction = current_aim_direction.normalized()
	elif last_shoot_direction.length() > 0.1:
		attack_direction = last_shoot_direction.normalized()
	elif current_movement_direction.length() > 0.1:
		attack_direction = current_movement_direction.normalized()
	else:
		attack_direction = Vector2.RIGHT
	
	# ACTUALIZAR DIRECCIONES PARA ANIMACIONES
	current_aim_direction = attack_direction
	last_shoot_direction = attack_direction
	
	# INICIAR ANIMACIÓN DE MELEE EN EL CONTROLADOR
	if animation_controller:
		animation_controller.start_melee_animation()
	
	# Mostrar cuchillo y ocultar arma
	if melee_knife_sprite:
		melee_knife_sprite.visible = true
	if weapon_renderer:
		weapon_renderer.hide_weapon()
	
	# BUSCAR ENEMIGOS EN DIRECCIÓN DE ATAQUE
	var melee_range = 90.0
	var enemies_hit = []
	
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy and is_instance_valid(enemy):
			var distance_to_enemy = enemy.global_position.distance_to(global_position)
			if distance_to_enemy <= melee_range:
				var direction_to_enemy = (enemy.global_position - global_position).normalized()
				var angle_diff = attack_direction.angle_to(direction_to_enemy)
				
				if abs(angle_diff) <= PI/2:
					enemies_hit.append(enemy)
	
	if not enemies_hit.is_empty():
		for enemy in enemies_hit:
			if enemy.has_method("take_damage"):
				enemy.take_damage(50, false)
				
				if score_system:
					score_system.add_kill_points(enemy.global_position, false, true)
				
				create_melee_effect(enemy.global_position)
	
	# Animar cuchillo según dirección
	animate_melee_knife_directional(attack_direction)
	
	# Finalizar melee después de la animación
	var melee_timer = Timer.new()
	melee_timer.wait_time = 0.5
	melee_timer.one_shot = true
	melee_timer.timeout.connect(_finish_melee_attack)
	add_child(melee_timer)
	melee_timer.start()

func animate_melee_knife_directional(attack_direction: Vector2):
	"""Animar el cuchillo según la dirección de ataque"""
	if not melee_knife_sprite:
		return
	
	var start_distance = 30.0
	var end_distance = 60.0
	
	var start_pos = global_position + (attack_direction * start_distance)
	var end_pos = global_position + (attack_direction * end_distance)
	
	melee_knife_sprite.global_position = start_pos
	melee_knife_sprite.rotation = attack_direction.angle()
	
	if attack_direction.x < 0:
		melee_knife_sprite.flip_v = true
	else:
		melee_knife_sprite.flip_v = false
	
	var tween = create_tween()
	tween.tween_property(melee_knife_sprite, "global_position", end_pos, 0.2)
	tween.tween_property(melee_knife_sprite, "global_position", start_pos, 0.2)

func _finish_melee_attack():
	"""Función para finalizar ataque melee"""
	finish_melee_attack()
	# Limpiar timer
	var melee_timer = get_node_or_null("Timer")
	if melee_timer:
		melee_timer.queue_free()

func finish_melee_attack():
	"""Finalizar ataque de melee"""
	is_performing_melee = false
	
	# Restaurar arma
	if melee_knife_sprite:
		melee_knife_sprite.visible = false
	if weapon_renderer:
		weapon_renderer.show_weapon()

func create_melee_effect(hit_pos: Vector2):
	"""Crear efecto visual de melee"""
	for i in range(6):
		var particle = Sprite2D.new()
		var particle_image = Image.create(6, 6, false, Image.FORMAT_RGBA8)
		particle_image.fill(Color.ORANGE)
		particle.texture = ImageTexture.create_from_image(particle_image)
		particle.global_position = hit_pos + Vector2(randf_range(-15, 15), randf_range(-15, 15))
		get_tree().current_scene.add_child(particle)
		
		var tween = create_tween()
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.5)
		tween.parallel().tween_property(particle, "global_position", 
			particle.global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30)), 0.5)
		tween.tween_callback(_cleanup_melee_particle.bind(particle))

func _cleanup_melee_particle(particle: Sprite2D):
	"""Limpiar partícula de melee"""
	if is_instance_valid(particle):
		particle.queue_free()

func on_enemy_killed():
	"""Callback cuando mata enemigo"""
	if character_stats and character_stats.should_say_kill_phrase():
		var phrase = character_stats.get_random_kill_phrase()
		show_kill_phrase(phrase)

func show_kill_phrase(phrase: String):
	"""Mostrar frase de kill en pantalla"""
	var phrase_label = Label.new()
	phrase_label.text = phrase
	phrase_label.add_theme_font_size_override("font_size", 24)
	phrase_label.add_theme_color_override("font_color", Color.CYAN)
	phrase_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	phrase_label.add_theme_constant_override("shadow_offset_x", 2)
	phrase_label.add_theme_constant_override("shadow_offset_y", 2)
	phrase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	phrase_label.global_position = global_position + Vector2(-50, -80)
	phrase_label.size = Vector2(100, 30)
	
	get_tree().current_scene.add_child(phrase_label)
	
	var tween = create_tween()
	tween.parallel().tween_property(phrase_label, "global_position", 
		phrase_label.global_position + Vector2(0, -50), 2.0)
	tween.parallel().tween_property(phrase_label, "modulate:a", 0.0, 1.5)
	tween.tween_callback(_cleanup_phrase_label.bind(phrase_label))

func _cleanup_phrase_label(label: Label):
	"""Limpiar etiqueta de frase"""
	if is_instance_valid(label):
		label.queue_free()

func take_damage(amount: int):
	"""Recibir daño - actualiza mini HUD"""
	if is_invulnerable or not is_alive():
		return
	
	if not is_fully_initialized:
		return
	
	var _old_health = current_health
	current_health -= amount
	current_health = max(current_health, 0)
	
	if mini_hud:
		mini_hud.update_health(current_health, max_health)
	
	if character_stats:
		character_stats.current_health = current_health
	
	flash_damage_effect()
	start_invulnerability()
	
	if score_system:
		score_system.reset_kill_streak()
	
	apply_screen_shake()
	
	if current_health <= 0:
		die()

func flash_damage_effect():
	"""Efecto visual de daño"""
	if not animated_sprite:
		return
	
	animated_sprite.modulate = Color(2.0, 0.3, 0.3, 1.0)
	var tween = create_tween()
	tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.3)

func start_invulnerability():
	"""Iniciar invulnerabilidad"""
	is_invulnerable = true
	
	if animated_sprite:
		var blink_tween = create_tween()
		var blink_count = int(invulnerability_duration * 8)
		blink_tween.set_loops(blink_count)
		blink_tween.tween_property(animated_sprite, "modulate:a", 0.3, 0.0625)
		blink_tween.tween_property(animated_sprite, "modulate:a", 1.0, 0.0625)
	
	var invul_timer = Timer.new()
	invul_timer.wait_time = invulnerability_duration
	invul_timer.one_shot = true
	invul_timer.timeout.connect(_end_invulnerability)
	add_child(invul_timer)
	invul_timer.start()

func _end_invulnerability():
	"""Terminar invulnerabilidad"""
	is_invulnerable = false
	if animated_sprite:
		animated_sprite.modulate = Color.WHITE
	# Limpiar timer
	var invul_timer = get_node_or_null("Timer")
	if invul_timer:
		invul_timer.queue_free()

func apply_screen_shake():
	"""Efecto de screen shake"""
	if not camera:
		return
	
	var shake_tween = create_tween()
	var shake_intensity = 8.0
	var shake_duration = 0.4
	
	for i in range(8):
		var shake_offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		shake_tween.tween_property(camera, "offset", shake_offset, shake_duration / 8.0)
	
	shake_tween.tween_property(camera, "offset", Vector2.ZERO, shake_duration / 8.0)

func apply_knockback(direction: Vector2, force: float):
	"""Aplicar knockback"""
	if direction.length() > 0:
		velocity += direction.normalized() * force

func die():
	"""Manejar muerte"""
	velocity = Vector2.ZERO
	set_physics_process(false)
	
	if animated_sprite:
		animated_sprite.modulate = Color.RED
		var death_tween = create_tween()
		death_tween.tween_property(animated_sprite, "modulate", Color.BLACK, 1.0)
		death_tween.tween_property(animated_sprite, "modulate:a", 0.1, 1.0)
	
	player_died.emit()

func heal(amount: int):
	"""Curar jugador y actualizar MiniHUD"""
	var _old_health = current_health
	current_health = min(current_health + amount, max_health)
	
	if mini_hud:
		mini_hud.update_health(current_health, max_health)
	
	if character_stats:
		character_stats.current_health = current_health

func get_current_health() -> int:
	return current_health

func get_max_health() -> int:
	return max_health

func is_alive() -> bool:
	return current_health > 0 and is_fully_initialized

func get_weapon_stats() -> WeaponStats:
	if character_stats:
		return character_stats.equipped_weapon
	return null

func get_camera() -> Camera2D:
	return camera

func start_manual_reload():
	"""Iniciar recarga manual con feedback visual"""
	if shooting_component:
		var reload_started = shooting_component.start_manual_reload()
		if reload_started:
			if animated_sprite:
				var reload_tween = create_tween()
				reload_tween.tween_property(animated_sprite, "modulate", Color(0.8, 0.8, 1.0, 1.0), 0.2)
				reload_tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.3)
		return reload_started
	return false

func get_ammo_info() -> Dictionary:
	"""Obtener información de munición"""
	if shooting_component:
		return shooting_component.get_ammo_info()
	return {"current": 0, "max": 0, "reloading": false, "reload_progress": 0.0}

# FUNCIONES DE DEBUG Y UTILIDAD

func debug_animation_state():
	"""Depurar estado de animaciones"""
	if animation_controller:
		animation_controller.debug_animation_state()
	print("🎮 === PLAYER DEBUG ===")
	print("🎮 Movimiento actual: ", current_movement_direction)
	print("🎮 Aim actual: ", current_aim_direction)
	print("🎮 Último disparo: ", last_shoot_direction)
	print("🎮 Último movimiento: ", last_movement_direction)
	print("🎮 En melee: ", is_performing_melee)
	print("🎮 =====================")

func force_idle_animation():
	"""Forzar animación idle"""
	if animation_controller:
		animation_controller.force_animation("idle")

func reset_animation_system():
	"""Resetear sistema de animaciones"""
	current_movement_direction = Vector2.ZERO
	current_aim_direction = Vector2.ZERO
	last_shoot_direction = Vector2.RIGHT
	last_movement_direction = Vector2.ZERO
	
	if animation_controller:
		animation_controller.reset_animation_state()

func _exit_tree():
	"""Limpiar al salir"""
	set_physics_process(false)
	set_process(false)
