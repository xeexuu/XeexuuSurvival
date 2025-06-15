# scenes/enemies/BasicEnemy.gd - SISTEMA DE ATAQUE ESTILO COD BLACK OPS 1 ZOMBIES COMPLETO
extends CharacterBody2D
class_name Enemy

signal died(enemy: Enemy)
signal damaged(enemy: Enemy, damage: int)

@export var max_health: int = 150
@export var current_health: int = 150
@export var move_speed: float = 80.0  # Más rápido como BO1
@export var damage: int = 50  # Más daño como BO1
@export var attack_range: float = 60.0  # Rango de ataque más amplio
@export var detection_range: float = 600.0

@onready var sprite = $Sprite2D
@onready var collision_shape = $CollisionShape2D
@onready var attack_timer = $AttackTimer
@onready var health_bar = $HealthBar

var player: Player = null
var is_dead: bool = false
var is_attacking: bool = false
var last_attack_time: float = 0.0
var attack_cooldown: float = 2.0  # Ataque cada 2 segundos como BO1

# Control de proximidad al jugador 
var proximity_distance: float = 45.0  # Distancia para empezar a atacar
var min_distance: float = 25.0  # Distancia mínima al jugador
var max_distance: float = 80.0  # Distancia máxima de persecución

# Variables para prevenir spam de ataques
var can_damage_player: bool = true
var damage_cooldown: float = 2.5  # Cooldown entre ataques exitosos

# Variables para sprites
var enemy_sprite_frames: SpriteFrames
var enemy_type: String = "zombie"
var is_sprite_loaded: bool = false

# Estados del enemigo estilo COD BO1
enum EnemyState {
	SPAWN,      # Apareciendo
	IDLE,       # Esperando
	CHASING,    # Persiguiendo
	GRABBING,   # Agarrando al jugador
	ATTACKING,  # Atacando
	STUNNED,    # Aturdido por daño
	DEAD        # Muerto
}

var current_state: EnemyState = EnemyState.SPAWN
var original_color: Color = Color.WHITE

# PATHFINDING COD BO1
var aggression_level: float = 1.0
var last_player_position: Vector2
var search_timer: float = 0.0
var stuck_timer: float = 0.0
var last_position: Vector2
var wander_target: Vector2

# Sistema de agarre estilo COD BO1
var grab_duration: float = 3.0
var grab_timer: float = 0.0
var is_grabbing: bool = false

# Separación entre enemigos
var separation_radius: float = 70.0

# Zona de headshot
var head_area: Area2D

func _ready():
	setup_enemy()
	setup_head_collision()
	setup_attack_system()

func setup_head_collision():
	"""Configurar área de colisión para headshots"""
	head_area = Area2D.new()
	head_area.name = "HeadArea"
	head_area.collision_layer = 0
	head_area.collision_mask = 4  # Solo balas
	
	var head_shape = CollisionShape2D.new()
	var head_circle = CircleShape2D.new()
	head_circle.radius = 25.0
	head_shape.shape = head_circle
	head_shape.position = Vector2(0, -35)
	
	head_area.add_child(head_shape)
	add_child(head_area)
	
	head_area.area_entered.connect(_on_head_area_entered)

func _on_head_area_entered(area):
	"""Cuando una bala entra en el área de la cabeza - HEADSHOT"""
	if is_dead:
		return
		
	if area.is_in_group("bullets") or area.name.contains("Bullet"):
		var bullet = area as Bullet
		if bullet and bullet.damage > 0:
			var headshot_damage = int(float(bullet.damage) * bullet.headshot_multiplier)
			take_damage(headshot_damage, true)
			
			if bullet.knockback_force > 0:
				var knockback_direction = (global_position - bullet.global_position).normalized()
				apply_knockback(knockback_direction, bullet.knockback_force)

func setup_attack_system():
	"""Configurar sistema de ataque estilo COD BO1"""
	var damage_cooldown_timer = Timer.new()
	damage_cooldown_timer.name = "DamageCooldownTimer"
	damage_cooldown_timer.wait_time = damage_cooldown
	damage_cooldown_timer.one_shot = true
	damage_cooldown_timer.timeout.connect(_on_damage_cooldown_finished)
	add_child(damage_cooldown_timer)

