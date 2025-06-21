# scenes/enemies/Enemy.gd - IA ESTILO COD BLACK OPS 1 + SKINS MEJORADAS
extends CharacterBody2D
class_name Enemy

signal died(enemy: Enemy)
signal damaged(enemy: Enemy, damage: int)

@export var enemy_type: String = "zombie_basic"
@export var max_health: int = 150
@export var current_health: int = 150
@export var base_move_speed: float = 100.0
@export var damage: int = 1
@export var attack_range: float = 60.0
@export var detection_range: float = 1000.0
@export var attack_cooldown: float = 1.0

@onready var sprite = $Sprite2D
@onready var collision_shape = $CollisionShape2D
@onready var attack_timer = $AttackTimer
@onready var health_bar = $HealthBar

# Hitboxes específicas
@onready var head_area: Area2D
@onready var body_area: Area2D
@onready var legs_area: Area2D

var player: Player = null
var is_dead: bool = false
var last_attack_time: float = 0.0
var current_move_speed: float = 150.0
var enemy_sprite_frames: SpriteFrames

# Variables de ataque visual
var attack_effect_sprite: Sprite2D
var is_attacking_player: bool = false

# IA ESTILO COD BLACK OPS 1 ZOMBIES
enum ZombieState {
	SPAWNING,
	HUNTING_PLAYER,
	MOVING_TO_BARRICADE,
	ATTACKING_BARRICADE,
	BREAKING_THROUGH,
	ATTACKING_PLAYER,
	STUNNED,
	SEARCHING_ENTRY_POINT,
	CIRCLING_PLAYER,      # NUEVO: Rodear al jugador
	RUSHING_PLAYER        # NUEVO: Cargar directo al jugador
}

var current_state: ZombieState = ZombieState.SPAWNING
var state_timer: float = 0.0
var target_barricade: Node2D = null
var wall_system: WallSystem = null
var path_blocked: bool = false

# Variables COD BO1 específicas
var last_known_player_position: Vector2
var barricade_attack_timer: float = 0.0
var barricade_attack_delay: float = 1.2  # MÁS RÁPIDO que antes
var wall_check_timer: float = 0.0
var wall_check_delay: float = 0.3  # MÁS FRECUENTE
var player_lost_timer: float = 0.0
var max_player_lost_time: float = 2.0  # MENOS TIEMPO antes de buscar barricadas

# Variables de pathfinding COD BO1
var current_target_position: Vector2
var stuck_timer: float = 0.0
var stuck_threshold: float = 1.5  # MENOS TOLERANCIA al atasco
var last_position: Vector2
var path_recalculation_timer: float = 0.0

# NUEVAS VARIABLES COD BO1
var circle_direction: int = 1  # 1 o -1 para dirección de círculo
var circle_radius: float = 200.0
var circle_speed_multiplier: float = 1.3
var rush_charge_timer: float = 0.0
var rush_duration: float = 3.0

func _ready():
	add_to_group("enemies")
	setup_enemy()
	setup_attack_effect()
	determine_zombie_variant()
	call_deferred("verify_sprite_after_ready")

func set_wall_system(wall_sys: WallSystem):
	"""Establecer referencia al sistema de paredes"""
	wall_system = wall_sys

func setup_attack_effect():
	"""Crear sprite para efectos de ataque"""
	attack_effect_sprite = Sprite2D.new()
	attack_effect_sprite.name = "AttackEffect"
	attack_effect_sprite.visible = false
	attack_effect_sprite.z_index = 20
	
	var effect_image = Image.create(80, 60, false, Image.FORMAT_RGBA8)
	effect_image.fill(Color.TRANSPARENT)
	
	var center = Vector2(15, 30)
	for x in range(80):
		for y in range(60):
			var dist = Vector2(x, y).distance_to(center)
			var angle = Vector2(x - center.x, y - center.y).angle()
			
			if dist < 45 and angle > -PI/3 and angle < PI/3:
				var alpha = 1.0 - (dist / 45.0)
				if dist < 25:
					effect_image.set_pixel(x, y, Color(1.0, 0.0, 0.0, alpha * 0.9))
				else:
					effect_image.set_pixel(x, y, Color(0.8, 0.2, 0.0, alpha * 0.7))
	
	attack_effect_sprite.texture = ImageTexture.create_from_image(effect_image)
	add_child(attack_effect_sprite)

func verify_sprite_after_ready():
	"""Verificar sprite después de _ready"""
	if not sprite or not sprite.visible:
		load_enemy_sprite_cod_style()
		force_sprite_visibility()

