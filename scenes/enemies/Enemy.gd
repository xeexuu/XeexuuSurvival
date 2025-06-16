# scenes/enemies/Enemy.gd - SOLUCIÓN SIMPLE: ANCLAJE EN ATAQUE
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

var player: Player = null
var is_dead: bool = false
var last_attack_time: float = 0.0
var current_move_speed: float = 150.0

# Variable que faltaba
var enemy_sprite_frames: SpriteFrames

# ===== SISTEMA SIMPLE ANTI-PEGADO =====
enum WaWState {
	SPAWNING,
	HUNTING,
	CHARGING,
	ATTACKING,    # ANCLADO: No se mueve cuando ataca
	STUNNED
}

var current_state: WaWState = WaWState.SPAWNING
var state_timer: float = 0.0

# Variables simples
var last_known_player_position: Vector2
var charge_speed_multiplier: float = 1.5
var min_separation_distance: float = 35.0
var max_separation_distance: float = 50.0

# SOLUCIÓN SIMPLE: ANCLAJE EN ATAQUE
var is_anchored: bool = false  # Anclado al suelo durante ataque
var anchor_position: Vector2   # Posición donde se ancla

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
	"""Variantes World at War"""
	var rand_val = randf()
	
	if rand_val < 0.15:  # 15% RUNNERS
		enemy_type = "zombie_runner"
		charge_speed_multiplier = randf_range(1.8, 2.2)
		max_health = int(float(max_health) * 0.6)
		current_health = max_health
		modulate = Color(1.4, 0.6, 0.6, 1.0)
		detection_range = 1200.0
		
	elif rand_val < 0.25:  # 10% CHARGERS
		enemy_type = "zombie_charger"  
		charge_speed_multiplier = randf_range(1.4, 1.7)
		max_health = int(float(max_health) * 0.8)
		current_health = max_health
		modulate = Color(1.2, 0.8, 0.6, 1.0)
		attack_range = 70.0
		
	elif rand_val < 0.35:  # 10% CRAWLERS
		enemy_type = "zombie_crawler"
		charge_speed_multiplier = randf_range(0.7, 0.9)
		max_health = int(float(max_health) * 1.3)
		current_health = max_health
		modulate = Color(0.8, 1.0, 0.8, 1.0)
		
	else:  # 65% BÁSICOS
		charge_speed_multiplier = randf_range(0.9, 1.3)
		max_health = int(float(max_health) * 1.0)
		current_health = max_health
		modulate = Color(1.0, 0.9, 0.8, 1.0)
	
	current_move_speed = base_move_speed * charge_speed_multiplier

func load_enemy_sprite_waw_size():
	"""Cargar sprite del enemigo"""
	var atlas_path = "res://sprites/enemies/zombie/walk_Right_Down.png"
	var atlas_texture = try_load_texture_safe(atlas_path)
	
	if atlas_texture:
		setup_animated_sprite_player_size(atlas_texture)
	else:
		create_default_enemy_sprite_player_size()

func setup_animated_sprite_player_size(atlas_texture: Texture2D):
	"""Configurar sprite animado"""
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

func create_default_enemy_sprite_player_size():
	"""Sprite por defecto"""
	var image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	
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
		normal_sprite.scale = Vector2(1.0, 1.0)
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
		health_bar.size = Vector2(80, 10)
		health_bar.position = Vector2(-40, -70)
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
	
	# RESETEAR SISTEMA DE ANCLAJE
	is_anchored = false
	anchor_position = Vector2.ZERO
	
	modulate = Color(1, 1, 1, 0)
	scale = Vector2.ZERO
	
	call_deferred("_reactivate_collision")
	update_health_bar()
	start_spawn_animation()

func start_spawn_animation():
	current_state = WaWState.SPAWNING
	
	var spawn_tween = create_tween()
	spawn_tween.set_parallel(true)
	
	spawn_tween.tween_method(set_spawn_scale, 0.0, 1.0, 0.5)
	spawn_tween.tween_method(set_spawn_alpha, 0.0, 1.0, 0.3)
	
	spawn_tween.tween_callback(func(): 
		current_state = WaWState.HUNTING
		state_timer = 0.0
	)

func set_spawn_scale(value: float):
	var base_scale = Vector2(1.0, 1.0)
	scale = base_scale * value

func set_spawn_alpha(value: float):
	var current_color = modulate
	current_color.a = value
	modulate = current_color

func _reactivate_collision():
	if collision_shape and is_instance_valid(collision_shape):
		collision_shape.disabled = false

func _physics_process(delta):
	if is_dead or not player or not is_instance_valid(player):
		return
	
	update_waw_ai_state_machine(delta)
	handle_waw_movement(delta)
	update_movement_animation()
	
	move_and_slide()

# ===== IA SIMPLE CON ANCLAJE =====

