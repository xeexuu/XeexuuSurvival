# scenes/enemies/ZombieDog.gd - PERROS ZOMBIES COD
extends BaseEnemy
class_name ZombieDog

# Estados específicos de perros
enum DogState {
	SPAWNING,
	HUNTING,
	STALKING,
	LUNGING,
	ATTACKING,
	STUNNED,
	DEAD
}

var dog_state: DogState = DogState.SPAWNING
var is_lunging: bool = false
var lunge_cooldown: float = 3.0
var last_lunge_time: float = 0.0
var lunge_force: float = 500.0
var circle_timer: float = 0.0
var circle_radius: float = 120.0

func _init():
	enemy_type = "zombie_dog"
	max_health = 80  # Menos vida
	current_health = 80
	base_move_speed = 200.0  # MUY RÁPIDOS
	damage = 40
	attack_range = 35.0
	detection_range = 900.0  # Detectan desde muy lejos
	attack_cooldown = 0.8  # Atacan muy rápido

func _ready():
	super._ready()
	current_move_speed = base_move_speed
	setup_dog_collision()

func setup_dog_collision():
	"""Configurar colisión más pequeña para perros"""
	if collision_shape:
		var shape = collision_shape.shape as RectangleShape2D
		if shape:
			shape.size = Vector2(32, 20)  # Más pequeño y alargado

func create_default_sprite():
	"""Crear sprite de perro zombie"""
	var image = Image.create(64, 48, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.3, 0.15, 0.1, 1.0))  # Marrón oscuro
	
	# Forma de perro (más alargada)
	for x in range(64):
		for y in range(48):
			var center_x = 32
			var center_y = 24
			var dist_x = abs(x - center_x)
			var dist_y = abs(y - center_y)
			
			# Cuerpo alargado
			if dist_x < 25 and dist_y < 15:
				image.set_pixel(x, y, Color(0.2, 0.1, 0.05, 1.0))
			elif dist_x < 30 and dist_y < 18:
				image.set_pixel(x, y, Color(0.15, 0.08, 0.03, 1.0))
	
	# Cabeza (parte delantera)
	for x in range(45, 64):
		for y in range(18, 30):
			image.set_pixel(x, y, Color(0.25, 0.12, 0.06, 1.0))
	
	# Ojos rojos brillantes
	add_dog_eyes(image)
	
	# Colmillos
	add_dog_fangs(image)
	
	var default_texture = ImageTexture.create_from_image(image)
	
	if sprite:
		if sprite is Sprite2D:
			var normal_sprite = sprite as Sprite2D
			normal_sprite.texture = default_texture
			normal_sprite.scale = Vector2(1.0, 1.0)

func add_dog_eyes(image: Image):
	"""Añadir ojos de perro zombie"""
	# Ojo izquierdo
	for x in range(52, 56):
		for y in range(20, 23):
			image.set_pixel(x, y, Color.RED)
	
	# Ojo derecho
	for x in range(52, 56):
		for y in range(25, 28):
			image.set_pixel(x, y, Color.RED)

func add_dog_fangs(image: Image):
	"""Añadir colmillos"""
	# Colmillos blancos
	for x in range(58, 62):
		for y in range(22, 26):
			if (x + y) % 2 == 0:  # Patrón para hacer colmillos
				image.set_pixel(x, y, Color.WHITE)

func update_state_machine(delta):
	"""Estados específicos del perro zombie"""
	state_timer += delta
	circle_timer += delta
	
	var distance_to_player = global_position.distance_to(player.global_position)
	var current_time = Time.get_ticks_msec() / 1000.0
	
	match dog_state:
		DogState.SPAWNING:
			if state_timer > 0.2:
				dog_state = DogState.HUNTING
				state_timer = 0.0
		
		DogState.HUNTING:
			if distance_to_player <= detection_range:
				dog_state = DogState.STALKING
				state_timer = 0.0
		
		DogState.STALKING:
			if distance_to_player <= 100 and current_time - last_lunge_time >= lunge_cooldown:
				dog_state = DogState.LUNGING
				state_timer = 0.0
				start_lunge()
			elif distance_to_player <= attack_range:
				dog_state = DogState.ATTACKING
				state_timer = 0.0
			elif distance_to_player > detection_range * 1.5:
				dog_state = DogState.HUNTING
				state_timer = 0.0
		
		DogState.LUNGING:
			if state_timer > 1.0 or distance_to_player <= attack_range:
				dog_state = DogState.ATTACKING
				state_timer = 0.0
				is_lunging = false
		
		DogState.ATTACKING:
			if distance_to_player > attack_range * 2:
				dog_state = DogState.STALKING
				state_timer = 0.0
		
		DogState.STUNNED:
			if state_timer > 0.3:
				dog_state = DogState.STALKING
				state_timer = 0.0

