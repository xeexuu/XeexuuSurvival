# scenes/enemies/Enemy.gd - COMPLETO CORREGIDO SIN PRINTS
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
var enemy_sprite_frames: SpriteFrames

enum WaWState {
	SPAWNING,
	HUNTING,
	CHARGING,
	ATTACKING,
	STUNNED
}

var current_state: WaWState = WaWState.SPAWNING
var state_timer: float = 0.0
var last_known_player_position: Vector2
var charge_speed_multiplier: float = 1.5
var min_separation_distance: float = 35.0
var max_separation_distance: float = 50.0
var is_anchored: bool = false
var anchor_position: Vector2

func _ready():
	add_to_group("enemies")
	setup_enemy()
	determine_waw_variant()
	call_deferred("verify_sprite_after_ready")

func verify_sprite_after_ready():
	"""Verificar sprite después de _ready"""
	if not sprite or not sprite.visible:
		load_enemy_sprite_waw_size()
		force_sprite_visibility()

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
	"""Configurar barra de vida CON NÚMEROS VISIBLES"""
	if not health_bar:
		health_bar = ProgressBar.new()
		health_bar.size = Vector2(100, 16)
		health_bar.position = Vector2(-50, -70)
		add_child(health_bar)
	
	health_bar.max_value = max_health
	health_bar.value = current_health
	health_bar.show_percentage = false
	health_bar.visible = true
	
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color.BLACK
	style_bg.border_color = Color.WHITE
	style_bg.border_width_left = 1
	style_bg.border_width_right = 1
	style_bg.border_width_top = 1
	style_bg.border_width_bottom = 1
	health_bar.add_theme_stylebox_override("background", style_bg)
	
	var style_fill = StyleBoxFlat.new()
	style_fill.bg_color = Color.RED
	health_bar.add_theme_stylebox_override("fill", style_fill)
	
	setup_health_text()

func setup_health_text():
	"""Configurar texto de vida encima de la barra"""
	var health_text = get_node_or_null("HealthText")
	if health_text:
		health_text.queue_free()
	
	health_text = Label.new()
	health_text.name = "HealthText"
	health_text.text = str(current_health) + "/" + str(max_health)
	health_text.add_theme_font_size_override("font_size", 14)
	health_text.add_theme_color_override("font_color", Color.WHITE)
	health_text.add_theme_color_override("font_shadow_color", Color.BLACK)
	health_text.add_theme_constant_override("shadow_offset_x", 1)
	health_text.add_theme_constant_override("shadow_offset_y", 1)
	health_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	health_text.position = Vector2(-25, -90)
	health_text.size = Vector2(50, 16)
	
	add_child(health_text)

func force_sprite_visibility():
	"""Forzar que el sprite sea visible"""
	if sprite:
		sprite.visible = true
		sprite.modulate = Color.WHITE
		sprite.scale = Vector2(1.0, 1.0)
		
		if sprite is AnimatedSprite2D:
			var animated_sprite = sprite as AnimatedSprite2D
			if animated_sprite.sprite_frames:
				if not animated_sprite.is_playing():
					animated_sprite.play("idle")
			else:
				load_enemy_sprite_waw_size()

func setup_for_spawn(target_player: Player, round_health: int = -1):
	"""Configurar para spawn - SIN RESETEAR BARRA DE VIDA"""
	player = target_player
	
	# Configurar salud si se proporciona
	if round_health > 0:
		max_health = round_health
	
	# Aplicar modificadores de variante
	match enemy_type:
		"zombie_runner":
			max_health = int(float(max_health) * 0.6)
		"zombie_charger":
			max_health = int(float(max_health) * 0.8)
		"zombie_crawler":
			max_health = int(float(max_health) * 1.3)
	
	current_health = max_health
	is_dead = false
	current_state = WaWState.SPAWNING
	is_anchored = false
	anchor_position = Vector2.ZERO
	
	modulate = Color(1, 1, 1, 1)
	scale = Vector2(1.0, 1.0)
	force_sprite_visibility()
	
	call_deferred("_reactivate_collision")
	update_health_bar()
	start_spawn_animation()