func update_waw_ai_state_machine(delta):
	"""IA con anclaje en ataque"""
	state_timer += delta
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	match current_state:
		WaWState.SPAWNING:
			pass
		
		WaWState.HUNTING:
			if distance_to_player <= detection_range:
				current_state = WaWState.CHARGING
				last_known_player_position = player.global_position
				state_timer = 0.0
		
		WaWState.CHARGING:
			last_known_player_position = player.global_position
			
			if distance_to_player <= attack_range:
				current_state = WaWState.ATTACKING
				state_timer = 0.0
				# ANCLAR AL ENTRAR EN ATAQUE
				anchor_at_current_position()
				start_waw_attack()
		
		WaWState.ATTACKING:
			# MANTENERSE ANCLADO DURANTE EL ATAQUE
			if distance_to_player <= attack_range and can_attack():
				execute_waw_attack()
			elif distance_to_player > attack_range * 1.5:
				# DESANCLAR Y VOLVER A CARGAR
				unanchor()
				current_state = WaWState.CHARGING
				state_timer = 0.0
		
		WaWState.STUNNED:
			if state_timer > 0.1:
				# DESANCLAR AL SALIR DE STUN
				unanchor()
				current_state = WaWState.CHARGING
				state_timer = 0.0

func anchor_at_current_position():
	"""ANCLAR: Fijar posición durante ataque"""
	is_anchored = true
	anchor_position = global_position
	print("🔒 Enemigo anclado en: ", anchor_position)

func unanchor():
	"""DESANCLAR: Permitir movimiento normal"""
	is_anchored = false
	anchor_position = Vector2.ZERO
	print("🔓 Enemigo desanclado")

func handle_waw_movement(delta):
	"""Movimiento con anclaje"""
	var movement_direction = Vector2.ZERO
	
	# SI ESTÁ ANCLADO, NO SE MUEVE
	if is_anchored:
		velocity = Vector2.ZERO
		# FORZAR POSICIÓN DE ANCLAJE
		global_position = anchor_position
		return
	
	match current_state:
		WaWState.SPAWNING:
			movement_direction = Vector2.ZERO
		
		WaWState.HUNTING:
			if player:
				movement_direction = (player.global_position - global_position).normalized()
		
		WaWState.CHARGING:
			movement_direction = get_waw_charge_movement()
		
		WaWState.ATTACKING:
			# NO DEBERÍA LLEGAR AQUÍ SI ESTÁ ANCLADO
			movement_direction = Vector2.ZERO
		
		WaWState.STUNNED:
			movement_direction = velocity * 0.1
	
	# Aplicar separación básica
	movement_direction += get_basic_separation() * 0.3
	
	if movement_direction != Vector2.ZERO:
		velocity = movement_direction.normalized() * current_move_speed

func get_waw_charge_movement() -> Vector2:
	"""Carga directa simple"""
	var direction_to_player = (player.global_position - global_position).normalized()
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# SEPARACIÓN BÁSICA
	if distance_to_player < min_separation_distance:
		var repulsion_dir = (global_position - player.global_position).normalized()
		return repulsion_dir * 1.2
	
	# CARGA DIRECTA NORMAL
	return direction_to_player * charge_speed_multiplier

func get_basic_separation() -> Vector2:
	"""Separación básica de otros enemigos"""
	var separation = Vector2.ZERO
	var separation_radius = 60.0
	
	# SEPARACIÓN DE OTROS ZOMBIES
	for other_zombie in get_tree().get_nodes_in_group("enemies"):
		if other_zombie == self or not is_instance_valid(other_zombie):
			continue
		
		var distance = global_position.distance_to(other_zombie.global_position)
		if distance < separation_radius and distance > 0:
			var separation_dir = (global_position - other_zombie.global_position).normalized()
			var strength = 1.0 - (distance / separation_radius)
			separation += separation_dir * strength * 1.0
	
	return separation.normalized() * min(separation.length(), 2.0)

# ===== RESTO DE FUNCIONES (SIMPLIFICADAS) =====

func start_waw_attack():
	"""Ataque simple"""
	if not player or not can_attack():
		return
	
	if sprite:
		sprite.modulate = Color.ORANGE
		var prep_tween = create_tween()
		prep_tween.tween_property(sprite, "scale", sprite.scale * 1.15, 0.1)
	
	execute_waw_attack()

func execute_waw_attack():
	"""Ejecutar ataque"""
	if not player or not is_instance_valid(player):
		finish_attack()
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	if distance_to_player <= attack_range:
		if player.has_method("take_damage"):
			player.take_damage(damage)
		
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
	
	if velocity.length() > 30.0 and not is_anchored:
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
	
	# DESANCLAR AL RECIBIR DAÑO
	unanchor()
	
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
	current_state = WaWState.SPAWNING
	is_anchored = false
	
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
	is_anchored = false
	anchor_position = Vector2.ZERO
	
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
	"""Limpiar al salir"""
	set_physics_process(false)
	set_process(false)
