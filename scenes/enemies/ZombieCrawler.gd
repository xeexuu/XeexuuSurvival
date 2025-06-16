# scenes/enemies/ZombieCrawler.gd - CABEZONES PEQUEÑOS (CRAWLERS) DE KINO DER TOTEN
extends BaseEnemy
class_name ZombieCrawler

# Estados específicos de crawlers
enum CrawlerState {
	SPAWNING,
	CRAWLING,
	SWARMING,
	LEAPING,
	ATTACKING,
	STUNNED,
	DEAD
}

var crawler_state: CrawlerState = CrawlerState.SPAWNING
var is_leaping: bool = false
var leap_cooldown: float = 4.0
var last_leap_time: float = 0.0
var leap_force: float = 300.0
var swarm_radius: float = 80.0
var leap_range: float = 150.0

func _init():
	enemy_type = "zombie_crawler"
	max_health = 50  # Muy poca vida
	current_health = 50
	base_move_speed = 100.0  # Lentos normalmente
	damage = 30  # Menos daño
	attack_range = 25.0  # Rango corto
	detection_range = 700.0  # Pero detectan bien
	attack_cooldown = 1.2

func _ready():
	super._ready()
	current_move_speed = base_move_speed
	setup_crawler_collision()

func setup_crawler_collision():
	"""Configurar colisión muy pequeña para crawlers"""
	if collision_shape:
		var shape = collision_shape.shape as RectangleShape2D
		if shape:
			shape.size = Vector2(24, 16)  # Muy pequeños

func create_default_sprite():
	"""Crear sprite de crawler (cabezón pequeño)"""
	var image = Image.create(48, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.6, 0.3, 0.2, 1.0))  # Marrón claro
	
	# Cabeza grande desproporcionada
	var head_center_x = 36  # Cabeza en la parte delantera
	var head_center_y = 16
	
	for x in range(48):
		for y in range(32):
			var dist_to_head = Vector2(x - head_center_x, y - head_center_y).length()
			var dist_to_body = Vector2(x - 16, y - 16).length()
			
			# Cabeza grande
			if dist_to_head < 14:
				if dist_to_head < 8:
					image.set_pixel(x, y, Color(0.8, 0.4, 0.3, 1.0))  # Centro de cabeza
				else:
					image.set_pixel(x, y, Color(0.6, 0.3, 0.2, 1.0))
			# Cuerpo pequeño
			elif dist_to_body < 8:
				image.set_pixel(x, y, Color(0.4, 0.2, 0.1, 1.0))
	
	# Ojos grandes y perturbadores
	add_crawler_eyes(image)
	
	# Boca con dientes
	add_crawler_mouth(image)
	
	var default_texture = ImageTexture.create_from_image(image)
	
	if sprite:
		if sprite is Sprite2D:
			var normal_sprite = sprite as Sprite2D
			normal_sprite.texture = default_texture
			normal_sprite.scale = Vector2(1.2, 1.2)  # Un poco más grande para verse

func add_crawler_eyes(image: Image):
	"""Ojos grandes y perturbadores"""
	# Ojo izquierdo (más grande)
	for x in range(32, 38):
		for y in range(12, 17):
			image.set_pixel(x, y, Color.RED)
	
	# Ojo derecho (más grande)
	for x in range(32, 38):
		for y in range(19, 24):
			image.set_pixel(x, y, Color.RED)
	
	# Pupilas negras
	for x in range(34, 36):
		for y in range(14, 16):
			image.set_pixel(x, y, Color.BLACK)
	
	for x in range(34, 36):
		for y in range(21, 23):
			image.set_pixel(x, y, Color.BLACK)

func add_crawler_mouth(image: Image):
	"""Boca con dientes pequeños"""
	# Boca
	for x in range(40, 46):
		for y in range(15, 19):
			image.set_pixel(x, y, Color.BLACK)
	
	# Dientes pequeños
	for x in range(41, 45):
		if x % 2 == 0:
			for y in range(16, 18):
				image.set_pixel(x, y, Color.WHITE)