func setup_enemy():
	"""Configurar enemigo con hitboxes específicas"""
	is_dead = false
	current_state = ZombieState.SPAWNING
	
	collision_layer = 2
	collision_mask = 1 | 3
	
	last_known_player_position = global_position
	current_target_position = global_position
	last_position = global_position
	
	load_enemy_sprite_cod_style()
	setup_health_bar()
	setup_hitboxes()
	
	if attack_timer:
		attack_timer.wait_time = attack_cooldown
		attack_timer.one_shot = true
		attack_timer.timeout.connect(_on_attack_timer_timeout)

func setup_hitboxes():
	"""Configurar hitboxes para diferentes partes del cuerpo"""
	# CABEZA (20% superior)
	head_area = Area2D.new()
	head_area.name = "HeadArea"
	head_area.collision_layer = 2
	head_area.collision_mask = 4
	
	var head_shape = CollisionShape2D.new()
	var head_rect = RectangleShape2D.new()
	head_rect.size = Vector2(48, 25)
	head_shape.shape = head_rect
	head_shape.position = Vector2(0, -38)
	head_area.add_child(head_shape)
	add_child(head_area)
	
	# CUERPO (60% medio)
	body_area = Area2D.new()
	body_area.name = "BodyArea"
	body_area.collision_layer = 2
	body_area.collision_mask = 4
	
	var body_shape = CollisionShape2D.new()
	var body_rect = RectangleShape2D.new()
	body_rect.size = Vector2(48, 77)
	body_shape.shape = body_rect
	body_shape.position = Vector2(0, 0)
	body_area.add_child(body_shape)
	add_child(body_area)
	
	# PIERNAS (20% inferior)
	legs_area = Area2D.new()
	legs_area.name = "LegsArea"
	legs_area.collision_layer = 2
	legs_area.collision_mask = 4
	
	var legs_shape = CollisionShape2D.new()
	var legs_rect = RectangleShape2D.new()
	legs_rect.size = Vector2(48, 25)
	legs_shape.shape = legs_rect
	legs_shape.position = Vector2(0, 38)
	legs_area.add_child(legs_shape)
	add_child(legs_area)

func determine_zombie_variant():
	"""Variantes COD BO1 con skins específicas"""
	match enemy_type:
		"zombie_dog":
			setup_dog_variant_cod()
		"zombie_crawler":
			setup_crawler_variant_cod()
		"zombie_runner":
			setup_runner_variant_cod()
		"zombie_charger":
			setup_charger_variant_cod()
		_:
			setup_basic_variant_cod()

func setup_dog_variant_cod():
	"""Configurar variante perro COD BO1"""
	base_move_speed = 180.0  # RÁPIDO
	current_move_speed = base_move_speed
	damage = 2
	attack_range = 70.0
	detection_range = 1200.0
	attack_cooldown = 0.7
	max_health = int(max_health * 0.7)  # MENOS VIDA
	current_health = max_health

func setup_crawler_variant_cod():
	"""Configurar variante crawler COD BO1"""
	base_move_speed = 90.0   # LENTO
	current_move_speed = base_move_speed
	damage = 1
	attack_range = 50.0
	detection_range = 600.0
	attack_cooldown = 1.0
	max_health = int(max_health * 1.2)  # MÁS VIDA
	current_health = max_health

func setup_runner_variant_cod():
	"""Configurar variante runner COD BO1"""
	base_move_speed = 150.0
	current_move_speed = base_move_speed
	detection_range = 1000.0
	attack_cooldown = 0.8

func setup_charger_variant_cod():
	"""Configurar variante charger COD BO1"""
	base_move_speed = 130.0
	current_move_speed = base_move_speed
	attack_range = 80.0
	damage = 2

func setup_basic_variant_cod():
	"""Configurar variante básica COD BO1"""
	pass

func load_enemy_sprite_cod_style():
	"""Cargar sprite estilo COD BO1 con skins específicas"""
	var atlas_path = ""
	
	match enemy_type:
		"zombie_dog":
			atlas_path = "res://sprites/enemies/zombie_dog/walk_Right_Down.png"
		"zombie_crawler":
			atlas_path = "res://sprites/enemies/zombie_crawler/walk_Right_Down.png"
		_:
			atlas_path = "res://sprites/enemies/zombie/walk_Right_Down.png"
	
	var atlas_texture = try_load_texture_safe(atlas_path)
	
	if atlas_texture:
		setup_animated_sprite_player_size(atlas_texture)
	else:
		match enemy_type:
			"zombie_dog":
				create_dog_sprite_cod()
			"zombie_crawler":
				create_crawler_sprite_cod()
			"zombie_runner":
				create_runner_sprite_cod()
			"zombie_charger":
				create_charger_sprite_cod()
			_:
				create_basic_zombie_sprite_cod()

