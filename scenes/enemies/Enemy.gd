# scenes/enemies/Enemy.gd - CON ANIMACIÓN DE SPAWN Y MOVIMIENTO
extends CharacterBody2D
class_name Enemy

signal died(enemy: Enemy)
signal damaged(enemy: Enemy, damage: int)

@export var enemy_type: String = "zombie_basic"
@export var max_health: int = 150
@export var current_health: int = 150
@export var base_move_speed: float = 120.0
@export var damage: int = 50
@export var attack_range: float = 45.0
@export var detection_range: float = 800.0  # Más grande para detectar mejor
@export var attack_cooldown: float = 2.0

@onready var sprite = $Sprite2D
@onready var collision_shape = $CollisionShape2D
@onready var attack_timer = $AttackTimer
@onready var health_bar = $HealthBar

var player: Player = null
var is_dead: bool = false
var last_attack_time: float = 0.0
var current_move_speed: float = 120.0

# Estados con spawn animado
enum EnemyState {
	SPAWNING,
	EMERGING,     # Saliendo del suelo
	WANDERING,
	PURSUING,
	ATTACKING,
	STUNNED,
	DEAD
}

var current_state: EnemyState = EnemyState.SPAWNING
var state_timer: float = 0.0

# Variables de movimiento mejoradas
var target_position: Vector2
var stuck_timer: float = 0.0
var last_position: Vector2
var path_update_timer: float = 0.0

# Variantes de enemigos
var is_runner: bool = false
var speed_multiplier: float = 1.0

# Spawn animation
var spawn_scale: float = 0.0
var spawn_alpha: float = 0.0

# Animación de movimiento
var enemy_sprite_frames: SpriteFrames

func _ready():
	setup_enemy()
	setup_attack_system()
	determine_enemy_variant()

func setup_enemy():
	"""Configurar enemigo base"""
	current_health = max_health
	is_dead = false
	current_state = EnemyState.SPAWNING
	
	collision_layer = 2
	collision_mask = 1 | 3
	
	last_position = global_position
	target_position = global_position
	
	# INICIAR INVISIBLE PARA ANIMACIÓN DE SPAWN
	modulate = Color(1, 1, 1, 0)
	scale = Vector2.ZERO
	
	load_enemy_sprite()
	setup_health_bar()
	
	if attack_timer:
		attack_timer.wait_time = attack_cooldown
		attack_timer.one_shot = true
		attack_timer.timeout.connect(_on_attack_timer_timeout)

func determine_enemy_variant():
	"""Determinar variante según el tipo"""
	match enemy_type:
		"zombie_basic":
			# 30% probabilidad de corredor
			if randf() < 0.3:
				is_runner = true
				speed_multiplier = randf_range(1.8, 2.5)
				max_health = int(max_health * 0.8)
				current_health = max_health
				modulate = Color(1.2, 0.8, 0.8, modulate.a)
			else:
				speed_multiplier = randf_range(1.2, 1.6)
		
		"zombie_dog":
			speed_multiplier = 2.0
			max_health = int(max_health * 0.6)
			current_health = max_health
			attack_cooldown = 0.8
			attack_range = 35.0
			modulate = Color(0.8, 0.6, 0.4, modulate.a)
		
		"zombie_crawler":
			speed_multiplier = 0.8
			max_health = int(max_health * 0.4)
			current_health = max_health
			attack_cooldown = 1.2
			attack_range = 25.0
			modulate = Color(0.6, 0.8, 0.6, modulate.a)
	
	current_move_speed = base_move_speed * speed_multiplier

func load_enemy_sprite():
	"""Cargar sprite del zombie con animación"""
	var atlas_path = "res://sprites/enemies/zombie/walk_Right_Down.png"
	var atlas_texture = try_load_texture_safe(atlas_path)
	
	if atlas_texture:
		setup_animated_sprite_with_movement(atlas_texture)
	else:
		create_default_enemy_sprite()

