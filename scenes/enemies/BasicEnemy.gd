# scenes/enemies/BasicEnemy.gd - SISTEMA COD ZOMBIES HARDCORE
extends CharacterBody2D
class_name Enemy

signal died(enemy: Enemy)
signal damaged(enemy: Enemy, damage: int)

@export var max_health: int = 150
@export var current_health: int = 150
@export var base_move_speed: float = 120.0  # Velocidad base más rápida
@export var damage: int = 50
@export var attack_range: float = 45.0
@export var detection_range: float = 800.0

@onready var sprite = $Sprite2D
@onready var collision_shape = $CollisionShape2D
@onready var attack_timer = $AttackTimer
@onready var health_bar = $HealthBar

var player: Player = null
var is_dead: bool = false
var last_attack_time: float = 0.0
var attack_cooldown: float = 1.5  # Ataque más frecuente

# Variables de velocidad dinámica
var current_move_speed: float = 120.0
var speed_multiplier: float = 1.0
var is_runner: bool = false

# Estados del enemigo COD Zombies
enum ZombieState {
	SPAWNING,
	WANDERING,
	PURSUING,
	ATTACKING,
	STUNNED,
	DEAD
}

var current_state: ZombieState = ZombieState.SPAWNING
var state_timer: float = 0.0

# Pathfinding agresivo
var target_position: Vector2
var stuck_timer: float = 0.0
var last_position: Vector2
var path_update_timer: float = 0.0

# Separación entre zombies
var separation_radius: float = 50.0
var min_player_distance: float = 30.0

# Sprites y animación
var enemy_sprite_frames: SpriteFrames
var is_sprite_loaded: bool = false

func _ready():
	setup_zombie()
	setup_attack_system()
	determine_zombie_type()

func determine_zombie_type():
	"""Determinar tipo de zombie según la ronda"""
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	var current_round = 1
	
	if game_manager and game_manager.has_method("get_current_round"):
		current_round = game_manager.get_current_round()
	
	# 30% de probabilidad de zombie corredor desde la ronda 1
	if randf() < 0.3:
		is_runner = true
		speed_multiplier = randf_range(1.8, 2.5)  # Corredores muy rápidos
		current_move_speed = base_move_speed * speed_multiplier
		
		# Runners tienen menos vida pero son más rápidos
		max_health = int(max_health * 0.7)
		current_health = max_health
		
		# Cambiar color para diferenciar
		modulate = Color(1.2, 0.8, 0.8, 1.0)
	else:
		# Zombies normales también más rápidos que antes
		speed_multiplier = randf_range(1.2, 1.6)
		current_move_speed = base_move_speed * speed_multiplier

func setup_zombie():
	"""Configurar zombie inicial"""
	current_health = max_health
	is_dead = false
	current_state = ZombieState.SPAWNING
	
	collision_layer = 2
	collision_mask = 1 | 3  # Jugador y paredes
	
	last_position = global_position
	target_position = global_position
	
	if not is_sprite_loaded:
		load_zombie_sprite()
	
	setup_health_bar()
	
	if attack_timer:
		attack_timer.wait_time = attack_cooldown
		attack_timer.one_shot = true
		attack_timer.timeout.connect(_on_attack_timer_timeout)
	
	# Transición rápida a wandering
	await get_tree().create_timer(0.2).timeout
	if current_state == ZombieState.SPAWNING:
		current_state = ZombieState.WANDERING

func load_zombie_sprite():
	"""Cargar sprite del zombie"""
	var atlas_path = "res://sprites/enemies/zombie/walk_Right_Down.png"
	var atlas_texture = try_load_texture_safe(atlas_path)
	
	if atlas_texture:
		enemy_sprite_frames = SpriteFrames.new()
		enemy_sprite_frames.add_animation("idle")
		enemy_sprite_frames.set_animation_speed("idle", 2.0)
		enemy_sprite_frames.set_animation_loop("idle", true)
		
		var first_frame = extract_first_frame_from_atlas(atlas_texture)
		if first_frame:
			enemy_sprite_frames.add_frame("idle", first_frame)
			
			# Configurar sprite como AnimatedSprite2D
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
				animated_sprite.sprite_frames = enemy_sprite_frames
				animated_sprite.play("idle")
				scale_sprite_to_96px(animated_sprite, first_frame)
				is_sprite_loaded = true
	else:
		create_default_zombie_sprite()

