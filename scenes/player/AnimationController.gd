# AnimationController.gd - SISTEMA DE ANIMACIÓN CORREGIDO CON ÁNGULOS ESPECÍFICOS
extends Node
class_name AnimationController

var animated_sprite: AnimatedSprite2D
var sprite_frames: SpriteFrames
var character_name: String
var is_system_ready: bool = false

# Atlas completos
var walk_right_down_atlas: Texture2D
var walk_right_up_atlas: Texture2D
var walk_left_up_atlas: Texture2D
var walk_left_down_atlas: Texture2D

# Estado de animación
var current_animation: String = "idle"
var is_melee_attacking: bool = false
var last_aim_direction: Vector2 = Vector2.RIGHT

func setup(sprite: AnimatedSprite2D, char_name: String):
	animated_sprite = sprite
	character_name = char_name
	
	load_atlases()
	create_directional_animations()

func load_atlases():
	"""Cargar los cuatro atlas principales"""
	var folder = get_character_folder_name()
	
	walk_right_down_atlas = load_texture_safe("res://sprites/player/" + folder + "/walk_Right_Down.png")
	walk_right_up_atlas = load_texture_safe("res://sprites/player/" + folder + "/walk_Right_Up.png")
	walk_left_up_atlas = load_texture_safe("res://sprites/player/" + folder + "/walk_Left_Up.png")
	walk_left_down_atlas = load_texture_safe("res://sprites/player/" + folder + "/walk_Left_Down.png")
	
	# Fallback a chica si no encuentra
	if not walk_right_down_atlas:
		walk_right_down_atlas = load_texture_safe("res://sprites/player/chica/walk_Right_Down.png")
	if not walk_right_up_atlas:
		walk_right_up_atlas = load_texture_safe("res://sprites/player/chica/walk_Right_Up.png")
	if not walk_left_up_atlas:
		walk_left_up_atlas = load_texture_safe("res://sprites/player/chica/walk_Left_Up.png")
	if not walk_left_down_atlas:
		walk_left_down_atlas = load_texture_safe("res://sprites/player/chica/walk_Left_Down.png")