func create_dog_sprite_cod():
	"""SPRITE PERRO COD BO1 - RECTÁNGULO ROJO"""
	var image = Image.create(120, 60, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	# RECTÁNGULO ROJO SÓLIDO PARA PERROS
	for x in range(10, 110):
		for y in range(15, 45):
			image.set_pixel(x, y, Color.RED)
	
	# OJOS AMARILLOS BRILLANTES
	for x in range(85, 95):
		for y in range(20, 25):
			image.set_pixel(x, y, Color.YELLOW)
	
	for x in range(85, 95):
		for y in range(30, 35):
			image.set_pixel(x, y, Color.YELLOW)
	
	# COLA
	for x in range(0, 15):
		for y in range(25, 35):
			image.set_pixel(x, y, Color.DARK_RED)
	
	var default_texture = ImageTexture.create_from_image(image)
	
	if not sprite:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)
	
	if sprite is Sprite2D:
		var normal_sprite = sprite as Sprite2D
		normal_sprite.texture = default_texture
		normal_sprite.scale = Vector2(1.0, 2.0)
		normal_sprite.visible = true

func create_crawler_sprite_cod():
	"""SPRITE CRAWLER COD BO1 - CUADRADO VERDE"""
	var image = Image.create(80, 80, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	# CUADRADO VERDE SÓLIDO PARA CRAWLERS
	for x in range(15, 65):
		for y in range(15, 65):
			image.set_pixel(x, y, Color.GREEN)
	
	# OJOS ROJOS BRILLANTES
	for x in range(25, 35):
		for y in range(25, 30):
			image.set_pixel(x, y, Color.RED)
	
	for x in range(45, 55):
		for y in range(25, 30):
			image.set_pixel(x, y, Color.RED)
	
	# BOCA
	for x in range(35, 45):
		for y in range(45, 50):
			image.set_pixel(x, y, Color.BLACK)
	
	var default_texture = ImageTexture.create_from_image(image)
	
	if not sprite:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)
	
	if sprite is Sprite2D:
		var normal_sprite = sprite as Sprite2D
		normal_sprite.texture = default_texture
		normal_sprite.scale = Vector2(1.5, 1.5)
		normal_sprite.visible = true

func create_runner_sprite_cod():
	"""SPRITE RUNNER COD BO1"""
	var image = Image.create(96, 128, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	for x in range(96):
		for y in range(128):
			if x >= 35 and x < 61 and y >= 40 and y < 85:
				image.set_pixel(x, y, Color.ORANGE)
			elif x >= 40 and x < 56 and y >= 20 and y < 45:
				image.set_pixel(x, y, Color.ORANGE_RED)
	
	var default_texture = ImageTexture.create_from_image(image)
	
	if not sprite:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)
	
	if sprite is Sprite2D:
		var normal_sprite = sprite as Sprite2D
		normal_sprite.texture = default_texture
		normal_sprite.scale = Vector2(1.33, 1.0)
		normal_sprite.visible = true

func create_charger_sprite_cod():
	"""SPRITE CHARGER COD BO1"""
	var image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	for x in range(128):
		for y in range(128):
			if x >= 25 and x < 103 and y >= 35 and y < 90:
				image.set_pixel(x, y, Color.PURPLE)
	
	var default_texture = ImageTexture.create_from_image(image)
	
	if not sprite:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)
	
	if sprite is Sprite2D:
		var normal_sprite = sprite as Sprite2D
		normal_sprite.texture = default_texture
		normal_sprite.scale = Vector2(1.0, 1.0)
		normal_sprite.visible = true

func create_basic_zombie_sprite_cod():
	"""Sprite básico COD BO1"""
	var image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	image.fill(Color.DARK_RED)
	
	var default_texture = ImageTexture.create_from_image(image)
	
	if not sprite:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)
	
	if sprite is Sprite2D:
		var normal_sprite = sprite as Sprite2D
		normal_sprite.texture = default_texture
		normal_sprite.scale = Vector2(1.0, 1.0)
		normal_sprite.visible = true

