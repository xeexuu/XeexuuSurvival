# scenes/enemies/Enemy.gd - IA ESTILO WORLD AT WAR AGRESIVA
extends CharacterBody2D
class_name Enemy

signal died(enemy: Enemy)
signal damaged(enemy: Enemy, damage: int)

@export var enemy_type: String = "zombie_basic"
@export var max_health: int = 150
@export var current_health: int = 150
@export var base_move_speed: float = 100.0  # REDUCIDO: velocidad base más moderada
@export var damage: int = 1
@export var attack_range: float = 60.0
@export var detection_range: float = 1000.0  # REDUCIDO un poco
@export var attack_cooldown: float = 1.0

@onready var sprite = $Sprite2D
@onready var collision_shape = $CollisionShape2D
@onready var attack_timer = $AttackTimer
@onready var health_bar = $HealthBar

var player: Player = null
var is_dead: bool = false
var last_attack_time: float = 0.0
var current_move_speed: float = 150.0

# ===== IA WORLD AT WAR - DIRECTA Y AGRESIVA =====
enum WaWState {
	SPAWNING,
	HUNTING,      # Cazando AGRESIVAMENTE
	CHARGING,     # Cargando directo al jugador
	ATTACKING,    # Atacando
	STUNNED       # Aturdido por daño
}

var current_state: WaWState = WaWState.SPAWNING
var state_timer: float = 0.0

# Variables World at War - SIN TORPE BÚSQUEDA
var last_known_player_position: Vector2
var charge_speed_multiplier: float = 1.5
var min_separation_distance: float = 35.0
var max_separation_distance: float = 50.0

# Sistema anti-pegado mejorado
var separation_force: float = 200.0
var is_slowing_player: bool = false
var slow_effect_range: float = 70.0
var slow_effect_strength: float = 0.4

# Spawn y sprites
var spawn_scale: float = 0.0
var spawn_alpha: float = 0.0
var enemy_sprite_frames: SpriteFrames

func _ready():
	add_to_group("enemies")
	setup_enemy()
	determine_waw_variant()

func setup_enemy():
	"""Configurar enemigo base"""
	current_health = max_health
	is_dead = false
	current_state = WaWState.SPAWNING
	
	collision_layer = 2
	collision_mask = 1 | 3
	
	last_known_player_position = global_position
	
	load_enemy_sprite_waw_size()
	setup_health_bar()
	
	if attack_timer:
		attack_timer.wait_time = attack_cooldown
		attack_timer.one_shot = true
		attack_timer.timeout.connect(_on_attack_timer_timeout)

func determine_waw_variant():
	"""Variantes World at War - VELOCIDADES MÁS BALANCEADAS"""
	var rand_val = randf()
	
	if rand_val < 0.15:  # 15% RUNNERS - SÚPER RÁPIDOS
		enemy_type = "zombie_runner"
		charge_speed_multiplier = randf_range(1.8, 2.2)  # RÁPIDOS
		max_health = int(float(max_health) * 0.6)  # MÁS FRÁGILES
		current_health = max_health
		modulate = Color(1.4, 0.6, 0.6, 1.0)
		detection_range = 1200.0
		
	elif rand_val < 0.25:  # 10% CHARGERS - RÁPIDOS
		enemy_type = "zombie_charger"  
		charge_speed_multiplier = randf_range(1.4, 1.7)  # MODERADAMENTE RÁPIDOS
		max_health = int(float(max_health) * 0.8)
		current_health = max_health
		modulate = Color(1.2, 0.8, 0.6, 1.0)
		attack_range = 70.0
		
	elif rand_val < 0.35:  # 10% CRAWLERS - LENTOS PERO RESISTENTES
		enemy_type = "zombie_crawler"
		charge_speed_multiplier = randf_range(0.7, 0.9)  # LENTOS
		max_health = int(float(max_health) * 1.3)  # MÁS RESISTENTES
		current_health = max_health
		modulate = Color(0.8, 1.0, 0.8, 1.0)
		
	else:  # 65% BÁSICOS - VELOCIDAD NORMAL VARIADA
		charge_speed_multiplier = randf_range(0.9, 1.3)  # VELOCIDAD NORMAL CON VARIACIÓN
		max_health = int(float(max_health) * 1.0)
		current_health = max_health
		modulate = Color(1.0, 0.9, 0.8, 1.0)
	
	current_move_speed = base_move_speed * charge_speed_multiplier