func _on_damage_cooldown_finished():
	"""Cuando termina el cooldown de daño"""
	can_damage_player = true
	is_grabbing = false
	grab_timer = 0.0

func setup_enemy():
	"""Configurar el enemigo inicial"""
	current_health = max_health
	is_dead = false
	is_attacking = false
	is_grabbing = false
	current_state = EnemyState.SPAWN
	damage = 50
	can_damage_player = true
	
	last_position = global_position
	wander_target = global_position + Vector2(randf_range(-200, 200), randf_range(-200, 200))
	
	# CONFIGURAR CAPAS DE COLISIÓN CORRECTAS
	collision_layer = 2
	collision_mask = 1 | 3  # Jugador y paredes
	
	if not is_sprite_loaded:
		load_enemy_sprite_from_atlas()
	
	if not has_valid_sprite():
		create_default_enemy_sprite()
	
	setup_health_bar()
	
	if attack_timer:
		attack_timer.wait_time = attack_cooldown
		attack_timer.one_shot = true
		attack_timer.timeout.connect(_on_attack_timer_timeout)
	
	# Transición a IDLE después de spawn
	await get_tree().create_timer(0.5).timeout
	if current_state == EnemyState.SPAWN:
		current_state = EnemyState.IDLE

func has_valid_sprite() -> bool:
	"""Verificar si el sprite es válido"""
	if sprite is AnimatedSprite2D:
		var animated_sprite = sprite as AnimatedSprite2D
		return animated_sprite.sprite_frames != null
	elif sprite is Sprite2D:
		var normal_sprite = sprite as Sprite2D
		return normal_sprite.texture != null
	return false

func load_enemy_sprite_from_atlas():
	"""Cargar sprite del enemigo desde atlas"""
	var atlas_path = "res://sprites/enemies/" + enemy_type + "/walk_Right_Down.png"
	var atlas_texture = try_load_texture_safe(atlas_path)
	
	if atlas_texture:
		enemy_sprite_frames = SpriteFrames.new()
		
		enemy_sprite_frames.add_animation("idle")
		enemy_sprite_frames.set_animation_speed("idle", 2.0)
		enemy_sprite_frames.set_animation_loop("idle", true)
		
		var first_frame = extract_first_frame_from_atlas(atlas_texture)
		if first_frame:
			enemy_sprite_frames.add_frame("idle", first_frame)
			
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
				
				enemy_sprite_frames.add_animation("walk")
				enemy_sprite_frames.set_animation_speed("walk", 8.0)
				enemy_sprite_frames.set_animation_loop("walk", true)
				
				load_frames_from_atlas(enemy_sprite_frames, "walk", atlas_texture, 8, 1)
				
				animated_sprite.play("idle")
				scale_sprite_to_128px(animated_sprite, first_frame)
				
				is_sprite_loaded = true

func extract_first_frame_from_atlas(atlas_texture: Texture2D) -> Texture2D:
	"""Extraer el primer frame de un atlas"""
	var texture_size = atlas_texture.get_size()
	var frame_width = float(texture_size.x) / 8.0
	var frame_height = float(texture_size.y)
	
	var first_frame = AtlasTexture.new()
	first_frame.atlas = atlas_texture
	first_frame.region = Rect2(0, 0, frame_width, frame_height)
	
	return first_frame

func load_frames_from_atlas(sprite_frames: SpriteFrames, anim_name: String, atlas_texture: Texture2D, h_frames: int, v_frames: int):
	"""Cargar frames desde un atlas"""
	var texture_size = atlas_texture.get_size()
	var frame_width = float(texture_size.x) / float(h_frames)
	var frame_height = float(texture_size.y) / float(v_frames)
	
	for i in range(h_frames * v_frames):
		var x = float(i % h_frames) * frame_width
		var y = (i / h_frames) * frame_height
		
		var atlas_frame = AtlasTexture.new()
		atlas_frame.atlas = atlas_texture
		atlas_frame.region = Rect2(x, y, frame_width, frame_height)
		
		sprite_frames.add_frame(anim_name, atlas_frame)

func scale_sprite_to_128px(animated_sprite: AnimatedSprite2D, reference_texture: Texture2D):
	"""Escalar sprite a 128px de alto"""
	if not reference_texture:
		animated_sprite.scale = Vector2(1.0, 1.0)
		return
	
	var current_height = reference_texture.get_size().y
	var target_height = 128.0
	
	var scale_factor = target_height / float(current_height)
	animated_sprite.scale = Vector2(scale_factor, scale_factor)

