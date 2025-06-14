# scenes/enemies/BasicEnemy.gd
extends CharacterBody2D
class_name Enemy

signal died(enemy: Enemy)
signal damaged(enemy: Enemy, damage: int)

@export var max_health: int = 150
@export var current_health: int = 150
@export var move_speed: float = 50.0
@export var damage: int = 15
@export var attack_range: float = 40.0
@export var detection_range: float = 500.0

@onready var sprite = $Sprite2D
@onready var collision_shape = $CollisionShape2D
@onready var attack_timer = $AttackTimer
@onready var health_bar = $HealthBar

var player: Player = null
var is_dead: bool = false
var is_attacking: bool = false
var last_attack_time: float = 0.0
var attack_cooldown: float = 2.0

# VARIABLES PARA SPRITES
var enemy_sprite_frames: SpriteFrames
var enemy_type: String = "zombie"
var is_sprite_loaded: bool = false

# Estados del enemigo
enum EnemyState {
	IDLE,
	CHASING,
	ATTACKING,
	STUNNED,
	DEAD
}

var current_state: EnemyState = EnemyState.IDLE
var original_color: Color = Color.WHITE

# VARIABLES ESTILO COD ZOMBIES
var aggression_level: float = 1.0
var last_player_position: Vector2
var search_timer: float = 0.0
var stuck_timer: float = 0.0
var last_position: Vector2
var unstuck_direction: Vector2
var wander_target: Vector2
var growl_timer: float = 0.0

# Comportamiento inteligente
var path_blocked_count: int = 0
var alternative_path_timer: float = 0.0
var circle_player: bool = false
var circle_direction: int = 1

# Sistema de colisiones entre enemigos
var nearby_enemies: Array[Enemy] = []
var separation_force: Vector2 = Vector2.ZERO
var separation_radius: float = 60.0

# Zona de headshot
var head_area: Area2D

func _ready():
	setup_enemy()
	setup_head_collision()

func setup_head_collision():
	"""Configurar área de colisión para headshots"""
	head_area = Area2D.new()
	head_area.name = "HeadArea"
	head_area.collision_layer = 0
	head_area.collision_mask = 4
	
	var head_shape = CollisionShape2D.new()
	var head_circle = CircleShape2D.new()
	head_circle.radius = 20.0
	head_shape.shape = head_circle
	head_shape.position = Vector2(0, -40)
	
	head_area.add_child(head_shape)
	add_child(head_area)
	
	head_area.area_entered.connect(_on_head_area_entered)

func _on_head_area_entered(area):
	"""Cuando una bala entra en el área de la cabeza"""
	if area.is_in_group("bullets") or area.name.contains("Bullet"):
		var bullet = area as Bullet
		if bullet and bullet.damage > 0:
			var headshot_damage = bullet.damage
			if bullet.has_method("get") and bullet.get("headshot_multiplier"):
				headshot_damage = int(float(bullet.damage) * bullet.headshot_multiplier)
			else:
				headshot_damage = int(float(bullet.damage) * 1.4)
			
			take_damage(headshot_damage, true)
			
			if bullet.knockback_force > 0:
				var knockback_direction = (global_position - bullet.global_position).normalized()
				apply_knockback(knockback_direction, bullet.knockback_force)

func try_load_texture_safe(path: String) -> Texture2D:
	"""Función para cargar texturas de forma segura"""
	if not ResourceLoader.exists(path):
		return null
	
	var resource = load(path)
	if resource is Texture2D:
		return resource as Texture2D
	else:
		return null
	
func setup_enemy():
	"""Configurar el enemigo inicial"""
	current_health = max_health
	is_dead = false
	is_attacking = false
	current_state = EnemyState.IDLE
	
	last_position = global_position
	wander_target = global_position + Vector2(randf_range(-200, 200), randf_range(-200, 200))
	
	if not is_sprite_loaded:
		load_enemy_sprite_from_atlas()
	
	var has_sprite = false
	if sprite:
		if sprite is AnimatedSprite2D:
			var animated_sprite = sprite as AnimatedSprite2D
			has_sprite = (animated_sprite.sprite_frames != null)
		elif sprite is Sprite2D:
			var normal_sprite = sprite as Sprite2D
			has_sprite = (normal_sprite.texture != null)
	
	if not has_sprite:
		create_default_enemy_sprite()
	
	setup_health_bar()
	
	if attack_timer:
		attack_timer.wait_time = attack_cooldown
		attack_timer.one_shot = true
		attack_timer.timeout.connect(_on_attack_timer_timeout)