func extract_first_frame_from_atlas(atlas_texture: Texture2D) -> Texture2D:
	"""Extraer primer frame del atlas"""
	var texture_size = atlas_texture.get_size()
	var frame_width = float(texture_size.x) / 8.0
	var frame_height = float(texture_size.y)
	
	var first_frame = AtlasTexture.new()
	first_frame.atlas = atlas_texture
	first_frame.region = Rect2(0, 0, frame_width, frame_height)
	
	return first_frame

func scale_sprite_to_96px(animated_sprite: AnimatedSprite2D, reference_texture: Texture2D):
	"""Escalar sprite a 96px"""
	if not reference_texture:
		animated_sprite.scale = Vector2(0.75, 0.75)  # Zombies más pequeños
		return
	
	var current_height = reference_texture.get_size().y
	var target_height = 96.0
	
	var scale_factor = target_height / float(current_height)
	animated_sprite.scale = Vector2(scale_factor, scale_factor)

func create_default_zombie_sprite():
	"""Crear sprite por defecto"""
	var image = Image.create(96, 96, false, Image.FORMAT_RGBA8)
	
	if is_runner:
		image.fill(Color.DARK_RED)
	else:
		image.fill(Color(0.4, 0.2, 0.2, 1.0))
	
	# Hacer más aterrador
	for x in range(96):
		for y in range(96):
			var dist = Vector2(x - 48, y - 48).length()
			if dist < 15:
				image.set_pixel(x, y, Color.BLACK)
			elif dist < 25:
				if is_runner:
					image.set_pixel(x, y, Color.RED)
				else:
					image.set_pixel(x, y, Color.DARK_RED)
	
	# Ojos rojos brillantes
	add_glowing_eyes(image)
	
	var default_texture = ImageTexture.create_from_image(image)
	
	if sprite:
		if sprite is Sprite2D:
			var normal_sprite = sprite as Sprite2D
			normal_sprite.texture = default_texture
			normal_sprite.scale = Vector2(0.75, 0.75)
		elif sprite is AnimatedSprite2D:
			var basic_frames = SpriteFrames.new()
			basic_frames.add_animation("idle")
			basic_frames.add_frame("idle", default_texture)
			
			var animated_sprite = sprite as AnimatedSprite2D
			animated_sprite.sprite_frames = basic_frames
			animated_sprite.play("idle")
			animated_sprite.scale = Vector2(0.75, 0.75)

func add_glowing_eyes(image: Image):
	"""Añadir ojos rojos brillantes"""
	var eye_positions = [
		Vector2(30, 35),  # Ojo izquierdo
		Vector2(66, 35)   # Ojo derecho
	]
	
	for eye_pos in eye_positions:
		for x in range(eye_pos.x - 4, eye_pos.x + 4):
			for y in range(eye_pos.y - 3, eye_pos.y + 3):
				if x >= 0 and x < 96 and y >= 0 and y < 96:
					image.set_pixel(x, y, Color.RED)

func try_load_texture_safe(path: String) -> Texture2D:
	"""Cargar textura de forma segura"""
	if not ResourceLoader.exists(path):
		return null
	
	var resource = load(path)
	if resource is Texture2D:
		return resource as Texture2D
	else:
		return null

func setup_health_bar():
	"""Configurar barra de vida"""
	if not health_bar:
		health_bar = ProgressBar.new()
		health_bar.size = Vector2(60, 8)
		health_bar.position = Vector2(-30, -50)
		add_child(health_bar)
	
	health_bar.max_value = max_health
	health_bar.value = current_health
	health_bar.show_percentage = false
	
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color.BLACK
	health_bar.add_theme_stylebox_override("background", style_bg)
	
	var style_fill = StyleBoxFlat.new()
	if is_runner:
		style_fill.bg_color = Color.ORANGE
	else:
		style_fill.bg_color = Color.RED
	health_bar.add_theme_stylebox_override("fill", style_fill)