func load_enemy_sprite_waw_size():
	"""Cargar sprite del MISMO TAMAÑO que el jugador"""
	var atlas_path = "res://sprites/enemies/zombie/walk_Right_Down.png"
	var atlas_texture = try_load_texture_safe(atlas_path)
	
	if atlas_texture:
		setup_animated_sprite_player_size(atlas_texture)
	else:
		create_default_enemy_sprite_player_size()

func setup_animated_sprite_player_size(atlas_texture: Texture2D):
	"""Sprite del MISMO TAMAÑO que el jugador - SIN INVISIBILIDAD"""
	if sprite and sprite is Sprite2D:
		sprite.queue_free()
		
	var animated_sprite = AnimatedSprite2D.new()
	animated_sprite.name = "AnimatedSprite2D"
	add_child(animated_sprite)
	sprite = animated_sprite
	
	enemy_sprite_frames = SpriteFrames.new()
	
	# Animación de movimiento
	enemy_sprite_frames.add_animation("walk")
	enemy_sprite_frames.set_animation_speed("walk", 12.0)
	enemy_sprite_frames.set_animation_loop("walk", true)
	
	for i in range(8):
		var frame = extract_frame_from_zombie_atlas(atlas_texture, i)
		enemy_sprite_frames.add_frame("walk", frame)
	
	# Animación idle
	enemy_sprite_frames.add_animation("idle")
	enemy_sprite_frames.set_animation_speed("idle", 4.0)
	enemy_sprite_frames.set_animation_loop("idle", true)
	var first_frame = extract_frame_from_zombie_atlas(atlas_texture, 0)
	enemy_sprite_frames.add_frame("idle", first_frame)
	
	# ASEGURAR VISIBILIDAD INMEDIATA
	animated_sprite.sprite_frames = enemy_sprite_frames
	animated_sprite.play("idle")
	animated_sprite.visible = true
	animated_sprite.modulate = Color.WHITE  # ASEGURAR OPACIDAD COMPLETA
	
	# TAMAÑO IGUAL AL JUGADOR
	animated_sprite.scale = Vector2(1.0, 1.0)

func extract_frame_from_zombie_atlas(atlas_texture: Texture2D, frame_index: int) -> Texture2D:
	var frame_width = 128.0
	var x_offset = float(frame_index) * frame_width
	
	var atlas_frame = AtlasTexture.new()
	atlas_frame.atlas = atlas_texture
	atlas_frame.region = Rect2(x_offset, 0, frame_width, 128.0)
	
	return atlas_frame

func create_default_enemy_sprite_player_size():
	"""Sprite por defecto del MISMO TAMAÑO que jugador"""
	var image = Image.create(128, 128, false, Image.FORMAT_RGBA8)  # TAMAÑO COMPLETO
	
	var base_color = Color.DARK_RED
	match enemy_type:
		"zombie_runner":
			base_color = Color(0.9, 0.2, 0.2, 1.0)
		"zombie_charger":
			base_color = Color(0.8, 0.4, 0.2, 1.0)
	
	image.fill(base_color)
	
	for x in range(128):
		for y in range(128):
			var dist = Vector2(x - 64, y - 64).length()
			if dist < 20:
				image.set_pixel(x, y, Color.BLACK)
			elif dist < 35:
				image.set_pixel(x, y, base_color.darkened(0.3))
	
	add_glowing_eyes(image)
	
	var default_texture = ImageTexture.create_from_image(image)
	
	if not sprite:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)
	
	if sprite is Sprite2D:
		var normal_sprite = sprite as Sprite2D
		normal_sprite.texture = default_texture
		normal_sprite.scale = Vector2(1.0, 1.0)  # TAMAÑO COMPLETO
		normal_sprite.visible = true

func add_glowing_eyes(image: Image):
	var eye_positions = [Vector2(45, 45), Vector2(83, 45)]
	
	for eye_pos in eye_positions:
		for x in range(eye_pos.x - 4, eye_pos.x + 4):
			for y in range(eye_pos.y - 3, eye_pos.y + 3):
				if x >= 0 and x < 128 and y >= 0 and y < 128:
					image.set_pixel(x, y, Color.RED)

