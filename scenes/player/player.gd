# scenes/player/player.gd - CON MINIHUD Y STATS DEL .tres
extends CharacterBody2D
class_name Player

signal player_died

@export var character_stats: CharacterStats
@onready var animated_sprite = $AnimatedSprite2D
@onready var collision_shape = $CollisionShape2D
@onready var shooting_component = $ShootingComponent
@onready var camera = $Camera2D

# Variables básicas - SE ACTUALIZAN DESDE EL .tres
var current_health: int = 4
var max_health: int = 4
var move_speed: float = 300.0
var is_mobile: bool = false

# Control móvil
var mobile_movement_direction: Vector2 = Vector2.ZERO
var mobile_shoot_direction: Vector2 = Vector2.ZERO
var mobile_is_shooting: bool = false

# Direcciones para animaciones
var current_aim_direction: Vector2 = Vector2.RIGHT

# Referencias
var score_system: ScoreSystem
var weapon_renderer: WeaponRenderer
var animation_controller: AnimationController
var mini_hud: MiniHUD  # REFERENCIA AL MINIHUD

# Estado
var is_fully_initialized: bool = false
var is_invulnerable: bool = false
var invulnerability_duration: float = 2.0

# Límites del mapa
var map_bounds: Rect2 = Rect2(-800, -800, 1600, 1600)

func _ready():
	is_mobile = OS.has_feature("mobile")
	setup_camera()
	setup_weapon_renderer()
	setup_mini_hud()  # CREAR MINIHUD
	
	collision_layer = 1
	collision_mask = 2 | 3
	
	print("🛡️ Jugador inicializado")

func setup_camera():
	"""Configurar cámara"""
	if camera:
		camera.enabled = true
		camera.zoom = Vector2(1.5, 1.5)
		camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
		camera.position_smoothing_enabled = true
		camera.position_smoothing_speed = 8.0

func setup_weapon_renderer():
	"""Configurar renderer del arma"""
	weapon_renderer = WeaponRenderer.new()
	weapon_renderer.name = "WeaponRenderer"
	weapon_renderer.set_player_reference(self)
	add_child(weapon_renderer)

func setup_mini_hud():
	"""CREAR Y CONFIGURAR MINIHUD"""
	mini_hud = MiniHUD.new()
	mini_hud.name = "MiniHUD"
	
	# Obtener CanvasLayer del juego para añadir el HUD
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_node("UIManager"):
		var ui_manager = game_manager.get_node("UIManager")
		ui_manager.add_child(mini_hud)
		print("✅ MiniHUD añadido a UIManager")
	else:
		# Fallback: añadir directamente a la escena
		get_tree().current_scene.add_child(mini_hud)
		print("✅ MiniHUD añadido a escena principal")

func update_character_stats(new_stats: CharacterStats):
	"""ACTUALIZAR ESTADÍSTICAS DESDE EL ARCHIVO .tres"""
	character_stats = new_stats
	apply_character_stats()

func apply_character_stats():
	"""APLICAR ESTADÍSTICAS RESPETANDO EL .tres"""
	if not character_stats:
		print("❌ No hay CharacterStats para aplicar")
		return
	
	# USAR VALORES EXACTOS DEL ARCHIVO .tres
	max_health = character_stats.max_health
	current_health = character_stats.current_health
	move_speed = float(character_stats.movement_speed)
	
	print("📊 APLICANDO STATS DEL .tres:")
	print("   Personaje: ", character_stats.character_name)
	print("   Vida: ", current_health, "/", max_health)
	print("   Velocidad: ", move_speed)
	print("   Suerte: ", character_stats.luck)
	
	# ACTUALIZAR MINIHUD CON LAS ESTADÍSTICAS
	if mini_hud:
		mini_hud.update_character_stats(character_stats)
		print("✅ MiniHUD actualizado con stats del .tres")
	else:
		print("❌ MiniHUD no encontrado")
	
	if shooting_component:
		shooting_component.update_stats_from_player()
	
	if weapon_renderer and character_stats.equipped_weapon:
		weapon_renderer.set_weapon_stats(character_stats.equipped_weapon)
	
	is_fully_initialized = true