func create_default_enemy_sprite():
	"""Crear sprite por defecto del enemigo"""
	var image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	image.fill(Color.DARK_RED)
	
	for x in range(128):
		for y in range(128):
			var dist = Vector2(x - 64, y - 64).length()
			if dist < 20:
				image.set_pixel(x, y, Color.DARK_RED.darkened(0.3))
			elif dist < 30:
				image.set_pixel(x, y, Color.RED.darkened(0.2))
	
	# Ojos rojos
	var eye_size = 8
	for x in range(64 - 15, 64 - 15 + eye_size):
		for y in range(64 - 15, 64 - 15 + eye_size):
			if x >= 0 and x < 128 and y >= 0 and y < 128:
				image.set_pixel(x, y, Color.RED)
	
	for x in range(64 + 7, 64 + 7 + eye_size):
		for y in range(64 - 15, 64 - 15 + eye_size):
			if x >= 0 and x < 128 and y >= 0 and y < 128:
				image.set_pixel(x, y, Color.RED)
	
	var default_texture = ImageTexture.create_from_image(image)
	
	if sprite:
		if sprite is Sprite2D:
			var normal_sprite = sprite as Sprite2D
			normal_sprite.texture = default_texture
			normal_sprite.scale = Vector2(1.0, 1.0)
		elif sprite is AnimatedSprite2D:
			var basic_frames = SpriteFrames.new()
			basic_frames.add_animation("idle")
			basic_frames.add_frame("idle", default_texture)
			
			var animated_sprite = sprite as AnimatedSprite2D
			animated_sprite.sprite_frames = basic_frames
			animated_sprite.play("idle")
			animated_sprite.scale = Vector2(1.0, 1.0)
	
	original_color = Color.WHITE

func try_load_texture_safe(path: String) -> Texture2D:
	"""Función para cargar texturas de forma segura"""
	if not ResourceLoader.exists(path):
		return null
	
	var resource = load(path)
	if resource is Texture2D:
		return resource as Texture2D
	else:
		return null

func set_enemy_type(new_type: String):
	"""Cambiar el tipo de enemigo"""
	enemy_type = new_type
	is_sprite_loaded = false
	load_enemy_sprite_from_atlas()

func setup_health_bar():
	"""Configurar la barra de vida"""
	if not health_bar:
		health_bar = ProgressBar.new()
		health_bar.size = Vector2(80, 10)
		health_bar.position = Vector2(-40, -70)
		add_child(health_bar)
	
	health_bar.max_value = max_health
	health_bar.value = current_health
	health_bar.show_percentage = false
	
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color.BLACK
	style_bg.border_width_left = 1
	style_bg.border_width_right = 1
	style_bg.border_width_top = 1
	style_bg.border_width_bottom = 1
	style_bg.border_color = Color.WHITE
	health_bar.add_theme_stylebox_override("background", style_bg)
	
	var style_fill = StyleBoxFlat.new()
	style_fill.bg_color = Color.RED
	health_bar.add_theme_stylebox_override("fill", style_fill)

func setup_for_spawn(target_player: Player, round_health: int = -1):
	"""Configurar el enemigo cuando es spawneado"""
	player = target_player
	
	if round_health > 0:
		max_health = round_health
	
	current_health = max_health
	is_dead = false
	is_attacking = false
	is_grabbing = false
	current_state = EnemyState.SPAWN
	damage = 50
	can_damage_player = true
	grab_timer = 0.0
	
	aggression_level = randf_range(0.8, 1.2)
	search_timer = 0.0
	stuck_timer = 0.0
	
	call_deferred("_reactivate_collision")
	
	if sprite:
		sprite.modulate = original_color
		sprite.visible = true
	
	update_health_bar()

func _reactivate_collision():
	"""Reactivar colisión de forma segura"""
	if collision_shape and is_instance_valid(collision_shape):
		collision_shape.disabled = false

func reset_for_pool():
	"""Resetear enemigo para el pool"""
	is_dead = false
	is_attacking = false
	is_grabbing = false
	current_state = EnemyState.SPAWN
	current_health = max_health
	damage = 50
	can_damage_player = true
	grab_timer = 0.0
	
	call_deferred("_deactivate_collision")
	
	if sprite:
		sprite.modulate = original_color
		sprite.visible = false
	
	set_physics_process(false)
	set_process(false)

