# scenes/player/player.gd - MELEE CON COOLDOWN CORREGIDO + INVULNERABILIDAD ARREGLADA
extends CharacterBody2D
class_name Player
signal player_died

@export var character_stats: CharacterStats
@onready var animated_sprite = $AnimatedSprite2D
@onready var collision_shape = $CollisionShape2D
@onready var shooting_component = $ShootingComponent
@onready var camera = $Camera2D

var current_health: int = 4
var max_health: int = 4
var move_speed: float = 300.0
var is_mobile: bool = false

# Control móvil
var mobile_movement_direction: Vector2 = Vector2.ZERO
var mobile_shoot_direction: Vector2 = Vector2.ZERO
var mobile_is_shooting: bool = false

# Variables de movimiento y animación
var current_movement_direction: Vector2 = Vector2.ZERO
var current_aim_direction: Vector2 = Vector2.ZERO
var last_direction: Vector2 = Vector2.RIGHT

# Melee attack - COOLDOWN CORREGIDO
var melee_cooldown: float = 0.6  # COOLDOWN MÁS CORTO PERO PRESENTE
var last_melee_time: float = 0.0
var is_performing_melee: bool = false
var melee_knife_sprite: Sprite2D
var melee_range: float = 150.0
var static_melee_damage: int = 150

# CURACIÓN AUTOMÁTICA BALANCEADA
var healing_timer: Timer
var healing_interval: float = 20.0
var healing_amount: int = 1

# INVULNERABILIDAD CORREGIDA
var is_invulnerable: bool = false
var invulnerability_duration: float = 1.0  # REDUCIDO
var invulnerability_timer: Timer

# Referencias
var score_system: ScoreSystem
var weapon_renderer: WeaponRenderer
var animation_controller: AnimationController
var mini_hud: MiniHUD
var wall_system: WallSystem
var rounds_manager: RoundsManager

# Estado
var is_fully_initialized: bool = false

# Límites del mapa
var map_bounds: Rect2 = Rect2(-2000, -1500, 4000, 3000)

func _ready():
	is_mobile = OS.has_feature("mobile")
	setup_camera()
	setup_weapon_renderer()
	setup_melee_knife()
	setup_healing_system()
	setup_invulnerability_timer()
	get_wall_system_reference()
	get_rounds_manager_reference()
	
	collision_layer = 1
	collision_mask = 2 | 3 | 16

func setup_invulnerability_timer():
	"""Configurar timer de invulnerabilidad separado"""
	invulnerability_timer = Timer.new()
	invulnerability_timer.name = "InvulnerabilityTimer"
	invulnerability_timer.one_shot = true
	invulnerability_timer.timeout.connect(_end_invulnerability)
	add_child(invulnerability_timer)

func get_rounds_manager_reference():
	"""Obtener referencia al rounds manager"""
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_node("RoundsManager"):
		rounds_manager = game_manager.get_node("RoundsManager")

func setup_healing_system():
	"""Configurar sistema de curación automática BALANCEADA"""
	healing_timer = Timer.new()
	healing_timer.name = "HealingTimer"
	healing_timer.wait_time = healing_interval
	healing_timer.autostart = true
	healing_timer.timeout.connect(_on_healing_timer_timeout)
	add_child(healing_timer)

func _on_healing_timer_timeout():
	"""Curar 1 de vida automáticamente - SOLO SI NO ESTÁ EN COMBATE"""
	if current_health < max_health and is_alive():
		# CURACIÓN INTELIGENTE: Solo curar si no hay enemigos muy cerca
		var nearby_enemies = get_enemies_in_range(200.0)
		if nearby_enemies.is_empty():
			heal(healing_amount)
		else:
			# Retrasar curación cuando hay enemigos cerca
			healing_timer.start()