func try_load_texture_safe(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	
	var resource = load(path)
	if resource is Texture2D:
		return resource as Texture2D
	return null

func setup_health_bar():
	if not health_bar:
		health_bar = ProgressBar.new()
		health_bar.size = Vector2(80, 10)  # MÁS GRANDE
		health_bar.position = Vector2(-40, -70)  # MÁS ARRIBA
		add_child(health_bar)
	
	health_bar.max_value = max_health
	health_bar.value = current_health
	health_bar.show_percentage = false
	health_bar.visible = true
	
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color.BLACK
	health_bar.add_theme_stylebox_override("background", style_bg)
	
	var style_fill = StyleBoxFlat.new()
	style_fill.bg_color = Color.RED
	health_bar.add_theme_stylebox_override("fill", style_fill)

func setup_for_spawn(target_player: Player, round_health: int = -1):
	player = target_player
	
	if round_health > 0:
		max_health = round_health
		match enemy_type:
			"zombie_runner":
				max_health = int(float(max_health) * 0.7)
			"zombie_charger":
				max_health = int(float(max_health) * 0.9)
	
	current_health = max_health
	is_dead = false
	current_state = WaWState.SPAWNING
	
	modulate = Color(1, 1, 1, 0)
	scale = Vector2.ZERO
	spawn_scale = 0.0
	spawn_alpha = 0.0
	
	call_deferred("_reactivate_collision")
	update_health_bar()
	start_spawn_animation()

func start_spawn_animation():
	current_state = WaWState.SPAWNING
	
	var spawn_tween = create_tween()
	spawn_tween.set_parallel(true)
	
	spawn_tween.tween_method(set_spawn_scale, 0.0, 1.0, 0.5)  # MÁS RÁPIDO
	spawn_tween.tween_method(set_spawn_alpha, 0.0, 1.0, 0.3)  # MÁS RÁPIDO
	
	spawn_tween.tween_callback(func(): 
		current_state = WaWState.HUNTING
		state_timer = 0.0
	)

func set_spawn_scale(value: float):
	spawn_scale = value
	var base_scale = Vector2(1.0, 1.0)  # TAMAÑO COMPLETO
	scale = base_scale * spawn_scale

func set_spawn_alpha(value: float):
	spawn_alpha = value
	var current_color = modulate
	current_color.a = spawn_alpha
	modulate = current_color

func _reactivate_collision():
	if collision_shape and is_instance_valid(collision_shape):
		collision_shape.disabled = false

func _physics_process(delta):
	if is_dead or not player or not is_instance_valid(player):
		return
	
	update_waw_ai_state_machine(delta)
	handle_waw_movement(delta)
	handle_player_slow_effect()
	update_movement_animation()
	
	move_and_slide()

# ===== IA WORLD AT WAR - DIRECTA Y SIN TONTERÍAS =====

func update_waw_ai_state_machine(delta):
	"""IA World at War - CON DETECCIÓN POR DISTANCIA"""
	state_timer += delta
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	match current_state:
		WaWState.SPAWNING:
			pass
		
		WaWState.HUNTING:
			# DETECCIÓN INSTANTÁNEA
			if distance_to_player <= detection_range:
				current_state = WaWState.CHARGING
				last_known_player_position = player.global_position
				state_timer = 0.0
		
		WaWState.CHARGING:
			# CARGA DIRECTA
			last_known_player_position = player.global_position
			
			if distance_to_player <= attack_range:
				current_state = WaWState.ATTACKING
				state_timer = 0.0
				start_waw_attack()
		
		WaWState.ATTACKING:
			# ATAQUE POR DISTANCIA - NO POR COLISIÓN
			if distance_to_player <= attack_range and can_attack():
				execute_waw_attack()
			elif distance_to_player > attack_range * 1.5:
				current_state = WaWState.CHARGING
				state_timer = 0.0
		
		WaWState.STUNNED:
			if state_timer > 0.1:
				current_state = WaWState.CHARGING
				state_timer = 0.0

func handle_waw_movement(delta):
	"""Movimiento World at War - DIRECTO Y AGRESIVO"""
	var movement_direction = Vector2.ZERO
	
	match current_state:
		WaWState.SPAWNING:
			movement_direction = Vector2.ZERO
		
		WaWState.HUNTING:
			# MOVIMIENTO DE CAZA - HACIA EL JUGADOR
			if player:
				movement_direction = (player.global_position - global_position).normalized()
		
		WaWState.CHARGING:
			# CARGA DIRECTA - SIN OBSTÁCULOS
			movement_direction = get_waw_charge_movement()
		
		WaWState.ATTACKING:
			# MOVIMIENTO DE ATAQUE - MANTENER PRESIÓN
			movement_direction = get_waw_attack_movement()
		
		WaWState.STUNNED:
			movement_direction = velocity * 0.1
	
	# Aplicar separación anti-pegado
	movement_direction += get_waw_separation() * 0.3
	
	if movement_direction != Vector2.ZERO:
		velocity = movement_direction.normalized() * current_move_speed
	
	check_waw_stuck(delta)

func get_waw_charge_movement() -> Vector2:
	"""Carga directa - CON SISTEMA ANTI-PEGADO FUERTE"""
	var direction_to_player = (player.global_position - global_position).normalized()
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# SISTEMA ANTI-PEGADO CRÍTICO
	if distance_to_player < min_separation_distance:
		# FUERZA DE REPULSIÓN FUERTE
		var repulsion_dir = (global_position - player.global_position).normalized()
		return repulsion_dir * 1.5  # FUERZA AUMENTADA
	
	# Si está muy cerca, hacer órbita en lugar de carga directa
	if distance_to_player < min_separation_distance * 1.5:
		var perpendicular = Vector2(-direction_to_player.y, direction_to_player.x)
		if randf() > 0.5:
			perpendicular = -perpendicular
		return perpendicular * 0.8  # MOVIMIENTO LATERAL
	
	# CARGA DIRECTA NORMAL
	return direction_to_player * charge_speed_multiplier

func get_waw_attack_movement() -> Vector2:
	"""Movimiento de ataque - ANTI-PEGADO EXTREMO"""
	var distance_to_player = global_position.distance_to(player.global_position)
	var direction_to_player = (player.global_position - global_position).normalized()
	
	# ANTI-PEGADO CRÍTICO - MÁXIMA PRIORIDAD
	if distance_to_player < min_separation_distance:
		var separation_dir = (global_position - player.global_position).normalized()
		return separation_dir * 2.0  # FUERZA DE SEPARACIÓN MUY FUERTE
	
	# ZONA DE CONFORT - NO ACERCARSE DEMASIADO
	if distance_to_player < min_separation_distance * 1.2:
		# MOVIMIENTO LATERAL PARA FLANQUEAR
		var lateral_direction = Vector2(-direction_to_player.y, direction_to_player.x)
		if randf() > 0.5:
			lateral_direction = -lateral_direction
		return lateral_direction * 0.9
	
	# MANTENER DISTANCIA DE ATAQUE ÓPTIMA
	if distance_to_player > max_separation_distance:
		return direction_to_player * 0.6
	else:
		# POSICIÓN ÓPTIMA - MOVIMIENTO MÍNIMO
		return Vector2.ZERO

func get_waw_separation() -> Vector2:
	"""Separación anti-pegado - MEJORADA"""
	var separation = Vector2.ZERO
	var zombie_count = 0
	var separation_radius = 80.0  # AUMENTADO
	
	# SEPARACIÓN DEL JUGADOR - MÁXIMA PRIORIDAD
	var distance_to_player = global_position.distance_to(player.global_position)
	if distance_to_player < min_separation_distance:
		var player_separation = (global_position - player.global_position).normalized()
		var player_strength = 1.0 - (distance_to_player / min_separation_distance)
		separation += player_separation * player_strength * 3.0  # FUERZA TRIPLE
	
	# SEPARACIÓN DE OTROS ZOMBIES
	for other_zombie in get_tree().get_nodes_in_group("enemies"):
		if other_zombie == self or not is_instance_valid(other_zombie):
			continue
		
		var distance = global_position.distance_to(other_zombie.global_position)
		if distance < separation_radius and distance > 0:
			var separation_dir = (global_position - other_zombie.global_position).normalized()
			var strength = 1.0 - (distance / separation_radius)
			separation += separation_dir * strength * 1.5  # FUERZA AUMENTADA
			zombie_count += 1
	
	if separation.length() > 0:
		separation = separation.normalized() * min(separation.length(), 2.0)
	
	return separation

func check_waw_stuck(delta):
	"""Anti-atasco World at War - SIN PRINTS"""
	var last_pos_key = str(int(last_known_player_position.x / 50)) + "_" + str(int(last_known_player_position.y / 50))
	
	if global_position.distance_to(last_known_player_position) < 10.0:
		state_timer += delta
		
		if state_timer > 0.5:
			# SALTO AGRESIVO HACIA EL JUGADOR
			var jump_direction = (player.global_position - global_position).normalized()
			velocity = jump_direction * current_move_speed * 2.0
			
			# FORCE STATE CHANGE
			current_state = WaWState.CHARGING
			state_timer = 0.0

func handle_player_slow_effect():
	"""Ralentización del jugador"""
	if not player or is_dead:
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	if distance_to_player <= slow_effect_range:
		if not is_slowing_player:
			is_slowing_player = true
			apply_slow_effect_to_player(true)
	else:
		if is_slowing_player:
			is_slowing_player = false
			apply_slow_effect_to_player(false)

func apply_slow_effect_to_player(apply: bool):
	if not player or not player.has_method("apply_zombie_slow"):
		return
	
	if apply:
		player.apply_zombie_slow(slow_effect_strength)
	else:
		player.remove_zombie_slow()

func start_waw_attack():
	"""Ataque World at War - INMEDIATO"""
	if not player or not can_attack():
		return
	
	if sprite:
		sprite.modulate = Color.ORANGE
		var prep_tween = create_tween()
		prep_tween.tween_property(sprite, "scale", sprite.scale * 1.15, 0.1)
	
	# ATAQUE INMEDIATO - SIN DELAY
	execute_waw_attack()

func execute_waw_attack():
	"""Ejecutar ataque World at War"""
	if not player or not is_instance_valid(player):
		finish_attack()
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	if distance_to_player <= attack_range:
		if player.has_method("take_damage"):
			player.take_damage(damage)
		
		# RALENTIZACIÓN FUERTE EN ATAQUE
		if player.has_method("apply_zombie_slow"):
			player.apply_zombie_slow(0.7)
			
			var slow_timer = Timer.new()
			slow_timer.wait_time = 0.8
			slow_timer.one_shot = true
			slow_timer.timeout.connect(func():
				if player and player.has_method("remove_zombie_slow"):
					player.remove_zombie_slow()
				slow_timer.queue_free()
			)
			add_child(slow_timer)
			slow_timer.start()
		
		create_attack_effect()
	
	finish_attack()

func create_attack_effect():
	for i in range(5):
		var particle = Sprite2D.new()
		var particle_image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
		particle_image.fill(Color.ORANGE)
		particle.texture = ImageTexture.create_from_image(particle_image)
		particle.global_position = global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		get_tree().current_scene.add_child(particle)
		
		var effect_tween = create_tween()
		effect_tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.5)
		effect_tween.parallel().tween_property(particle, "global_position", 
			particle.global_position + Vector2(randf_range(-25, 25), randf_range(-25, 25)), 0.5)
		effect_tween.tween_callback(func(): particle.queue_free())