func apply_dynamic_scaling_128px(animated_sprite: AnimatedSprite2D, reference_texture: Texture2D):
	"""Aplicar escalado dinámico para que el enemigo tenga 128px de alto"""
	if not reference_texture:
		animated_sprite.scale = Vector2(2.0, 2.0)
		return
	
	var current_height = reference_texture.get_size().y
	var target_height = 128.0
	
	var scale_factor = target_height / float(current_height)
	animated_sprite.scale = Vector2(scale_factor, scale_factor)

func load_enemy_sprite_from_atlas():
	"""Cargar sprite del enemigo desde atlas - ESCALADO DINÁMICO A 128px"""
	var atlas_path = "res://sprites/enemies/" + enemy_type + "/walk_Right_Down.png"
	var atlas_texture = try_load_texture_safe(atlas_path)
	
	if atlas_texture:
		enemy_sprite_frames = SpriteFrames.new()
		
		enemy_sprite_frames.add_animation("idle")
		enemy_sprite_frames.set_animation_speed("idle", 2.0)
		enemy_sprite_frames.set_animation_loop("idle", true)
		
		var first_frame = extract_first_frame_from_enemy_atlas(atlas_texture)
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
				
				load_frames_from_enemy_atlas(enemy_sprite_frames, "walk", atlas_texture, 8, 1)
				
				animated_sprite.play("idle")
				
				apply_dynamic_scaling_128px(animated_sprite, first_frame)
				
				is_sprite_loaded = true
				return

func extract_first_frame_from_enemy_atlas(atlas_texture: Texture2D) -> Texture2D:
	"""Extraer el primer frame de un atlas de enemigo - DIVISIÓN CORREGIDA"""
	var texture_size = atlas_texture.get_size()
	var frame_width = float(texture_size.x) / 8.0  # CORREGIDO: División flotante
	var frame_height = float(texture_size.y)
	
	var first_frame = AtlasTexture.new()
	first_frame.atlas = atlas_texture
	first_frame.region = Rect2(0, 0, frame_width, frame_height)
	
	return first_frame

func load_frames_from_enemy_atlas(sprite_frames: SpriteFrames, anim_name: String, atlas_texture: Texture2D, h_frames: int, v_frames: int):
	"""Cargar frames desde un atlas de enemigo - DIVISIÓN CORREGIDA"""
	var texture_size = atlas_texture.get_size()
	var frame_width = float(texture_size.x) / float(h_frames)  # CORREGIDO: División flotante
	var frame_height = float(texture_size.y) / float(v_frames)  # CORREGIDO: División flotante
	
	for i in range(h_frames * v_frames):
		var x = float(i % h_frames) * frame_width
		var y = float(i / h_frames) * frame_height
		
		var atlas_frame = AtlasTexture.new()
		atlas_frame.atlas = atlas_texture
		atlas_frame.region = Rect2(x, y, frame_width, frame_height)
		
		sprite_frames.add_frame(anim_name, atlas_frame)

func create_default_enemy_sprite():
	"""Crear sprite por defecto del enemigo - ESCALADO DINÁMICO A 128px"""
	var image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	image.fill(Color.DARK_RED)
	
	for x in range(128):
		for y in range(128):
			var dist = Vector2(x - 64, y - 64).length()
			if dist < 20:
				image.set_pixel(x, y, Color.DARK_RED.darkened(0.3))
			elif dist < 30:
				image.set_pixel(x, y, Color.RED.darkened(0.2))
	
	var eye_size = 8
	for x in range(64 - 20, 64 - 20 + eye_size):
		for y in range(64 - 20, 64 - 20 + eye_size):
			if x >= 0 and x < 128 and y >= 0 and y < 128:
				image.set_pixel(x, y, Color.RED)
	
	for x in range(64 + 12, 64 + 12 + eye_size):
		for y in range(64 - 20, 64 - 20 + eye_size):
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
	current_state = EnemyState.IDLE
	
	aggression_level = randf_range(0.8, 1.2)
	search_timer = 0.0
	stuck_timer = 0.0
	path_blocked_count = 0
	circle_player = randf() < 0.3
	circle_direction = 1 if randf() < 0.5 else -1
	
	if sprite:
		sprite.modulate = original_color
		sprite.visible = true
	
	update_health_bar()
	randomize_stats()