func setup_animated_sprite_player_size(atlas_texture: Texture2D):
	"""Configurar sprite animado"""
	if sprite and sprite is Sprite2D:
		sprite.queue_free()
		
	var animated_sprite = AnimatedSprite2D.new()
	animated_sprite.name = "AnimatedSprite2D"
	add_child(animated_sprite)
	sprite = animated_sprite
	
	enemy_sprite_frames = SpriteFrames.new()
	
	enemy_sprite_frames.add_animation("walk")
	enemy_sprite_frames.set_animation_speed("walk", 12.0)
	enemy_sprite_frames.set_animation_loop("walk", true)
	
	for i in range(8):
		var frame = extract_frame_from_zombie_atlas(atlas_texture, i)
		enemy_sprite_frames.add_frame("walk", frame)
	
	enemy_sprite_frames.add_animation("idle")
	enemy_sprite_frames.set_animation_speed("idle", 4.0)
	enemy_sprite_frames.set_animation_loop("idle", true)
	var first_frame = extract_frame_from_zombie_atlas(atlas_texture, 0)
	enemy_sprite_frames.add_frame("idle", first_frame)
	
	enemy_sprite_frames.add_animation("attack")
	enemy_sprite_frames.set_animation_speed("attack", 8.0)
	enemy_sprite_frames.set_animation_loop("attack", false)
	for i in range(2, 5):
		var frame = extract_frame_from_zombie_atlas(atlas_texture, i)
		enemy_sprite_frames.add_frame("attack", frame)
	
	animated_sprite.sprite_frames = enemy_sprite_frames
	animated_sprite.play("idle")
	animated_sprite.visible = true
	animated_sprite.modulate = Color.WHITE
	animated_sprite.scale = Vector2(1.0, 1.0)

func extract_frame_from_zombie_atlas(atlas_texture: Texture2D, frame_index: int) -> Texture2D:
	var frame_width = 128.0
	var x_offset = float(frame_index) * frame_width
	
	var atlas_frame = AtlasTexture.new()
	atlas_frame.atlas = atlas_texture
	atlas_frame.region = Rect2(x_offset, 0, frame_width, 128.0)
	
	return atlas_frame