func setup_attack_system():
	"""Configurar sistema de ataque"""
	var damage_cooldown_timer = Timer.new()
	damage_cooldown_timer.name = "DamageCooldownTimer"
	damage_cooldown_timer.wait_time = attack_cooldown
	damage_cooldown_timer.one_shot = true
	add_child(damage_cooldown_timer)

func setup_for_spawn(target_player: Player, round_health: int = -1):
	"""Configurar para spawn"""
	player = target_player
	
	if round_health > 0:
		max_health = round_health
		if is_runner:
			max_health = int(max_health * 0.7)  # Runners tienen menos vida
	
	current_health = max_health
	is_dead = false
	current_state = ZombieState.SPAWNING
	
	call_deferred("_reactivate_collision")
	
	if sprite:
		sprite.visible = true
	
	update_health_bar()
	determine_zombie_type()

func _reactivate_collision():
	"""Reactivar colisión"""
	if collision_shape and is_instance_valid(collision_shape):
		collision_shape.disabled = false

func reset_for_pool():
	"""Reset para pool"""
	is_dead = false
	current_state = ZombieState.SPAWNING
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
	
	move_and_slide()

func update_state_machine(delta):
	"""Máquina de estados agresiva"""
	state_timer += delta
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	match current_state:
		ZombieState.SPAWNING:
			if state_timer > 0.2:
				current_state = ZombieState.WANDERING
				state_timer = 0.0
		
		ZombieState.WANDERING:
			if distance_to_player <= detection_range:
				current_state = ZombieState.PURSUING
				state_timer = 0.0
		
		ZombieState.PURSUING:
			if distance_to_player <= attack_range:
				current_state = ZombieState.ATTACKING
				state_timer = 0.0
			elif distance_to_player > detection_range * 1.2:
				current_state = ZombieState.WANDERING
				state_timer = 0.0
		
		ZombieState.ATTACKING:
			if distance_to_player > attack_range * 1.5:
				current_state = ZombieState.PURSUING
				state_timer = 0.0
		
		ZombieState.STUNNED:
			if state_timer > 0.3:
				current_state = ZombieState.PURSUING
				state_timer = 0.0

func handle_movement(delta):
	"""Movimiento agresivo hacia el jugador"""
	var movement_direction = Vector2.ZERO
	
	match current_state:
		ZombieState.WANDERING:
			movement_direction = get_wander_movement()
		
		ZombieState.PURSUING, ZombieState.ATTACKING:
			movement_direction = get_aggressive_pursuit()
		
		ZombieState.STUNNED:
			movement_direction = velocity * 0.1  # Reducir velocidad gradualmente
		
		ZombieState.SPAWNING, ZombieState.DEAD:
			movement_direction = Vector2.ZERO
	
	# Aplicar separación entre zombies
	apply_zombie_separation()
	
	# Aplicar velocidad con boost si es runner
	var final_speed = current_move_speed
	if current_state == ZombieState.PURSUING and is_runner:
		final_speed *= 1.3  # Boost adicional al perseguir
	
	if movement_direction != Vector2.ZERO:
		velocity = movement_direction.normalized() * final_speed
	
	# Detectar si está atascado
	check_if_stuck(delta)

func get_aggressive_pursuit() -> Vector2:
	"""Persecución agresiva directa al jugador"""
	if not player:
		return Vector2.ZERO
	
	var direction_to_player = (player.global_position - global_position).normalized()
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Si está muy cerca, mantener distancia mínima
	if distance_to_player < min_player_distance:
		return direction_to_player * 0.3
	
	return direction_to_player

func get_wander_movement() -> Vector2:
	"""Movimiento de deambulación"""
	if target_position.distance_to(global_position) < 30:
		# Buscar nueva posición aleatoria
		var angle = randf() * TAU
		var distance = randf_range(100, 200)
		target_position = global_position + Vector2.from_angle(angle) * distance
	
	return (target_position - global_position).normalized() * 0.4