func get_enemies_in_range(range_distance: float) -> Array:
	"""Obtener enemigos en rango específico"""
	var nearby_enemies = []
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	
	for enemy in all_enemies:
		if is_instance_valid(enemy) and enemy.has_method("is_alive") and enemy.is_alive():
			var distance = global_position.distance_to(enemy.global_position)
			if distance <= range_distance:
				nearby_enemies.append(enemy)
	
	return nearby_enemies

func get_wall_system_reference():
	"""Obtener referencia al sistema de paredes"""
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_node("WallSystem"):
		wall_system = game_manager.get_node("WallSystem")

func setup_camera():
	if camera:
		camera.enabled = true
		camera.zoom = Vector2(0.75, 0.75)
		camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
		camera.position_smoothing_enabled = true
		camera.position_smoothing_speed = 8.0

func setup_weapon_renderer():
	weapon_renderer = WeaponRenderer.new()
	weapon_renderer.name = "WeaponRenderer"
	weapon_renderer.set_player_reference(self)
	add_child(weapon_renderer)

func setup_melee_knife():
	"""Configurar cuchillo de melee"""
	melee_knife_sprite = Sprite2D.new()
	melee_knife_sprite.name = "MeleeKnife"
	melee_knife_sprite.visible = false
	melee_knife_sprite.z_index = 15
	
	var knife_image = Image.create(48, 12, false, Image.FORMAT_RGBA8)
	knife_image.fill(Color.TRANSPARENT)
	
	# Hoja del cuchillo
	for x in range(28, 48):
		for y in range(3, 9):
			knife_image.set_pixel(x, y, Color.LIGHT_GRAY)
	
	# Mango del cuchillo
	for x in range(0, 28):
		for y in range(2, 10):
			knife_image.set_pixel(x, y, Color(0.6, 0.4, 0.2))
	
	melee_knife_sprite.texture = ImageTexture.create_from_image(knife_image)
	add_child(melee_knife_sprite)

func _physics_process(delta):
	if not is_fully_initialized:
		return
		
	handle_movement(delta)
	handle_shooting()
	update_weapon_position()
	update_melee_knife_position()
	update_animations_simplified()
	move_and_slide()
	apply_map_bounds()

func _input(event):
	if not is_fully_initialized:
		return
	
	if event.is_action_pressed("melee_attack"):
		perform_melee_attack_enhanced()
		get_viewport().set_input_as_handled()

func perform_melee_attack_enhanced():
	"""ATAQUE MELEE CON COOLDOWN CORREGIDO"""
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# VERIFICAR COOLDOWN
	if current_time - last_melee_time < melee_cooldown:
		return
	
	if is_performing_melee:
		return
	
	last_melee_time = current_time
	is_performing_melee = true
	
	var attack_direction = Vector2.ZERO
	if current_aim_direction.length() > 0.1:
		attack_direction = current_aim_direction.normalized()
	elif current_movement_direction.length() > 0.1:
		attack_direction = current_movement_direction.normalized()
	else:
		attack_direction = last_direction
	
	if animation_controller:
		animation_controller.start_melee_animation()
	
	if melee_knife_sprite:
		melee_knife_sprite.visible = true
	if weapon_renderer:
		weapon_renderer.hide_weapon()
	
	# BUSCAR Y ATACAR ENEMIGOS
	var enemies_hit = find_enemies_for_melee_guaranteed(attack_direction)
	
	for enemy in enemies_hit:
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			var enemy_health_before = enemy.current_health if "current_health" in enemy else 0
			
			# APLICAR DAÑO DIRECTO Y GARANTIZADO
			enemy.take_damage(static_melee_damage, false, 0.6)
			
			var enemy_health_after = enemy.current_health if "current_health" in enemy else 0
			var actual_damage = enemy_health_before - enemy_health_after
			
			# VERIFICAR SI MURIÓ
			var enemy_is_dead = false
			if enemy.has_method("is_alive"):
				enemy_is_dead = not enemy.is_alive()
			elif "is_dead" in enemy:
				enemy_is_dead = enemy.is_dead
			elif enemy_health_after <= 0:
				enemy_is_dead = true
			
			# PUNTUACIÓN
			if score_system:
				if enemy_is_dead:
					score_system.add_kill_points(enemy.global_position, false, true)
				else:
					score_system.add_damage_points(enemy.global_position, actual_damage, false)
			
			# EFECTO VISUAL
			create_enhanced_melee_effect(enemy.global_position)
	
	animate_melee_knife(attack_direction)
	
	# Timer para terminar melee
	var melee_timer = Timer.new()
	melee_timer.wait_time = 0.5
	melee_timer.one_shot = true
	melee_timer.timeout.connect(_finish_melee_attack)
	add_child(melee_timer)
	melee_timer.start()

