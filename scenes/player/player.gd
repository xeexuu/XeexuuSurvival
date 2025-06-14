# scenes/player/player.gd - AUDIO CORREGIDO Y VISTA DESDE ARRIBA
extends CharacterBody2D
class_name Player

signal player_died

@export var character_stats: CharacterStats
@onready var animated_sprite = $AnimatedSprite2D
@onready var collision_shape = $CollisionShape2D
@onready var shooting_component = $ShootingComponent
@onready var health_component = $HealthComponent
@onready var camera = $Camera2D

# Variables de movimiento estilo COD Black Ops
var current_health: int = 4
var max_health: int = 4
var move_speed: float = 300.0
var is_mobile: bool = false

# Control de movimiento móvil
var mobile_movement_direction: Vector2 = Vector2.ZERO

# Direcciones para animaciones y disparos
var last_movement_direction: Vector2 = Vector2.ZERO
var last_shot_direction: Vector2 = Vector2.RIGHT

# Referencias a sistemas
var score_system: ScoreSystem
var weapon_renderer: WeaponRenderer

# AUDIO SIN SOLAPAMIENTO
var audio_player: AudioStreamPlayer2D
var last_audio_time: float = 0.0
var audio_cooldown: float = 0.1

# Efectos de daño estilo COD Black Ops
var is_invulnerable: bool = false
var invulnerability_duration: float = 1.0
var damage_flash_duration: float = 0.1

# Estado de inicialización
var is_fully_initialized: bool = false

# Efectos de agarre de zombies
var is_grabbed: bool = false
var grab_slowdown_factor: float = 0.3
var grab_effect_duration: float = 1.0

func _ready():
	is_mobile = OS.has_feature("mobile")
	setup_camera()
	setup_weapon_renderer()
	setup_audio_player()
	
	# CONFIGURAR CAPAS DE COLISIÓN CORRECTAS
	collision_layer = 1
	collision_mask = 2 | 3

func setup_audio_player():
	"""Configurar reproductor de audio sin solapamiento"""
	audio_player = AudioStreamPlayer2D.new()
	audio_player.name = "AudioPlayer"
	add_child(audio_player)

func setup_camera():
	"""Configurar la cámara para vista desde arriba"""
	if camera:
		camera.enabled = true
		camera.zoom = Vector2(1.5, 1.5)  # Zoom para mejor vista
		camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
		camera.position_smoothing_enabled = true
		camera.position_smoothing_speed = 8.0
		camera.rotation_smoothing_enabled = false

func setup_weapon_renderer():
	"""Configurar el renderer del arma"""
	weapon_renderer = WeaponRenderer.new()
	weapon_renderer.name = "WeaponRenderer"
	weapon_renderer.set_player_reference(self)
	add_child(weapon_renderer)

func update_character_stats(new_stats: CharacterStats):
	"""Actualizar estadísticas del personaje"""
	character_stats = new_stats
	apply_character_stats()

func apply_character_stats():
	"""Aplicar estadísticas del personaje"""
	if not character_stats:
		return
	
	# RESPETAR VALORES ORIGINALES DEL ARCHIVO
	max_health = character_stats.max_health
	current_health = character_stats.current_health
	move_speed = float(character_stats.movement_speed)
	
	# Configurar componente de disparo
	if shooting_component:
		shooting_component.update_stats_from_player()
	
	# Configurar renderer del arma
	if weapon_renderer and character_stats.equipped_weapon:
		weapon_renderer.set_weapon_stats(character_stats.equipped_weapon)
	
	# Cargar sprites
	load_character_sprites()
	
	is_fully_initialized = true

func load_character_sprites():
	"""Cargar sprites del personaje"""
	if not character_stats or not animated_sprite:
		return
	
	var sprite_frames = SpriteEffectsHandler.load_character_sprite_atlas(character_stats.character_name)
	if sprite_frames:
		animated_sprite.sprite_frames = sprite_frames
		animated_sprite.play("idle")
		
		var reference_texture = sprite_frames.get_frame_texture("idle", 0)
		SpriteEffectsHandler.scale_sprite_to_128px(animated_sprite, reference_texture)

func set_score_system(score_sys: ScoreSystem):
	"""Establecer referencia al sistema de puntuación"""
	score_system = score_sys

func _physics_process(delta):
	if not is_fully_initialized:
		return
		
	handle_movement(delta)
	handle_shooting()
	update_weapon_position()
	
	move_and_slide()
	
	if is_alive():
		handle_enemy_separation()

func handle_enemy_separation():
	"""Separación de enemigos para evitar overlapping"""
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = 60.0
	query.shape = circle_shape
	query.transform = Transform2D(0, global_position)
	query.collision_mask = 2
	query.exclude = [self]
	
	var results = space_state.intersect_shape(query, 5)
	
	for result in results:
		var enemy = result.collider
		if enemy and enemy.has_method("apply_knockback"):
			var separation_vector = enemy.global_position - global_position
			var distance = separation_vector.length()
			
			if distance > 0 and distance < 60:
				var push_direction = separation_vector.normalized()
				var push_force = (60 - distance) * 5.0
				enemy.apply_knockback(push_direction, push_force)