func update_state_machine(delta):
	"""Estados específicos del crawler"""
	state_timer += delta
	
	var distance_to_player = global_position.distance_to(player.global_position)
	var current_time = Time.get_ticks_msec() / 1000.0
	
	match crawler_state:
		CrawlerState.SPAWNING:
			if state_timer > 0.2:
				crawler_state = CrawlerState.CRAWLING
				state_timer = 0.0
		
		CrawlerState.CRAWLING:
			if distance_to_player <= detection_range:
				crawler_state = CrawlerState.SWARMING
				state_timer = 0.0
		
		CrawlerState.SWARMING:
			if distance_to_player <= leap_range and current_time - last_leap_time >= leap_cooldown:
				crawler_state = CrawlerState.LEAPING
				state_timer = 0.0
				start_leap()
			elif distance_to_player <= attack_range:
				crawler_state = CrawlerState.ATTACKING
				state_timer = 0.0
			elif distance_to_player > detection_range * 1.4:
				crawler_state = CrawlerState.CRAWLING
				state_timer = 0.0
		
		CrawlerState.LEAPING:
			if state_timer > 1.5 or distance_to_player <= attack_range:
				crawler_state = CrawlerState.ATTACKING
				state_timer = 0.0
				is_leaping = false
		
		CrawlerState.ATTACKING:
			if distance_to_player > attack_range * 2:
				crawler_state = CrawlerState.SWARMING
				state_timer = 0.0
		
		CrawlerState.STUNNED:
			if state_timer > 0.5:  # Se aturden más tiempo
				crawler_state = CrawlerState.SWARMING
				state_timer = 0.0

func handle_movement(delta):
	"""Movimiento específico del crawler"""
	var movement_direction = Vector2.ZERO
	
	match crawler_state:
		CrawlerState.CRAWLING:
			movement_direction = get_crawling_movement()
		
		CrawlerState.SWARMING:
			movement_direction = get_swarming_movement()
		
		CrawlerState.LEAPING:
			movement_direction = get_leap_movement()
		
		CrawlerState.ATTACKING:
			movement_direction = get_attack_movement()
		
		CrawlerState.STUNNED:
			movement_direction = velocity * 0.05  # Se mueven muy poco cuando stunned
	
	if movement_direction != Vector2.ZERO:
		var speed_multiplier = 1.0
		if crawler_state == CrawlerState.LEAPING:
			speed_multiplier = 2.5  # Muy rápidos durante salto
		elif crawler_state == CrawlerState.SWARMING:
			speed_multiplier = 1.3  # Un poco más rápidos cuando se acercan
		
		velocity = movement_direction.normalized() * current_move_speed * speed_multiplier
	
	check_if_stuck(delta)

func get_crawling_movement() -> Vector2:
	"""Movimiento de arrastre lento"""
	if target_position.distance_to(global_position) < 30:
		var angle = randf() * TAU
		var distance = randf_range(60, 120)
		target_position = global_position + Vector2.from_angle(angle) * distance
	
	return (target_position - global_position).normalized() * 0.4

func get_swarming_movement() -> Vector2:
	"""Movimiento de enjambre hacia el jugador"""
	if not player:
		return Vector2.ZERO
	
	var direction_to_player = (player.global_position - global_position).normalized()
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Buscar otros crawlers cercanos para formar enjambre
	var swarm_direction = Vector2.ZERO
	var nearby_crawlers = find_nearby_crawlers()
	
	if nearby_crawlers.size() > 0:
		# Moverse hacia el centro del enjambre
		var swarm_center = Vector2.ZERO
		for crawler in nearby_crawlers:
			swarm_center += crawler.global_position
		swarm_center /= nearby_crawlers.size()
		
		var direction_to_swarm = (swarm_center - global_position).normalized()
		swarm_direction = direction_to_swarm * 0.3
	
	# Combinar dirección al jugador con comportamiento de enjambre
	if distance_to_player > swarm_radius:
		return (direction_to_player * 0.7 + swarm_direction * 0.3).normalized()
	else:
		return direction_to_player