func find_enemies_for_melee_guaranteed(attack_direction: Vector2) -> Array:
	"""DETECCIÓN GARANTIZADA DE ENEMIGOS PARA MELEE"""
	var enemies_hit = []
	
	# MÉTODO 1: Buscar por grupo
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	
	for enemy in all_enemies:
		if not is_instance_valid(enemy):
			continue
		
		# Verificar que esté vivo
		if enemy.has_method("is_alive") and not enemy.is_alive():
			continue
		if "is_dead" in enemy and enemy.is_dead:
			continue
		if "current_health" in enemy and enemy.current_health <= 0:
			continue
		
		var distance = enemy.global_position.distance_to(global_position)
		
		if distance > melee_range:
			continue
		
		# DETECCIÓN DE DIRECCIÓN MUY PERMISIVA
		var direction_to_enemy = (enemy.global_position - global_position).normalized()
		var angle_diff = attack_direction.angle_to(direction_to_enemy)
		var angle_diff_degrees = rad_to_deg(abs(angle_diff))
		
		# MUY PERMISIVO: 120 grados (casi cualquier dirección)
		if angle_diff_degrees > 60.0:  # 120 grados total / 2
			continue
		enemies_hit.append(enemy)
	
	return enemies_hit

func animate_melee_knife(attack_direction: Vector2):
	"""Animar cuchillo"""
	if not melee_knife_sprite:
		return
	
	var start_distance = 25.0
	var end_distance = 90.0
	
	var start_pos = global_position + (attack_direction * start_distance)
	var end_pos = global_position + (attack_direction * end_distance)
	
	melee_knife_sprite.global_position = start_pos
	melee_knife_sprite.rotation = attack_direction.angle()
	
	if attack_direction.x < 0:
		melee_knife_sprite.flip_v = true
	else:
		melee_knife_sprite.flip_v = false
	
	var tween = create_tween()
	tween.tween_property(melee_knife_sprite, "global_position", end_pos, 0.15)
	tween.tween_property(melee_knife_sprite, "global_position", start_pos, 0.25)

func create_enhanced_melee_effect(hit_pos: Vector2):
	"""Crear efecto visual mejorado para ataques melee"""
	for i in range(15):
		var particle = Sprite2D.new()
		var particle_size = randi_range(8, 20)
		var particle_image = Image.create(particle_size, particle_size, false, Image.FORMAT_RGBA8)
		
		var colors = [Color.ORANGE, Color.YELLOW, Color.RED, Color.WHITE, Color.GOLD]
		particle_image.fill(colors[i % colors.size()])
		
		particle.texture = ImageTexture.create_from_image(particle_image)
		particle.global_position = hit_pos + Vector2(randf_range(-40, 40), randf_range(-40, 40))
		get_tree().current_scene.add_child(particle)
		
		var tween = create_tween()
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 1.2)
		tween.parallel().tween_property(particle, "global_position", 
			particle.global_position + Vector2(randf_range(-80, 80), randf_range(-80, 80)), 1.2)
		tween.parallel().tween_property(particle, "scale", Vector2(3.0, 3.0), 0.6)
		tween.tween_callback(func():
			if is_instance_valid(particle):
				particle.queue_free()
		)