func handle_movement(_delta):
	"""Manejar movimiento del jugador"""
	var input_direction = Vector2.ZERO
	
	if is_mobile:
		input_direction = mobile_movement_direction
	else:
		input_direction.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		input_direction.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	
	if input_direction.length() > 1.0:
		input_direction = input_direction.normalized()
	
	var final_speed = move_speed
	if is_grabbed:
		final_speed *= grab_slowdown_factor
	
	velocity = input_direction * final_speed
	update_animations(input_direction)

func handle_shooting():
	"""Manejar disparo del jugador"""
	if not shooting_component or is_grabbed:
		return
	
	var shoot_direction = Vector2.ZERO
	
	if is_mobile:
		return
	else:
		shoot_direction.x = Input.get_action_strength("shoot_right") - Input.get_action_strength("shoot_left")
		shoot_direction.y = Input.get_action_strength("shoot_down") - Input.get_action_strength("shoot_up")
	
	if shoot_direction.length() > 0:
		perform_shoot(shoot_direction.normalized())

func mobile_shoot(direction: Vector2):
	"""Función para disparar desde controles móviles"""
	if direction.length() > 0 and not is_grabbed:
		perform_shoot(direction.normalized())

func perform_shoot(direction: Vector2):
	"""Realizar disparo en la dirección especificada"""
	if not shooting_component:
		return
	
	last_shot_direction = direction
	
	var shoot_position = global_position
	if weapon_renderer:
		shoot_position = weapon_renderer.get_muzzle_world_position()
	elif character_stats and character_stats.equipped_weapon:
		var weapon = character_stats.equipped_weapon
		shoot_position = weapon.get_muzzle_world_position(global_position, direction)
	
	var shot_fired = shooting_component.try_shoot(direction, shoot_position)
	
	if shot_fired:
		if weapon_renderer:
			weapon_renderer.start_shooting_animation()
		
		update_shooting_animation(direction)

func update_weapon_position():
	"""Actualizar posición y rotación del arma"""
	if not weapon_renderer:
		return
	
	var aim_direction = last_shot_direction
	if aim_direction == Vector2.ZERO and last_movement_direction != Vector2.ZERO:
		aim_direction = last_movement_direction
	elif aim_direction == Vector2.ZERO:
		aim_direction = Vector2.RIGHT
	
	weapon_renderer.update_weapon_position_and_rotation(aim_direction)

func update_animations(movement_direction: Vector2):
	"""Actualizar animaciones del jugador para vista desde arriba"""
	if not animated_sprite or not animated_sprite.sprite_frames:
		return
	
	if movement_direction.length() > 0.1:
		var animation_name = get_animation_name_from_direction(movement_direction)
		
		if animated_sprite.sprite_frames.has_animation(animation_name):
			if animated_sprite.animation != animation_name:
				animated_sprite.play(animation_name)
		else:
			if animated_sprite.sprite_frames.has_animation("walk"):
				animated_sprite.play("walk")
			elif animated_sprite.sprite_frames.has_animation("idle"):
				animated_sprite.play("idle")
		
		# Para vista desde arriba: voltear según dirección horizontal
		if movement_direction.x < 0:
			animated_sprite.flip_h = true
		elif movement_direction.x > 0:
			animated_sprite.flip_h = false
		
		last_movement_direction = movement_direction
	else:
		if animated_sprite.sprite_frames.has_animation("idle"):
			if animated_sprite.animation != "idle":
				animated_sprite.play("idle")

func get_animation_name_from_direction(direction: Vector2) -> String:
	"""Obtener nombre de animación para vista desde arriba"""
	var angle = direction.angle()
	var degrees = rad_to_deg(angle)
	
	if degrees < 0:
		degrees += 360
	
	if degrees >= 315 or degrees < 45:
		return "walk_Right"
	elif degrees >= 45 and degrees < 135:
		return "walk_Down"
	elif degrees >= 135 and degrees < 225:
		return "walk_Left"
	else:
		return "walk_Up"

func update_shooting_animation(_shoot_direction: Vector2):
	"""Actualizar animación al disparar"""
	pass

func take_damage(amount: int):
	"""Recibir daño con efectos estilo COD Black Ops"""
	if is_invulnerable or not is_alive():
		return
	
	if not is_fully_initialized:
		return
	
	current_health -= amount
	current_health = max(current_health, 0)
	
	flash_damage_effect()
	start_invulnerability()
	
	if score_system:
		score_system.reset_kill_streak()
	
	apply_screen_shake()
	
	if current_health <= 0:
		die()

func apply_grab_effect(duration: float):
	"""Aplicar efecto de agarre de zombie"""
	if is_grabbed:
		return
	
	is_grabbed = true
	
	if animated_sprite:
		var grab_tween = create_tween()
		grab_tween.set_loops(int(duration * 4))
		grab_tween.tween_property(animated_sprite, "modulate", Color.PURPLE, 0.125)
		grab_tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.125)
	
	var grab_timer = Timer.new()
	grab_timer.wait_time = duration
	grab_timer.one_shot = true
	grab_timer.timeout.connect(func(): 
		end_grab_effect()
		grab_timer.queue_free()
	)
	add_child(grab_timer)
	grab_timer.start()

