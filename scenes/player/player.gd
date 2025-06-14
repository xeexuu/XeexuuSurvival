# scenes/player/player.gd
extends CharacterBody2D
class_name Player

signal player_died
signal health_changed(current_health: int, max_health: int)

@export var speed: float = 150.0  # Velocidad estilo COD zombies
@export var character_stats: CharacterStats

@onready var animated_sprite = $AnimatedSprite2D
@onready var camera = $Camera2D
@onready var shooting_component = $ShootingComponent
@onready var collision_shape = $CollisionShape2D

# NUEVO: Componente de renderizado de arma
var weapon_renderer: WeaponRenderer

# SISTEMA DE AUDIO SIMPLE
var audio_player: AudioStreamPlayer2D
var is_audio_playing: bool = false

var bullets_fired: int = 0
var current_health: int = 100
var is_dead: bool = false  # NUEVO: Estado de muerte

# SISTEMA DE ANIMACIONES SIMPLIFICADO - SIN IZQUIERDA/DERECHA
enum AnimationState {
	IDLE,
	WALK_UP,
	WALK_DOWN,
	WALK_UP_LEFT,
	WALK_UP_RIGHT,
	WALK_DOWN_LEFT,
	WALK_DOWN_RIGHT
}

var current_animation_state: AnimationState = AnimationState.IDLE

# Control de orientación y estado
var facing_right: bool = true
var last_movement_direction: Vector2 = Vector2.ZERO
var current_aim_direction: Vector2 = Vector2(1, 0)

# Movimiento móvil
var mobile_movement_direction: Vector2 = Vector2.ZERO

# Límites del mapa
var map_bounds: Rect2 = Rect2(-800, -800, 1600, 1600)
var camera_bounds: Rect2 = Rect2(-900, -900, 1800, 1800)

var is_mobile: bool = false

# NUEVO: Sistema de sonido de Pelao cuando mata enemigos
var pelao_kill_sound: AudioStream
var kill_sound_chance: float = 0.3  # 30% probabilidad

# REFERENCIAS DEL SISTEMA
var score_system: ScoreSystem = null

func _ready():
	is_mobile = OS.has_feature("mobile")
	z_index = 50
	
	if not animated_sprite:
		push_error("AnimatedSprite2D no encontrado. Asegúrate de que esté en la escena.")
		return
	
	# Configurar estadísticas por defecto si no las hay
	if not character_stats:
		character_stats = CharacterStats.new()
		character_stats.character_name = "Guerrero"
	
	# USAR VELOCIDAD DEL PERSONAJE
	speed = character_stats.movement_speed
	current_health = character_stats.current_health
	
	# Configurar componentes
	setup_camera()
	setup_shooting()
	setup_audio_system()
	setup_collision()
	setup_walking_animations_from_stats()
	setup_weapon_renderer()
	
	if is_mobile:
		Engine.physics_ticks_per_second = 60

func set_score_system(score_sys: ScoreSystem):
	"""Establecer referencia al sistema de puntuación"""
	score_system = score_sys

func setup_weapon_renderer():
	"""Configurar el renderizador de arma"""
	weapon_renderer = WeaponRenderer.new()
	weapon_renderer.name = "WeaponRenderer"
	add_child(weapon_renderer)
	
	# Configurar referencia al jugador
	weapon_renderer.set_player_reference(self)
	
	# Si ya tenemos estadísticas de personaje con arma, configurarla
	if character_stats and character_stats.equipped_weapon:
		weapon_renderer.set_weapon_stats(character_stats.equipped_weapon)

func setup_collision():
	"""Configurar la forma de colisión basada en el sprite escalado a 128px"""
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var rect_shape = collision_shape.shape as RectangleShape2D
		rect_shape.size = Vector2(48, 80)
		collision_shape.position = Vector2(0, 8)