func set_animation_controller(controller: AnimationController):
	"""Establecer controlador de animaciones"""
	animation_controller = controller

func set_score_system(score_sys: ScoreSystem):
	"""Establecer sistema de puntuación"""
	score_system = score_sys

func _physics_process(delta):
	if not is_fully_initialized:
		return
		
	handle_movement(delta)
	handle_shooting()
	update_weapon_position()
	
	move_and_slide()

func handle_movement(_delta):
	"""Manejar movimiento"""
	var input_direction = Vector2.ZERO
	
	if is_mobile:
		input_direction = mobile_movement_direction
	else:
		input_direction.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		input_direction.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	
	if input_direction.length() > 1.0:
		input_direction = input_direction.normalized()
	
	velocity = input_direction * move_speed
	apply_map_bounds()
	update_animations(input_direction)

func apply_map_bounds():
	"""Aplicar límites del mapa"""
	var next_position = global_position + velocity * get_physics_process_delta_time()
	
	if next_position.x < map_bounds.position.x:
		velocity.x = max(0, velocity.x)
		global_position.x = map_bounds.position.x
	elif next_position.x > map_bounds.position.x + map_bounds.size.x:
		velocity.x = min(0, velocity.x)
		global_position.x = map_bounds.position.x + map_bounds.size.x
	
	if next_position.y < map_bounds.position.y:
		velocity.y = max(0, velocity.y)
		global_position.y = map_bounds.position.y
	elif next_position.y > map_bounds.position.y + map_bounds.size.y:
		velocity.y = min(0, velocity.y)
		global_position.y = map_bounds.position.y + map_bounds.size.y

func handle_shooting():
	"""Manejar disparo"""
	if not shooting_component:
		return
	
	var shoot_direction = Vector2.ZERO
	
	if is_mobile:
		if mobile_is_shooting and mobile_shoot_direction.length() > 0:
			shoot_direction = mobile_shoot_direction
	else:
		shoot_direction.x = Input.get_action_strength("shoot_right") - Input.get_action_strength("shoot_left")
		shoot_direction.y = Input.get_action_strength("shoot_down") - Input.get_action_strength("shoot_up")
	
	if shoot_direction.length() > 0:
		current_aim_direction = shoot_direction.normalized()
		perform_shoot(current_aim_direction)

func perform_shoot(direction: Vector2):
	"""Realizar disparo"""
	if not shooting_component:
		return
	
	current_aim_direction = direction
	
	var shoot_position = global_position
	if weapon_renderer:
		shoot_position = weapon_renderer.get_muzzle_world_position()
	
	var shot_fired = shooting_component.try_shoot(direction, shoot_position)
	
	if shot_fired and weapon_renderer:
		weapon_renderer.start_shooting_animation()

func update_weapon_position():
	"""Actualizar posición del arma"""
	if not weapon_renderer:
		return
	
	var aim_direction = current_aim_direction
	if aim_direction == Vector2.ZERO:
		aim_direction = Vector2.RIGHT
	
	weapon_renderer.update_weapon_position_and_rotation(aim_direction)

func update_animations(movement_direction: Vector2):
	"""Actualizar animaciones"""
	if animation_controller:
		animation_controller.update_animation(movement_direction, current_aim_direction)

func take_damage(amount: int):
	"""RECIBIR DAÑO - ACTUALIZA MINIHUD"""
	if is_invulnerable or not is_alive():
		print("🛡️ Daño bloqueado - Invulnerable o muerto")
		return
	
	if not is_fully_initialized:
		print("❌ Jugador no inicializado, ignorando daño")
		return
	
	# APLICAR DAÑO
	var old_health = current_health
	current_health -= amount
	current_health = max(current_health, 0)
	
	print("💔 DAÑO RECIBIDO:")
	print("   Daño: ", amount)
	print("   Vida anterior: ", old_health, "/", max_health)
	print("   Vida actual: ", current_health, "/", max_health)
	
	# ACTUALIZAR MINIHUD CON NUEVA VIDA
	if mini_hud:
		mini_hud.update_health(current_health, max_health)
	
	# ACTUALIZAR TAMBIÉN EL CHARACTERSTATS
	if character_stats:
		character_stats.current_health = current_health
	
	# EFECTOS VISUALES
	flash_damage_effect()
	start_invulnerability()
	
	if score_system:
		score_system.reset_kill_streak()
	
	apply_screen_shake()
	
	# VERIFICAR MUERTE
	if current_health <= 0:
		print("💀 Jugador va a morir")
		die()
	else:
		print("✅ Jugador sobrevive con ", current_health, " corazones")