func randomize_stats():
	"""Añadir variación aleatoria estilo COD"""
	damage += randi_range(-3, 8)
	var speed_variation = randf_range(-10.0, 15.0)
	move_speed += speed_variation
	
	move_speed = max(move_speed, 30.0)
	damage = max(damage, 8)

func reset_for_pool():
	"""Resetear enemigo para el pool"""
	is_dead = false
	is_attacking = false
	current_state = EnemyState.IDLE
	current_health = max_health
	
	if sprite:
		sprite.modulate = original_color
		sprite.visible = false
	
	set_physics_process(false)
	set_process(false)

func _physics_process(delta):
	if is_dead or not player or not is_instance_valid(player):
		return
	
	update_timers(delta)
	update_state()
	update_nearby_enemies()
	handle_movement_cod_style(delta)
	handle_combat_cod_style()

func update_nearby_enemies():
	"""Actualizar lista de enemigos cercanos para evitar solapamiento"""
	nearby_enemies.clear()
	separation_force = Vector2.ZERO
	
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = separation_radius
	query.shape = circle_shape
	query.transform = Transform2D(0, global_position)
	query.collision_mask = 2
	query.exclude = [self]
	
	var results = space_state.intersect_shape(query, 10)
	
	for result in results:
		var enemy = result.collider as Enemy
		if enemy and enemy != self and not enemy.is_dead:
			nearby_enemies.append(enemy)
			
			var separation_vector = global_position - enemy.global_position
			var distance = separation_vector.length()
			
			if distance > 0 and distance < separation_radius:
				var force_magnitude = (separation_radius - distance) / separation_radius
				separation_force += separation_vector.normalized() * force_magnitude * 50.0

func update_timers(delta):
	"""Actualizar timers del comportamiento COD"""
	search_timer += delta
	growl_timer += delta
	
	if global_position.distance_to(last_position) < 10.0:
		stuck_timer += delta
	else:
		stuck_timer = 0.0
		last_position = global_position
	
	if alternative_path_timer > 0:
		alternative_path_timer -= delta

func update_state():
	"""Actualizar estado estilo COD Zombies"""
	if is_dead:
		current_state = EnemyState.DEAD
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	if distance_to_player <= detection_range:
		last_player_position = player.global_position
		search_timer = 0.0
	
	if distance_to_player <= attack_range and not is_attacking:
		current_state = EnemyState.ATTACKING
	elif distance_to_player <= detection_range:
		current_state = EnemyState.CHASING
	elif search_timer < 5.0:
		current_state = EnemyState.CHASING
	else:
		current_state = EnemyState.IDLE

func handle_movement_cod_style(delta):
	"""Manejo de movimiento estilo COD Zombies con separación"""
	var movement_direction = Vector2.ZERO
	
	match current_state:
		EnemyState.CHASING:
			movement_direction = get_movement_towards_player()
		EnemyState.ATTACKING:
			movement_direction = Vector2.ZERO
		EnemyState.IDLE:
			movement_direction = get_wander_movement(delta)
		EnemyState.STUNNED:
			movement_direction = velocity.move_toward(Vector2.ZERO, move_speed * delta * 2)
	
	if separation_force.length() > 0:
		movement_direction += separation_force.normalized() * 0.3
	
	if movement_direction != Vector2.ZERO:
		velocity = movement_direction.normalized() * move_speed
	else:
		velocity = Vector2.ZERO
	
	move_and_slide()
	
	if get_slide_collision_count() > 0:
		handle_collision_behavior()

