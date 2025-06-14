# scenes/player/player.gd
extends CharacterBody2D
class_name Player

signal player_died

@export var character_stats: CharacterStats
@onready var animated_sprite = $AnimatedSprite2D
@onready var collision_shape = $CollisionShape2D
@onready var shooting_component = $ShootingComponent
@onready var health_component = $HealthComponent
@onready var camera = $Camera2D

# Variables de movimiento estilo COD
var current_health: int = 100
var max_health: int = 100
var move_speed: float = 300.0
var is_mobile: bool = false

# Control de movimiento móvil
var mobile_movement_direction: Vector2 = Vector2.ZERO

# Última dirección de movimiento para animaciones
var last_movement_direction: Vector2 = Vector2.ZERO
var last_shot_direction: Vector2 = Vector2.RIGHT

# Score system reference
var score_system: ScoreSystem

# Invulnerabilidad temporal después de recibir daño
var is_invulnerable: bool = false
var invulnerability_duration: float = 1.0
var damage_flash_duration: float = 0.1

# Renderer de arma
var weapon_renderer: WeaponRenderer

# NUEVO: Variable para verificar si está configurado completamente
var is_fully_initialized: bool = false

# ❌ NUEVO: Sistema de sonido de kill SOLO para Pelao
var kill_sound_player: AudioStreamPlayer2D

func _ready():
	is_mobile = OS.has_feature("mobile")
	setup_camera()
	setup_weapon_renderer()
	setup_kill_sound_system()  # ❌ NUEVO
	
	# Configurar collision layers
	collision_layer = 1  # Capa del jugador
	collision_mask = 2   # Detectar enemigos
	
	print("🎮 Jugador inicializado")

func setup_camera():
	"""Configurar la cámara del jugador"""
	if camera:
		camera.enabled = true
		camera.zoom = Vector2(1.5, 1.5)  # Zoom más cercano estilo COD
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

func setup_kill_sound_system():
	"""❌ NUEVO: Configurar sistema de sonido de kill SOLO para Pelao"""
	kill_sound_player = AudioStreamPlayer2D.new()
	kill_sound_player.name = "KillSoundPlayer"
	add_child(kill_sound_player)

func update_character_stats(new_stats: CharacterStats):
	"""Actualizar estadísticas del personaje"""
	character_stats = new_stats
	apply_character_stats()

func apply_character_stats():
	"""Aplicar estadísticas del personaje - CORREGIDO"""
	if not character_stats:
		print("❌ No hay character_stats para aplicar")
		return
	
	# APLICAR CORRECTAMENTE LA VIDA
	max_health = character_stats.max_health
	current_health = character_stats.max_health  # CAMBIO: Usar max_health en lugar de current_health
	move_speed = float(character_stats.movement_speed)
	
	# Asegurarse de que la vida esté en rango válido
	if current_health <= 0:
		current_health = max_health
	
	# Configurar el componente de disparo
	if shooting_component:
		shooting_component.update_stats_from_player()
	
	# Configurar el renderer del arma
	if weapon_renderer and character_stats.equipped_weapon:
		weapon_renderer.set_weapon_stats(character_stats.equipped_weapon)
	
	# ❌ NUEVO: Configurar sonido de kill para Pelao
	setup_pelao_kill_sound()
	
	# Marcar como completamente inicializado
	is_fully_initialized = true
	
	print("✅ Estadísticas aplicadas: ", character_stats.character_name)
	print("💚 Vida configurada: ", current_health, "/", max_health)

func setup_pelao_kill_sound():
	"""❌ NUEVO: Configurar sonido específico para Pelao"""
	if not character_stats:
		return
	
	var char_name = character_stats.character_name.to_lower().replace(" ", "")
	
	# Solo cargar sonido para Pelao
	if char_name == "pelao":
		if ResourceLoader.exists("res://audio/pelao_shoot.ogg"):
			var kill_sound = load("res://audio/pelao_shoot.ogg")
			if kill_sound and kill_sound_player:
				kill_sound_player.stream = kill_sound
				kill_sound_player.volume_db = -5.0  # Volumen más alto para feedback
				kill_sound_player.pitch_scale = 1.2  # Pitch más alto para diferenciarlo del disparo
				print("🔊 Sonido de kill configurado para Pelao")
		else:
			print("❌ No se encontró audio/pelao_shoot.ogg")
	else:
		# Para otros personajes, limpiar el sonido
		if kill_sound_player:
			kill_sound_player.stream = null
		print("🔇 Sin sonido de kill para: ", char_name)

func set_score_system(score_sys: ScoreSystem):
	"""Establecer referencia al sistema de puntuación"""
	score_system = score_sys

func _physics_process(delta):
	# NUEVO: Solo procesar si está completamente inicializado
	if not is_fully_initialized:
		return
		
	handle_movement(delta)
	handle_shooting()
	
	# Actualizar posición del arma
	update_weapon_position()
	
	# Mover y manejar colisiones
	move_and_slide()
	
	# Manejar colisiones con enemigos SOLO si está vivo
	if is_alive():
		handle_enemy_collisions()