func setup_animated_sprite_with_movement(atlas_texture: Texture2D):
	"""Configurar AnimatedSprite2D con movimiento desde atlas"""
	# Reemplazar Sprite2D con AnimatedSprite2D
	if sprite and sprite is Sprite2D:
		sprite.queue_free()
		var animated_sprite = AnimatedSprite2D.new()
		animated_sprite.name = "AnimatedSprite2D"
		add_child(animated_sprite)
		sprite = animated_sprite
	elif not sprite:
		var animated_sprite = AnimatedSprite2D.new()
		animated_sprite.name = "AnimatedSprite2D"
		add_child(animated_sprite)
		sprite = animated_sprite
	
	if sprite is AnimatedSprite2D:
		var animated_sprite = sprite as AnimatedSprite2D
		enemy_sprite_frames = SpriteFrames.new()
		
		# Crear animación de movimiento
		enemy_sprite_frames.add_animation("walk")
		enemy_sprite_frames.set_animation_speed("walk", 8.0)
		enemy_sprite_frames.set_animation_loop("walk", true)
		
		# Extraer todos los frames del atlas
		for i in range(8):
			var frame = extract_frame_from_zombie_atlas(atlas_texture, i)
			enemy_sprite_frames.add_frame("walk", frame)
		
		# Crear animación idle (primer frame)
		enemy_sprite_frames.add_animation("idle")
		enemy_sprite_frames.set_animation_speed("idle", 2.0)
		enemy_sprite_frames.set_animation_loop("idle", true)
		var first_frame = extract_frame_from_zombie_atlas(atlas_texture, 0)
		enemy_sprite_frames.add_frame("idle", first_frame)
		
		animated_sprite.sprite_frames = enemy_sprite_frames
		animated_sprite.play("idle")
		scale_zombie_sprite(animated_sprite, first_frame)

func extract_frame_from_zombie_atlas(atlas_texture: Texture2D, frame_index: int) -> Texture2D:
	"""Extraer frame del atlas de zombie 1024x128"""
	var frame_width = 128.0  # Cada frame es 128x128
	var x_offset = float(frame_index) * frame_width
	
	var atlas_frame = AtlasTexture.new()
	atlas_frame.atlas = atlas_texture
	atlas_frame.region = Rect2(x_offset, 0, frame_width, 128.0)
	
	return atlas_frame

func scale_zombie_sprite(animated_sprite: AnimatedSprite2D, reference_texture: Texture2D):
	"""Escalar sprite de zombie a tamaño apropiado"""
	if not reference_texture:
		animated_sprite.scale = Vector2(0.75, 0.75)
		return
	
	var current_height = reference_texture.get_size().y
	var target_height = 96.0
	
	var scale_factor = target_height / float(current_height)
	animated_sprite.scale = Vector2(scale_factor, scale_factor)

func create_default_enemy_sprite():
	"""Crear sprite por defecto si no hay atlas"""
	var image = Image.create(96, 96, false, Image.FORMAT_RGBA8)
	
	var base_color = Color.DARK_RED
	match enemy_type:
		"zombie_dog":
			base_color = Color(0.6, 0.3, 0.1, 1.0)
		"zombie_crawler":
			base_color = Color(0.4, 0.6, 0.2, 1.0)
	
	image.fill(base_color)
	
	# Forma básica
	for x in range(96):
		for y in range(96):
			var dist = Vector2(x - 48, y - 48).length()
			if dist < 15:
				image.set_pixel(x, y, Color.BLACK)
			elif dist < 25:
				image.set_pixel(x, y, base_color.darkened(0.3))
	
	# Ojos rojos
	add_glowing_eyes(image)
	
	var default_texture = ImageTexture.create_from_image(image)
	
	if sprite:
		if sprite is Sprite2D:
			var normal_sprite = sprite as Sprite2D
			normal_sprite.texture = default_texture
			normal_sprite.scale = Vector2(0.75, 0.75)

func add_glowing_eyes(image: Image):
	"""Añadir ojos brillantes"""
	var eye_positions = [Vector2(35, 35), Vector2(61, 35)]
	
	for eye_pos in eye_positions:
		for x in range(eye_pos.x - 3, eye_pos.x + 3):
			for y in range(eye_pos.y - 2, eye_pos.y + 2):
				if x >= 0 and x < 96 and y >= 0 and y < 96:
					image.set_pixel(x, y, Color.RED)

func try_load_texture_safe(path: String) -> Texture2D:
	"""Cargar textura de forma segura"""
	if not ResourceLoader.exists(path):
		return null
	
	var resource = load(path)
	if resource is Texture2D:
		return resource as Texture2D
	return null

func setup_health_bar():
	"""Configurar barra de vida VISIBLE"""
	if not health_bar:
		health_bar = ProgressBar.new()
		health_bar.size = Vector2(60, 8)
		health_bar.position = Vector2(-30, -50)
		add_child(health_bar)
	
	health_bar.max_value = max_health
	health_bar.value = current_health
	health_bar.show_percentage = false
	health_bar.visible = true  # ASEGURAR QUE SEA VISIBLE
	
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color.BLACK
	health_bar.add_theme_stylebox_override("background", style_bg)
	
	var style_fill = StyleBoxFlat.new()
	style_fill.bg_color = Color.RED
	health_bar.add_theme_stylebox_override("fill", style_fill)