func finish_attack():
	if sprite:
		sprite.modulate = Color.WHITE
		var restore_tween = create_tween()
		restore_tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)
	
	last_attack_time = Time.get_ticks_msec() / 1000.0

func can_attack() -> bool:
	var current_time = Time.get_ticks_msec() / 1000.0
	return current_time - last_attack_time >= attack_cooldown

func update_movement_animation():
	if not sprite or not (sprite is AnimatedSprite2D):
		return
	
	var animated_sprite = sprite as AnimatedSprite2D
	
	if current_state == WaWState.SPAWNING:
		if animated_sprite.animation != "idle":
			animated_sprite.play("idle")
		return
	
	if velocity.length() > 30.0:
		if animated_sprite.animation != "walk":
			animated_sprite.play("walk")
	else:
		if animated_sprite.animation != "idle":
			animated_sprite.play("idle")

func take_damage(amount: int, is_headshot: bool = false):
	if is_dead:
		return
	
	current_health -= amount
	current_health = max(current_health, 0)
	
	current_state = WaWState.STUNNED
	state_timer = 0.0
	
	if sprite:
		if is_headshot:
			sprite.modulate = Color.YELLOW
		else:
			sprite.modulate = Color.RED
		
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	
	update_health_bar()
	damaged.emit(self, amount)
	
	if current_health <= 0:
		die()