func get_leap_movement() -> Vector2:
	"""Movimiento durante salto"""
	if not player:
		return Vector2.ZERO
	
	return (player.global_position - global_position).normalized()

func get_attack_movement() -> Vector2:
	"""Movimiento durante ataque"""
	if not player:
		return Vector2.ZERO
	
	var direction_to_player = (player.global_position - global_position).normalized()
	var distance_to_player = global_position.distance_to(player.global_position)
	
	if distance_to_player < 15:
		return Vector2.ZERO  # Parar si está muy cerca
	
	return direction_to_player

func find_nearby_crawlers() -> Array:
	"""Encontrar otros crawlers cercanos para formar enjambre"""
	var nearby = []
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = swarm_radius
	query.shape = circle_shape
	query.transform = Transform2D(0, global_position)
	query.collision_mask = 2  # Capa de enemigos
	query.exclude = [self]
	
	var results = space_state.intersect_shape(query, 5)
	
	for result in results:
		var other_enemy = result.collider
		if other_enemy and other_enemy.has_method("get_enemy_type"):
			if other_enemy.get_enemy_type() == "zombie_crawler":
				nearby.append(other_enemy)
	
	return nearby

func start_leap():
	"""Iniciar salto hacia el jugador"""
	is_leaping = true
	last_leap_time = Time.get_ticks_msec() / 1000.0
	
	if player:
		var leap_direction = (player.global_position - global_position).normalized()
		velocity += leap_direction * leap_force
	
	# Efecto visual de salto
	if sprite:
		sprite.modulate = Color.YELLOW
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.8)

func check_if_stuck(delta):
	"""Verificar si está atascado"""
	if global_position.distance_to(last_position) < 5.0:
		stuck_timer += delta
		
		if stuck_timer > 2.0:  # Más tiempo porque son lentos
			var random_direction = Vector2.from_angle(randf() * TAU)
			velocity += random_direction * current_move_speed * 1.5
			stuck_timer = 0.0
	else:
		stuck_timer = 0.0
		last_position = global_position

func perform_attack():
	"""Ataque específico del crawler"""
	super.perform_attack()
	
	# Los crawlers hacen menos knockback pero intentan "agarrarse"
	if player and player.has_method("apply_knockback"):
		var knockback_direction = (player.global_position - global_position).normalized()
		player.apply_knockback(knockback_direction, 50.0)  # Knockback ligero

func take_damage(amount: int, is_headshot: bool = false):
	"""Los crawlers son más vulnerables a headshots"""
	var final_damage = amount
	if is_headshot:
		final_damage = int(amount * 2.0)  # Doble daño por headshot
	
	super.take_damage(final_damage, is_headshot)
	
	if current_health > 0:
		crawler_state = CrawlerState.STUNNED
		state_timer = 0.0

func setup_health_bar():
	"""Barra de vida muy pequeña para crawlers"""
	super.setup_health_bar()
	
	if health_bar:
		health_bar.size = Vector2(30, 4)
		health_bar.position = Vector2(-15, -25)
		
		var style_fill = StyleBoxFlat.new()
		style_fill.bg_color = Color.YELLOW  # Color distintivo para crawlers
		health_bar.add_theme_stylebox_override("fill", style_fill)

func setup_for_spawn(target_player: Player, round_health: int = -1):
	"""Configurar para spawn con vida ajustada"""
	super.setup_for_spawn(target_player, round_health)
	
	# Los crawlers tienen menos vida base pero escalan menos con las rondas
	if round_health > 0:
		max_health = int(round_health * 0.4)  # Solo 40% de la vida de zombies normales
		current_health = max_health