func _deactivate_collision():
	"""Desactivar colisión de forma segura"""
	if collision_shape and is_instance_valid(collision_shape):
		collision_shape.disabled = true

func _on_attack_timer_timeout():
	"""Cuando termina el cooldown de ataque"""
	is_attacking = false

func apply_knockback(direction: Vector2, force: float):
	"""Aplicar knockback al enemigo"""
	if direction.length() > 0:
		velocity += direction.normalized() * force

func take_damage(amount: int, is_headshot: bool = false):
	"""Recibir daño"""
	if is_dead:
		return
	
	current_health -= amount
	current_health = max(current_health, 0)
	
	current_state = EnemyState.STUNNED
	var stun_timer = Timer.new()
	stun_timer.wait_time = 0.2  # Stun más corto
	stun_timer.one_shot = true
	stun_timer.timeout.connect(func(): 
		if current_state == EnemyState.STUNNED:
			current_state = EnemyState.CHASING
		stun_timer.queue_free()
	)
	add_child(stun_timer)
	stun_timer.start()
	
	aggression_level += 0.1
	aggression_level = min(aggression_level, 2.0)
	
	if is_headshot:
		flash_headshot_effect()
	else:
		flash_damage_effect()
	
	update_health_bar()
	damaged.emit(self, amount)
	
	if current_health <= 0:
		die()

func flash_damage_effect():
	"""Efecto visual al recibir daño normal"""
	if sprite:
		sprite.modulate = Color.WHITE
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", original_color, 0.2)

func flash_headshot_effect():
	"""Efecto visual especial para headshots"""
	if sprite:
		sprite.modulate = Color.YELLOW
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
		tween.tween_property(sprite, "modulate", original_color, 0.1)

func die():
	"""Manejar la muerte del enemigo"""
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
		tween.tween_property(sprite, "modulate:a", 0.3, 1.0)
	
	if health_bar:
		health_bar.visible = false
	
	died.emit(self)
	
	if player and player.has_method("on_enemy_killed"):
		player.on_enemy_killed()

func update_health_bar():
	"""Actualizar la barra de vida"""
	if health_bar:
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

func _physics_process(delta):
	if is_dead or not player or not is_instance_valid(player):
		return
	
	update_timers(delta)
	update_state_cod_bo1()
	handle_movement_cod_bo1(delta)
	handle_combat_cod_bo1(delta)

func update_timers(delta):
	"""Actualizar timers del comportamiento"""
	search_timer += delta
	
	if global_position.distance_to(last_position) < 10.0:
		stuck_timer += delta
	else:
		stuck_timer = 0.0
		last_position = global_position
	
	# Timer de agarre
	if is_grabbing:
		grab_timer += delta

func update_state_cod_bo1():
	"""Actualizar estado estilo COD Black Ops 1"""
	if is_dead:
		current_state = EnemyState.DEAD
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Detectar jugador
	if distance_to_player <= detection_range:
		last_player_position = player.global_position
		search_timer = 0.0
	
	# Determinar estado según distancia
	match current_state:
		EnemyState.SPAWN:
			# Ya manejado en setup
			pass
		EnemyState.IDLE:
			if distance_to_player <= detection_range:
				current_state = EnemyState.CHASING
		EnemyState.CHASING:
			if distance_to_player <= proximity_distance:
				current_state = EnemyState.GRABBING
			elif distance_to_player > detection_range and search_timer > 8.0:
				current_state = EnemyState.IDLE
		EnemyState.GRABBING:
			if distance_to_player > max_distance:
				current_state = EnemyState.CHASING
			elif grab_timer >= grab_duration:
				current_state = EnemyState.ATTACKING
		EnemyState.ATTACKING:
			if not is_attacking:
				current_state = EnemyState.CHASING
		EnemyState.STUNNED:
			# Se maneja en take_damage
			pass