func load_texture_safe(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func create_directional_animations():
	"""Crear animaciones direccionales completas"""
	if not animated_sprite:
		return
	
	sprite_frames = SpriteFrames.new()
	
	# IDLE (primer frame de walk_right_down)
	sprite_frames.add_animation("idle")
	sprite_frames.set_animation_speed("idle", 1.0)
	sprite_frames.set_animation_loop("idle", false)
	if walk_right_down_atlas:
		var first_frame = extract_frame(walk_right_down_atlas, 0)
		sprite_frames.add_frame("idle", first_frame)
	
	# WALK_RIGHT_DOWN (1° a 89°)
	sprite_frames.add_animation("walk_right_down")
	sprite_frames.set_animation_speed("walk_right_down", 12.0)
	sprite_frames.set_animation_loop("walk_right_down", true)
	if walk_right_down_atlas:
		for i in range(8):
			var frame = extract_frame(walk_right_down_atlas, i)
			sprite_frames.add_frame("walk_right_down", frame)
	
	# WALK_RIGHT_UP (90° a 179°)
	sprite_frames.add_animation("walk_right_up")
	sprite_frames.set_animation_speed("walk_right_up", 12.0)
	sprite_frames.set_animation_loop("walk_right_up", true)
	if walk_right_up_atlas:
		for i in range(8):
			var frame = extract_frame(walk_right_up_atlas, i)
			sprite_frames.add_frame("walk_right_up", frame)
	
	# WALK_LEFT_UP (180° a 270°)
	sprite_frames.add_animation("walk_left_up")
	sprite_frames.set_animation_speed("walk_left_up", 12.0)
	sprite_frames.set_animation_loop("walk_left_up", true)
	if walk_left_up_atlas:
		for i in range(8):
			var frame = extract_frame(walk_left_up_atlas, i)
			sprite_frames.add_frame("walk_left_up", frame)
	
	# WALK_LEFT_DOWN (271° a 0°)
	sprite_frames.add_animation("walk_left_down")
	sprite_frames.set_animation_speed("walk_left_down", 12.0)
	sprite_frames.set_animation_loop("walk_left_down", true)
	if walk_left_down_atlas:
		for i in range(8):
			var frame = extract_frame(walk_left_down_atlas, i)
			sprite_frames.add_frame("walk_left_down", frame)
	
	# Asignar y configurar
	animated_sprite.sprite_frames = sprite_frames
	animated_sprite.play("idle")
	animated_sprite.pause()
	is_system_ready = true

func extract_frame(atlas: Texture2D, frame_index: int) -> Texture2D:
	var frame_width = 128.0
	var x_offset = float(frame_index) * frame_width
	
	var atlas_frame = AtlasTexture.new()
	atlas_frame.atlas = atlas
	atlas_frame.region = Rect2(x_offset, 0, frame_width, 128.0)
	
	return atlas_frame

# FUNCIÓN PRINCIPAL: ANIMACIÓN COMBINADA MOVIMIENTO + DISPARO CON ÁNGULOS ESPECÍFICOS
func update_animation_combined(movement: Vector2, aim_direction: Vector2):
	"""SISTEMA CON ÁNGULOS ESPECÍFICOS SEGÚN ESPECIFICACIONES"""
	if not is_system_ready:
		return
	
	# Si está en melee, no cambiar animación hasta que termine
	if is_melee_attacking:
		return
	
	var is_moving = movement.length() > 0.1
	var is_aiming = aim_direction.length() > 0.1
	
	# DETERMINAR DIRECCIÓN PRINCIPAL PARA ANIMACIÓN
	var animation_direction = Vector2.ZERO
	
	if is_aiming:
		# PRIORIDAD 1: Dirección de aim/disparo
		animation_direction = aim_direction.normalized()
		last_aim_direction = animation_direction
	elif is_moving:
		# PRIORIDAD 2: Dirección de movimiento
		animation_direction = movement.normalized()
	else:
		# PRIORIDAD 3: Mantener última dirección de aim
		animation_direction = last_aim_direction
	
	# APLICAR ANIMACIÓN BASÁNDOSE EN LA DIRECCIÓN PRINCIPAL
	if is_moving or is_aiming:
		# DETERMINAR ANIMACIÓN SEGÚN ÁNGULOS ESPECÍFICOS
		var animation_name = determine_animation_by_exact_angles(animation_direction)
		
		# APLICAR ANIMACIÓN SIN FLIP (ya está manejado por los atlas específicos)
		play_animation(animation_name)
		animated_sprite.flip_h = false  # Los atlas ya manejan la orientación
	else:
		# IDLE
		play_animation("idle")
		animated_sprite.pause()

func determine_animation_by_exact_angles(direction: Vector2) -> String:
	"""Determinar animación según ángulos específicos"""
	var angle = direction.angle()
	var angle_degrees = rad_to_deg(angle)
	
	# Normalizar ángulo a 0-360
	if angle_degrees < 0:
		angle_degrees += 360
	
	# APLICAR ÁNGULOS ESPECÍFICOS SEGÚN ESPECIFICACIONES
	if angle_degrees >= 1 and angle_degrees <= 89:
		# 1° a 89° - DERECHA ABAJO
		return "walk_right_down"
	elif angle_degrees >= 90 and angle_degrees <= 179:
		# 90° a 179° - DERECHA ARRIBA
		return "walk_right_up"
	elif angle_degrees >= 180 and angle_degrees <= 270:
		# 180° a 270° - IZQUIERDA ARRIBA
		return "walk_left_up"
	elif angle_degrees >= 271 and angle_degrees <= 360:
		# 271° a 360° - IZQUIERDA ABAJO
		return "walk_left_down"
	elif angle_degrees >= 0 and angle_degrees < 1:
		# 0° (exacto) - DERECHA ABAJO
		return "walk_right_down"
	else:
		# Fallback
		return "walk_right_down"

# FUNCIÓN BACKWARD COMPATIBILITY
func update_animation_by_shooting_direction(movement: Vector2, shooting: Vector2):
	"""BACKWARD COMPATIBILITY: llamar a la función principal"""
	update_animation_combined(movement, shooting)

func start_melee_animation():
	"""Iniciar animación de melee"""
	if not is_system_ready or is_melee_attacking:
		return
	
	is_melee_attacking = true
	current_animation = "melee_attack"
	
	# Cambiar sprite a versión más agresiva (usar primer frame con tinte rojo)
	if animated_sprite:
		animated_sprite.modulate = Color(1.3, 0.8, 0.8, 1.0)
	
	# Timer para finalizar animación de melee
	var melee_timer = Timer.new()
	melee_timer.wait_time = 0.5
	melee_timer.one_shot = true
	melee_timer.timeout.connect(_finish_melee_animation)
	add_child(melee_timer)
	melee_timer.start()

func _finish_melee_animation():
	"""Finalizar animación de melee"""
	is_melee_attacking = false
	
	# Restaurar color normal
	if animated_sprite:
		animated_sprite.modulate = Color.WHITE
	
	# Volver a idle
	play_animation("idle")
	animated_sprite.pause()
	
	# Limpiar timer
	var melee_timer = get_node_or_null("Timer")
	if melee_timer:
		melee_timer.queue_free()

func play_animation(anim_name: String):
	"""Reproducir animación con verificaciones"""
	if not is_system_ready:
		return
	
	# No interrumpir melee
	if is_melee_attacking and anim_name != "melee_attack":
		return
	
	if animated_sprite.animation != anim_name:
		current_animation = anim_name
		animated_sprite.play(anim_name)

func force_animation(anim_name: String):
	"""Forzar animación específica"""
	if not is_system_ready:
		return
	
	is_melee_attacking = false
	current_animation = anim_name
	animated_sprite.play(anim_name)

func reset_animation_state():
	"""Resetear estado de animación"""
	is_melee_attacking = false
	current_animation = "idle"
	last_aim_direction = Vector2.RIGHT
	
	if is_system_ready:
		animated_sprite.play("idle")
		animated_sprite.pause()
		animated_sprite.flip_h = false
		animated_sprite.modulate = Color.WHITE

func get_character_folder_name() -> String:
	var char_name_lower = character_name.to_lower()
	match char_name_lower:
		"pelao": return "pelao"
		"juancar": return "juancar" 
		"chica": return "chica"
		_: return "chica"

func is_playing_melee() -> bool:
	"""Verificar si está reproduciendo animación de melee"""
	return is_melee_attacking

func get_current_animation() -> String:
	"""Obtener animación actual"""
	return current_animation

func update_animation_for_movement(movement_direction: Vector2, aim_direction: Vector2):
	"""COMPATIBILITY: Actualizar animación para movimiento"""
	update_animation_combined(movement_direction, aim_direction)

func update_animation_for_movement_with_melee(movement_direction: Vector2, aim_direction: Vector2, is_melee: bool):
	"""COMPATIBILITY: Nueva función que incluye melee"""
	if is_melee and not is_melee_attacking:
		start_melee_animation()
		return
	
	update_animation_combined(movement_direction, aim_direction)

func set_character_direction(direction: Vector2):
	"""Establecer dirección del personaje para idle"""
	if direction.length() > 0.1:
		last_aim_direction = direction.normalized()

func get_current_facing_direction() -> Vector2:
	"""Obtener dirección actual hacia la que mira el personaje"""
	return last_aim_direction

func is_facing_left() -> bool:
	"""Verificar si está mirando hacia la izquierda"""
	return false  # Ya no usamos flip_h

func is_facing_right() -> bool:
	"""Verificar si está mirando hacia la derecha"""
	return true  # Ya no usamos flip_h

func _exit_tree():
	"""Limpiar al salir"""
	is_system_ready = false
	is_melee_attacking = false
	
	# Limpiar timers
	var melee_timer = get_node_or_null("Timer")
	if melee_timer:
		melee_timer.queue_free()
