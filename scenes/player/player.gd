# scenes/player/player.gd - AUDIO ELIMINADO Y COLISIONES CORREGIDAS
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
	
	# CONFIGURAR CAPAS DE COLISIÓN CORRECTAS
	collision_layer = 1  # Jugador en capa 1
	collision_mask = 2 | 3  # Colisiona con enemigos (2) y estructuras (3)

func setup_camera():
	"""Configurar la cámara del jugador para COD Black Ops style"""
	if camera:
		camera.enabled = true
		camera.zoom = Vector2(1.0, 1.0)
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
	"""Aplicar estadísticas del personaje respetando valores originales"""
	if not character_stats:
		return
	
	# Respetar valores del archivo .tres
	max_health = character_stats.max_health
	current_health = character_stats.current_health
	move_speed = float(character_stats.movement_speed)
	
	# Configurar componente de disparo
	if shooting_component:
		shooting_component.update_stats_from_player()
	
	# Configurar renderer del arma
	if weapon_renderer and character_stats.equipped_weapon:
		weapon_renderer.set_weapon_stats(character_stats.equipped_weapon)
	
	# Cargar sprites usando el sistema separado
	load_character_sprites()
	
	is_fully_initialized = true

func load_character_sprites():
	"""Cargar sprites del personaje usando el sistema separado"""
	if not character_stats or not animated_sprite:
		return
	
	var sprite_frames = SpriteEffectsHandler.load_character_sprite_atlas(character_stats.character_name)
	if sprite_frames:
		animated_sprite.sprite_frames = sprite_frames
		animated_sprite.play("idle")
		
		# Escalar a 128px usando el sistema separado
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
	
	# CORREGIR: Verificar colisiones con enemigos para prevenir overlapping
	if is_alive():
		handle_enemy_separation()

func handle_enemy_separation():
	"""Manejar separación de enemigos para evitar que se peguen"""
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = 60.0  # Radio de separación
	query.shape = circle_shape
	query.transform = Transform2D(0, global_position)
	query.collision_mask = 2  # Solo enemigos
	query.exclude = [self]
	
	var results = space_state.intersect_shape(query, 5)
	
	for result in results:
		var enemy = result.collider
		if enemy and enemy.has_method("apply_knockback"):
			var separation_vector = enemy.global_position - global_position
			var distance = separation_vector.length()
			
			if distance > 0 and distance < 60:
				# Empujar al enemigo lejos del jugador
				var push_direction = separation_vector.normalized()
				var push_force = (60 - distance) * 5.0  # Fuerza proporcional a la proximidad
				enemy.apply_knockback(push_direction, push_force)

func handle_movement(_delta):
	"""Manejar movimiento del jugador estilo COD Black Ops"""
	var input_direction = Vector2.ZERO
	
	if is_mobile:
		input_direction = mobile_movement_direction
	else:
		input_direction.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		input_direction.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	
	if input_direction.length() > 1.0:
		input_direction = input_direction.normalized()
	
	# Aplicar efecto de agarre si está siendo agarrado
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
		# AUDIO ELIMINADO - NO reproducir sonido aquí
		
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
	"""Actualizar animaciones del jugador estilo COD Black Ops"""
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
		
		# Voltear sprite según dirección horizontal
		if movement_direction.x < 0:
			animated_sprite.flip_h = true
		elif movement_direction.x > 0:
			animated_sprite.flip_h = false
		
		last_movement_direction = movement_direction
	else:
		# Idle
		if animated_sprite.sprite_frames.has_animation("idle"):
			if animated_sprite.animation != "idle":
				animated_sprite.play("idle")

func get_animation_name_from_direction(direction: Vector2) -> String:
	"""Obtener nombre de animación basado en la dirección"""
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
	"""Actualizar animación al disparar - COD Black Ops style"""
	pass

func take_damage(amount: int):
	"""Recibir daño con efectos estilo COD Black Ops"""
	if is_invulnerable or not is_alive():
		return
	
	if not is_fully_initialized:
		return
	
	print("💔 Jugador recibiendo ", amount, " de daño")
	
	current_health -= amount
	current_health = max(current_health, 0)
	
	# Efectos visuales de daño
	flash_damage_effect()
	
	# Activar invulnerabilidad temporal
	start_invulnerability()
	
	# Resetear racha de kills en score system
	if score_system:
		score_system.reset_kill_streak()
	
	# Screen shake effect (COD Black Ops style)
	apply_screen_shake()
	
	if current_health <= 0:
		die()

func apply_grab_effect(duration: float):
	"""Aplicar efecto de agarre de zombie estilo COD Black Ops"""
	if is_grabbed:
		return
	
	is_grabbed = true
	
	# Efecto visual de agarre
	if animated_sprite:
		var grab_tween = create_tween()
		grab_tween.set_loops(int(duration * 4))
		grab_tween.tween_property(animated_sprite, "modulate", Color.PURPLE, 0.125)
		grab_tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.125)
	
	# Timer para quitar el efecto
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
	"""Aplicar efecto de screen shake estilo COD Black Ops"""
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
	"""Efecto visual al recibir daño estilo COD Black Ops"""
	if not animated_sprite:
		return
	
	# Flash rojo más intenso
	animated_sprite.modulate = Color(2.0, 0.3, 0.3, 1.0)
	
	var tween = create_tween()
	tween.tween_property(animated_sprite, "modulate", Color.WHITE, damage_flash_duration)

func start_invulnerability():
	"""Iniciar periodo de invulnerabilidad estilo COD Black Ops"""
	is_invulnerable = true
	
	# Efecto de parpadeo más visible
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
	"""Manejar muerte del jugador estilo COD Black Ops"""
	velocity = Vector2.ZERO
	set_physics_process(false)
	
	# Efectos visuales de muerte más dramáticos
	if animated_sprite:
		animated_sprite.modulate = Color.RED
		var death_tween = create_tween()
		death_tween.tween_property(animated_sprite, "modulate", Color.BLACK, 1.0)
		death_tween.tween_property(animated_sprite, "modulate:a", 0.1, 1.0)
	
	# Screen fade effect
	apply_death_screen_effect()
	
	player_died.emit()

func apply_death_screen_effect():
	"""Aplicar efecto de pantalla de muerte estilo COD Black Ops"""
	if not camera:
		return
	
	# Crear overlay rojo de muerte
	var death_overlay = ColorRect.new()
	death_overlay.color = Color(0.8, 0.0, 0.0, 0.0)
	death_overlay.size = get_viewport().get_visible_rect().size * 2
	death_overlay.position = -get_viewport().get_visible_rect().size * 0.5
	camera.add_child(death_overlay)
	
	var death_tween = create_tween()
	death_tween.tween_property(death_overlay, "color:a", 0.7, 2.0)

func on_enemy_killed():
	"""ELIMINADO: Sin sonido de kill"""
	# NO hace nada - audio eliminado completamente
	pass

# Funciones de recarga manual
func start_manual_reload():
	"""Iniciar recarga manual cuando el jugador presiona R"""
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