func setup_audio_system():
	audio_player = AudioStreamPlayer2D.new()
	audio_player.name = "AudioPlayer"
	audio_player.volume_db = 5.0
	audio_player.max_distance = 2000.0
	audio_player.attenuation = 1.0
	audio_player.bus = "Master"
	audio_player.finished.connect(_on_audio_finished)
	add_child(audio_player)
	
	if OS.has_feature("mobile"):
		audio_player.volume_db = 8.0
	
	# Cargar sonido de kill de Pelao acelerado
	if ResourceLoader.exists("res://audio/pelao_shoot.ogg"):
		pelao_kill_sound = load("res://audio/pelao_shoot.ogg")

func _on_audio_finished():
	is_audio_playing = false

func play_shoot_sound():
	var weapon_sound: AudioStream = null
	if character_stats and character_stats.equipped_weapon:
		weapon_sound = character_stats.equipped_weapon.attack_sound
	
	if not weapon_sound or not audio_player:
		return
	
	if is_mobile:
		if is_audio_playing:
			return
		
		if audio_player.stream != weapon_sound:
			audio_player.stream = weapon_sound
		
		if audio_player.stream:
			audio_player.play()
			is_audio_playing = true
	else:
		if not is_audio_playing:
			audio_player.stream = weapon_sound
			if audio_player.stream:
				audio_player.play()
				is_audio_playing = true

# NUEVO: Función para reproducir sonido de kill de Pelao
func play_pelao_kill_sound():
	"""Reproducir sonido de Pelao cuando mata enemigo (solo para Pelao)"""
	if not character_stats or character_stats.character_name.to_lower() != "pelao":
		return
	
	if not pelao_kill_sound or randf() > kill_sound_chance:
		return
	
	if is_audio_playing:
		return
	
	audio_player.stream = pelao_kill_sound
	audio_player.pitch_scale = 1.5  # Acelerar 1.5x
	audio_player.play()
	is_audio_playing = true

func setup_camera():
	if camera:
		camera.enabled = true
		camera.make_current()
		if is_mobile:
			camera.zoom = Vector2(1.8, 1.8)
		else:
			camera.zoom = Vector2(2.5, 2.5)
		setup_camera_limits()

func setup_camera_limits():
	if camera:
		camera.limit_left = int(camera_bounds.position.x)
		camera.limit_top = int(camera_bounds.position.y)
		camera.limit_right = int(camera_bounds.position.x + camera_bounds.size.x)
		camera.limit_bottom = int(camera_bounds.position.y + camera_bounds.size.y)

func setup_shooting():
	if shooting_component:
		shooting_component.bullet_fired.connect(_on_bullet_fired)

func _on_bullet_fired(bullet: Bullet, _direction: Vector2):
	bullets_fired += 1
	play_shoot_sound()
	
	# Iniciar animación de disparo del arma
	if weapon_renderer:
		weapon_renderer.start_shooting_animation()
	
	if bullet and bullet.sprite:
		bullet.modulate = Color.YELLOW

func take_damage(amount: int):
	"""Función para recibir daño de los enemigos"""
	if is_dead:
		return
	
	current_health -= amount
	current_health = max(current_health, 0)
	
	if character_stats:
		character_stats.current_health = current_health
	
	# Resetear racha de kills en el score system
	if score_system:
		score_system.reset_kill_streak()
	
	# Efecto visual de daño
	if animated_sprite:
		animated_sprite.modulate = Color.RED
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.3)
	
	# Emitir señal de cambio de vida
	health_changed.emit(current_health, character_stats.max_health if character_stats else 100)
	
	print("💔 Jugador recibe ", amount, " de daño. Vida: ", current_health)
	
	# Verificar muerte
	if current_health <= 0:
		die()

func die():
	"""Manejar la muerte del jugador"""
	if is_dead:
		return
	
	is_dead = true
	current_health = 0
	
	print("💀 JUGADOR HA MUERTO")
	
	# Detener movimiento
	velocity = Vector2.ZERO
	set_physics_process(false)
	
	# Efecto visual de muerte
	if animated_sprite:
		animated_sprite.modulate = Color.DARK_RED
		var death_tween = create_tween()
		death_tween.tween_property(animated_sprite, "modulate:a", 0.5, 1.0)
		death_tween.tween_property(animated_sprite, "scale", Vector2(1.5, 0.5), 1.0)
	
	# Emitir señal de muerte
	player_died.emit()