func _finish_melee_attack():
	"""Terminar ataque melee"""
	is_performing_melee = false
	
	if melee_knife_sprite:
		melee_knife_sprite.visible = false
	if weapon_renderer:
		weapon_renderer.show_weapon()
	
	# Limpiar timer
	for child in get_children():
		if child is Timer and child.name.begins_with("@Timer"):
			child.queue_free()

func update_melee_knife_position():
	"""Actualizar posición del cuchillo"""
	if not melee_knife_sprite or not is_performing_melee:
		return
	
	var knife_direction = Vector2.ZERO
	
	if current_aim_direction.length() > 0.1:
		knife_direction = current_aim_direction.normalized()
	elif current_movement_direction.length() > 0.1:
		knife_direction = current_movement_direction.normalized()
	else:
		knife_direction = last_direction
	
	var knife_distance = 50.0
	var knife_offset = knife_direction * knife_distance
	
	melee_knife_sprite.global_position = global_position + knife_offset
	melee_knife_sprite.rotation = knife_direction.angle()
	
	if knife_direction.x < 0:
		melee_knife_sprite.flip_v = true
	else:
		melee_knife_sprite.flip_v = false

func handle_movement(_delta):
	var input_direction = Vector2.ZERO
	
	if is_mobile:
		input_direction = mobile_movement_direction
	else:
		input_direction.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		input_direction.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	
	if input_direction.length() > 1.0:
		input_direction = input_direction.normalized()
	
	current_movement_direction = input_direction
	velocity = input_direction * move_speed
	
	check_barricade_collision()

func check_barricade_collision():
	"""Verificar que el jugador no pueda atravesar barricadas aunque no tengan tablones"""
	if not wall_system:
		return
	
	var player_pos = global_position
	
	for barricade in wall_system.get_all_barricades():
		if not is_instance_valid(barricade):
			continue
		
		var distance = player_pos.distance_to(barricade.global_position)
		var barricade_size = barricade.get_meta("size", Vector2(200, 60))
		
		if distance < barricade_size.length() / 2 + 50:
			var current_planks = barricade.get_meta("current_planks", 0)
			
			if current_planks == 0:
				var to_barricade = barricade.global_position - player_pos
				var barricade_bounds = Rect2(
					barricade.global_position - barricade_size/2,
					barricade_size
				)
				
				if barricade_bounds.has_point(player_pos):
					var push_direction = -to_barricade.normalized()
					velocity += push_direction * move_speed * 2

func handle_shooting():
	var shoot_direction = Vector2.ZERO
	
	if is_mobile:
		if mobile_is_shooting and mobile_shoot_direction.length() > 0:
			shoot_direction = mobile_shoot_direction
	else:
		shoot_direction.x = Input.get_action_strength("shoot_right") - Input.get_action_strength("shoot_left")
		shoot_direction.y = Input.get_action_strength("shoot_down") - Input.get_action_strength("shoot_up")
	
	if shoot_direction.length() > 0:
		current_aim_direction = shoot_direction.normalized()
		perform_shoot(current_aim_direction)
	else:
		current_aim_direction = Vector2.ZERO

func update_animations_simplified():
	"""Sistema simplificado de animaciones"""
	if not animation_controller:
		return
	
	var is_moving = current_movement_direction.length() > 0.1
	var is_shooting = current_aim_direction.length() > 0.1
	
	var animation_direction = Vector2.ZERO
	
	if is_shooting and is_moving:
		animation_direction = current_aim_direction
		last_direction = current_aim_direction
	elif is_shooting:
		animation_direction = current_aim_direction
		last_direction = current_aim_direction
	elif is_moving:
		animation_direction = current_movement_direction
		last_direction = current_movement_direction
		current_aim_direction = Vector2.ZERO
	else:
		animation_direction = last_direction
	
	animation_controller.update_animation_combined(animation_direction, animation_direction)

func perform_shoot(direction: Vector2):
	if not shooting_component:
		return
	
	current_aim_direction = direction
	var shoot_pos = get_corrected_bullet_spawn_position(direction)
	var shot_fired = shooting_component.try_shoot(direction, shoot_pos)
	
	if shot_fired and weapon_renderer:
		weapon_renderer.start_shooting_animation()