func handle_movement(_delta):
	"""Manejar movimiento del jugador"""
	var input_direction = Vector2.ZERO
	
	if is_mobile:
		# Usar dirección del joystick móvil
		input_direction = mobile_movement_direction
	else:
		# Controles de teclado/gamepad
		input_direction.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		input_direction.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	
	# Normalizar para movimiento diagonal consistente
	if input_direction.length() > 1.0:
		input_direction = input_direction.normalized()
	
	# Aplicar velocidad
	velocity = input_direction * move_speed
	
	# Actualizar animaciones
	update_animations(input_direction)

func handle_shooting():
	"""Manejar disparo del jugador"""
	if not shooting_component:
		return
	
	var shoot_direction = Vector2.ZERO
	
	if is_mobile:
		# El GameManager maneja el disparo móvil
		return
	else:
		# Controles de teclado
		shoot_direction.x = Input.get_action_strength("shoot_right") - Input.get_action_strength("shoot_left")
		shoot_direction.y = Input.get_action_strength("shoot_down") - Input.get_action_strength("shoot_up")
	
	if shoot_direction.length() > 0:
		perform_shoot(shoot_direction.normalized())

func mobile_shoot(direction: Vector2):
	"""Función para disparar desde controles móviles"""
	if direction.length() > 0:
		perform_shoot(direction.normalized())

func perform_shoot(direction: Vector2):
	"""Realizar disparo en la dirección especificada"""
	if not shooting_component:
		return
	
	last_shot_direction = direction
	
	# Obtener posición del cañón desde el weapon renderer
	var shoot_position = global_position
	if weapon_renderer:
		shoot_position = weapon_renderer.get_muzzle_world_position()
	elif character_stats and character_stats.equipped_weapon:
		var weapon = character_stats.equipped_weapon
		shoot_position = weapon.get_muzzle_world_position(global_position, direction)
	
	# Intentar disparar
	var shot_fired = shooting_component.try_shoot(direction, shoot_position)
	
	if shot_fired:
		# Reproducir sonido de disparo si existe
		play_shoot_sound()
		
		# Actualizar animación de disparo en el weapon renderer
		if weapon_renderer:
			weapon_renderer.start_shooting_animation()
		
		# Actualizar animación de disparo del jugador
		update_shooting_animation(direction)

func update_weapon_position():
	"""Actualizar posición y rotación del arma"""
	if not weapon_renderer:
		return
	
	# Usar la última dirección de disparo o movimiento
	var aim_direction = last_shot_direction
	if aim_direction == Vector2.ZERO and last_movement_direction != Vector2.ZERO:
		aim_direction = last_movement_direction
	elif aim_direction == Vector2.ZERO:
		aim_direction = Vector2.RIGHT  # Dirección por defecto
	
	weapon_renderer.update_weapon_position_and_rotation(aim_direction)

func play_shoot_sound():
	"""Reproducir sonido de disparo"""
	if character_stats and character_stats.equipped_weapon and character_stats.equipped_weapon.attack_sound:
		# Crear AudioStreamPlayer2D temporal
		var audio_player = AudioStreamPlayer2D.new()
		audio_player.stream = character_stats.equipped_weapon.attack_sound
		audio_player.pitch_scale = randf_range(0.9, 1.1)  # Variación en el pitch
		audio_player.volume_db = -10.0  # Volumen moderado
		
		get_tree().current_scene.add_child(audio_player)
		audio_player.play()
		
		# Limpiar el reproductor después de que termine
		audio_player.finished.connect(func(): audio_player.queue_free())

func update_animations(movement_direction: Vector2):
	"""Actualizar animaciones del jugador"""
	if not animated_sprite or not animated_sprite.sprite_frames:
		return
	
	if movement_direction.length() > 0.1:
		# Determinar animación basada en la dirección
		var animation_name = get_animation_name_from_direction(movement_direction)
		
		# Reproducir animación si existe
		if animated_sprite.sprite_frames.has_animation(animation_name):
			if animated_sprite.animation != animation_name:
				animated_sprite.play(animation_name)
		else:
			# Fallback a animación básica
			if animated_sprite.sprite_frames.has_animation("walk_Right_Down"):
				animated_sprite.play("walk_Right_Down")
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
	
	# Normalizar ángulo entre 0 y 360
	if degrees < 0:
		degrees += 360
	
	# Determinar dirección principal
	if degrees >= 315 or degrees < 45:
		return "walk_Right_Down"  # Derecha
	elif degrees >= 45 and degrees < 135:
		return "walk_Down"  # Abajo
	elif degrees >= 135 and degrees < 225:
		return "walk_Left_Down"  # Izquierda
	else:
		return "walk_Up"  # Arriba

func update_shooting_animation(_shoot_direction: Vector2):
	"""Actualizar animación al disparar"""
	# Aquí se podría añadir lógica específica para animaciones de disparo del jugador
	# Por ejemplo, cambiar temporalmente a un sprite de disparo
	pass