func die():
	if is_dead:
		return
	
	is_dead = true
	current_state = WaWState.SPAWNING  # Reset state
	
	if is_slowing_player:
		apply_slow_effect_to_player(false)
	
	call_deferred("_deactivate_collision")
	
	velocity = Vector2.ZERO
	set_physics_process(false)
	
	if sprite:
		sprite.modulate = Color.GRAY
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 1.0)
	
	if health_bar:
		health_bar.visible = false
	
	died.emit(self)

func update_health_bar():
	if not health_bar:
		return
	
	health_bar.value = current_health
	health_bar.max_value = max_health
	health_bar.visible = true

func reset_for_pool():
	is_dead = false
	current_state = WaWState.SPAWNING
	current_health = max_health
	is_slowing_player = false
	
	call_deferred("_deactivate_collision")
	
	if sprite:
		sprite.visible = true
	
	set_physics_process(false)
	set_process(false)

func _deactivate_collision():
	if collision_shape and is_instance_valid(collision_shape):
		collision_shape.disabled = true

func _on_attack_timer_timeout():
	pass

func get_current_health() -> int:
	return current_health

func get_max_health() -> int:
	return max_health

func is_alive() -> bool:
	return current_health > 0 and not is_dead

func get_damage() -> int:
	return damage

func get_enemy_type() -> String:
	return enemy_type

func _exit_tree():
	if is_slowing_player and player:
		apply_slow_effect_to_player(false)
	
	set_physics_process(false)
	set_process(false)