func handle_movement(delta):
	"""Movimiento específico del perro"""
	var movement_direction = Vector2.ZERO
	
	match dog_state:
		DogState.HUNTING:
			movement_direction = get_hunting_movement()
		
		DogState.STALKING:
			movement_direction = get_stalking_movement()
		
		DogState.LUNGING:
			movement_direction = get_lunge_movement()
		
		DogState.ATTACKING:
			movement_direction = get_attack_movement()
		
		DogState.STUNNED:
			movement_direction = velocity * 0.1
	
	if movement_direction != Vector2.ZERO:
		var speed_multiplier = 1.0
		if dog_state == DogState.LUNGING:
			speed_multiplier = 2.0  # Más rápido durante lunge
		
		velocity = movement_direction.normalized() * current_move_speed * speed_multiplier
	
	check_if_stuck(delta)

func get_hunting_movement() -> Vector2:
	"""Movimiento de caza - búsqueda del jugador"""
	if target_position.distance_to(global_position) < 50:
		var angle = randf() * TAU
		var distance = randf_range(100, 200)
		target_position = global_position + Vector2.from_angle(angle) * distance
	
	return (target_position - global_position).normalized() * 0.6

func get_stalking_movement() -> Vector2:
	"""Movimiento de acecho - rodear al jugador"""
	if not player:
		return Vector2.ZERO
	
	var direction_to_player = (player.global_position - global_position).normalized()
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Rodear al jugador manteniendo distancia
	if distance_to_player > circle_radius + 20:
		# Acercarse
		return direction_to_player * 0.8
	elif distance_to_player < circle_radius - 20:
		# Alejarse
		return -direction_to_player * 0.5
	else:
		# Circular alrededor del jugador
		var perpendicular = Vector2(-direction_to_player.y, direction_to_player.x)
		var circle_direction = sin(circle_timer * 2.0)
		return (perpendicular * circle_direction + direction_to_player * 0.2).normalized()

func get_lunge_movement() -> Vector2:
	"""Movimiento durante el salto/lunge"""
	if not player:
		return Vector2.ZERO
	
	return (player.global_position - global_position).normalized()

func get_attack_movement() -> Vector2:
	"""Movimiento durante ataque"""
	if not player:
		return Vector2.ZERO
	
	var direction_to_player = (player.global_position - global_position).normalized()
	var distance_to_player = global_position.distance_to(player.global_position)
	
	if distance_to_player < 25:
		return Vector2.ZERO  # Parar si está muy cerca
	
	return direction_to_player

func start_lunge():
	"""Iniciar salto hacia el jugador"""
	is_lunging = true
	last_lunge_time = Time.get_ticks_msec() / 1000.0
	
	if player:
		var lunge_direction = (player.global_position - global_position).normalized()
		velocity += lunge_direction * lunge_force
	
	# Efecto visual de lunge
	if sprite:
		sprite.modulate = Color.CYAN
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.5)

func check_if_stuck(delta):
	"""Verificar si está atascado"""
	if global_position.distance_to(last_position) < 8.0:
		stuck_timer += delta
		
		if stuck_timer > 1.0:
			var random_direction = Vector2.from_angle(randf() * TAU)
			velocity += random_direction * current_move_speed
			stuck_timer = 0.0
	else:
		stuck_timer = 0.0
		last_position = global_position

func perform_attack():
	"""Ataque específico del perro"""
	super.perform_attack()
	
	# Los perros hacen knockback más ligero pero más frecuente
	if player and player.has_method("apply_knockback"):
		var knockback_direction = (player.global_position - global_position).normalized()
		player.apply_knockback(knockback_direction, 100.0)

func take_damage(amount: int, is_headshot: bool = false):
	"""Los perros entran en estado stunned al recibir daño"""
	super.take_damage(amount, is_headshot)
	
	if current_health > 0:
		dog_state = DogState.STUNNED
		state_timer = 0.0

func setup_health_bar():
	"""Barra de vida más pequeña para perros"""
	super.setup_health_bar()
	
	if health_bar:
		health_bar.size = Vector2(40, 6)
		health_bar.position = Vector2(-20, -35)
		
		var style_fill = StyleBoxFlat.new()
		style_fill.bg_color = Color.ORANGE  # Color distintivo para perros
		health_bar.add_theme_stylebox_override("fill", style_fill)