func handle_enemy_collisions():
	"""Manejar colisiones con enemigos - MEJORADO"""
	if is_invulnerable or not is_alive():
		return
	
	# Verificar colisiones con enemigos
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if collider is Enemy:
			var enemy = collider as Enemy
			if not enemy.is_dead:
				# Recibir daño del enemigo
				take_damage(enemy.damage)
				
				# Aplicar knockback
				var knockback_direction = (global_position - enemy.global_position).normalized()
				apply_knockback(knockback_direction, 100.0)
				
				break

func take_damage(amount: int):
	"""Recibir daño - MEJORADO CON VALIDACIONES"""
	if is_invulnerable or not is_alive():
		return
	
	# VALIDACIÓN EXTRA: Asegurarse de que está inicializado
	if not is_fully_initialized:
		print("⚠ Intentando hacer daño a jugador no inicializado")
		return
	
	current_health -= amount
	current_health = max(current_health, 0)
	
	print("💔 Jugador recibe ", amount, " de daño. Vida restante: ", current_health)
	
	# Efectos visuales de daño
	flash_damage_effect()
	
	# Activar invulnerabilidad temporal
	start_invulnerability()
	
	# Resetear racha de kills en score system
	if score_system:
		score_system.reset_kill_streak()
	
	# Verificar muerte
	if current_health <= 0:
		die()

func flash_damage_effect():
	"""Efecto visual al recibir daño"""
	if not animated_sprite:
		return
	
	# Flash rojo
	animated_sprite.modulate = Color.RED
	
	var tween = create_tween()
	tween.tween_property(animated_sprite, "modulate", Color.WHITE, damage_flash_duration)

func start_invulnerability():
	"""Iniciar periodo de invulnerabilidad"""
	is_invulnerable = true
	
	# Efecto de parpadeo
	if animated_sprite:
		var blink_tween = create_tween()
		blink_tween.set_loops(int(invulnerability_duration * 8))  # 8 parpadeos por segundo
		blink_tween.tween_property(animated_sprite, "modulate:a", 0.5, 0.0625)
		blink_tween.tween_property(animated_sprite, "modulate:a", 1.0, 0.0625)
	
	# Timer de invulnerabilidad
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
	print("💚 Jugador curado. Vida actual: ", current_health, "/", max_health)

func die():
	"""Manejar muerte del jugador"""
	print("💀 JUGADOR HA MUERTO")
	
	# Detener movimiento
	velocity = Vector2.ZERO
	set_physics_process(false)
	
	# Efectos visuales de muerte
	if animated_sprite:
		animated_sprite.modulate = Color.GRAY
		var death_tween = create_tween()
		death_tween.tween_property(animated_sprite, "modulate:a", 0.3, 1.0)
	
	# Emitir señal de muerte
	player_died.emit()

func on_enemy_killed():
	"""❌ NUEVO: Llamar cuando el jugador mata un enemigo - SOLO SONIDO PARA PELAO"""
	if not character_stats:
		return
	
	var char_name = character_stats.character_name.to_lower().replace(" ", "")
	
	# Solo reproducir sonido para Pelao
	if char_name == "pelao" and kill_sound_player and kill_sound_player.stream:
		# Reproducir sonido de kill con variación
		kill_sound_player.pitch_scale = randf_range(1.1, 1.3)  # Pitch más alto que el disparo
		kill_sound_player.play()
		print("🔊 Pelao: Sonido de kill reproducido")
	else:
		print("🔇 ", char_name, ": Sin sonido de kill")

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
	"""Obtener vida actual"""
	return current_health

func get_max_health() -> int:
	"""Obtener vida máxima"""
	return max_health

func is_alive() -> bool:
	"""Verificar si el jugador está vivo"""
	return current_health > 0 and is_fully_initialized

func get_weapon_stats() -> WeaponStats:
	"""Obtener estadísticas del arma equipada"""
	if character_stats:
		return character_stats.equipped_weapon
	return null

# Input adicional para recarga manual
func _input(event):
	"""Manejar inputs adicionales como recarga"""
	if event.is_action_pressed("ui_accept") and Input.is_key_pressed(KEY_R):
		start_manual_reload()

# Debug y información
func debug_player_info():
	"""Mostrar información de debug del jugador"""
	print("=== DEBUG JUGADOR ===")
	print("Posición: ", global_position)
	print("Vida: ", current_health, "/", max_health)
	print("Velocidad: ", move_speed)
	print("Móvil: ", is_mobile)
	print("Invulnerable: ", is_invulnerable)
	print("Inicializado: ", is_fully_initialized)
	if character_stats:
		print("Personaje: ", character_stats.character_name)
		if character_stats.equipped_weapon:
			print("Arma: ", character_stats.equipped_weapon.weapon_name)
	print("====================")

# Función para obtener la cámara (útil para UI)
func get_camera() -> Camera2D:
	"""Obtener la cámara del jugador"""
	return camera