func get_corrected_bullet_spawn_position(direction: Vector2) -> Vector2:
	var base_offset = Vector2(0, -15)
	var angle = direction.angle()
	var rotated_offset = base_offset.rotated(angle)
	
	if abs(angle) < PI/4:
		rotated_offset += Vector2(25, 0)
	elif abs(angle) > 3*PI/4:
		rotated_offset += Vector2(-25, 0)
	elif angle > PI/4 and angle < 3*PI/4:
		rotated_offset += Vector2(0, 15)
	elif angle < -PI/4 and angle > -3*PI/4:
		rotated_offset += Vector2(0, -25)
	
	if weapon_renderer:
		var muzzle_pos = weapon_renderer.get_muzzle_world_position()
		if muzzle_pos != global_position:
			return muzzle_pos
	
	return global_position + rotated_offset

func update_weapon_position():
	if not weapon_renderer:
		return
	
	var aim_direction = current_aim_direction
	if aim_direction.length() < 0.1:
		aim_direction = last_direction
	
	weapon_renderer.update_weapon_position_and_rotation(aim_direction)

func apply_map_bounds():
	"""Aplicar límites del mapa"""
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

func take_damage(amount: int):
	"""SISTEMA DE DAÑO CORREGIDO - INVULNERABILIDAD SIMPLE"""
	if is_invulnerable or not is_alive():
		return
	
	if not is_fully_initialized:
		return
	
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
	
	if current_health <= 0:
		die()

func heal(amount: int):
	"""Curar jugador"""
	var old_health = current_health
	current_health = min(current_health + amount, max_health)
	
	if mini_hud:
		mini_hud.update_health(current_health, max_health)
	
	if character_stats:
		character_stats.current_health = current_health
	
	if animated_sprite and current_health > old_health:
		var tween = create_tween()
		animated_sprite.modulate = Color.GREEN
		tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.3)

func flash_damage_effect():
	if not animated_sprite:
		return
	
	animated_sprite.modulate = Color(2.0, 0.3, 0.3, 1.0)
	var tween = create_tween()
	tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.3)

func start_invulnerability():
	"""INVULNERABILIDAD SIMPLE CON TIMER SEPARADO"""
	is_invulnerable = true
	
	if animated_sprite:
		var blink_tween = create_tween()
		var blink_count = int(invulnerability_duration * 6)
		blink_tween.set_loops(blink_count)
		blink_tween.tween_property(animated_sprite, "modulate:a", 0.3, 0.08)
		blink_tween.tween_property(animated_sprite, "modulate:a", 1.0, 0.08)
	
	# Usar timer separado
	invulnerability_timer.wait_time = invulnerability_duration
	invulnerability_timer.start()

func _end_invulnerability():
	"""Terminar invulnerabilidad"""
	is_invulnerable = false
	
	if animated_sprite:
		animated_sprite.modulate = Color.WHITE

func die():
	velocity = Vector2.ZERO
	set_physics_process(false)
	
	if animated_sprite:
		animated_sprite.modulate = Color.RED
		var death_tween = create_tween()
		death_tween.tween_property(animated_sprite, "modulate", Color.BLACK, 1.0)
		death_tween.tween_property(animated_sprite, "modulate:a", 0.1, 1.0)
	
	player_died.emit()

# Funciones de acceso
func update_character_stats(new_stats: CharacterStats):
	character_stats = new_stats
	apply_character_stats()
	call_deferred("setup_mini_hud_with_stats")

func apply_character_stats():
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

func setup_mini_hud_with_stats():
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

func set_animation_controller(controller: AnimationController):
	animation_controller = controller

func set_score_system(score_sys: ScoreSystem):
	score_system = score_sys

func start_manual_reload():
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
	if shooting_component:
		return shooting_component.get_ammo_info()
	return {"current": 0, "max": 0, "reloading": false, "reload_progress": 0.0}

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