func get_movement_towards_player() -> Vector2:
	"""Obtener dirección de movimiento hacia el jugador"""
	if not player:
		return Vector2.ZERO
	
	var target_position = player.global_position
	
	if stuck_timer > 2.0:
		return get_alternative_path_movement()
	
	if circle_player and global_position.distance_to(player.global_position) < 200:
		return get_circle_movement()
	
	var direction = (target_position - global_position).normalized()
	
	if randf() < 0.1:
		direction = direction.rotated(randf_range(-0.3, 0.3))
	
	update_sprite_animation("walk", direction)
	
	return direction

func get_alternative_path_movement() -> Vector2:
	"""Obtener movimiento de ruta alternativa cuando está atascado"""
	if alternative_path_timer <= 0:
		var angles = [PI/4, -PI/4, PI/2, -PI/2]
		var random_angle = angles[randi() % angles.size()]
		
		var player_direction = (player.global_position - global_position).normalized()
		unstuck_direction = player_direction.rotated(random_angle)
		
		alternative_path_timer = 1.5
		stuck_timer = 0.0
	
	update_sprite_animation("walk", unstuck_direction)
	return unstuck_direction

func get_circle_movement() -> Vector2:
	"""Rodear al jugador para confundirlo"""
	var to_player = player.global_position - global_position
	var distance = to_player.length()
	
	var ideal_distance = 120.0
	var direction_to_player = to_player.normalized()
	
	var tangent = Vector2(-direction_to_player.y, direction_to_player.x) * float(circle_direction)
	
	var final_direction = tangent
	if distance > ideal_distance + 30:
		final_direction += direction_to_player * 0.5
	elif distance < ideal_distance - 30:
		final_direction -= direction_to_player * 0.5
	
	update_sprite_animation("walk", final_direction)
	return final_direction

func get_wander_movement(_delta) -> Vector2:
	"""Comportamiento de deambulación cuando no ve al jugador"""
	var to_wander_target = wander_target - global_position
	
	if to_wander_target.length() < 50.0:
		wander_target = global_position + Vector2(randf_range(-300, 300), randf_range(-300, 300))
	else:
		var direction = to_wander_target.normalized()
		update_sprite_animation("walk", direction)
		return direction * 0.3
	
	return Vector2.ZERO

func handle_collision_behavior():
	"""Manejar comportamiento cuando colisiona"""
	path_blocked_count += 1
	
	if path_blocked_count > 3:
		circle_player = true
		path_blocked_count = 0

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

func handle_combat_cod_style():
	"""Manejo de combate estilo COD"""
	if current_state == EnemyState.ATTACKING and not is_attacking:
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - last_attack_time >= attack_cooldown:
			attack_player_cod_style()

func attack_player_cod_style():
	"""Ataque estilo COD Zombies"""
	if not player or is_attacking:
		return
	
	is_attacking = true
	last_attack_time = Time.get_ticks_msec() / 1000.0
	
	if sprite:
		sprite.modulate = Color.ORANGE_RED
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", original_color, 0.4)
	
	var final_damage = int(float(damage) * aggression_level)
	
	if player.has_method("take_damage"):
		player.take_damage(final_damage)
	elif player.has_node("HealthComponent"):
		var health_component = player.get_node("HealthComponent")
		if health_component.has_method("take_damage"):
			health_component.take_damage(final_damage)
	
	if player and player.has_method("apply_knockback"):
		var push_direction = (player.global_position - global_position).normalized()
		player.apply_knockback(push_direction, 100.0)
	
	if attack_timer:
		attack_timer.start()

func _on_attack_timer_timeout():
	"""Cuando termina el cooldown de ataque"""
	is_attacking = false

func apply_knockback(direction: Vector2, force: float):
	"""Aplicar knockback al enemigo"""
	if direction.length() > 0:
		velocity += direction.normalized() * force

func take_damage(amount: int, is_headshot: bool = false):
	"""Recibir daño con comportamiento COD"""
	if is_dead:
		return
	
	current_health -= amount
	current_health = max(current_health, 0)
	
	current_state = EnemyState.STUNNED
	var stun_timer = Timer.new()
	stun_timer.wait_time = 0.3
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
	
	velocity = Vector2.ZERO
	set_physics_process(false)
	
	if sprite:
		sprite.modulate = Color.GRAY
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 1.0)
	
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