func setup_attack_system():
	"""Configurar sistema de ataque"""
	pass

func setup_for_spawn(target_player: Player, round_health: int = -1):
	"""Configurar para spawn con animación"""
	player = target_player
	
	if round_health > 0:
		max_health = round_health
		# Ajustar según tipo
		match enemy_type:
			"zombie_dog":
				max_health = int(max_health * 0.6)
			"zombie_crawler":
				max_health = int(max_health * 0.4)
		
		if is_runner:
			max_health = int(max_health * 0.8)
	
	current_health = max_health
	is_dead = false
	current_state = EnemyState.SPAWNING
	
	# INICIAR ANIMACIÓN DE SPAWN
	modulate = Color(1, 1, 1, 0)
	scale = Vector2.ZERO
	spawn_scale = 0.0
	spawn_alpha = 0.0
	
	call_deferred("_reactivate_collision")
	
	if sprite:
		sprite.visible = true
	
	update_health_bar()
	start_spawn_animation()

func start_spawn_animation():
	"""Iniciar animación de emergencia del suelo"""
	current_state = EnemyState.SPAWNING
	
	var spawn_tween = create_tween()
	spawn_tween.set_parallel(true)
	
	# Escala: de 0 a 1 en 0.8 segundos
	spawn_tween.tween_method(set_spawn_scale, 0.0, 1.0, 0.8)
	
	# Alpha: de 0 a 1 en 0.6 segundos
	spawn_tween.tween_method(set_spawn_alpha, 0.0, 1.0, 0.6)
	
	# Al terminar, cambiar a estado emergente
	spawn_tween.tween_callback(func(): 
		current_state = EnemyState.EMERGING
		state_timer = 0.0
	)

func set_spawn_scale(value: float):
	"""Establecer escala durante spawn"""
	spawn_scale = value
	var base_scale = Vector2(0.75, 0.75)  # Escala base del zombie
	scale = base_scale * spawn_scale

func set_spawn_alpha(value: float):
	"""Establecer alpha durante spawn"""
	spawn_alpha = value
	var current_color = modulate
	current_color.a = spawn_alpha
	modulate = current_color

func _reactivate_collision():
	"""Reactivar colisión después del spawn"""
	if collision_shape and is_instance_valid(collision_shape):
		collision_shape.disabled = false

func reset_for_pool():
	"""Reset para pool"""
	is_dead = false
	current_state = EnemyState.SPAWNING
	current_health = max_health
	
	call_deferred("_deactivate_collision")
	
	if sprite:
		sprite.visible = false
	
	set_physics_process(false)
	set_process(false)

func _deactivate_collision():
	"""Desactivar colisión"""
	if collision_shape and is_instance_valid(collision_shape):
		collision_shape.disabled = true

func _physics_process(delta):
	if is_dead or not player or not is_instance_valid(player):
		return
	
	update_state_machine(delta)
	handle_movement(delta)
	handle_combat()
	update_movement_animation()
	
	move_and_slide()

func update_state_machine(delta):
	"""Máquina de estados con spawn mejorado"""
	state_timer += delta
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	match current_state:
		EnemyState.SPAWNING:
			# Se maneja en start_spawn_animation()
			pass
		
		EnemyState.EMERGING:
			if state_timer > 0.5:  # Tiempo adicional emergiendo
				current_state = EnemyState.WANDERING
				state_timer = 0.0
		
		EnemyState.WANDERING:
			if distance_to_player <= detection_range:
				current_state = EnemyState.PURSUING
				state_timer = 0.0
		
		EnemyState.PURSUING:
			if distance_to_player <= attack_range:
				current_state = EnemyState.ATTACKING
				state_timer = 0.0
			elif distance_to_player > detection_range * 1.5:
				current_state = EnemyState.WANDERING
				state_timer = 0.0
		
		EnemyState.ATTACKING:
			if distance_to_player > attack_range * 1.5:
				current_state = EnemyState.PURSUING
				state_timer = 0.0
		
		EnemyState.STUNNED:
			if state_timer > 0.4:
				current_state = EnemyState.PURSUING
				state_timer = 0.0

func handle_movement(delta):
	"""Manejo de movimiento mejorado"""
	var movement_direction = Vector2.ZERO
	
	match current_state:
		EnemyState.SPAWNING, EnemyState.EMERGING:
			movement_direction = Vector2.ZERO  # No moverse durante spawn
		
		EnemyState.WANDERING:
			movement_direction = get_wander_movement()
		
		EnemyState.PURSUING, EnemyState.ATTACKING:
			movement_direction = get_improved_pursuit_direction()
		
		EnemyState.STUNNED:
			movement_direction = velocity * 0.2
	
	if movement_direction != Vector2.ZERO:
		velocity = movement_direction.normalized() * current_move_speed
	
	check_if_stuck(delta)