func flash_damage_effect():
	"""Efecto visual de daño"""
	if not animated_sprite:
		return
	
	animated_sprite.modulate = Color(2.0, 0.3, 0.3, 1.0)
	var tween = create_tween()
	tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.3)

func start_invulnerability():
	"""Iniciar invulnerabilidad"""
	is_invulnerable = true
	print("🛡️ Invulnerabilidad activada por ", invulnerability_duration, " segundos")
	
	if animated_sprite:
		var blink_tween = create_tween()
		var blink_count = int(invulnerability_duration * 8)
		blink_tween.set_loops(blink_count)
		blink_tween.tween_property(animated_sprite, "modulate:a", 0.3, 0.0625)
		blink_tween.tween_property(animated_sprite, "modulate:a", 1.0, 0.0625)
	
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
	"""Terminar invulnerabilidad"""
	is_invulnerable = false
	print("🛡️ Invulnerabilidad terminada")
	if animated_sprite:
		animated_sprite.modulate = Color.WHITE

func apply_screen_shake():
	"""Efecto de screen shake"""
	if not camera:
		return
	
	var shake_tween = create_tween()
	var shake_intensity = 8.0
	var shake_duration = 0.4
	
	for i in range(8):
		var shake_offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		shake_tween.tween_property(camera, "offset", shake_offset, shake_duration / 8.0)
	
	shake_tween.tween_property(camera, "offset", Vector2.ZERO, shake_duration / 8.0)

func apply_knockback(direction: Vector2, force: float):
	"""Aplicar knockback"""
	if direction.length() > 0:
		velocity += direction.normalized() * force

func die():
	"""Manejar muerte"""
	print("💀 JUGADOR HA MUERTO - Vida final: ", current_health, "/", max_health)
	velocity = Vector2.ZERO
	set_physics_process(false)
	
	if animated_sprite:
		animated_sprite.modulate = Color.RED
		var death_tween = create_tween()
		death_tween.tween_property(animated_sprite, "modulate", Color.BLACK, 1.0)
		death_tween.tween_property(animated_sprite, "modulate:a", 0.1, 1.0)
	
	player_died.emit()

func heal(amount: int):
	"""Curar jugador y actualizar MiniHUD"""
	var old_health = current_health
	current_health = min(current_health + amount, max_health)
	
	# Actualizar MiniHUD
	if mini_hud:
		mini_hud.update_health(current_health, max_health)
	
	# Actualizar CharacterStats
	if character_stats:
		character_stats.current_health = current_health
	
	print("💚 Curación: ", old_health, " -> ", current_health, "/", max_health)

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

func on_enemy_killed():
	"""Callback cuando mata enemigo"""
	pass

func start_manual_reload():
	"""Iniciar recarga manual"""
	if shooting_component:
		return shooting_component.start_manual_reload()
	return false

func get_ammo_info() -> Dictionary:
	"""Obtener información de munición"""
	if shooting_component:
		return shooting_component.get_ammo_info()
	return {"current": 0, "max": 0, "reloading": false, "reload_progress": 0.0}

func _input(event):
	"""Manejar inputs adicionales"""
	if event.is_action_pressed("ui_accept") and Input.is_key_pressed(KEY_R):
		start_manual_reload()
	
	# DEBUG: Tecla H para curar
	if event.is_action_pressed("ui_home"):
		heal(1)

func _exit_tree():
	"""Limpiar al salir"""
	set_physics_process(false)
	set_process(false)