func apply_zombie_separation():
	"""Separación entre zombies mejorada"""
	var separation_force = Vector2.ZERO
	var nearby_enemies = 0
	
	# Buscar zombies cercanos
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = separation_radius
	query.shape = circle_shape
	query.transform = Transform2D(0, global_position)
	query.collision_mask = 2
	query.exclude = [self]
	
	var results = space_state.intersect_shape(query, 8)
	
	for result in results:
		var other_enemy = result.collider as Enemy
		if other_enemy and other_enemy != self and not other_enemy.is_dead:
			var separation_vector = global_position - other_enemy.global_position
			var distance = separation_vector.length()
			
			if distance > 0 and distance < separation_radius:
				var force_magnitude = (separation_radius - distance) / separation_radius
				separation_force += separation_vector.normalized() * force_magnitude
				nearby_enemies += 1
	
	if nearby_enemies > 0:
		velocity += separation_force.normalized() * 40.0

func check_if_stuck(delta):
	"""Verificar si está atascado y aplicar corrección"""
	var movement_threshold = 5.0
	
	if global_position.distance_to(last_position) < movement_threshold:
		stuck_timer += delta
		
		if stuck_timer > 1.0:  # Atascado por 1 segundo
			# Aplicar empujón aleatorio
			var random_direction = Vector2.from_angle(randf() * TAU)
			velocity += random_direction * current_move_speed * 0.5
			stuck_timer = 0.0
	else:
		stuck_timer = 0.0
		last_position = global_position

func handle_combat():
	"""Sistema de combate agresivo"""
	if not player or current_state != ZombieState.ATTACKING:
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	if distance_to_player <= attack_range and can_attack():
		perform_attack()

func can_attack() -> bool:
	"""Verificar si puede atacar"""
	var current_time = Time.get_ticks_msec() / 1000.0
	return current_time - last_attack_time >= attack_cooldown

func perform_attack():
	"""Realizar ataque al jugador"""
	if not player or not player.has_method("take_damage"):
		return
	
	last_attack_time = Time.get_ticks_msec() / 1000.0
	
	# Aplicar daño
	var final_damage = damage
	if is_runner:
		final_damage = int(damage * 0.8)  # Runners hacen un poco menos daño
	
	player.take_damage(final_damage)
	
	# Efecto visual de ataque
	if sprite:
		sprite.modulate = Color.YELLOW
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)
	
	# Aplicar knockback al jugador
	if player.has_method("apply_knockback"):
		var knockback_direction = (player.global_position - global_position).normalized()
		var knockback_force = 200.0 if is_runner else 150.0
		player.apply_knockback(knockback_direction, knockback_force)

func _on_attack_timer_timeout():
	"""Timeout del timer de ataque"""
	pass  # Ya no necesario con el nuevo sistema

func take_damage(amount: int, is_headshot: bool = false):
	"""Recibir daño"""
	if is_dead:
		return
	
	current_health -= amount
	current_health = max(current_health, 0)
	
	# Stun breve
	current_state = ZombieState.STUNNED
	state_timer = 0.0
	
	# Efecto visual
	if is_headshot and sprite:
		sprite.modulate = Color.YELLOW
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	elif sprite:
		sprite.modulate = Color.RED
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	
	update_health_bar()
	damaged.emit(self, amount)
	
	if current_health <= 0:
		die()

func die():
	"""Muerte del zombie"""
	if is_dead:
		return
	
	is_dead = true
	current_state = ZombieState.DEAD
	
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
	
	var health_percentage = float(current_health) / float(max_health)
	var style_fill = StyleBoxFlat.new()
	
	if health_percentage > 0.6:
		style_fill.bg_color = Color.GREEN
	elif health_percentage > 0.3:
		style_fill.bg_color = Color.YELLOW
	else:
		style_fill.bg_color = Color.RED
	
	health_bar.add_theme_stylebox_override("fill", style_fill)

# Funciones de información
func get_current_health() -> int:
	return current_health

func get_max_health() -> int:
	return max_health

func is_alive() -> bool:
	return current_health > 0 and not is_dead

func get_damage() -> int:
	return damage

func is_in_range_of_player() -> bool:
	if not player:
		return false
	return global_position.distance_to(player.global_position) <= detection_range

func is_in_attack_range() -> bool:
	if not player:
		return false
	return global_position.distance_to(player.global_position) <= attack_range

func _exit_tree():
	"""Limpiar al salir"""
	set_physics_process(false)
	set_process(false)