# NUEVO: Función para aplicar knockback al jugador
func apply_knockback(direction: Vector2, force: float):
	"""Aplicar knockback al jugador cuando recibe daño"""
	if is_dead:
		return
		
	if direction.length() > 0:
		velocity += direction.normalized() * force

# NUEVO: Función llamada cuando el jugador mata un enemigo
func on_enemy_killed():
	"""Llamada cuando el jugador mata un enemigo"""
	play_pelao_kill_sound()

func get_animation_state_from_movement(movement: Vector2) -> AnimationState:
	"""Convertir un vector de movimiento en un estado de animación de caminata"""
	if movement.length() < 0.1:
		return AnimationState.IDLE
	
	var angle = movement.angle()
	var degrees = rad_to_deg(angle)
	
	# Normalizar el ángulo para que esté entre 0 y 360
	if degrees < 0:
		degrees += 360
	
	# Determinar la dirección de caminata basada en el ángulo (SIN LEFT/RIGHT)
	if degrees >= 315 or degrees < 45:
		return AnimationState.WALK_DOWN_RIGHT
	elif degrees >= 45 and degrees < 135:
		if degrees >= 67.5 and degrees < 112.5:
			return AnimationState.WALK_DOWN
		elif degrees < 67.5:
			return AnimationState.WALK_DOWN_RIGHT
		else:
			return AnimationState.WALK_DOWN_LEFT
	elif degrees >= 135 and degrees < 225:
		return AnimationState.WALK_DOWN_LEFT
	elif degrees >= 225 and degrees < 315:
		if degrees >= 247.5 and degrees < 292.5:
			return AnimationState.WALK_UP
		elif degrees < 247.5:
			return AnimationState.WALK_UP_LEFT
		else:
			return AnimationState.WALK_UP_RIGHT
	
	return AnimationState.IDLE

func play_animation_for_state(state: AnimationState):
	"""Reproducir la animación correspondiente al estado con fallback"""
	var animation_name = get_animation_name_for_state(state)
	
	# Intentar reproducir la animación específica
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(animation_name):
		animated_sprite.play(animation_name)
		return
	
	# Si no existe, usar fallback
	var fallback_animation = get_fallback_animation(state)
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(fallback_animation):
		animated_sprite.play(fallback_animation)
		return
	
	# Último recurso: idle
	animated_sprite.play("idle")

func get_animation_name_for_state(state: AnimationState) -> String:
	"""Obtener el nombre de la animación para un estado dado"""
	match state:
		AnimationState.IDLE:
			return "idle"
		AnimationState.WALK_UP:
			return "walk_Up"
		AnimationState.WALK_DOWN:
			return "walk_Down"
		AnimationState.WALK_UP_LEFT:
			return "walk_Left_Up"
		AnimationState.WALK_UP_RIGHT:
			return "walk_Right_Up"
		AnimationState.WALK_DOWN_LEFT:
			return "walk_Left_Down"
		AnimationState.WALK_DOWN_RIGHT:
			return "walk_Right_Down"
		_:
			return "idle"

func get_fallback_animation(state: AnimationState) -> String:
	"""Obtener animación de fallback para direcciones faltantes"""
	match state:
		AnimationState.WALK_UP_LEFT:
			if animated_sprite.sprite_frames.has_animation("walk_Up"):
				return "walk_Up"
			elif animated_sprite.sprite_frames.has_animation("walk_Left_Down"):
				return "walk_Left_Down"
		
		AnimationState.WALK_UP_RIGHT:
			if animated_sprite.sprite_frames.has_animation("walk_Up"):
				return "walk_Up"
			elif animated_sprite.sprite_frames.has_animation("walk_Right_Down"):
				return "walk_Right_Down"
		
		AnimationState.WALK_DOWN_LEFT:
			if animated_sprite.sprite_frames.has_animation("walk_Down"):
				return "walk_Down"
			elif animated_sprite.sprite_frames.has_animation("walk_Right_Down"):
				return "walk_Right_Down"
		
		AnimationState.WALK_DOWN_RIGHT:
			if animated_sprite.sprite_frames.has_animation("walk_Down"):
				return "walk_Down"
		
		_:
			pass
	
	return "idle"