func end_grab_effect():
	"""Terminar efecto de agarre"""
	is_grabbed = false
	if animated_sprite:
		animated_sprite.modulate = Color.WHITE

func apply_screen_shake():
	"""Aplicar efecto de screen shake"""
	if not camera:
		return
	
	var shake_tween = create_tween()
	var shake_intensity = 5.0
	var shake_duration = 0.3
	
	for i in range(6):
		var shake_offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		shake_tween.tween_property(camera, "offset", shake_offset, shake_duration / 6.0)
	
	shake_tween.tween_property(camera, "offset", Vector2.ZERO, shake_duration / 6.0)

func flash_damage_effect():
	"""Efecto visual al recibir daño"""
	if not animated_sprite:
		return
	
	animated_sprite.modulate = Color(2.0, 0.3, 0.3, 1.0)
	
	var tween = create_tween()
	tween.tween_property(animated_sprite, "modulate", Color.WHITE, damage_flash_duration)

func start_invulnerability():
	"""Iniciar periodo de invulnerabilidad"""
	is_invulnerable = true
	
	if animated_sprite:
		var blink_tween = create_tween()
		blink_tween.set_loops(int(invulnerability_duration * 6))
		blink_tween.tween_property(animated_sprite, "modulate:a", 0.3, 0.083)
		blink_tween.tween_property(animated_sprite, "modulate:a", 1.0, 0.083)
	
	var invul_timer = Timer.new()
	invul_timer.wait_time = invulnerability_duration
	invul_timer.one_shot = true
	invul_timer.timeout.connect(func(): 
		end_invulnerability()
		invul_timer.queue_free()
	)
	add_child(invul_timer)
	invul_timer.start()

func end_invulnerability():
	"""Terminar periodo de invulnerabilidad"""
	is_invulnerable = false
	if animated_sprite:
		animated_sprite.modulate = Color.WHITE

func apply_knockback(direction: Vector2, force: float):
	"""Aplicar knockback al jugador"""
	if direction.length() > 0:
		velocity += direction.normalized() * force

func heal(amount: int):
	"""Curar al jugador"""
	current_health = min(current_health + amount, max_health)

func die():
	"""Manejar muerte del jugador"""
	velocity = Vector2.ZERO
	set_physics_process(false)
	
	if animated_sprite:
		animated_sprite.modulate = Color.RED
		var death_tween = create_tween()
		death_tween.tween_property(animated_sprite, "modulate", Color.BLACK, 1.0)
		death_tween.tween_property(animated_sprite, "modulate:a", 0.1, 1.0)
	
	apply_death_screen_effect()
	player_died.emit()

func apply_death_screen_effect():
	"""Aplicar efecto de pantalla de muerte"""
	if not camera:
		return
	
	var death_overlay = ColorRect.new()
	death_overlay.color = Color(0.8, 0.0, 0.0, 0.0)
	death_overlay.size = get_viewport().get_visible_rect().size * 2
	death_overlay.position = -get_viewport().get_visible_rect().size * 0.5
	camera.add_child(death_overlay)
	
	var death_tween = create_tween()
	death_tween.tween_property(death_overlay, "color:a", 0.7, 2.0)

func on_enemy_killed():
	"""Reproducir audio SIN SOLAPAMIENTO cuando mata enemigo"""
	var current_time = Time.get_ticks_msec() / 1000.0
	
	if current_time - last_audio_time >= audio_cooldown:
		if character_stats and character_stats.equipped_weapon and character_stats.equipped_weapon.attack_sound:
			if audio_player and not audio_player.playing:
				audio_player.stream = character_stats.equipped_weapon.attack_sound
				audio_player.play()
				last_audio_time = current_time

func start_manual_reload():
	"""Iniciar recarga manual"""
	if shooting_component:
		return shooting_component.start_manual_reload()
	return false

func get_ammo_info() -> Dictionary:
	"""Obtener información de munición para la UI"""
	if shooting_component:
		return shooting_component.get_ammo_info()
	return {"current": 0, "max": 0, "reloading": false, "reload_progress": 0.0}

# Funciones de información del jugador
func get_current_health() -> int:
	return current_health

func get_max_health() -> int:
	return max_health

func is_alive() -> bool:
	return current_health > 0 and is_fully_initialized

func get_weapon_stats() -> WeaponStats:
	if character_stats:
		return character_stats.equipped_weapon
	return null

func get_camera() -> Camera2D:
	return camera

func _input(event):
	"""Manejar inputs adicionales como recarga"""
	if event.is_action_pressed("ui_accept") and Input.is_key_pressed(KEY_R):
		start_manual_reload()

func _exit_tree():
	"""Limpiar recursos al salir del árbol"""
	set_physics_process(false)
	set_process(false)