func try_load_texture_safe(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	
	var resource = load(path)
	if resource is Texture2D:
		return resource as Texture2D
	return null

func setup_health_bar():
	"""Configurar barra de vida"""
	if not health_bar:
		health_bar = ProgressBar.new()
		health_bar.size = Vector2(100, 16)
		health_bar.position = Vector2(-50, -70)
		add_child(health_bar)
	
	health_bar.max_value = max_health
	health_bar.value = current_health
	health_bar.show_percentage = false
	health_bar.visible = true

func force_sprite_visibility():
	"""Forzar que el sprite sea visible"""
	if sprite:
		sprite.visible = true
		sprite.modulate = Color.WHITE
		sprite.scale = Vector2(1.0, 1.0)

func setup_for_spawn(target_player: Player, round_health: int = -1):
	"""Configurar para spawn"""
	player = target_player
	
	if round_health > 0:
		match enemy_type:
			"zombie_dog":
				max_health = int(float(round_health) * 0.6)
			"zombie_crawler":
				max_health = int(float(round_health) * 1.3)
			"zombie_runner":
				max_health = int(float(round_health) * 0.7)
			"zombie_charger":
				max_health = int(float(round_health) * 0.9)
			_:
				max_health = round_health
		
		current_health = max_health
	
	is_dead = false
	current_state = ZombieState.SPAWNING
	target_barricade = null
	path_blocked = false
	
	# Reset timers COD BO1
	state_timer = 0.0
	stuck_timer = 0.0
	player_lost_timer = 0.0
	barricade_attack_timer = 0.0
	wall_check_timer = 0.0
	path_recalculation_timer = 0.0
	rush_charge_timer = 0.0
	
	# Dirección aleatoria para círculo
	circle_direction = 1 if randf() > 0.5 else -1
	
	last_known_player_position = target_player.global_position
	current_target_position = global_position
	last_position = global_position
	
	modulate = Color(1, 1, 1, 1)
	scale = Vector2(1.0, 1.0)
	force_sprite_visibility()
	
	call_deferred("_reactivate_collision")
	update_health_bar()
	start_spawn_animation()

func start_spawn_animation():
	"""Spawn sin ocultar sprite"""
	current_state = ZombieState.SPAWNING
	
	var spawn_timer_node = Timer.new()
	spawn_timer_node.wait_time = 0.1
	spawn_timer_node.one_shot = true
	spawn_timer_node.timeout.connect(_on_spawn_finished)
	add_child(spawn_timer_node)
	spawn_timer_node.start()

func _on_spawn_finished():
	"""Función para manejar finalización del spawn"""
	current_state = ZombieState.HUNTING_PLAYER
	state_timer = 0.0
	var spawn_timer_node = get_node_or_null("Timer")
	if spawn_timer_node:
		spawn_timer_node.queue_free()

func update_health_bar():
	"""Actualizar barra de vida"""
	if not health_bar:
		setup_health_bar()
		return
	
	health_bar.value = current_health
	health_bar.max_value = max_health
	health_bar.visible = true

func _reactivate_collision():
	if collision_shape and is_instance_valid(collision_shape):
		collision_shape.disabled = false

func _physics_process(delta):
	if is_dead or not player or not is_instance_valid(player):
		return
	
	update_cod_bo1_ai_state_machine(delta)
	handle_cod_bo1_movement(delta)
	update_movement_animation()
	check_if_stuck(delta)
	
	move_and_slide()

func update_cod_bo1_ai_state_machine(delta):
	"""IA ESTILO COD BLACK OPS 1 MEJORADA"""
	state_timer += delta
	wall_check_timer += delta
	barricade_attack_timer += delta
	path_recalculation_timer += delta
	
	var distance_to_player = global_position.distance_to(player.global_position)
	var can_see_player = has_clear_path_to_player()
	
	# Actualizar última posición conocida del jugador
	if can_see_player and distance_to_player <= detection_range:
		last_known_player_position = player.global_position
		player_lost_timer = 0.0
	else:
		player_lost_timer += delta
	
	match current_state:
		ZombieState.SPAWNING:
			pass
		
		ZombieState.HUNTING_PLAYER:
			handle_hunting_state_cod(distance_to_player, can_see_player)
		
		ZombieState.CIRCLING_PLAYER:
			handle_circling_state_cod(distance_to_player, can_see_player)
		
		ZombieState.RUSHING_PLAYER:
			handle_rushing_state_cod(distance_to_player, delta)
		
		ZombieState.SEARCHING_ENTRY_POINT:
			handle_searching_entry_point()
		
		ZombieState.MOVING_TO_BARRICADE:
			handle_moving_to_barricade()
		
		ZombieState.ATTACKING_BARRICADE:
			handle_attacking_barricade()
		
		ZombieState.ATTACKING_PLAYER:
			handle_attacking_player(distance_to_player)
		
		ZombieState.STUNNED:
			handle_stunned_state()

func handle_hunting_state_cod(distance_to_player: float, can_see_player: bool):
	"""Manejar estado de caza COD BO1"""
	if can_see_player and distance_to_player <= detection_range:
		if distance_to_player <= attack_range:
			current_state = ZombieState.ATTACKING_PLAYER
			state_timer = 0.0
		elif distance_to_player > 300 and randf() < 0.3:
			# COD BO1: A veces rodean al jugador
			current_state = ZombieState.CIRCLING_PLAYER
			state_timer = 0.0
		elif randf() < 0.1:
			# COD BO1: A veces cargan directo
			current_state = ZombieState.RUSHING_PLAYER
			rush_charge_timer = 0.0
		else:
			current_target_position = player.global_position
	else:
		if player_lost_timer > max_player_lost_time or path_recalculation_timer > 1.5:
			current_state = ZombieState.SEARCHING_ENTRY_POINT
			state_timer = 0.0
			path_recalculation_timer = 0.0

func handle_circling_state_cod(distance_to_player: float, can_see_player: bool):
	"""NUEVO: Rodear al jugador estilo COD BO1"""
	if not can_see_player or distance_to_player < attack_range:
		current_state = ZombieState.HUNTING_PLAYER
		return
	
	if state_timer > 4.0:  # Cambiar después de 4 segundos
		current_state = ZombieState.HUNTING_PLAYER if randf() < 0.7 else ZombieState.RUSHING_PLAYER
		return
	
	# Calcular posición circular alrededor del jugador
	var angle_to_player = (global_position - player.global_position).angle()
	var circle_angle = angle_to_player + (circle_direction * PI/3 * state_timer)
	var circle_pos = player.global_position + Vector2.from_angle(circle_angle) * circle_radius
	
	current_target_position = circle_pos
	current_move_speed = base_move_speed * circle_speed_multiplier

func handle_rushing_state_cod(distance_to_player: float, delta: float):
	"""NUEVO: Cargar directo al jugador estilo COD BO1"""
	rush_charge_timer += delta
	
	if distance_to_player <= attack_range:
		current_state = ZombieState.ATTACKING_PLAYER
		return
	
	if rush_charge_timer > rush_duration:
		current_state = ZombieState.HUNTING_PLAYER
		return
	
	# Cargar directo al jugador más rápido
	current_target_position = player.global_position
	current_move_speed = base_move_speed * 1.5

func handle_searching_entry_point():
	"""Buscar punto de entrada cuando no puede ver al jugador"""
	if state_timer > 0.3:
		find_path_to_player()
		state_timer = 0.0

func handle_moving_to_barricade():
	"""Manejar movimiento hacia barricada"""
	if target_barricade and is_instance_valid(target_barricade):
		var distance_to_barricade = global_position.distance_to(target_barricade.global_position)
		if distance_to_barricade <= 80.0:
			current_state = ZombieState.ATTACKING_BARRICADE
			state_timer = 0.0
		else:
			current_target_position = target_barricade.global_position
	else:
		current_state = ZombieState.SEARCHING_ENTRY_POINT

func handle_attacking_barricade():
	"""Manejar ataque a barricada"""
	if target_barricade and is_instance_valid(target_barricade):
		attack_barricade()
		var current_planks = target_barricade.get_meta("current_planks", 0)
		if current_planks <= 0:
			target_barricade = null
			current_state = ZombieState.HUNTING_PLAYER
	else:
		current_state = ZombieState.HUNTING_PLAYER

func handle_attacking_player(distance_to_player: float):
	"""Manejar ataque al jugador"""
	if distance_to_player <= attack_range and can_attack():
		execute_player_attack_with_animation()
	elif distance_to_player > attack_range * 1.5:
		current_state = ZombieState.HUNTING_PLAYER
		state_timer = 0.0

func handle_stunned_state():
	"""Manejar estado aturdido"""
	if state_timer > 0.2:  # MÁS RÁPIDO en COD BO1
		current_state = ZombieState.HUNTING_PLAYER
		state_timer = 0.0

func has_clear_path_to_player() -> bool:
	"""Verificar si hay camino directo al jugador"""
	if not player or not wall_system:
		return true
	
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		player.global_position
	)
	query.collision_mask = 3
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	return result.is_empty()