func _physics_process(delta):
	if is_dead:
		return
		
	handle_movement(delta)
	if not is_mobile:
		handle_shooting()
	else:
		handle_mobile_shooting()
	
	apply_movement_with_bounds()
	update_animation_state()
	update_weapon_position()

func update_weapon_position():
	"""Actualizar posición y rotación del arma"""
	if weapon_renderer:
		weapon_renderer.update_weapon_position_and_rotation(current_aim_direction)

func update_animation_state():
	"""Actualizar el estado de animación basado en el movimiento"""
	var new_state = get_animation_state_from_movement(velocity)
	
	# Solo cambiar si es diferente al estado actual
	if new_state != current_animation_state:
		current_animation_state = new_state
		play_animation_for_state(current_animation_state)
		
		# Actualizar orientación del sprite
		update_sprite_orientation()

func update_sprite_orientation():
	"""Actualizar la orientación horizontal del sprite basado en movimiento"""
	if velocity.x < -0.1 and facing_right:
		facing_right = false
		animated_sprite.flip_h = true
	elif velocity.x > 0.1 and not facing_right:
		facing_right = true
		animated_sprite.flip_h = false

func handle_movement(_delta: float):
	var input_vector = Vector2.ZERO
	
	if not is_mobile:
		if Input.is_action_pressed("move_left"):
			input_vector.x -= 1
		if Input.is_action_pressed("move_right"):
			input_vector.x += 1
		if Input.is_action_pressed("move_up"):
			input_vector.y -= 1
		if Input.is_action_pressed("move_down"):
			input_vector.y += 1
	else:
		if mobile_movement_direction.length() > 0.05:
			input_vector = mobile_movement_direction
		else:
			input_vector = Vector2.ZERO
	
	if input_vector.length() > 0:
		velocity = input_vector.normalized() * speed
		last_movement_direction = input_vector.normalized()
	else:
		velocity = Vector2.ZERO

func apply_movement_with_bounds():
	move_and_slide()
	
	var clamped_pos = Vector2(
		clamp(global_position.x, map_bounds.position.x, map_bounds.position.x + map_bounds.size.x),
		clamp(global_position.y, map_bounds.position.y, map_bounds.position.y + map_bounds.size.y)
	)
	
	if global_position != clamped_pos:
		global_position = clamped_pos
		if global_position.x <= map_bounds.position.x or global_position.x >= map_bounds.position.x + map_bounds.size.x:
			velocity.x = 0
		if global_position.y <= map_bounds.position.y or global_position.y >= map_bounds.position.y + map_bounds.size.y:
			velocity.y = 0

func handle_shooting():
	"""Manejo de disparo para desktop"""
	if not shooting_component:
		return
	
	var shoot_direction = Vector2.ZERO
	
	if Input.is_action_pressed("shoot_left"):
		shoot_direction.x -= 1
	if Input.is_action_pressed("shoot_right"):
		shoot_direction.x += 1
	if Input.is_action_pressed("shoot_up"):
		shoot_direction.y -= 1
	if Input.is_action_pressed("shoot_down"):
		shoot_direction.y += 1
	
	if shoot_direction != Vector2.ZERO:
		current_aim_direction = shoot_direction.normalized()
		
		# Usar posición del cañón para disparar
		var muzzle_position = global_position
		if weapon_renderer:
			muzzle_position = weapon_renderer.get_muzzle_world_position()
		
		shooting_component.try_shoot(current_aim_direction, muzzle_position)

func handle_mobile_shooting():
	"""Manejo de disparo para móvil - llamado desde GameManager"""
	pass

func mobile_shoot(direction: Vector2):
	"""Función para disparar desde móvil"""
	if shooting_component and direction.length() > 0:
		current_aim_direction = direction.normalized()
		
		# Usar posición del cañón para disparar
		var muzzle_position = global_position
		if weapon_renderer:
			muzzle_position = weapon_renderer.get_muzzle_world_position()
		
		shooting_component.try_shoot(current_aim_direction, muzzle_position)