func handle_movement_cod_bo1(delta):
	"""Manejo de movimiento estilo COD Black Ops 1"""
	var movement_direction = Vector2.ZERO
	
	match current_state:
		EnemyState.SPAWN, EnemyState.IDLE:
			movement_direction = get_wander_movement()
		EnemyState.CHASING:
			movement_direction = get_chase_movement()
		EnemyState.GRABBING:
			movement_direction = get_grab_movement()
		EnemyState.ATTACKING:
			movement_direction = Vector2.ZERO  # No moverse durante ataque
		EnemyState.STUNNED:
			movement_direction = velocity.move_toward(Vector2.ZERO, move_speed * delta * 3)
		EnemyState.DEAD:
			movement_direction = Vector2.ZERO
	
	# Aplicar separación entre enemigos
	apply_enemy_separation()
	
	if movement_direction != Vector2.ZERO:
		velocity = movement_direction.normalized() * move_speed
	else:
		velocity = Vector2.ZERO
	
	move_and_slide()

func get_chase_movement() -> Vector2:
	"""Obtener movimiento de persecución"""
	if not player:
		return Vector2.ZERO
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Mantener distancia óptima
	if distance_to_player < min_distance:
		# Muy cerca - alejarse un poco
		return (global_position - player.global_position).normalized() * 0.5
	elif distance_to_player > proximity_distance:
		# Lejos - acercarse
		return (player.global_position - global_position).normalized()
	else:
		# Distancia óptima - rodear al jugador
		var direction_to_player = (player.global_position - global_position).normalized()
		var perpendicular = Vector2(-direction_to_player.y, direction_to_player.x)
		return (direction_to_player * 0.3 + perpendicular * 0.7).normalized()

func get_grab_movement() -> Vector2:
	"""Obtener movimiento durante agarre"""
	if not player:
		return Vector2.ZERO
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	if distance_to_player > proximity_distance + 10:
		# Acercarse para mantener el agarre
		return (player.global_position - global_position).normalized()
	else:
		# Mantener posición de agarre
		return Vector2.ZERO

func get_wander_movement() -> Vector2:
	"""Comportamiento de deambulación"""
	var to_wander_target = wander_target - global_position
	
	if to_wander_target.length() < 50.0:
		wander_target = global_position + Vector2(randf_range(-300, 300), randf_range(-300, 300))
	else:
		return to_wander_target.normalized() * 0.4
	
	return Vector2.ZERO

func apply_enemy_separation():
	"""Aplicar separación entre enemigos"""
	var separation_force = Vector2.ZERO
	var nearby_count = 0
	
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = separation_radius
	query.shape = circle_shape
	query.transform = Transform2D(0, global_position)
	query.collision_mask = 2
	query.exclude = [self]
	
	var results = space_state.intersect_shape(query, 5)
	
	for result in results:
		var other_enemy = result.collider as Enemy
		if other_enemy and other_enemy != self and not other_enemy.is_dead:
			var separation_vector = global_position - other_enemy.global_position
			var distance = separation_vector.length()
			
			if distance > 0 and distance < separation_radius:
				var force_magnitude = (separation_radius - distance) / separation_radius
				separation_force += separation_vector.normalized() * force_magnitude
				nearby_count += 1
	
	if nearby_count > 0:
		velocity += separation_force.normalized() * 30.0

func handle_combat_cod_bo1(delta):
	"""Manejo de combate estilo COD Black Ops 1"""
	if not player or is_dead:
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Sistema de agarre estilo COD BO1
	if current_state == EnemyState.GRABBING and not is_grabbing:
		if distance_to_player <= proximity_distance:
			start_grab_attack()
	
	# Sistema de ataque después del agarre
	if current_state == EnemyState.ATTACKING and can_damage_player:
		if distance_to_player <= attack_range:
			perform_cod_bo1_attack()

func start_grab_attack():
	"""Iniciar agarre estilo COD BO1"""
	if is_grabbing or not can_damage_player:
		return
	
	is_grabbing = true
	grab_timer = 0.0
	
	# Efecto visual de agarre
	if sprite:
		sprite.modulate = Color.PURPLE
		var color_tween = create_tween()
		color_tween.tween_property(sprite, "modulate", Color.WHITE, 0.5)
	
	# Aplicar efecto de ralentización al jugador
	if player and player.has_method("apply_grab_effect"):
		player.apply_grab_effect(grab_duration)
	
	# Crear efecto visual
	create_grab_effect()