func find_path_to_player():
	"""Encontrar camino al jugador a través de barricadas"""
	if not wall_system:
		current_state = ZombieState.HUNTING_PLAYER
		return
	
	var nearest_barricade = find_nearest_attackable_barricade()
	if nearest_barricade:
		target_barricade = nearest_barricade
		current_state = ZombieState.MOVING_TO_BARRICADE
		current_target_position = target_barricade.global_position
		return
	
	current_target_position = last_known_player_position
	current_state = ZombieState.HUNTING_PLAYER

func find_nearest_attackable_barricade() -> Node2D:
	"""Encontrar barricada más cercana que se pueda atacar"""
	if not wall_system:
		return null
	
	var nearest_barricade: Node2D = null
	var nearest_distance: float = INF
	var search_radius = 600.0  # MÁS PEQUEÑO en COD BO1
	
	for barricade in wall_system.get_all_barricades():
		if not is_instance_valid(barricade):
			continue
		
		var distance = global_position.distance_to(barricade.global_position)
		if distance > search_radius:
			continue
		
		var current_planks = barricade.get_meta("current_planks", 0)
		if current_planks <= 0:
			continue
		
		var direction_to_player = (last_known_player_position - global_position).normalized()
		var direction_to_barricade = (barricade.global_position - global_position).normalized()
		var angle_diff = direction_to_player.angle_to(direction_to_barricade)
		
		if abs(angle_diff) < PI/2 and distance < nearest_distance:
			nearest_distance = distance
			nearest_barricade = barricade
	
	return nearest_barricade

func attack_barricade():
	"""Atacar barricada COD BO1"""
	if not target_barricade or not is_instance_valid(target_barricade):
		return
	
	if barricade_attack_timer < barricade_attack_delay:
		return
	
	barricade_attack_timer = 0.0
	
	if wall_system:
		wall_system.damage_barricade(target_barricade, 1)
	
	create_barricade_attack_effect()