func update_character_stats(new_stats: CharacterStats):
	"""Función para actualizar las estadísticas del personaje en tiempo de ejecución"""
	character_stats = new_stats
	speed = character_stats.movement_speed
	current_health = character_stats.current_health
	
	# Actualizar el ShootingComponent con las nuevas estadísticas del ARMA
	if shooting_component:
		shooting_component.update_stats_from_player()
	
	# NUEVO: Actualizar el WeaponRenderer con la nueva arma
	if weapon_renderer and character_stats.equipped_weapon:
		weapon_renderer.set_weapon_stats(character_stats.equipped_weapon)
	
	# Configurar animaciones con el nuevo sistema de 128px
	setup_walking_animations_from_stats()
	
	# Actualizar colisión para el nuevo tamaño
	setup_collision()

func setup_walking_animations_from_stats():
	"""Configurar las animaciones de caminata desde las estadísticas del personaje - OPTIMIZADO PARA 128px EN PARTIDA"""
	if not character_stats:
		create_default_sprite_frames_128px()
		return
	
	# Obtener el folder basado en el nombre del personaje del recurso
	var char_name = character_stats.character_name.to_lower().replace(" ", "")
	var folder_name = get_folder_name_from_character_name(char_name)
	
	# NUEVO: Intentar cargar SpriteFrames pre-configurado primero
	var sprite_frames_path = "res://sprites/player/" + folder_name + "/" + folder_name + "_animations.tres"
	var loaded_sprite_frames = load_sprite_frames_safe(sprite_frames_path)
	
	if loaded_sprite_frames:
		animated_sprite.sprite_frames = loaded_sprite_frames
		ensure_sprite_scaling_128px()
		animated_sprite.play("idle")
		return
	
	# Si no existe el .tres, crear desde atlas de caminata
	create_walking_sprite_frames_from_atlas_128px(folder_name)

func get_folder_name_from_character_name(char_name: String) -> String:
	"""Determinar el nombre de carpeta basado en el nombre del personaje"""
	# Mapeo básico para nombres conocidos
	var name_mappings = {
		"pelao": "pelao",
		"juancar": "juancar", 
		"juan_car": "juancar",
		"chica": "chica",
		"guerrerobásico": "pelao",
		"guerrerobasico": "pelao"
	}
	
	return name_mappings.get(char_name, char_name)

func load_sprite_frames_safe(path: String) -> SpriteFrames:
	"""Cargar SpriteFrames de forma segura"""
	if ResourceLoader.exists(path):
		var resource = load(path)
		if resource and resource is SpriteFrames:
			return resource as SpriteFrames
	return null

