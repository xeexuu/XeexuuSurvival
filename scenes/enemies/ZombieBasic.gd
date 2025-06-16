# scenes/enemies/ZombieBasic.gd - ZOMBIE BÁSICO
extends BaseEnemy
class_name ZombieBasic

func _init():
	enemy_type = "zombie_basic"
	max_health = 150
	current_health = 150
	base_move_speed = 120.0
	damage = 50
	attack_range = 45.0
	detection_range = 600.0
	attack_cooldown = 2.0

func _ready():
	super._ready()
	current_move_speed = base_move_speed
	determine_zombie_variant()

func determine_zombie_variant():
	"""Determinar si es zombie corredor"""
	# 30% probabilidad de ser corredor
	if randf() < 0.3:
		current_move_speed = base_move_speed * randf_range(1.8, 2.5)
		max_health = int(max_health * 0.8)  # Menos vida pero más rápido
		current_health = max_health
		modulate = Color(1.2, 0.8, 0.8, 1.0)  # Tinte rojizo

func create_default_sprite():
	"""Crear sprite de zombie básico"""
	var image = Image.create(96, 96, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.4, 0.2, 0.2, 1.0))  # Marrón rojizo
	
	# Forma humanoide básica
	for x in range(96):
		for y in range(96):
			var dist = Vector2(x - 48, y - 48).length()
			if dist < 15:
				image.set_pixel(x, y, Color.BLACK)  # Centro oscuro
			elif dist < 25:
				image.set_pixel(x, y, Color.DARK_RED)
	
	# Ojos rojos
	add_glowing_eyes(image, Vector2(35, 35), Vector2(61, 35))
	
	var default_texture = ImageTexture.create_from_image(image)
	
	if sprite:
		if sprite is Sprite2D:
			var normal_sprite = sprite as Sprite2D
			normal_sprite.texture = default_texture
			normal_sprite.scale = Vector2(0.75, 0.75)

func add_glowing_eyes(image: Image, eye1_pos: Vector2, eye2_pos: Vector2):
	"""Añadir ojos brillantes"""
	var eye_positions = [eye1_pos, eye2_pos]
	
	for eye_pos in eye_positions:
		for x in range(eye_pos.x - 3, eye_pos.x + 3):
			for y in range(eye_pos.y - 2, eye_pos.y + 2):
				if x >= 0 and x < 96 and y >= 0 and y < 96:
					image.set_pixel(x, y, Color.RED)

func update_state_machine(delta):
	"""Estados específicos del zombie básico"""
	state_timer += delta
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	match current_state:
		EnemyState.SPAWNING:
			if state_timer > 0.3:
				current_state = EnemyState.IDLE
				state_timer = 0.0
		
		EnemyState.IDLE:
			if distance_to_player <= detection_range:
				current_state = EnemyState.PURSUING
				state_timer = 0.0
		
		EnemyState.PURSUING:
			if distance_to_player <= attack_range:
				current_state = EnemyState.ATTACKING
				state_timer = 0.0
			elif distance_to_player > detection_range * 1.3:
				current_state = EnemyState.IDLE
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
	"""Movimiento agresivo del zombie"""
	var movement_direction = Vector2.ZERO
	
	match current_state:
		EnemyState.IDLE:
			movement_direction = get_wander_movement()
		
		EnemyState.PURSUING, EnemyState.ATTACKING:
			movement_direction = get_aggressive_pursuit()
		
		EnemyState.STUNNED:
			movement_direction = velocity * 0.2
	
	if movement_direction != Vector2.ZERO:
		velocity = movement_direction.normalized() * current_move_speed
	
	check_if_stuck(delta)

func get_aggressive_pursuit() -> Vector2:
	"""Persecución agresiva directa"""
	if not player:
		return Vector2.ZERO
	
	var direction_to_player = (player.global_position - global_position).normalized()
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Mantener distancia mínima
	if distance_to_player < 30.0:
		return direction_to_player * 0.3
	
	return direction_to_player

func get_wander_movement() -> Vector2:
	"""Movimiento de deambulación"""
	if target_position.distance_to(global_position) < 40:
		var angle = randf() * TAU
		var distance = randf_range(80, 150)
		target_position = global_position + Vector2.from_angle(angle) * distance
	
	return (target_position - global_position).normalized() * 0.5

func check_if_stuck(delta):
	"""Verificar si está atascado"""
	if global_position.distance_to(last_position) < 10.0:
		stuck_timer += delta
		
		if stuck_timer > 1.5:
			var random_direction = Vector2.from_angle(randf() * TAU)
			velocity += random_direction * current_move_speed * 0.8
			stuck_timer = 0.0
	else:
		stuck_timer = 0.0
		last_position = global_position

func perform_attack():
	"""Ataque específico del zombie básico"""
	super.perform_attack()
	
	# Knockback al jugador
	if player and player.has_method("apply_knockback"):
		var knockback_direction = (player.global_position - global_position).normalized()
		player.apply_knockback(knockback_direction, 150.0)