func create_barricade_attack_effect():
	"""Crear efecto de ataque a barricada"""
	if not target_barricade:
		return
	
	for i in range(3):
		var particle = Sprite2D.new()
		var particle_image = Image.create(6, 6, false, Image.FORMAT_RGBA8)
		particle_image.fill(Color.BROWN)
		particle.texture = ImageTexture.create_from_image(particle_image)
		particle.global_position = target_barricade.global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		get_tree().current_scene.add_child(particle)
		
		var tween = create_tween()
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.8)
		tween.parallel().tween_property(particle, "global_position", 
			particle.global_position + Vector2(randf_range(-15, 15), randf_range(-15, 15)), 0.8)
		tween.tween_callback(func(): particle.queue_free())

func handle_cod_bo1_movement(delta):
	"""Movimiento estilo COD BO1"""
	var movement_direction = Vector2.ZERO
	
	match current_state:
		ZombieState.SPAWNING:
			movement_direction = Vector2.ZERO
		
		ZombieState.HUNTING_PLAYER, ZombieState.CIRCLING_PLAYER, ZombieState.RUSHING_PLAYER:
			if player:
				movement_direction = (current_target_position - global_position).normalized()
		
		ZombieState.SEARCHING_ENTRY_POINT:
			movement_direction = (current_target_position - global_position).normalized()
		
		ZombieState.MOVING_TO_BARRICADE:
			movement_direction = (current_target_position - global_position).normalized()
		
		ZombieState.ATTACKING_BARRICADE, ZombieState.ATTACKING_PLAYER:
			movement_direction = Vector2.ZERO
		
		ZombieState.STUNNED:
			movement_direction = velocity * 0.1
	
	# Separación mejorada
	movement_direction += get_improved_separation() * 0.3
	movement_direction += get_wall_avoidance() * 0.5
	
	if movement_direction != Vector2.ZERO:
		velocity = movement_direction.normalized() * current_move_speed
	
	# Resetear velocidad después de estados especiales
	if current_state == ZombieState.HUNTING_PLAYER:
		current_move_speed = base_move_speed
	
	last_position = global_position

func get_improved_separation() -> Vector2:
	"""Separación mejorada COD BO1"""
	var separation = Vector2.ZERO
	var separation_radius = 60.0  # MÁS PEQUEÑO
	var separation_strength = 1.8
	
	for other_zombie in get_tree().get_nodes_in_group("enemies"):
		if other_zombie == self or not is_instance_valid(other_zombie):
			continue
		
		var distance = global_position.distance_to(other_zombie.global_position)
		if distance < separation_radius and distance > 0:
			var separation_dir = (global_position - other_zombie.global_position).normalized()
			var strength = 1.0 - (distance / separation_radius)
			separation += separation_dir * strength * separation_strength
	
	return separation.normalized() * min(separation.length(), 2.5)

func get_wall_avoidance() -> Vector2:
	"""Evitar colisiones con paredes"""
	var avoidance = Vector2.ZERO
	var look_ahead_distance = 80.0  # MÁS PEQUEÑO
	
	var space_state = get_world_2d().direct_space_state
	
	var forward_direction = velocity.normalized() if velocity.length() > 0 else Vector2.RIGHT
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + forward_direction * look_ahead_distance
	)
	query.collision_mask = 3
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	if not result.is_empty():
		var hit_normal = result.get("normal", Vector2.ZERO)
		avoidance = hit_normal * 1.8
	
	return avoidance

func check_if_stuck(delta):
	"""Verificar si el enemigo está atascado"""
	var movement_threshold = 8.0  # MÁS ESTRICTO
	
	if global_position.distance_to(last_position) < movement_threshold:
		stuck_timer += delta
	else:
		stuck_timer = 0.0
	
	if stuck_timer > stuck_threshold:
		stuck_timer = 0.0
		if current_state == ZombieState.HUNTING_PLAYER or current_state == ZombieState.MOVING_TO_BARRICADE:
			current_state = ZombieState.SEARCHING_ENTRY_POINT
			state_timer = 0.0

func execute_player_attack_with_animation():
	"""Ejecutar ataque al jugador"""
	if not player or not is_instance_valid(player):
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	if distance_to_player <= attack_range:
		start_attack_animation()
		
		if player.has_method("take_damage"):
			player.take_damage(damage)
		
		create_attack_effect()
	
	last_attack_time = Time.get_ticks_msec() / 1000.0