func create_walking_sprite_frames_from_atlas_128px(folder_name: String):
	"""Crear SpriteFrames desde atlas - SIEMPRE DESDE ATLAS CON FALLBACK A CHICA - 128px PARA PARTIDA"""
	var sprite_frames = SpriteFrames.new()
	
	# Lista de animaciones de caminata disponibles
	var walking_animations = [
		"walk_Up",
		"walk_Down", 
		"walk_Left_Up",
		"walk_Right_Up",
		"walk_Left_Down",
		"walk_Right_Down"
	]
	
	# CREAR IDLE SIEMPRE DESDE ATLAS - NUNCA DESDE SPRITE ESTÁTICO
	sprite_frames.add_animation("idle")
	sprite_frames.set_animation_speed("idle", 1.0)
	sprite_frames.set_animation_loop("idle", true)
	
	# Intentar cargar walk_Right_Down del personaje actual
	var walk_right_down_atlas = try_load_texture_safe("res://sprites/player/" + folder_name + "/walk_Right_Down.png")
	
	if walk_right_down_atlas:
		var idle_frame = extract_first_frame_from_atlas(walk_right_down_atlas)
		var scaled_idle = create_scaled_texture_dynamic(idle_frame)
		sprite_frames.add_frame("idle", scaled_idle)
	else:
		# FALLBACK: Usar walk_Right_Down de chica
		var chica_atlas = try_load_texture_safe("res://sprites/player/chica/walk_Right_Down.png")
		if chica_atlas:
			var idle_frame = extract_first_frame_from_atlas(chica_atlas)
			var scaled_idle = create_scaled_texture_dynamic(idle_frame)
			sprite_frames.add_frame("idle", scaled_idle)
		else:
			# Último recurso: textura por defecto
			sprite_frames.add_frame("idle", create_default_texture_dynamic(Color.CYAN))
	
	# Crear animaciones de caminata con fallback a chica
	for anim_name in walking_animations:
		# Intentar cargar del personaje actual
		var atlas_path = "res://sprites/player/" + folder_name + "/" + anim_name + ".png"
		var atlas_texture = try_load_texture_safe(atlas_path)
		
		# Si no existe, usar el de chica
		if not atlas_texture:
			var chica_path = "res://sprites/player/chica/" + anim_name + ".png"
			atlas_texture = try_load_texture_safe(chica_path)
		
		if atlas_texture:
			sprite_frames.add_animation(anim_name)
			sprite_frames.set_animation_speed(anim_name, 8.0)
			sprite_frames.set_animation_loop(anim_name, true)
			
			load_walking_animation_from_atlas_scaled_64px(sprite_frames, anim_name, atlas_texture)
	
	# Asignar el SpriteFrames al AnimatedSprite2D
	animated_sprite.sprite_frames = sprite_frames
	ensure_sprite_scaling_128px()
	animated_sprite.play("idle")

func load_walking_animation_from_atlas_scaled_64px(sprite_frames: SpriteFrames, anim_name: String, atlas_texture: Texture2D):
	"""Cargar animación de caminata desde atlas y preparar para escalar a 128px"""
	# Cargar frames normalmente
	load_frames_from_atlas(sprite_frames, anim_name, atlas_texture, 8, 1)
	
	# ESCALAR TODOS LOS FRAMES A 64px DE ALTO (que luego se escalan a 128px)
	scale_animation_frames_to_64px(sprite_frames, anim_name)

func scale_animation_frames_to_64px(sprite_frames: SpriteFrames, anim_name: String):
	"""Escalar todos los frames de una animación a 64px de alto"""
	var frame_count = sprite_frames.get_frame_count(anim_name)
	
	for i in range(frame_count):
		var original_frame = sprite_frames.get_frame_texture(anim_name, i)
		if original_frame:
			var scaled_frame = create_scaled_texture_dynamic(original_frame)
			sprite_frames.set_frame(anim_name, i, scaled_frame)

func create_scaled_texture_dynamic(original_texture: Texture2D, target_height: int = 64) -> Texture2D:
	"""Crear una versión escalada de la textura al alto objetivo"""
	if not original_texture:
		return create_default_texture_dynamic(Color.MAGENTA, target_height)
	
	var original_size = original_texture.get_size()
	
	# Si ya tiene el alto objetivo, retornar original
	if original_size.y == target_height:
		return original_texture
	
	# Calcular nueva escala manteniendo proporción
	var scale_factor = float(target_height) / float(original_size.y)
	var new_width = int(float(original_size.x) * scale_factor)
	var new_height = target_height
	
	# Crear nueva imagen escalada
	var original_image = original_texture.get_image()
	var scaled_image = original_image.duplicate()
	scaled_image.resize(new_width, new_height, Image.INTERPOLATE_NEAREST)
	
	var scaled_texture = ImageTexture.create_from_image(scaled_image)
	
	return scaled_texture

func create_default_texture_dynamic(color: Color, texture_size: int = 64) -> Texture2D:
	"""Crear una textura por defecto del tamaño especificado"""
	var image = Image.create(texture_size, texture_size, false, Image.FORMAT_RGBA8)
	image.fill(color)
	
	# Agregar algunos detalles básicos escalados
	var center = Vector2(float(texture_size) / 2.0, float(texture_size) / 2.0)
	var detail_radius = float(texture_size) / 8.0
	
	for x in range(texture_size):
		for y in range(texture_size):
			var dist = Vector2(x, y).distance_to(center)
			if dist < detail_radius:
				image.set_pixel(x, y, Color.WHITE)
			elif dist < detail_radius * 1.5:
				image.set_pixel(x, y, color.darkened(0.3))
	
	return ImageTexture.create_from_image(image)