func perform_cod_bo1_attack():
	"""Realizar ataque estilo COD Black Ops 1"""
	if not player or not can_damage_player or is_attacking:
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)	
	if distance_to_player > attack_range:
		return
	
	is_attacking = true
	can_damage_player = false
	last_attack_time = Time.get_ticks_msec() / 1000.0
	
	# Efecto visual de ataque
	if sprite:
		sprite.modulate = Color.ORANGE_RED
		var color_tween = create_tween()
		color_tween.tween_property(sprite, "modulate", original_color, 0.5)
	
	# APLICAR DAÑO AL JUGADOR
	if player.has_method("take_damage"):
		player.take_damage(damage)
	
	# Aplicar knockback fuerte estilo BO1
	if player and player.has_method("apply_knockback"):
		var push_direction = (player.global_position - global_position).normalized()
		player.apply_knockback(push_direction, 150.0)
	
	# Crear efecto de ataque
	create_attack_effect()
	
	# Iniciar cooldowns
	if attack_timer:
		attack_timer.start()
	
	var damage_timer = get_node("DamageCooldownTimer")
	if damage_timer:
		damage_timer.start()

func create_grab_effect():
	"""Crear efecto visual de agarre"""
	var effect = Node2D.new()
	effect.position = global_position
	get_tree().current_scene.add_child(effect)
	
	for i in range(8):
		var particle = Sprite2D.new()
		var particle_image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
		particle_image.fill(Color.PURPLE)
		particle.texture = ImageTexture.create_from_image(particle_image)
		
		var angle = (float(i) * PI * 2.0) / 8.0
		var offset = Vector2.from_angle(angle) * randf_range(20, 40)
		particle.position = offset
		
		effect.add_child(particle)
		
		var particle_tween = effect.create_tween()
		particle_tween.parallel().tween_property(particle, "position", offset * 1.5, 0.8)
		particle_tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.8)
	
	var cleanup_timer = Timer.new()
	cleanup_timer.wait_time = 1.0
	cleanup_timer.one_shot = true
	cleanup_timer.timeout.connect(func(): 
		if is_instance_valid(effect):
			effect.queue_free()
	)
	effect.add_child(cleanup_timer)
	cleanup_timer.start()

func create_attack_effect():
	"""Crear efecto visual de ataque"""
	var effect = Node2D.new()
	effect.position = global_position
	get_tree().current_scene.add_child(effect)
	
	for i in range(6):
		var particle = Sprite2D.new()
		var particle_image = Image.create(10, 10, false, Image.FORMAT_RGBA8)
		particle_image.fill(Color.ORANGE_RED)
		particle.texture = ImageTexture.create_from_image(particle_image)
		
		var angle = (float(i) * PI * 2.0) / 6.0
		var offset = Vector2.from_angle(angle) * randf_range(15, 25)
		particle.position = offset
		
		effect.add_child(particle)
		
		var particle_tween = effect.create_tween()
		particle_tween.parallel().tween_property(particle, "position", offset * 2, 0.6)
		particle_tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.6)
		particle_tween.parallel().tween_property(particle, "scale", Vector2.ZERO, 0.6)
	
	var cleanup_timer = Timer.new()
	cleanup_timer.wait_time = 0.8
	cleanup_timer.one_shot = true
	cleanup_timer.timeout.connect(func(): 
		if is_instance_valid(effect):
			effect.queue_free()
	)
	effect.add_child(cleanup_timer)
	cleanup_timer.start()

func update_sprite_animation(animation: String, direction: Vector2):
	"""Actualizar animación del sprite"""
	if sprite and sprite is AnimatedSprite2D:
		var animated_sprite = sprite as AnimatedSprite2D
		
		if direction.x < 0:
			animated_sprite.flip_h = true
		else:
			animated_sprite.flip_h = false
		
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(animation):
			if animated_sprite.animation != animation:
				animated_sprite.play(animation)
		elif animated_sprite.animation != "idle":
			animated_sprite.play("idle")

# Funciones básicas de información
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

func is_in_range_of_player() -> bool:
	if not player:
		return false
	return global_position.distance_to(player.global_position) <= detection_range

func is_in_attack_range() -> bool:
	if not player:
		return false
	return global_position.distance_to(player.global_position) <= attack_range

func _exit_tree():
	"""Limpiar recursos al salir del árbol"""
	set_physics_process(false)
	set_process(false)