func start_attack_animation():
	"""Iniciar animación de ataque"""
	is_attacking_player = true
	
	if attack_effect_sprite:
		attack_effect_sprite.visible = true
		
		var direction_to_player = (player.global_position - global_position).normalized()
		attack_effect_sprite.position = direction_to_player * 40
		attack_effect_sprite.rotation = direction_to_player.angle()
	
	if sprite and sprite is AnimatedSprite2D:
		var animated_sprite = sprite as AnimatedSprite2D
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("attack"):
			animated_sprite.play("attack")
	
	if sprite:
		sprite.modulate = Color(1.3, 0.8, 0.8, 1.0)
	
	var attack_anim_timer = Timer.new()
	attack_anim_timer.wait_time = 0.3
	attack_anim_timer.one_shot = true
	attack_anim_timer.timeout.connect(_finish_attack_animation)
	add_child(attack_anim_timer)
	attack_anim_timer.start()

func _finish_attack_animation():
	"""Finalizar animación de ataque"""
	is_attacking_player = false
	
	if attack_effect_sprite:
		attack_effect_sprite.visible = false
	
	if sprite:
		sprite.modulate = Color.WHITE
	
	if sprite and sprite is AnimatedSprite2D:
		var animated_sprite = sprite as AnimatedSprite2D
		if velocity.length() > 30.0:
			animated_sprite.play("walk")
		else:
			animated_sprite.play("idle")
	
	var attack_anim_timer = get_node_or_null("Timer")
	if attack_anim_timer and attack_anim_timer.name != "AttackTimer":
		attack_anim_timer.queue_free()

func create_attack_effect():
	"""Crear efecto de ataque"""
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

func can_attack() -> bool:
	var current_time = Time.get_ticks_msec() / 1000.0
	return current_time - last_attack_time >= attack_cooldown

func update_movement_animation():
	if not sprite or not (sprite is AnimatedSprite2D):
		return
	
	var animated_sprite = sprite as AnimatedSprite2D
	
	if is_attacking_player:
		return
	
	if current_state == ZombieState.SPAWNING:
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
	"""Recibir daño"""
	if is_dead:
		return
	
	current_health -= amount
	current_health = max(current_health, 0)
	
	current_state = ZombieState.STUNNED
	state_timer = 0.0
	
	if sprite:
		if is_headshot:
			sprite.modulate = Color.YELLOW
		else:
			sprite.modulate = Color.RED
		
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	
	update_health_bar()
	show_damage_number(amount, is_headshot)
	
	damaged.emit(self, amount)
	
	if current_health <= 0:
		die()

func show_damage_number(damage_amount: int, is_headshot: bool = false):
	"""Mostrar número de daño flotante"""
	var damage_label = Label.new()
	damage_label.text = "-" + str(damage_amount)
	
	if is_headshot:
		damage_label.text = "HEADSHOT! -" + str(damage_amount)
		damage_label.add_theme_color_override("font_color", Color.YELLOW)
		damage_label.add_theme_font_size_override("font_size", 18)
	else:
		damage_label.add_theme_color_override("font_color", Color.RED)
		damage_label.add_theme_font_size_override("font_size", 16)
	
	damage_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	damage_label.add_theme_constant_override("shadow_offset_x", 2)
	damage_label.add_theme_constant_override("shadow_offset_y", 2)
	damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	damage_label.position = Vector2(-25, -120)
	damage_label.size = Vector2(50, 20)
	
	add_child(damage_label)
	
	var tween = create_tween()
	tween.parallel().tween_property(damage_label, "position", damage_label.position + Vector2(0, -50), 1.0)
	tween.parallel().tween_property(damage_label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(func(): damage_label.queue_free())

func die():
	"""Muerte"""
	if is_dead:
		return
	
	is_dead = true
	current_state = ZombieState.SPAWNING
	
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

func reset_for_pool():
	"""Reset para pool"""
	is_dead = false
	current_state = ZombieState.SPAWNING
	target_barricade = null
	path_blocked = false
	is_attacking_player = false
	
	state_timer = 0.0
	stuck_timer = 0.0
	player_lost_timer = 0.0
	barricade_attack_timer = 0.0
	wall_check_timer = 0.0
	path_recalculation_timer = 0.0
	rush_charge_timer = 0.0
	
	call_deferred("_deactivate_collision")
	
	if sprite:
		sprite.visible = true
		sprite.modulate = Color.WHITE
		sprite.scale = Vector2(1.0, 1.0)
	
	if attack_effect_sprite:
		attack_effect_sprite.visible = false
	
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
	"""Limpiar al salir"""
	set_physics_process(false)
	set_process(false)