func ensure_sprite_scaling_128px():
	"""Asegurar que el sprite del jugador tenga 128px de alto dinámicamente"""
	if not animated_sprite:
		return
	
	# Obtener textura actual para medir
	var current_texture: Texture2D = null
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("idle"):
		current_texture = animated_sprite.sprite_frames.get_frame_texture("idle", 0)
	
	if current_texture:
		var current_height = current_texture.get_size().y
		var target_height = 128.0
		
		# Solo escalar si no tiene ya 128px
		if current_height != target_height:
			var scale_factor = target_height / float(current_height)
			animated_sprite.scale = Vector2(scale_factor, scale_factor)
		else:
			animated_sprite.scale = Vector2(1.0, 1.0)
	else:
		# Escala por defecto si no hay textura
		animated_sprite.scale = Vector2(4.0, 4.0)

func create_default_sprite_frames_128px():
	"""Crear SpriteFrames por defecto optimizado para 128px EN PARTIDA"""
	var sprite_frames = SpriteFrames.new()
	
	# Crear animación idle por defecto
	sprite_frames.add_animation("idle")
	sprite_frames.set_animation_speed("idle", 1.0)
	sprite_frames.set_animation_loop("idle", true)
	
	var default_texture = create_default_texture_dynamic(Color.BLUE, 64)
	sprite_frames.add_frame("idle", default_texture)
	
	# Crear animaciones de caminata básicas
	var basic_walk_animations = ["walk_Up", "walk_Down", "walk_Left_Down", "walk_Right_Down"]
	
	for anim_name in basic_walk_animations:
		sprite_frames.add_animation(anim_name)
		sprite_frames.set_animation_speed(anim_name, 8.0)
		sprite_frames.set_animation_loop(anim_name, true)
		
		# Crear 4 frames por animación con colores ligeramente diferentes
		for frame_idx in range(4):
			var frame_color = Color.BLUE.lightened(float(frame_idx) * 0.1)
			var frame_texture = create_default_texture_dynamic(frame_color, 64)
			sprite_frames.add_frame(anim_name, frame_texture)
	
	animated_sprite.sprite_frames = sprite_frames
	ensure_sprite_scaling_128px()
	animated_sprite.play("idle")

func try_load_texture_safe(path: String) -> Texture2D:
	"""Función para cargar texturas de forma segura"""
	if not ResourceLoader.exists(path):
		return null
	
	var resource = load(path)
	if resource is Texture2D:
		return resource as Texture2D
	else:
		return null

func extract_first_frame_from_atlas(atlas_texture: Texture2D) -> Texture2D:
	"""Extraer el primer frame de un atlas de 8x1"""
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
		var y = float(i / h_frames) * frame_height
		
		var atlas_frame = AtlasTexture.new()
		atlas_frame.atlas = atlas_texture
		atlas_frame.region = Rect2(x, y, frame_width, frame_height)
		
		sprite_frames.add_frame(anim_name, atlas_frame)

func set_mobile_movement_direction(direction: Vector2):
	"""Función para establecer la dirección de movimiento desde el joystick móvil"""
	mobile_movement_direction = direction

func get_current_health() -> int:
	"""Obtener la vida actual del jugador"""
	return current_health

func get_max_health() -> int:
	"""Obtener la vida máxima del jugador"""
	if character_stats:
		return character_stats.max_health
	return 100

func heal(amount: int):
	"""Curar al jugador"""
	if is_dead:
		return
		
	current_health += amount
	var max_hp = get_max_health()
	current_health = min(current_health, max_hp)
	
	if character_stats:
		character_stats.current_health = current_health
	
	health_changed.emit(current_health, max_hp)

func is_player_dead() -> bool:
	"""Verificar si el jugador está muerto"""
	return is_dead