func start_spawn_animation():
	"""Spawn sin ocultar sprite"""
	current_state = WaWState.SPAWNING
	
	var spawn_timer = Timer.new()
	spawn_timer.wait_time = 0.1
	spawn_timer.one_shot = true
	spawn_timer.timeout.connect(func():
		current_state = WaWState.HUNTING
		state_timer = 0.0
		spawn_timer.queue_free()
	)
	add_child(spawn_timer)
	spawn_timer.start()

func update_health_bar():
	"""Actualizar barra de vida Y texto"""
	if not health_bar:
		setup_health_bar()
		return
	
	health_bar.value = current_health
	health_bar.max_value = max_health
	health_bar.visible = true
	
	var health_text = get_node_or_null("HealthText")
	if not health_text:
		setup_health_text()
		health_text = get_node_or_null("HealthText")
	
	if health_text:
		health_text.text = str(current_health) + "/" + str(max_health)
		
		var health_percentage = float(current_health) / float(max_health)
		if health_percentage > 0.7:
			health_text.add_theme_color_override("font_color", Color.WHITE)
		elif health_percentage > 0.3:
			health_text.add_theme_color_override("font_color", Color.YELLOW)
		else:
			health_text.add_theme_color_override("font_color", Color.RED)

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
				anchor_at_current_position()
				start_waw_attack()
		
		WaWState.ATTACKING:
			if distance_to_player <= attack_range and can_attack():
				execute_waw_attack()
			elif distance_to_player > attack_range * 1.5:
				unanchor()
				current_state = WaWState.CHARGING
				state_timer = 0.0
		
		WaWState.STUNNED:
			if state_timer > 0.1:
				unanchor()
				current_state = WaWState.CHARGING
				state_timer = 0.0

func anchor_at_current_position():
	"""Anclar posición durante ataque"""
	is_anchored = true
	anchor_position = global_position

func unanchor():
	"""Desanclar - permitir movimiento normal"""
	is_anchored = false
	anchor_position = Vector2.ZERO

func handle_waw_movement(_delta):
	"""Movimiento con anclaje"""
	var movement_direction = Vector2.ZERO
	
	if is_anchored:
		velocity = Vector2.ZERO
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
			movement_direction = Vector2.ZERO
		
		WaWState.STUNNED:
			movement_direction = velocity * 0.1
	
	movement_direction += get_basic_separation() * 0.3
	
	if movement_direction != Vector2.ZERO:
		velocity = movement_direction.normalized() * current_move_speed

func get_waw_charge_movement() -> Vector2:
	"""Carga directa simple"""
	var direction_to_player = (player.global_position - global_position).normalized()
	var distance_to_player = global_position.distance_to(player.global_position)
	
	if distance_to_player < min_separation_distance:
		var repulsion_dir = (global_position - player.global_position).normalized()
		return repulsion_dir * 1.2
	
	return direction_to_player * charge_speed_multiplier

func get_basic_separation() -> Vector2:
	"""Separación básica de otros enemigos"""
	var separation = Vector2.ZERO
	var separation_radius = 60.0
	
	for other_zombie in get_tree().get_nodes_in_group("enemies"):
		if other_zombie == self or not is_instance_valid(other_zombie):
			continue
		
		var distance = global_position.distance_to(other_zombie.global_position)
		if distance < separation_radius and distance > 0:
			var separation_dir = (global_position - other_zombie.global_position).normalized()
			var strength = 1.0 - (distance / separation_radius)
			separation += separation_dir * strength * 1.0
	
	return separation.normalized() * min(separation.length(), 2.0)

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
	"""Recibir daño con texto actualizado"""
	if is_dead:
		return
	
	current_health -= amount
	current_health = max(current_health, 0)
	
	current_state = WaWState.STUNNED
	state_timer = 0.0
	
	unanchor()
	
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
	"""Muerte con texto"""
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
	
	var health_text = get_node_or_null("HealthText")
	if health_text:
		health_text.visible = false
	
	died.emit(self)

func reset_for_pool():
	"""Reset para pool SIN RESETEAR barra de vida"""
	is_dead = false
	current_state = WaWState.SPAWNING
	current_health = max_health
	is_anchored = false
	anchor_position = Vector2.ZERO
	
	call_deferred("_deactivate_collision")
	
	if sprite:
		sprite.visible = true
		sprite.modulate = Color.WHITE
		sprite.scale = Vector2(1.0, 1.0)
	
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