func get_wander_movement() -> Vector2:
	"""Movimiento de deambulación"""
	path_update_timer += get_physics_process_delta_time()
	
	if target_position.distance_to(global_position) < 40 or path_update_timer > 2.0:
		# Actualizar target hacia el jugador pero con randomización
		if player:
			var direction_to_player = (player.global_position - global_position).normalized()
			var random_angle = randf_range(-PI/3, PI/3)  # ±60 grados
			var wandering_direction = direction_to_player.rotated(random_angle)
			target_position = global_position + wandering_direction * randf_range(100, 200)
		else:
			var angle = randf() * TAU
			target_position = global_position + Vector2.from_angle(angle) * randf_range(80, 150)
		
		path_update_timer = 0.0
	
	return (target_position - global_position).normalized() * 0.6

func get_improved_pursuit_direction() -> Vector2:
	"""Persecución mejorada y directa"""
	if not player:
		return Vector2.ZERO
	
	var direction_to_player = (player.global_position - global_position).normalized()
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Distancia mínima para evitar apilamiento
	if distance_to_player < 30.0:
		return direction_to_player * 0.3
	
	return direction_to_player

func update_movement_animation():
	"""Actualizar animación según movimiento"""
	if not sprite or not (sprite is AnimatedSprite2D):
		return
	
	var animated_sprite = sprite as AnimatedSprite2D
	
	# Solo animar si no está en spawn
	if current_state == EnemyState.SPAWNING or current_state == EnemyState.EMERGING:
		if animated_sprite.animation != "idle":
			animated_sprite.play("idle")
		return
	
	# Cambiar entre idle y walk según velocidad
	if velocity.length() > 20.0:
		if animated_sprite.animation != "walk":
			animated_sprite.play("walk")
	else:
		if animated_sprite.animation != "idle":
			animated_sprite.play("idle")

func check_if_stuck(delta):
	"""Verificar si está atascado"""
	if global_position.distance_to(last_position) < 10.0:
		stuck_timer += delta
		
		if stuck_timer > 1.5:
			var random_direction = Vector2.from_angle(randf() * TAU)
			velocity += random_direction * current_move_speed * 0.8
			stuck_timer = 0.0
			# Forzar nuevo target
			path_update_timer = 999.0
	else:
		stuck_timer = 0.0
		last_position = global_position

func handle_combat():
	"""Manejo de combate"""
	if not player or current_state != EnemyState.ATTACKING:
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	if distance_to_player <= attack_range and can_attack():
		perform_attack()

func can_attack() -> bool:
	"""Verificar si puede atacar"""
	var current_time = Time.get_ticks_msec() / 1000.0
	return current_time - last_attack_time >= attack_cooldown

func perform_attack():
	"""Realizar ataque"""
	if not player or not player.has_method("take_damage"):
		return
	
	last_attack_time = Time.get_ticks_msec() / 1000.0
	
	player.take_damage(damage)
	
	if sprite:
		sprite.modulate = Color.ORANGE_RED
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)

func _on_attack_timer_timeout():
	"""Timeout del timer de ataque"""
	pass

func take_damage(amount: int, is_headshot: bool = false):
	"""Recibir daño"""
	if is_dead:
		return
	
	current_health -= amount
	current_health = max(current_health, 0)
	
	current_state = EnemyState.STUNNED
	state_timer = 0.0
	
	if sprite:
		if is_headshot:
			sprite.modulate = Color.YELLOW
		else:
			sprite.modulate = Color.RED
		
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	
	update_health_bar()
	damaged.emit(self, amount)
	
	if current_health <= 0:
		die()

func die():
	"""Muerte del enemigo"""
	if is_dead:
		return
	
	is_dead = true
	current_state = EnemyState.DEAD
	
	call_deferred("_deactivate_collision")
	
	velocity = Vector2.ZERO
	set_physics_process(false)
	
	if sprite:
		sprite.modulate = Color.GRAY
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 1.5)
	
	if health_bar:
		health_bar.visible = false
	
	died.emit(self)

func update_health_bar():
	"""Actualizar barra de vida"""
	if not health_bar:
		return
	
	health_bar.value = current_health
	health_bar.max_value = max_health
	health_bar.visible = true  # ASEGURAR VISIBILIDAD

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
	"""Limpiar al salir"""
	set_physics_process(false)
	set_process(false)
